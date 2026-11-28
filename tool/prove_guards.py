#!/usr/bin/env python3
# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
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
- a break's run is broken: it ended without a named killer test failing an assertion
  (tool/breaks_verdict.py: a crash, an import error or a command that cannot start
  proves nothing);
- a break marked `survives` is now killed (take the mark off);
- a file marked `Guard file` kills no break, or every break naming it ran and none saw a
  test in it fail;
- the list grew where it may only shrink (tool/breaks_rules.py), or a break cannot run
  on GitHub (no Flutter where Flutter breaks are asked for).

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
import breaks_verdict as verdicts  # noqa: E402
from breaks_app import APP  # noqa: E402
from breaks_kit import PROMISES, Break, NoLongerApplies, apply_edit  # noqa: E402
from breaks_rules import (  # noqa: E402
    git,
    guard_files,
    imports,
    list_problems,
    lists_at,
    shrink_problems,
    was_guard_on,
)
from breaks_server import SERVER  # noqa: E402
from breaks_tools import NOT_YET_PROVED, TOOLS  # noqa: E402
from change_base import change_base  # noqa: E402

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
JUNIT = "prove-guards-junit.xml"
TAIL = 12
STEP = (
    "the deliberate breaks this change reaches",
    ".",
    ["tool/prove_guards.py", "--reached"],
)


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


def handover_steps(changed: list[str]) -> list[tuple[str, str, list[str]]]:
    """`just handover`'s step: the breaks of the promises the change touches."""
    return [STEP] if reached(BREAKS, changed) else []


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


def python() -> str:
    return str(ROOT / "backend" / ".venv" / "bin" / "python")


def commands(m: Break, copy: Path) -> list[tuple[Path, list[str], str]]:
    """(folder, argv, the killer file it runs) for each command of the break."""
    runner = m.runner()
    if runner == "cmd":
        return [(copy, list(m.command), m.command[0])]
    if runner == "backend":
        ids = [t.removeprefix("backend/") for t in m.tests]
        argv = [python(), "-m", "pytest", *PYTEST, f"--junitxml={JUNIT}", *ids]
        return [(copy / "backend", argv, "")]
    out = []
    for test in m.tests:
        path, _, only = test.partition("::")
        if runner == "flutter":
            name = ["--plain-name", only] if only else []
            argv = ["flutter", "test", *FLUTTER, *name, path.removeprefix("frontend/")]
            out.append((copy / "frontend", argv, path))
            continue
        folder = str(Path(path).parent)
        argv = [
            sys.executable,
            "-m",
            "unittest",
            "discover",
            "-s",
            folder,
            "-t",
            folder,
            "-p",
            Path(path).name,
            *(["-k", only] if only else []),
        ]
        out.append((copy, argv, path))
    return out


def judge(m: Break, code: int, output: str, killer: str, folder: Path):
    runner = m.runner()
    if runner == "backend":
        report = folder / JUNIT
        junit = report.read_text() if report.is_file() else None
        report.unlink(missing_ok=True)
        return verdicts.backend(
            code, junit, [k for k in m.killers() if k.endswith(".py")]
        )
    if runner == "guardrails":
        return verdicts.guardrails(code, output, killer)
    if runner == "flutter":
        return verdicts.flutter(code, output, killer)
    return verdicts.command(code, output, m.expect, killer)


def resample(copy: Path, env: dict) -> str | None:
    """Re-record the samples in the copy; why it failed, or None."""
    argv = [
        python(),
        "-m",
        "pytest",
        *PYTEST,
        "tests/contract/test_contract_samples.py",
    ]
    done = subprocess.run(
        argv,
        cwd=copy / "backend",
        capture_output=True,
        text=True,
        env={**env, "UPDATE_CONTRACT_SAMPLES": "1"},
    )
    if done.returncode == 0:
        return None
    return "re-recording the samples failed: " + (done.stdout + done.stderr)[-300:]


def run_one(m: Break, copy: Path) -> dict:
    started = time.monotonic()
    saved: dict[Path, str] = {}
    result = {
        "name": m.name,
        "status": "survived",
        "failed": set(),
        "why": "",
        "tail": "",
    }
    try:
        for edit in m.edits:
            path = copy / edit.path
            if path not in saved:
                saved[path] = path.read_text()
            path.write_text(apply_edit(path.read_text(), edit))
    except NoLongerApplies as problem:
        for path, text in saved.items():
            path.write_text(text)
        return {
            **result,
            "status": "no longer applies",
            "seconds": 0,
            "why": f"break no longer applies: update it. {problem}",
        }
    env = {
        **os.environ,
        **dict(m.env),
        "PYTHONDONTWRITEBYTECODE": "1",
        "HEAVY_SLOT": os.environ.get("HEAVY_SLOT", "prove-guards"),
    }
    env.pop("VIRTUAL_ENV", None)
    try:
        failed = resample(copy, env) if m.resample else None
        if failed:
            result.update(status="broken", why=failed)
        for folder, argv, killer in [] if failed else commands(m, copy):
            try:
                done = subprocess.run(
                    argv,
                    cwd=folder,
                    env=env,
                    capture_output=True,
                    text=True,
                    errors="replace",
                )
            except OSError as error:
                result.update(status="broken", why=f"cannot start {argv[0]}: {error}")
                break
            output = done.stdout + done.stderr
            status, files, why = judge(m, done.returncode, output, killer, folder)
            result.update(tail=output)
            if status != "survived":
                result.update(status=status, failed=files, why=why)
                break
    finally:
        for path, text in saved.items():
            path.write_text(text)
        if m.resample:
            subprocess.run(
                ["git", "checkout", "-q", "--", "contract_samples"], cwd=copy
            )
            subprocess.run(["git", "clean", "-fdq", "--", "contract_samples"], cwd=copy)
    tail = "\n".join(result["tail"].strip().splitlines()[-TAIL:])
    return {**result, "tail": tail, "seconds": round(time.monotonic() - started)}


