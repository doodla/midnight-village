#!/usr/bin/env python3
"""No giant lines in the notes: two branches that add a word to one line clash.

A paragraph or a list item written as ONE line of thousands of characters makes
every two branches that touch it conflict, and the merge is fixed by hand. A
line break inside a paragraph is a space to Markdown, so the same words can sit
one sentence to a line and read the same on the page.

    tool/doc_lines.py                 check: fail on a prose line over LIMIT
    tool/doc_lines.py --fix [file..]  reflow the long lines (all checked files, or those named)

What is a prose line: not a table row, not inside a code block, not a heading,
not a link definition. A line that is long only because of one unbreakable piece
(a URL, a code span, a link) is left alone and is not a failure.

`--fix` breaks a long line after a sentence (". ", "; ", "? ", "! ", ": ") and,
where a sentence is still too long, at a space; never inside a code span, a
link or brackets, and never so that the next line would start something
(a list mark, a heading, a quote, a table). The continuation of a list item is
indented under its text. Words, order and punctuation are untouched:
`.claude/guardrails/tests/test_doc_lines.py` holds that the text with its
whitespace collapsed is the same, and that the rendered page is.

Checked: every tracked `*.md` but the ones in SKIPPED (the owner's words as
written, quoted by line; recorded samples; licences).
"""

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIMIT = 200  # the check: no prose line longer
WIDTH = 160  # the reflow: where a sentence too long for one line is broken
SKIPPED = (
    "docs/dev/owner-feedback.md",  # the owner's words as written: quoted by line
    "contract_samples/",
    "frontend/ios/",
    "frontend/android/",
)

FENCE = re.compile(r"^\s*(```|~~~)")
ITEM = re.compile(r"^(\s*)([-*+]|\d+[.)])(\s+)(\[[ xX]\]\s+)?")
QUOTE = re.compile(r"^(\s*>\s?)+")
# what would start something if a broken line began with it
STARTS = re.compile(r"^([-*+]\s|\d+[.)]\s|#|>|\||```|~~~|=+\s*$|-+\s*$|\s{4,})")
SENTENCE_END = (".", ";", "?", "!", ":")


def tracked() -> list[str]:
    out = subprocess.run(
        ["git", "-C", str(ROOT), "ls-files", "*.md"], capture_output=True, text=True
    ).stdout.split("\n")
    return [p for p in out if p and not p.startswith(SKIPPED) and p not in SKIPPED]


def is_prose(line: str) -> bool:
    stripped = line.lstrip()
    if not stripped or stripped.startswith(("#", "|", "<")):
        return False
    return not re.match(r"^\s*\[[^\]]+\]:\s", line)  # a link definition


def pieces(text: str) -> list[str]:
    """The text cut at the spaces where a line may end: outside code spans, links
    and brackets. Each piece keeps the space after it."""
    cut, start, depth, code = [], 0, 0, None
    i = 0
    while i < len(text):
        ch = text[i]
        if ch == "`":
            run = len(text) - len(text[i:].lstrip("`")) - i
            ticks = text[i : i + run]
            if code is None:
                code = ticks
            elif code == ticks:
                code = None
            i += run
            continue
        if code is None:
            if ch in "([":
                depth += 1
            elif ch in ")]":
                depth = max(0, depth - 1)
            elif ch == " " and depth == 0:
                cut.append(text[start : i + 1])
                start = i + 1
        i += 1
    cut.append(text[start:])
    return [p for p in cut if p]


def broken(text: str, room: int) -> list[str]:
    """The text on several lines: a new line after a sentence, and inside a
    sentence longer than `room` at a space. Never a line that would start
    something."""
    lines, line = [], ""
    for piece in pieces(text):
        ends = line.rstrip().endswith(SENTENCE_END) and len(line) > 40
        full = len(line) + len(piece.rstrip()) > room
        if line and (ends or full) and not STARTS.match(piece):
            lines.append(line.rstrip())
            line = ""
        line += piece
    if line.strip():
        lines.append(line.rstrip())
    return lines


def reflowed(text: str) -> str:
    out, fenced = [], False
    for line in text.split("\n"):
        if FENCE.match(line):
            fenced = not fenced
        if fenced or FENCE.match(line) or len(line) <= LIMIT or not is_prose(line):
            out.append(line)
            continue
        quote = QUOTE.match(line)
        item = ITEM.match(line)
        if quote:
            first = rest = quote.group(0)
        elif item:
            first = item.group(0)
            rest = " " * len(first)
        else:
            first = rest = line[: len(line) - len(line.lstrip())]
        if len(rest) >= 4 and not item and not quote:
            out.append(line)  # indented prose: a break could make it a code block
            continue
        body = broken(line[len(first) :], WIDTH - len(rest))
        out.append(first + body[0])
        out.extend(rest + more for more in body[1:])
    return "\n".join(out)


def long_lines(text: str) -> list[tuple[int, int]]:
    """[(line number, length)] of the prose lines over LIMIT that could be broken."""
    found, fenced = [], False
    for number, line in enumerate(text.split("\n"), 1):
        if FENCE.match(line):
            fenced = not fenced
            continue
        if fenced or len(line) <= LIMIT or not is_prose(line):
            continue
        if len(reflowed(line).split("\n")) > 1:
            found.append((number, len(line)))
    return found


def main(argv: list[str]) -> int:
    if argv and argv[0] == "--fix":
        changed = 0
        for path in argv[1:] or tracked():
            file = ROOT / path
            before = file.read_text()
            after = reflowed(before)
            if after != before:
                file.write_text(after)
                changed += 1
                print(f"reflowed {path}")
        print(f"doc lines: {changed} file(s) reflowed.")
        return 0
    bad = 0
    for path in tracked():
        for number, length in long_lines((ROOT / path).read_text()):
            bad += 1
            if bad <= 20:
                print(
                    f"{path}:{number}: a line of {length} characters", file=sys.stderr
                )
    if bad:
        print(
            f"\ndoc lines: {bad} line(s) over {LIMIT} characters. Two branches that add a"
            " word to one such line clash. One sentence to a line reads the same on the"
            " page: `tool/doc_lines.py --fix <file>` does it, changing line breaks only.",
            file=sys.stderr,
        )
        return 1
    print(f"doc lines: no prose line over {LIMIT} characters.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
