#!/usr/bin/env python3
"""The commit a change was built on: what every "what did this change do?" check
compares with.

Not "main as it is now". Main moves while a check runs, and a branch may be behind
it: compared with today's main, everything main gained since looks like something
this change removed (a guard another pull request edited looked edited here, and a
check failed for a change that never touched it).

- On a pull request GitHub checks out a merge of the branch into main. Its first
  parent is the main it was built on: that commit, fetched if the checkout is
  shallow.
- Anywhere else: where the branch left main (the merge base), or main itself when
  the history to work that out is not here.

usage: tool/change_base.py [<main ref>]      prints the commit, or nothing
"""

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAIN = "origin/main"


def _git(root: Path, *args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True)


def _has(root: Path, ref: str) -> bool:
    return _git(root, "rev-parse", "-q", "--verify", f"{ref}^{{commit}}").returncode == 0


def _built_on(root: Path) -> str | None:
    """First parent of GitHub's merge commit, read from the commit itself (a shallow
    checkout hides parents from `git log`, not from the object)."""
    raw = _git(root, "cat-file", "-p", "HEAD").stdout
    parents = [line.split()[1] for line in raw.split("\n\n", 1)[0].splitlines()
               if line.startswith("parent ")]
    if len(parents) != 2:
        return None
    first = parents[0]
    if not _has(root, first):
        _git(root, "fetch", "-q", "--no-tags", "--depth=1", "origin", first)
    return first if _has(root, first) else None


def change_base(root: Path = ROOT, main: str = MAIN) -> str | None:
    """The commit to compare with, or None when there is nothing to compare with."""
    if os.environ.get("GITHUB_EVENT_NAME") == "pull_request":
        built_on = _built_on(root)
        if built_on:
            return built_on
    if not _has(root, main):
        remote, _, branch = main.partition("/")
        if branch:
            _git(root, "fetch", "-q", "--no-tags", "--depth=1", remote,
                 f"+refs/heads/{branch}:refs/remotes/{remote}/{branch}")
    if not _has(root, main):
        return None
    left_at = _git(root, "merge-base", main, "HEAD")
    return left_at.stdout.strip() if left_at.returncode == 0 and left_at.stdout.strip() else main


if __name__ == "__main__":
    found = change_base(ROOT, *sys.argv[1:2])
    if found:
        print(found)