def verdict(m: Break, result: dict) -> str | None:
    status = result["status"]
    if m.survives:
        if status == "killed":
            return f"{m.name} is killed now: take its `survives` mark off"
        return (
            None if status == "survived" else f"{m.name}: {status}: {result.get('why')}"
        )
    if status == "killed":
        return None
    if status == "survived":
        return (
            f"{m.name} SURVIVED: {', '.join(m.killers())} did not fail on it ({m.why})"
        )
    return f"{m.name}: {status}: {result.get('why', '')}"


def proved(breaks, results, root: Path = ROOT) -> set[str]:
    """The guard files a run saw bite: a killer test that failed, and the helper guards
    that test imports."""
    by_name = {m.name: m for m in breaks}
    seen: set[str] = set()
    for result in results:
        m = by_name[result["name"]]
        if result["status"] != "killed" or m.survives:
            continue
        seen |= result["failed"]
        for helper in m.guards:
            readers = [f for f in result["failed"] if (root / f).is_file()]
            if (
                helper in result["failed"]
                or any(
                    imports((root / f).read_text(errors="replace"), helper)
                    for f in readers
                )
                or (m.command and helper == m.command[0] and result["failed"])
            ):
                seen.add(helper)
    return seen


def unproved(breaks, ran: set[str], seen: set[str], guards: set[str]) -> list[str]:
    """Guard files every break of which ran, and none of which saw it bite."""
    out = []
    named = {k for m in breaks if not m.survives for k in m.killers()}
    for guard in sorted(named & guards):
        naming = [m for m in breaks if guard in m.killers() and not m.survives]
        if all(m.name in ran for m in naming) and guard not in seen:
            out.append(f"{guard}: its breaks ran and no test in it was seen to fail")
    return out


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
                f"  {mark:4} {m.name:46} {result['status']:18} {result['seconds']:4} s",
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
        print(f"{m.name:46} {m.promise:22} {', '.join(m.killers())}{mark}")


def problems_before_running(base: str | None) -> list[str]:
    problems = list_problems(BREAKS, guard_files(), NOT_YET_PROVED, was_guard_on(base))
    now = {
        "names": [m.name for m in BREAKS],
        "survives": [m.name for m in BREAKS if m.survives],
        "debt": sorted(NOT_YET_PROVED),
    }
    return problems + shrink_problems(now, lists_at(base), os.environ.get("PR_BODY"))


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
        or os.environ.get("PROVE_GUARDS_JOBS")
        or (os.cpu_count() if os.environ.get("CI") else 2)
        or 2
    )
    flags = {a for a in args if a.startswith("--")}
    names = [a for a in args if not a.startswith("--")]
    base = change_base(ROOT, "origin/main")
    problems = problems_before_running(base)
    for problem in problems:
        print(f"prove-guards: {problem}")
    if "--list" in flags:
        show_list(BREAKS)
        return 1 if problems else 0
    unknown = [n for n in names if n not in {m.name for m in BREAKS}]
    if unknown:
        print(
            f"prove-guards: no break named {', '.join(unknown)} (`just prove-guards --list`)"
        )
        return 1
    chosen = [m for m in BREAKS if not names or m.name in names]
    if "--reached" in flags:
        chosen = reached(chosen, changed_files(base)) if base else chosen
    chosen = [m for m in chosen if m.runner() in runners or (names and m.name in names)]
    for m in [m for m in chosen if not can_run(m.runner())]:
        if os.environ.get("CI"):
            problems.append(
                f"{m.name}: no {m.runner()} on this machine, so it proves nothing"
            )
        else:
            print(
                f"prove-guards: {m.name} skipped: no {m.runner()} here (GitHub runs it)"
            )
    chosen = [m for m in chosen if can_run(m.runner())]
    started = time.monotonic()
    print(
        f"prove-guards: {len(chosen)} break(s), {jobs} at a time, each in a copy of the tree"
    )
    results = run_all(chosen, jobs) if chosen else []
    failed = [r["problem"] for r in results if r["problem"]]
    ran, seen = {r["name"] for r in results}, proved(chosen, results)
    failed += unproved(chosen, ran, seen, set(guard_files()))
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
