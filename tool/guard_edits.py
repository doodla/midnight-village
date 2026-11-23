#!/usr/bin/env python3
"""A pull request that edits a guard says so, and why.

A guard is a test that holds a rule for everyone (sizes, words, contrast, what
may import what). Twice a guard was loosened for the whole app to get one change
through, and nobody saw it go by. Editing a guard is sometimes right; doing it
quietly is not.

A file is a guard when its first lines carry the words `Guard file` in a comment.
There is no list: a new guard joins by carrying the line.

When a change edits a guard (one that already carried the line on main), the pull
request's description must hold a line for it:

    Guards changed
    - type_guard_test.dart: the discussion clock gets its own role, others keep the floor

On GitHub (`PR_BODY` is set) a missing line fails the check. Locally it prints
what the description will need and passes.

usage: tool/guard_edits.py [--base <ref>]
"""

import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MARK = re.compile(r"^\s*(#|//)\s*Guard file\b", re.M)
HEAD_LINES = 30
MIN_REASON = 10


def git(*args: str) -> str:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args], capture_output=True, text=True, check=True
    ).stdout


def base_ref(wanted: str) -> str | None:
    def has(ref: str) -> bool:
        return (
            subprocess.run(
                ["git", "-C", str(ROOT), "rev-parse", "-q", "--verify", f"{ref}^{{commit}}"],
                capture_output=True,
            ).returncode
            == 0
        )

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
    return None


def is_guard(text: str) -> bool:
    return bool(MARK.search("\n".join(text.splitlines()[:HEAD_LINES])))


def edited_guards(base: str) -> list[tuple[str, int, int]]:
    """(path, lines added, lines removed) for each guard on the base this change edits."""
    found = []
    for line in git("diff", "--numstat", "--no-renames", base).splitlines():
        added, removed, path = line.split("\t", 2)
        try:
            before = git("show", f"{base}:{path}")
        except subprocess.CalledProcessError:
            continue  # new in this change: it joins as a guard, it is not edited
        if is_guard(before):
            found.append((path, int(added or 0), int(removed or 0)))
    return found


def explained(path: str, body: str) -> bool:
    name = re.escape(Path(path).name)
    return bool(re.search(rf"^\W*`?{name}`?\s*:\s*\S.{{{MIN_REASON - 1},}}", body, re.M))


def main(argv: list[str]) -> int:
    wanted = argv[argv.index("--base") + 1] if "--base" in argv else "origin/main"
    base = base_ref(wanted)
    if base is None:
        print(f"guard edits: no {wanted} to compare with; nothing checked.")
        return 0
    guards = edited_guards(base)
    if not guards:
        print("guard edits: no guard file is edited.")
        return 0
    body = os.environ.get("PR_BODY")
    missing = []
    for path, added, removed in guards:
        said = body is not None and explained(path, body)
        print(f"guard edited: {path} (+{added} -{removed}){'' if said else '  <- needs its line'}")
        if not said:
            missing.append(path)
    if not missing:
        return 0
    print(
        "\nThe pull request's description needs a line per guard, saying why it changed:\n\n"
        "Guards changed\n"
        + "".join(f"- {Path(p).name}: <why, in a sentence>\n" for p in missing)
    )
    if body is None:
        print("(not on GitHub: this is a reminder, not a failure)")
        return 0
    print("A guard holds a rule for the whole app: say why it moves.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
