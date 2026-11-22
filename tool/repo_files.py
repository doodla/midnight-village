"""The files a test or check scans in a checkout: what git tracks, plus new files nobody
has added yet, minus anything git ignores.

Walking a folder (rglob, glob) also reads what git ignores, such as the copies of the repo
that builders keep under .claude/worktrees/, and __pycache__. Ask git instead.
Used by backend/tests (pytest's pythonpath includes tool/), .claude/guardrails/tests and
the backend's pyrefly search path.
"""

from __future__ import annotations

import subprocess
from collections.abc import Iterable
from pathlib import Path


def checkout_files(folder: Path, *, suffixes: Iterable[str] = ()) -> list[Path]:
    """The absolute paths of the files below ``folder`` that a scan reads: tracked by
    git, or untracked and not ignored, sorted, with one of ``suffixes`` when given.
    Never a ``__pycache__`` file. A file git lists but that is gone from disk is skipped.
    Raises if ``folder`` is not inside a git checkout."""
    folder = Path(folder).resolve()
    listed = subprocess.run(  # noqa: S603 (git, on the checkout given)
        [
            "git",
            "-C",
            str(folder),
            "ls-files",
            "-z",
            "--cached",
            "--others",
            "--exclude-standard",
            "--",
            ".",
        ],
        capture_output=True,
        check=True,
    ).stdout
    wanted = set(suffixes)
    paths = []
    for name in listed.decode("utf-8").split("\0"):
        if not name or "__pycache__" in Path(name).parts:
            continue
        path = folder / name
        if (not wanted or path.suffix in wanted) and path.is_file():
            paths.append(path)
    return sorted(set(paths))
