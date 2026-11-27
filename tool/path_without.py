#!/usr/bin/env python3
"""A PATH that does not have some tools, for running a check as GitHub's job runs it.

    PATH="$(tool/path_without.py flutter dart)" python3 -m unittest ...

GitHub's "Backend Checks" job has no Flutter, so a guardrail test that runs it passes on a
builder's machine and fails there (the brief of a screen did). `just test-guardrails` runs
without them. Each PATH folder that holds one of the tools is replaced, in the same place,
by a folder of links to everything else in it, under the temp dir (the system cleans it).

usage: tool/path_without.py <tool> [<tool> ...]    prints the new PATH
"""

import os
import sys
import tempfile
from pathlib import Path


def path_without(names: list[str], path: str, scratch: Path) -> str:
    out = []
    for number, folder in enumerate(path.split(os.pathsep)):
        here = Path(folder)
        if (
            not folder
            or not here.is_dir()
            or not any((here / n).exists() for n in names)
        ):
            out.append(folder)
            continue
        bridge = scratch / str(number)
        bridge.mkdir(parents=True, exist_ok=True)
        for entry in here.iterdir():
            if entry.name in names or not os.access(entry, os.X_OK):
                continue
            link = bridge / entry.name
            if not link.exists() and not link.is_symlink():
                link.symlink_to(entry)
        out.append(str(bridge))
    return os.pathsep.join(out)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("usage: tool/path_without.py <tool> [<tool> ...]")
    scratch = Path(tempfile.mkdtemp(prefix="path-without-"))
    print(path_without(sys.argv[1:], os.environ.get("PATH", ""), scratch))
