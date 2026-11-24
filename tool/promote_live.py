#!/usr/bin/env python3
"""Move the branches Vercel deploys from, only when what they serve changed.

Vercel allows 100 deployments in 24 hours, and a merge to main used to cost two
(the server and the app), whatever it touched: a change to tests, docs or tooling
spent two for nothing a player sees, and at the cap Vercel skips builds.

So Vercel deploys from two branches, not from main:

- `live-server`: the server project (backend/vercel.json);
- `live-app`: the app project (frontend/vercel.json).

After each merge this moves a branch to the merged commit when the files that
side ships differ from what the branch holds. It compares with the BRANCH, not
with the last merge, so a run that was cancelled or failed is made up by the next.

What a side ships: everything under its folder except its tests and its
Markdown. When in doubt a path ships (an extra deployment costs little; a missed
one leaves players on old code).

usage: tool/promote_live.py [--dry-run]
Prints one line per side; on GitHub also writes `server=<sha>` and `app=<sha>`
(what each branch holds afterwards) to $GITHUB_OUTPUT.
"""

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SIDES = {
    # side: (branch, folder, folders inside it that never ship)
    "server": ("live-server", "backend", ("tests/",)),
    "app": (
        "live-app",
        "frontend",
        ("test/", "test_screens/", "test_e2e/", "integration_test/", "test_driver/"),
    ),
}


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args], capture_output=True, text=True, check=check
    )


def ships(path: str, folder: str, not_shipped: tuple[str, ...]) -> bool:
    """Whether a changed path is part of what this side's build serves."""
    if not path.startswith(folder + "/"):
        return False
    inside = path[len(folder) + 1 :]
    return not inside.endswith(".md") and not inside.startswith(not_shipped)


def remote_head(branch: str) -> str:
    """The commit the branch holds on the remote ('' when it does not exist yet)."""
    out = git("ls-remote", "origin", f"refs/heads/{branch}").stdout.split()
    return out[0] if out else ""


def changed_since(old: str, new: str) -> list[str]:
    if git("cat-file", "-e", f"{old}^{{commit}}", check=False).returncode != 0:
        git("fetch", "-q", "--no-tags", "origin", old, check=False)
    return git("diff", "--name-only", "--no-renames", old, new).stdout.splitlines()


def promote(side: str, head: str, dry_run: bool) -> str:
    """Moves the side's branch when it must; returns the commit it holds afterwards."""
    branch, folder, not_shipped = SIDES[side]
    holds = remote_head(branch)
    if holds == head:
        print(f"{side}: {branch} is already at {head[:10]}.")
        return head
    if holds:
        moved = [p for p in changed_since(holds, head) if ships(p, folder, not_shipped)]
        if not moved:
            print(
                f"{side}: nothing it ships changed since {holds[:10]}; {branch} stays."
            )
            return holds
        why = f"{len(moved)} shipped files changed (first: {moved[0]})"
    else:
        why = "the branch does not exist yet"
    if dry_run:
        print(f"{side}: would move {branch} to {head[:10]}: {why}.")
        return head
    pushed = git("push", "origin", f"{head}:refs/heads/{branch}", check=False)
    if pushed.returncode != 0:
        # a newer merge's run moved it past us: that run's commit holds ours
        now = remote_head(branch)
        if (
            now
            and git("merge-base", "--is-ancestor", head, now, check=False).returncode
            == 0
        ):
            print(f"{side}: {branch} is already past {head[:10]} (at {now[:10]}).")
            return now
        print(pushed.stderr, file=sys.stderr)
        raise SystemExit(f"{side}: could not move {branch} to {head[:10]}")
    print(f"{side}: moved {branch} to {head[:10]}: {why}.")
    return head


def main(argv: list[str]) -> int:
    dry_run = "--dry-run" in argv
    head = git("rev-parse", "HEAD").stdout.strip()
    result = {side: promote(side, head, dry_run) for side in SIDES}
    output = os.environ.get("GITHUB_OUTPUT")
    if output:
        with open(output, "a") as handle:
            for side, commit in result.items():
                handle.write(f"{side}={commit}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
