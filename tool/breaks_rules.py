# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""The rules on the list of breaks itself (tool/prove_guards.py), checked before anything
runs.

- Every file marked `Guard file` is a killer of some break, or is on `NOT_YET_PROVED`.
- A break's killers are its test files, a helper those tests import (`two_deals.py`), or,
  for a command break, the command's own file. Naming a guard proves nothing by itself:
  the run must also see a test in it fail (prove_guards.proved).
- Compared with main: `NOT_YET_PROVED` and the set of known survivors only shrink, and no
  break disappears, unless the pull request's description names it under
  "Guards changed" (`- <name>: <why>`). Locally that is a reminder; on GitHub a failure.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from breaks_kit import PROMISES
from guard_edits import explained, is_guard

ROOT = Path(__file__).resolve().parents[1]
LIST_FILES = ("breaks_kit.py", "breaks_server.py", "breaks_tools.py", "breaks_app.py")
READ_LISTS = """
import json, sys
sys.path.insert(0, sys.argv[1])
from breaks_server import SERVER
from breaks_tools import TOOLS, NOT_YET_PROVED
from breaks_app import APP
breaks = SERVER + TOOLS + APP
print(json.dumps({"names": [b.name for b in breaks],
                  "survives": [b.name for b in breaks if b.survives],
                  "debt": sorted(NOT_YET_PROVED)}))
"""


def git(root: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(root), *args], capture_output=True, text=True, check=True
    ).stdout


def guard_files(root: Path = ROOT) -> list[str]:
    names = git(root, "ls-files", "-z", "--cached", "--others", "--exclude-standard")
    found = []
    for name in sorted(set(filter(None, names.split("\0")))):
        path = root / name
        if path.suffix in (".py", ".dart", ".sh") and path.is_file():
            if is_guard(path.read_text(errors="replace")):
                found.append(name)
    return found


def imports(test_text: str, helper: str) -> bool:
    """Whether a test file's own imports name the helper module (Python or Dart)."""
    stem = Path(helper).stem
    pattern = rf"^\s*(from\s+[\w.]*\b{stem}\b|import\s+[\w., ]*\b{stem}\b|import\s+'[^']*{re.escape(Path(helper).name)}')"
    return bool(re.search(pattern, test_text, re.M))


def helper_problems(m, root: Path) -> list[str]:
    tests = {t.split("::")[0] for t in m.tests}
    problems = []
    for killer in m.guards:
        if killer in tests or (m.command and killer == m.command[0]):
            continue
        readers = [t for t in tests if (root / t).is_file()]
        if not any(
            imports((root / t).read_text(errors="replace"), killer) for t in readers
        ):
            problems.append(
                f"{m.name}: guards= names {killer}, which is not its command's file nor a"
                " helper its tests import: a guard counts only where a test of it runs"
            )
    return problems


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
        if m.command and not m.expect:
            problems.append(
                f"{m.name}: a command break says what its guard prints (expect=)"
            )
        named = all("::" in t for t in m.tests)
        if m.tests and m.runner() == "backend" and not (m.expect or named or m.survives):
            problems.append(
                f"{m.name}: a backend break names the failure that kills it: expect="
                " (words its failing assertion says) or its tests as path::test"
            )
        for path in m.files():
            if not (root / path).exists():
                problems.append(f"{m.name}: {path} does not exist: update the break")
        problems += helper_problems(m, root)
    bitten = {
        k for m in breaks if not (m.survives or m.proves_nothing) for k in m.killers()
    }
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


def lists_at(base: str | None, root: Path = ROOT) -> dict | None:
    """The break names, known survivors and NOT_YET_PROVED on the base (None: none there)."""
    if base is None:
        return None
    with tempfile.TemporaryDirectory() as folder:
        listed = git(root, "ls-tree", "--name-only", base, "tool/").split()
        wanted = [n for n in listed if Path(n).name.startswith("breaks_")]
        if not all(f"tool/{name}" in wanted for name in LIST_FILES):
            return None
        for name in [*wanted, "tool/guard_edits.py", "tool/change_base.py"]:
            try:
                (Path(folder) / Path(name).name).write_text(
                    git(root, "show", f"{base}:{name}")
                )
            except subprocess.CalledProcessError:
                continue
        done = subprocess.run(
            [sys.executable, "-I", "-c", READ_LISTS, folder],
            capture_output=True,
            text=True,
            env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"},
        )
        if done.returncode != 0:
            return {"error": done.stderr.strip().splitlines()[-1:]}
        return json.loads(done.stdout)


def shrink_problems(now: dict, before: dict | None, body: str | None) -> list[str]:
    """What grew or went since the base, and is not named in the description."""
    if not before:
        return []
    if "error" in before:
        return [f"the base's list of breaks cannot be read: {before['error']}"]
    moves = [
        *(
            f"{n} was added to NOT_YET_PROVED"
            for n in sorted(set(now["debt"]) - set(before["debt"]))
        ),
        *(
            f"{n} is a new known survivor"
            for n in sorted(set(now["survives"]) - set(before["survives"]))
        ),
        *(f"{n} is gone" for n in sorted(set(before["names"]) - set(now["names"]))),
    ]
    out = []
    for move in moves:
        name = move.split(" ", 1)[0]
        if body is not None and explained(name, body):
            continue
        hint = "" if body is not None else " (on GitHub this fails without the line)"
        out.append(f"{move}: the description needs '- {Path(name).name}: <why>'{hint}")
    return out
