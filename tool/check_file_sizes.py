#!/usr/bin/env python3
"""Fails when a change makes a source file too long to hold in one read.

A file over LIMIT lines is where an agent (or a person) gets lost: it cannot be
read whole, a change to one part risks another, and two branches that touch it
collide. The rule has no list and no numbers to keep:

- a new source file may not be over LIMIT lines;
- a file that was under LIMIT on main may not pass it;
- a file that is already over LIMIT on main may shrink or stay as it is, but
  may not GROW: move something out of it first (a split is cheap), then add.

"On main" is origin/main as this checkout knows it (a renamed file is compared
with its old path). So leaving a long file alone, or shrinking it, never needs
an edit anywhere; only the change that adds to it fails.

Checked: backend/apps (not migrations), frontend/lib (not generated code),
.claude/hooks, .claude/guardrails (not tests) and tool. Tests are not checked.

Run by `just check` (the working tree), by the commit gate with --staged (what
is being committed) and by `just gate-full`.

usage: tool/check_file_sizes.py [--staged]
"""

import os
import subprocess
import sys
from pathlib import Path

LIMIT = 600
ROOT = Path(__file__).resolve().parents[1]
# What a change is compared with. A shallow checkout (GitHub's) does not have it
# yet: it is fetched. A repository with no such remote compares with its HEAD.
BASE = "origin/main"


def checked(path: str) -> bool:
    if path.endswith((".g.dart", ".freezed.dart")):
        return False
    if path.startswith("backend/apps/"):
        return path.endswith(".py") and "/migrations/" not in path
    if path.startswith("frontend/lib/"):
        return path.endswith(".dart")
    if path.startswith(".claude/guardrails/"):
        return path.endswith(".py") and "/tests/" not in path
    if path.startswith((".claude/hooks/", "tool/")):
        return path.endswith((".py", ".sh"))
    return False


def git(*args: str) -> bytes:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args], capture_output=True, check=True
    ).stdout


def has(ref: str) -> bool:
    return (
        subprocess.run(
            ["git", "-C", str(ROOT), "rev-parse", "-q", "--verify", f"{ref}^{{commit}}"],
            capture_output=True,
        ).returncode
        == 0
    )


def base_ref() -> str | None:
    """The commit a change is measured against, or None in a repository with no commit."""
    wanted = os.environ.get("FILE_SIZE_BASE", BASE)
    if has(wanted):
        return wanted
    remote, _, branch = wanted.partition("/")
    if branch:
        subprocess.run(
            ["git", "-C", str(ROOT), "fetch", "-q", "--no-tags", "--depth=1", remote,
             f"+refs/heads/{branch}:refs/remotes/{remote}/{branch}"],
            capture_output=True,
        )
        if has(wanted):
            return wanted
    return "HEAD" if has("HEAD") else None


def count(data: bytes) -> int:
    return data.count(b"\n") + (1 if data and not data.endswith(b"\n") else 0)


def line_counts(staged: bool) -> dict[str, int]:
    """Lines of every checked file: as staged for the commit, or as on disk."""
    listing = ["ls-files", "-z", "--cached"]
    if not staged:
        listing += ["--others", "--exclude-standard"]
    counts = {}
    for name in sorted(set(git(*listing).decode().split("\0"))):
        if not name or not checked(name):
            continue
        if staged:
            try:
                data = git("show", f":{name}")
            except subprocess.CalledProcessError:
                continue
        else:
            path = ROOT / name
            if not path.is_file():
                continue
            data = path.read_bytes()
        counts[name] = count(data)
    return counts


def renamed_from(base: str, staged: bool) -> dict[str, str]:
    """{path now: path at the base} for files this change renamed."""
    args = ["diff", "-z", "-M", "--name-status", "--diff-filter=R"]
    args += ["--cached", base] if staged else [base]
    fields = git(*args).decode().split("\0")
    moves = {}
    for i in range(0, len(fields) - 2, 3):
        if fields[i].startswith("R"):
            moves[fields[i + 2]] = fields[i + 1]
    return moves


def size_at(base: str, path: str) -> int | None:
    """Lines the file had at the base, or None when it was not there."""
    try:
        return count(git("show", f"{base}:{path}"))
    except subprocess.CalledProcessError:
        return None


def main(argv: list[str]) -> int:
    staged = "--staged" in argv
    counts = line_counts(staged)
    base = base_ref()
    moves = renamed_from(base, staged) if base else {}
    problems = []
    for path, lines in counts.items():
        if lines <= LIMIT:
            continue
        before = size_at(base, moves.get(path, path)) if base else None
        if before is None:
            problems.append(
                f"{path} is new and {lines} lines, over the {LIMIT}-line limit: split it"
                " into parts that can each be read whole."
            )
        elif before <= LIMIT:
            problems.append(
                f"{path} grew from {before} to {lines} lines, past the {LIMIT}-line limit:"
                " split it into parts that can each be read whole."
            )
        elif lines > before:
            problems.append(
                f"{path} is already over the limit ({before} lines on main) and this change"
                f" grows it to {lines}: move something out of it first, then add."
            )
    for problem in problems:
        print(problem, file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
