#!/usr/bin/env python3
"""The tests that read the whole app instead of one feature.

A change to one file can fail a test far from it: a scan of all of `lib/` for a raw
colour, a string in a widget, a haptic call outside its home. The "nearest test files"
of `just piece-check` and `just handover` never reach those (nothing imports the file
under change), and GitHub's "Widget Tests" does. So they are found by what they do,
not kept in a list:

- a test that lists a directory tree (`Directory(...).listSync(recursive: true)`), or
- a test file that carries `Guard file` at its top (a rule held for the whole app:
  tool/guard_edits.py).

A new scan joins by doing either. Over-including costs a few seconds; missing one is
what this exists to stop (`guardrails/tests/test_lib_scans.py`).

usage: tool/lib_scans.py     print them, one per line, relative to frontend/
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GUARD = re.compile(r"^\s*(#|//)\s*Guard file\b", re.M)
HEAD_LINES = 30
LISTS_A_TREE = re.compile(
    r"Directory\([^;]*?\)\s*\.(?:listSync|list)\(\s*recursive:\s*true", re.S
)


def is_scan(text: str) -> bool:
    return bool(
        GUARD.search("\n".join(text.splitlines()[:HEAD_LINES]))
        or LISTS_A_TREE.search(text)
    )


def whole_lib_tests(root: Path = ROOT) -> list[str]:
    """Test files under frontend/test that scan, as paths relative to frontend/."""
    top = root / "frontend"
    found = []
    for path in sorted((top / "test").rglob("*_test.dart")):
        try:
            text = path.read_text()
        except (UnicodeDecodeError, OSError):
            continue
        if is_scan(text):
            found.append(str(path.relative_to(top)))
    return found


if __name__ == "__main__":
    print("\n".join(whole_lib_tests()))
    sys.exit(0)
