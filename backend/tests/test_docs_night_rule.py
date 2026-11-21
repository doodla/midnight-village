"""The docs and comments say the night as it is: a phone WITH a choice sends a
``choose``; a phone with nothing to choose sends nothing and is never waited for
(first time play spec, section 8). The old rule ("every phone sends / chooses")
outlived the change in a dozen READMEs and docstrings; this fails on any line
that says it again, anywhere in the repository's prose or code."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# "every phone chooses", "every present phone has chosen", "every player sends
# a choose", ...: the old rule, said of every phone or player.
OLD_RULE = re.compile(
    r"\bevery (present )?(phone|player)s? "
    r"(sends (one |a |the same )?`*choose|chooses|has chosen|chose|"
    r"has a prompt in every window and chooses)\b",
    re.IGNORECASE,
)

SKIP_DIRS = {
    ".git",
    ".venv",
    "node_modules",
    "build",
    ".dart_tool",
    "__pycache__",
    "contract_samples",
}
SUFFIXES = {".md", ".py", ".dart"}

# What is history on purpose: the old code the migration tests run, the design
# brief the spec amends, and the spec's "Was" column (a row's first cell).
EXEMPT_FILES = {
    "backend/tests/old_code.py",
    "docs/specs/frontend/design-brief.md",
    "backend/tests/test_docs_night_rule.py",
}


def _lines():
    for path in ROOT.rglob("*"):
        if path.suffix not in SUFFIXES or not path.is_file():
            continue
        rel = path.relative_to(ROOT)
        if SKIP_DIRS & set(rel.parts) or rel.as_posix() in EXEMPT_FILES:
            continue
        for number, line in enumerate(path.read_text("utf-8").splitlines(), 1):
            yield rel.as_posix(), number, line


def _was_cell(line: str, match: re.Match[str]) -> bool:
    """The match is in the first cell of a table row (the "Was" column)."""
    return (
        line.lstrip().startswith("|")
        and "|"
        not in line.lstrip()[1 : match.start() - (len(line) - len(line.lstrip()))]
    )


def test_no_doc_says_every_phone_chooses_at_night() -> None:
    stale = [
        f"{path}:{number}: {line.strip()}"
        for path, number, line in _lines()
        for match in OLD_RULE.finditer(line)
        if not _was_cell(line, match)
    ]
    assert stale == []


def test_the_pattern_finds_the_old_rule_and_spares_the_new() -> None:
    assert OLD_RULE.search("Window 2 closes when every phone has chosen.")
    assert OLD_RULE.search("every phone sends one `choose` per window")
    assert not OLD_RULE.search("every phone with a choice has chosen")
    line = "| Every phone chooses twice in window 1 | A phone with a choice |"
    match = OLD_RULE.search(line)
    assert match is not None
    assert _was_cell(line, match)
