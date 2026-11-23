#!/usr/bin/env python3
"""Check only what this change touches: seconds to a couple of minutes.

While building a piece you do not need the whole suite on every round: GitHub
runs it all on the pull request. This runs the fast checks, and only the test
files that can see a file you changed.

For the app, which tests is worked out, not listed: a test file can see a change
when it, or anything it imports (followed all the way down), is one of the changed
files. The ones nearest the change, and one import further, are run (`--far`: all
that can see it). So there is no
table of "this test covers that file" to keep.

- Backend: `just check`, then every backend test in parallel (about a minute and
  a half; choosing among them does not pay, see `plan`); the migration tests when
  a migration changed.
- Frontend: analyze and format, then `flutter test` on the affected test files;
  the generated-code check when a file with generated parts changed.
- Guardrails: when .claude/, tool/, a justfile or a workflow changed.
- A frontend change this cannot map (pubspec, an asset, test settings) runs all
  the frontend tests, and says why.

Screens are not rendered here: `just screens` stays a step of its own.

usage: tool/piece_check.py [--list] [--far] [--base <ref>]
  --list   print what would run, run nothing
  --far    every frontend test that can see the change, however far away
  --base   what the change is measured against (default: where this branch
           left origin/main)
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DART_DIRECTIVE = re.compile(r"""^\s*(?:import|export|part)\s+['"]([^'"]+)['"]""", re.M)
GENERATED_PART = re.compile(r"""^\s*part\s+['"][^'"]+\.(?:g|freezed)\.dart['"]""", re.M)
# A change to one of these can alter any test of its side: run them all.
FRONTEND_ALL = (
    "frontend/pubspec.yaml",
    "frontend/pubspec.lock",
    "frontend/assets/",
    "frontend/dart_test.yaml",
    "frontend/analysis_options.yaml",
)
GUARDRAIL_PATHS = (
    ".claude/",
    "tool/",
    "justfile",
    "backend/justfile",
    "frontend/justfile",
    ".github/",
)


def git(*args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args], capture_output=True, text=True, check=True
    ).stdout


def changed_files(base: str | None) -> list[str]:
    """Paths that differ from the base (committed, staged or not, and new files)."""
    if base is None:
        try:
            base = git("merge-base", "origin/main", "HEAD").strip()
        except subprocess.CalledProcessError:
            base = "HEAD"
    names = set(git("diff", "--name-only", "--no-renames", base).splitlines())
    names |= set(git("ls-files", "--others", "--exclude-standard").splitlines())
    return sorted(n for n in names if n)


# ---- which files a file imports ------------------------------------------------


def dart_imports(path: Path, lib: Path, package: str) -> set[Path]:
    """Files this Dart file imports, exports or holds as parts."""
    try:
        text = path.read_text()
    except (UnicodeDecodeError, OSError):
        return set()
    found = set()
    for target in DART_DIRECTIVE.findall(text):
        if target.startswith(f"package:{package}/"):
            candidate = lib / target.split("/", 1)[1]
        elif ":" in target:
            continue  # the SDK or another package
        else:
            candidate = (path.parent / target).resolve()
        if candidate.is_file():
            found.add(candidate)
    return found


def distance(start: Path, imports, targets: set[Path], cache: dict) -> int | None:
    """How many imports lie between `start` and the nearest of `targets` (0: it is
    one of them), or None when it cannot see any."""
    frontier, seen, steps = {start}, {start}, 0
    while frontier:
        if frontier & targets:
            return steps
        following = set()
        for here in frontier:
            if here not in cache:
                cache[here] = imports(here)
            following |= cache[here] - seen
        seen |= following
        frontier, steps = following, steps + 1
    return None


# ---- the plan -------------------------------------------------------------------


def frontend_tests(changed: list[str], everything: bool = False) -> tuple[list[str], str]:
    top = ROOT / "frontend"
    mine = [c for c in changed if c.startswith("frontend/")]
    for name in mine:
        if name.startswith(FRONTEND_ALL):
            return [], f"{name} can change any test"
    package = "midnight_village"
    match = re.search(r"^name:\s*(\S+)", (top / "pubspec.yaml").read_text(), re.M)
    if match:
        package = match.group(1)
    targets = {(ROOT / c).resolve() for c in mine if c.endswith(".dart")}
    samples = any(c.startswith("contract_samples/") for c in changed)
    cache: dict = {}
    reads_samples: dict[Path, bool] = {}

    def imports(path: Path) -> set[Path]:
        return dart_imports(path, top / "lib", package)

    def sees_samples(test: Path) -> bool:
        """A test (or a helper it imports) that reads the recorded samples."""
        stack, seen = [test], set()
        while stack:
            here = stack.pop()
            if here in seen or (top / "lib") in here.parents:
                continue
            seen.add(here)
            if here not in reads_samples:
                try:
                    reads_samples[here] = "contract_samples" in here.read_text()
                except (UnicodeDecodeError, OSError):
                    reads_samples[here] = False
            if reads_samples[here]:
                return True
            if here not in cache:
                cache[here] = imports(here)
            stack.extend(cache[here])
        return False

    def resolved_imports(path: Path) -> set[Path]:
        return {p.resolve() for p in imports(path)}

    how_far: dict[str, int] = {}
    for test in sorted((top / "test").rglob("*_test.dart")):
        test = test.resolve()
        name = str(test.relative_to(top.resolve()))
        steps = distance(test, resolved_imports, targets, cache) if targets else None
        if steps is None and samples and sees_samples(test):
            steps = 0
        if steps is not None:
            how_far[name] = steps
    if not how_far or everything:
        return sorted(how_far), ""
    # The tests nearest the change and one step further: a central file is seen by
    # half the suite through the app's router, and those far tests say little
    # about this change. GitHub runs them all.
    nearest = min(how_far.values())
    return sorted(n for n, steps in how_far.items() if steps <= nearest + 1), ""


def plan(changed: list[str], everything: bool = False) -> list[tuple[str, str, list[str]]]:
    """[(what it is, folder to run in, command)] for this change."""
    steps: list[tuple[str, str, list[str]]] = []
    backend = [c for c in changed if c.startswith("backend/")]
    frontend = [c for c in changed if c.startswith("frontend/")]
    samples = any(c.startswith("contract_samples/") for c in changed)

    steps.append(
        ("checks (lint, format, types, links, file sizes)", ".", ["just", "check"])
    )
    if backend or samples:
        # Not selected: the backend's modules all lead to each other, and a test
        # that goes through a URL imports no view. The whole suite in parallel is
        # quick enough, and cannot miss.
        steps.append(("all backend tests, in parallel", "backend", ["just", "test-fast"]))
        if any("/migrations/" in c for c in backend):
            steps.append(("the migration tests", "backend", ["just", "test-migrations"]))
    if frontend or samples:
        if frontend:
            steps.append(("analyze", "frontend", ["just", "analyze"]))
            steps.append(("format", "frontend", ["just", "format-check"]))
        tests, why_all = frontend_tests(changed, everything)
        if why_all:
            steps.append(
                (f"all frontend tests ({why_all})", "frontend", ["just", "test"])
            )
        elif tests:
            steps.append(
                (
                    f"{len(tests)} frontend test files {'that can see' if everything else 'nearest'} the change",
                    "frontend",
                    [
                        "flutter",
                        "test",
                        "--dart-define=ENV=dev",
                        "--exclude-tags",
                        "e2e",
                        *tests,
                    ],
                )
            )
        generated = [
            c
            for c in frontend
            if c.endswith(".dart")
            and (ROOT / c).is_file()
            and GENERATED_PART.search((ROOT / c).read_text(errors="ignore"))
        ]
        if generated:
            steps.append(
                ("generated code is up to date", "frontend", ["just", "gen-check"])
            )
    if any(c.startswith(GUARDRAIL_PATHS) or c == "justfile" for c in changed):
        steps.append(("guardrail tests", ".", ["just", "test-guardrails"]))
    return steps


def main(argv: list[str]) -> int:
    base = argv[argv.index("--base") + 1] if "--base" in argv else None
    changed = changed_files(base)
    if not changed:
        print("piece-check: nothing changed against main.")
        return 0
    steps = plan(changed, everything="--far" in argv)
    print(f"piece-check: {len(changed)} changed files, {len(steps)} steps")
    if "--list" in argv:
        for what, folder, command in steps:
            shown = " ".join(command)
            print(
                f"  {what}\n    ({folder}) {shown[:300]}{' ...' if len(shown) > 300 else ''}"
            )
        return 0
    failed = []
    for what, folder, command in steps:
        print(f"\n== {what}", flush=True)
        if subprocess.run(command, cwd=ROOT / folder).returncode != 0:
            failed.append(what)
    print()
    for what, _, _ in steps:
        print(f"{'FAIL' if what in failed else 'ok  '} {what}")
    if not failed:
        print(
            "\nThis is the fast check: GitHub runs the whole suite on the pull request."
        )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
