"""The files a test or check scans: the ones git tracks in the checkout it reads.

Walking a folder (rglob, glob) also reads what git ignores, such as the copies of the repo
that builders keep under .claude/worktrees/, and files nobody has added. Ask git instead.
Used by backend/tests (pytest's pythonpath includes tool/) and .claude/guardrails/tests.
"""

from __future__ import annotations

import subprocess
from collections.abc import Iterable
from pathlib import Path


def tracked_files(folder: Path, *, suffixes: Iterable[str] = ()) -> list[Path]:
    """The absolute paths of the files git tracks below ``folder`` (in its checkout),
    sorted, with one of ``suffixes`` when given. A file git lists but that is gone from
    disk is skipped. Raises if ``folder`` is not inside a git checkout."""
    folder = Path(folder).resolve()
    listed = subprocess.run(  # noqa: S603, S607 (git, on the checkout given)
        ["git", "-C", str(folder), "ls-files", "-z", "--cached", "--", "."],
        capture_output=True,
        check=True,
    ).stdout
    wanted = set(suffixes)
    paths = []
    for name in listed.decode("utf-8").split("\0"):
        if not name:
            continue
        path = folder / name
        if (not wanted or path.suffix in wanted) and path.is_file():
            paths.append(path)
    return sorted(paths)
