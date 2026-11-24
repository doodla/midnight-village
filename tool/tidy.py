#!/usr/bin/env python3
"""Give the disk back: worktrees whose work is over lose their build output, or go.

Each builder works in its own worktree, and each fills about a gigabyte of build
output (the app's build folder, a Python environment, coverage pages). Nothing
removed them: a machine reached 99% and a test run hung on a full disk.

Two rules, the first for build output only (it can always be made again):

1. A worktree that has gone QUIET loses its build output: no source file in it
   changed for some hours (--hours, 3 by default) and no process is working in
   it (a long test run writes only into the build folders, so the files alone
   would lie). This needs no knowledge of branches: a helper's worktree sits on a
   local branch that is never pushed under its own name.
2. A worktree whose work is provably OVER is removed with --worktrees: its
   branch tracked a remote branch that is gone (a merged pull request deletes
   it), nothing in it is uncommitted, and no process is working in it.

Never touched: the checkout this runs from, a worktree with a process in it, and
(for removal) anything that cannot be shown to be merged. Removing a helper's
worktree whose branch never had a remote stays a person's decision.

usage: tool/tidy.py [--worktrees] [--hours N] [--dry-run] [--quiet]
`just tidy` runs it with --worktrees. The session-start hook runs it with
--quiet (build output only).
"""

import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# A worktree is quiet when no source file in it changed for this long.
QUIET_HOURS = 3.0
# What a build leaves behind, inside a checkout. All of it is made again by the
# recipes; none of it is tracked.
BUILD_OUTPUT = (
    "frontend/build",
    "frontend/.dart_tool",
    "backend/.venv",
    "backend/htmlcov",
    "backend/coverage.xml",
    "backend/.pytest_cache",
)


def git(*args: str, cwd: Path | None = None, check: bool = True) -> str:
    return subprocess.run(
        ["git", "-C", str(cwd or ROOT), *args], capture_output=True, text=True, check=check
    ).stdout


def worktrees() -> list[tuple[Path, str]]:
    """(folder, branch or "") for every worktree of this clone."""
    found, folder, branch = [], None, ""
    for line in [*git("worktree", "list", "--porcelain").splitlines(), ""]:
        if line.startswith("worktree "):
            folder, branch = Path(line[len("worktree ") :]), ""
        elif line.startswith("branch refs/heads/"):
            branch = line[len("branch refs/heads/") :]
        elif not line and folder is not None:
            found.append((folder, branch))
            folder = None
    return found


def remote_is_gone(branch: str) -> bool:
    """The branch tracked a remote branch that no longer exists."""
    track = git("for-each-ref", "--format=%(upstream)|%(upstream:track)", f"refs/heads/{branch}")
    upstream, _, state = track.strip().partition("|")
    return bool(upstream) and "gone" in state


def is_clean(folder: Path) -> bool:
    return not git("status", "--porcelain", cwd=folder, check=False).strip()


def size_of(path: Path) -> int:
    if path.is_file():
        return path.stat().st_size
    return sum(f.stat().st_size for f in path.rglob("*") if f.is_file() and not f.is_symlink())


def busy(folder: Path) -> bool:
    """A process is working inside the worktree (its current directory is in it)."""
    inside = str(folder.resolve())
    for entry in Path("/proc").glob("[0-9]*"):
        try:
            cwd = (entry / "cwd").resolve()
        except OSError:
            continue
        if str(cwd) == inside or str(cwd).startswith(inside + "/"):
            return True
    return False


def last_change(folder: Path) -> float:
    """When a source file in the worktree last changed (build output is not source)."""
    names = git("ls-files", "-z", "--cached", "--others", "--exclude-standard", cwd=folder, check=False)
    latest = 0.0
    for name in names.split("\0"):
        if not name or name.startswith(BUILD_OUTPUT):
            continue
        try:
            latest = max(latest, (folder / name).lstat().st_mtime)
        except OSError:
            continue
    return latest


def quiet_for(folder: Path, hours: float, now: float) -> bool:
    return now - last_change(folder) >= hours * 3600


def main(argv: list[str], now: float | None = None) -> int:
    whole, dry, quiet = "--worktrees" in argv, "--dry-run" in argv, "--quiet" in argv
    hours = float(argv[argv.index("--hours") + 1]) if "--hours" in argv else QUIET_HOURS
    now = time.time() if now is None else now
    git("fetch", "--prune", "--quiet", "origin", check=False)
    here = Path(git("rev-parse", "--show-toplevel").strip()).resolve()
    freed = 0

    def say(text: str) -> None:
        if not quiet:
            print(f"tidy: {text}")

    for folder, branch in worktrees():
        if not folder.is_dir() or folder.resolve() == here or here in folder.resolve().parents:
            continue  # this checkout, and what lives inside it (build/look/base)
        if busy(folder):
            continue
        name = branch or "no branch"
        if whole and branch and remote_is_gone(branch) and is_clean(folder):
            freed += size_of(folder)
            if not dry:
                git("worktree", "remove", "--force", str(folder), check=False)
            say(f"{'would remove' if dry else 'removed'} {folder} ({name}: merged, nothing uncommitted)")
            continue
        if not ((branch and remote_is_gone(branch)) or quiet_for(folder, hours, now)):
            continue
        cleared = 0
        for part in BUILD_OUTPUT:
            path = folder / part
            if not path.exists():
                continue
            cleared += size_of(path)
            if not dry:
                shutil.rmtree(path, ignore_errors=True) if path.is_dir() else path.unlink(missing_ok=True)
        if cleared:
            freed += cleared
            say(f"{'would clear' if dry else 'cleared'} the build output of {folder} ({name}: quiet, no process in it)")
    if not dry:
        git("worktree", "prune", check=False)
    if freed and not (quiet and freed < 1 << 20):
        print(f"tidy: {'would free' if dry else 'freed'} {freed / (1 << 30):.1f} GB")
    elif not quiet:
        print("tidy: nothing to clear.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
