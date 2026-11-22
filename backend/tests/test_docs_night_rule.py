"""The docs and comments say the night as it is: a phone WITH a choice sends a
``choose``; a phone with nothing to choose sends nothing and is never waited for
(first time play spec, section 8). The old rule ("every phone sends / chooses")
outlived the change in a dozen READMEs and docstrings; this fails on any line
that says it again, anywhere in the repository's prose or code. Only the files git
tracks are read: a builder's worktree copy under .claude/worktrees/ is not the repo."""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

from repo_files import tracked_files

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


def _lines(root: Path = ROOT):
    for path in tracked_files(root, suffixes=SUFFIXES):
        rel = path.relative_to(root)
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


def _stale(root: Path = ROOT) -> list[str]:
    return [
        f"{path}:{number}: {line.strip()}"
        for path, number, line in _lines(root)
        for match in OLD_RULE.finditer(line)
        if not _was_cell(line, match)
    ]


def _checkout(tmp_path: Path, tracked: str, stray: str | None = None) -> Path:
    """A git checkout whose tracked doc says ``tracked``, plus (optionally) an
    ignored worktree copy under .claude/worktrees/ that says ``stray``."""
    root = tmp_path / "checkout"
    (root / "docs").mkdir(parents=True)
    (root / "docs" / "night.md").write_text(tracked + "\n", encoding="utf-8")
    (root / ".gitignore").write_text(".claude/worktrees/\n", encoding="utf-8")
    if stray is not None:
        copy = root / ".claude" / "worktrees" / "agent-7" / "docs"
        copy.mkdir(parents=True)
        (copy / "night.md").write_text(stray + "\n", encoding="utf-8")
    subprocess.run(  # noqa: S603 (git, on a test checkout made here)
        ["git", "-C", str(root), "init", "-q"],  # noqa: S607
        check=True,
    )
    subprocess.run(  # noqa: S603 (git, on a test checkout made here)
        ["git", "-C", str(root), "add", ".gitignore", "docs/night.md"],  # noqa: S607
        check=True,
    )
    return root


def test_no_doc_says_every_phone_chooses_at_night() -> None:
    assert _stale() == []


def test_a_stale_line_in_a_tracked_file_is_caught(tmp_path: Path) -> None:
    root = _checkout(tmp_path, tracked="Every phone chooses twice in window 1.")

    stale = _stale(root)

    assert len(stale) == 1
    assert stale[0].startswith("docs/night.md:1:")


def test_a_stale_copy_under_worktrees_is_not_scanned(tmp_path: Path) -> None:
    root = _checkout(
        tmp_path,
        tracked="Window 1 closes on the table's timer.",
        stray="Every phone chooses twice in window 1.",
    )

    assert _stale(root) == []


def test_the_pattern_finds_the_old_rule_and_spares_the_new() -> None:
    assert OLD_RULE.search("Window 2 closes when every phone has chosen.")
    assert OLD_RULE.search("every phone sends one `choose` per window")
    assert not OLD_RULE.search("every phone with a choice has chosen")
    line = "| Every phone chooses twice in window 1 | A phone with a choice |"
    match = OLD_RULE.search(line)
    assert match is not None
    assert _was_cell(line, match)
