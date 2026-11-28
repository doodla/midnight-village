#!/usr/bin/env python3
"""A guard counts only if a recorded deliberate break proves it bites.

    just prove-guards                    every break this machine can run
    just prove-guards <name>...          only those
    just prove-guards --list             the breaks, their promises and their killers
    just prove-guards --reached          only the breaks whose promise this change touches
                                  (what `just handover` runs)
    just prove-guards --runner backend,guardrails,cmd   only breaks of those kinds
                                  (GitHub: "Backend Checks"; flutter: "Analyze and Format")

Each break (tool/breaks_server.py, breaks_tools.py, breaks_app.py) is a small realistic
mistake, the CLAUDE.md promise it breaks, and the focused tests that must FAIL on it. Each
is put into a throwaway copy of the tree (never this checkout), its tests are run there,
and the copy is put back. `just prove-guards` fails when:

- a break survives (its tests pass with the mistake in);
- a break no longer applies (the code it lands in moved: update it);
- a break's run is broken rather than failed (a collection or compile error proves
  nothing);
- a break marked `survives` is now killed (take the mark off);
- a file marked `Guard file` is the killer of no break: every guard arrives with the
  break it catches. The guards that came before this rule are listed in
  `NOT_YET_PROVED` (tool/breaks_tools.py), which only shrinks.

usage: tool/prove_guards.py [--list] [--reached] [--runner kinds] [--jobs n] [name...]
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from queue import Queue

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from change_base import change_base  # noqa: E402
from guard_edits import is_guard  # noqa: E402
from breaks_app import APP  # noqa: E402
from breaks_kit import PROMISES, Break, NoLongerApplies, apply_edit  # noqa: E402
from breaks_server import SERVER  # noqa: E402
from breaks_tools import NOT_YET_PROVED, TOOLS  # noqa: E402

BREAKS: tuple[Break, ...] = SERVER + TOOLS + APP
RUNNERS = ("backend", "guardrails", "cmd", "flutter")
# what a copy needs beyond the tracked files to run the tests
EXTRAS = (
    "backend/.env",
    "frontend/.dart_tool/package_config.json",
    "frontend/.dart_tool/package_graph.json",
    "frontend/.dart_tool/version",
)
PYTEST = [
    "-x",
    "-q",
    "--no-cov",
    "-p",
    "no:cacheprovider",
    "-o",
    "addopts=",
    "--nomigrations",
    "--strict-markers",
]
FLUTTER = ["--dart-define=ENV=dev", "--reporter", "failures-only"]
TAIL = 12


def git(root: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(root), *args], capture_output=True, text=True, check=True
    ).stdout


# ---- the rules on the list itself ----------------------------------------------------


def guard_files(root: Path = ROOT) -> list[str]:
    names = git(root, "ls-files", "-z", "--cached", "--others", "--exclude-standard")
    found = []
    for name in sorted(set(filter(None, names.split("\0")))):
        path = root / name
        if path.suffix in (".py", ".dart", ".sh") and path.is_file():
            if is_guard(path.read_text(errors="replace")):
                found.append(name)
    return found


def list_problems(breaks, guards: list[str], debt, was_guard=None, root: Path = ROOT):
    """What is wrong with the list, before anything runs. `was_guard(path)` says whether
    a path was a guard on the main this change left (None: not known)."""
    problems = []
    names = [m.name for m in breaks]
    for name in sorted({n for n in names if names.count(n) > 1}):
        problems.append(f"two breaks are named {name}")
    for m in breaks:
        if m.promise not in PROMISES:
            problems.append(
                f"{m.name}: no promise named {m.promise!r} (breaks_kit.PROMISES)"
            )
        if not (m.tests or m.command):
            problems.append(f"{m.name}: names no tests and no command")
        for path in m.files():
            if not (root / path).exists():
                problems.append(f"{m.name}: {path} does not exist: update the break")
    bitten = {k for m in breaks if not m.survives for k in m.killers()}
    for guard in guards:
        if guard not in bitten and guard not in debt:
            problems.append(
                f"{guard} is a guard with no recorded break: add a break it kills"
                " (tool/breaks_*.py), so it is proved to bite"
            )
    for path in sorted(debt):
        if path in bitten:
            problems.append(f"{path} now kills a break: take it off NOT_YET_PROVED")
        elif path not in guards:
            problems.append(f"{path} is no guard now: take it off NOT_YET_PROVED")
        elif was_guard is not None and not was_guard(path):
            problems.append(
                f"{path} is a new guard: it arrives with its break, NOT_YET_PROVED only shrinks"
            )
    return problems


def was_guard_on(base: str | None):
    if base is None:
        return None

    def check(path: str) -> bool:
        try:
            return is_guard(git(ROOT, "show", f"{base}:{path}"))
        except subprocess.CalledProcessError:
            return False

    return check


# ---- which breaks -----------------------------------------------------------------


def changed_files(base: str) -> list[str]:
    tracked = git(ROOT, "diff", "--name-only", "--no-renames", base).split()
    loose = git(ROOT, "ls-files", "--others", "--exclude-standard").split()
    return sorted(set(tracked + loose))


def reached(breaks, changed: list[str]):
    """The breaks whose promise, files or killers the change touches."""
    out = []
    for m in breaks:
        paths = PROMISES[m.promise][1]
        if any(c in m.files() or c.startswith(paths) for c in changed):
            out.append(m)
    return out


def can_run(runner: str) -> bool:
    return runner != "flutter" or shutil.which("flutter") is not None


# ---- the copy and the run ----------------------------------------------------------


def make_copy(dest: Path) -> None:
    names = git(ROOT, "ls-files", "-z", "--cached", "--others", "--exclude-standard")
    for name in [*filter(None, names.split("\0")), *EXTRAS]:
        source = ROOT / name
        if source.is_file() and not source.is_symlink():
            target = dest / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    quiet = {"capture_output": True, "check": True, "cwd": dest}
    subprocess.run(["git", "init", "-q"], **quiet)
    subprocess.run(["git", "add", "-A"], **quiet)
    subprocess.run(
        [
            "git",
            "-c",
            "user.name=prove-guards",
            "-c",
            "user.email=prove-guards@localhost",
            "commit",
            "-q",
            "--no-verify",
            "-m",
            "the tree as it stands",
        ],
        **quiet,
    )


def commands(m: Break, copy: Path) -> list[tuple[Path, list[str]]]:
    runner = m.runner()
    if runner == "cmd":
        return [(copy, list(m.command))]
    if runner == "backend":
        python = str(ROOT / "backend" / ".venv" / "bin" / "python")
        ids = [t.removeprefix("backend/") for t in m.tests]
        return [(copy / "backend", [python, "-m", "pytest", *PYTEST, *ids])]
    if runner == "flutter":
        out = []
        for test in m.tests:
            path, _, plain = test.removeprefix("frontend/").partition("::")
            name = ["--plain-name", plain] if plain else []
            out.append((copy / "frontend", ["flutter", "test", *FLUTTER, *name, path]))
        return out
    out = []
    for test in m.tests:
        path, _, only = test.partition("::")
        folder = str(Path(path).parent)
        pick = ["-k", only] if only else []
        out.append(
            (
                copy,
                [
                    sys.executable,
                    "-m",
                    "unittest",
                    "discover",
                    "-q",
                    "-s",
                    folder,
                    "-t",
                    folder,
                    "-p",
                    Path(path).name,
                    *pick,
                ],
            )
        )
    return out


def resample_command() -> list[str]:
    python = str(ROOT / "backend" / ".venv" / "bin" / "python")
    return [python, "-m", "pytest", *PYTEST, "tests/contract/test_contract_samples.py"]


def broken(runner: str, code: int, output: str) -> bool:
    """A run that proves nothing: it did not get as far as a test failing."""
    if runner == "backend":
        return code not in (0, 1)
    if runner == "flutter":
        return "Failed to load" in output or "Compilation failed" in output
    if runner == "guardrails":
        return code not in (0, 1) or "ImportError" in output
    return False


def run_one(m: Break, copy: Path) -> dict:
    started = time.monotonic()
    saved: dict[Path, str] = {}
    try:
        for edit in m.edits:
            path = copy / edit.path
            text = saved.get(path) or path.read_text()
            saved.setdefault(path, text)
            path.write_text(apply_edit(path.read_text(), edit))
    except NoLongerApplies as problem:
        for path, text in saved.items():
            path.write_text(text)
        return {
            "name": m.name,
            "status": "no longer applies",
            "seconds": 0,
            "tail": f"break no longer applies: update it. {problem}",
        }
    status, tail = "survived", ""
    env = {
        **os.environ,
        **dict(m.env),
        "HEAVY_SLOT": os.environ.get("HEAVY_SLOT", "prove-guards"),
    }
    env.pop("VIRTUAL_ENV", None)
    try:
        if m.resample:
            subprocess.run(resample_command(), cwd=copy / "backend", capture_output=True,
                           env={**env, "UPDATE_CONTRACT_SAMPLES": "1"})
        for folder, argv in commands(m, copy):
            done = subprocess.run(
                argv,
                cwd=folder,
                env=env,
                capture_output=True,
                text=True,
                errors="replace",
            )
            output = done.stdout + done.stderr
            if broken(m.runner(), done.returncode, output):
                status, tail = "broken", output
                break
            if done.returncode != 0:
                status, tail = "killed", output
                break
            tail = output
    finally:
        for path, text in saved.items():
            path.write_text(text)
        if m.resample:
            subprocess.run(["git", "checkout", "-q", "--", "contract_samples"], cwd=copy)
            subprocess.run(["git", "clean", "-fdq", "--", "contract_samples"], cwd=copy)
    last = "\n".join(tail.strip().splitlines()[-TAIL:])
    return {
        "name": m.name,
        "status": status,
        "seconds": round(time.monotonic() - started),
        "tail": last,
    }


def verdict(m: Break, result: dict) -> str | None:
    status = result["status"]
    if m.survives:
        if status == "killed":
            return f"{m.name} is killed now: take its `survives` mark off"
        return None if status == "survived" else f"{m.name}: {status}"
    if status == "killed":
        return None
    if status == "survived":
        return (
            f"{m.name} SURVIVED: {', '.join(m.killers())} did not fail on it ({m.why})"
        )
    return f"{m.name}: {status}"


def run_all(breaks, jobs: int) -> list[dict]:
    copies: Queue = Queue()
    scratch = Path(tempfile.mkdtemp(prefix="prove-guards-"))
    try:
        for number in range(min(jobs, len(breaks))):
            folder = scratch / str(number)
            make_copy(folder)
            copies.put(folder)

        def work(m: Break) -> dict:
            folder = copies.get()
            try:
                result = run_one(m, folder)
            finally:
                copies.put(folder)
            problem = verdict(m, result)
            mark = "ok" if problem is None else "FAIL"
            print(
                f"  {mark:4} {m.name:42} {result['status']:18} {result['seconds']:4} s",
                flush=True,
            )
            if problem:
                print("       " + problem)
                print(
                    "\n".join(
                        f"       | {line[:160]}" for line in result["tail"].splitlines()
                    )
                )
            return {**result, "problem": problem}

        with ThreadPoolExecutor(max_workers=max(1, jobs)) as pool:
            return list(pool.map(work, breaks))
    finally:
        shutil.rmtree(scratch, ignore_errors=True)


def show_list(breaks) -> None:
    for m in breaks:
        mark = f"  (survives: {m.survives})" if m.survives else ""
        print(f"{m.name:42} {m.promise:22} {', '.join(m.killers())}{mark}")


def main(argv: list[str]) -> int:
    args = list(argv)

    def option(flag: str) -> str | None:
        if flag in args:
            value = args[args.index(flag) + 1]
            del args[args.index(flag) : args.index(flag) + 2]
            return value
        return None

    runners = (option("--runner") or ",".join(RUNNERS)).split(",")
    jobs = int(
        option("--jobs")
        or os.environ.get("TEETH_JOBS")
        or (os.cpu_count() if os.environ.get("CI") else 2)
        or 2
    )
    flags = {a for a in args if a.startswith("--")}
    names = [a for a in args if not a.startswith("--")]
    base = change_base(ROOT, "origin/main")
    problems = list_problems(BREAKS, guard_files(), NOT_YET_PROVED, was_guard_on(base))
    for problem in problems:
        print(f"prove-guards: {problem}")
    if "--list" in flags:
        show_list(BREAKS)
        return 1 if problems else 0
    unknown = [n for n in names if n not in {m.name for m in BREAKS}]
    if unknown:
        print(f"prove-guards: no break named {', '.join(unknown)} (`just prove-guards --list`)")
        return 1
    chosen = [m for m in BREAKS if not names or m.name in names]
    if "--reached" in flags:
        chosen = reached(chosen, changed_files(base)) if base else chosen
    chosen = [m for m in chosen if m.runner() in runners or (names and m.name in names)]
    skipped = [m for m in chosen if not can_run(m.runner())]
    chosen = [m for m in chosen if can_run(m.runner())]
    for m in skipped:
        print(f"prove-guards: {m.name} skipped: no {m.runner()} here (GitHub runs it)")
    started = time.monotonic()
    print(f"prove-guards: {len(chosen)} breaks, {jobs} at a time, each in a copy of the tree")
    results = run_all(chosen, jobs) if chosen else []
    failed = [r["problem"] for r in results if r["problem"]]
    kept = [m.name for m in chosen if m.survives]
    print(
        f"prove-guards: {len(chosen)} run in {time.monotonic() - started:.0f} s;"
        f" {len(failed)} failing; known survivors: {', '.join(kept) or 'none'}"
    )
    for problem in failed + problems:
        print(f"prove-guards: FAIL {problem}")
    return 1 if failed or problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
