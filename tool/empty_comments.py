"""Which comments code can prove say nothing, so they may be deleted unattended.

The no-comments sorters only propose (tool/comment_rows.py). A deletion is applied only
when the comment is in one of these classes, and carries no rule word:

- commented-out code: what is left after the comment marks parses as code (Python:
  `ast`; the `//` languages: a statement's shape, ending in `;`, `{` or `}`);
- a banner or divider: no letters, or only a title whose words are the file's name or a
  class it declares;
- a "Part of x" line that repeats the file's `part of` directive;
- a restatement: every word but the small ones is in the names on its own line, or on
  the declaration right below it;
- a copy of a comment the same file keeps elsewhere, word for word.

A rule word (`RULE_WORDS`) keeps a comment out of every class. On PR #208 the sorters
read three rules as narration, and each had one: "(committed), each on their own group",
"(none: no beat known, or paused)", "one that heard no beat at all counts toward ...".
"""

import ast
import re
import textwrap
from pathlib import Path

RULE_WORDS = {
    *("never", "must", "only", "always", "after", "before", "until", "unless"),
    *("null", "none", "because", "count", "counts", "order", "first", "once"),
    *("each", "every", "own", "committed", "else", "otherwise", "instead", "no"),
    *("not", "without", "why", "keep", "kept", "nothing", "again", "still"),
}
RULE_PHRASES = ("so that",)
SMALL = {
    *("a", "an", "the", "of", "to", "is", "are", "be", "this", "that", "it", "its"),
    *("and", "or", "for", "in", "on", "by", "with", "from", "as", "at", "which"),
    *("whether", "what", "here", "now", "s"),
}
MARKS = re.compile(r"^\s*(?:///?|/\*+|\*/|\*|#+|[rR]?\"\"\"|''')\s?")
DIRECTIVE = re.compile(r"^part of ['\"]([^'\"]+)['\"];")
DART_STATEMENT = re.compile(r"^[^\s].*[;{}]$|^[{}]$")
DIVIDER = re.compile(r"[-=*#~_]{3}|[─━]{2}")
PROSE = re.compile(r"\b[a-z]+ [a-z]+ [a-z]+\b")  # three words in a row: prose


def comment_text(path: str, line: str) -> str:
    """`line`'s comment without its marks (the part after the code, for a trailing one)."""
    stripped = line.strip()
    if not MARKS.match(stripped):
        cut = re.split(r"\s#\s|\s//\s", line, maxsplit=1)
        stripped = cut[1] if len(cut) > 1 else ""
    text = MARKS.sub("", stripped, count=1)
    return re.sub(r"(\"\"\"|''')$|\*/$", "", text).strip()


def words(text: str) -> list[str]:
    """The words of prose or of names: `gameId` and `game_id` are "game", "id"."""
    found = re.findall(r"[A-Z]?[a-z]+|[A-Z]+(?![a-z])", text)
    return [w.lower() for w in found]


def stem(word: str) -> str:
    return word[:-1] if len(word) > 3 and word.endswith("s") else word


def has_rule_word(text: str) -> bool:
    low = text.lower()
    return bool(RULE_WORDS & set(re.findall(r"[a-z]+", low))) or any(
        p in low for p in RULE_PHRASES
    )


def normal(text: str) -> str:
    return " ".join(words(text))


def code_part(line: str) -> str:
    return re.split(r"\s#\s|\s//\s", line, maxsplit=1)[0]


def is_code(path: str, bodies: list[str]) -> bool:
    lines = [b for b in bodies if b.strip()]
    if not lines or PROSE.search(" ".join(lines)):
        return False
    if Path(path).suffix == ".py":
        source = textwrap.dedent("\n".join(lines))
        if not re.search(r"[(=\[]", source):
            return False
        try:
            ast.parse(source)
        except SyntaxError:
            return False
        return True
    return all(
        DART_STATEMENT.match(b.strip()) and re.search(r"[(=]|^[{}]", b) for b in lines
    )


def names_of_file(path: str, lines: list[str]) -> set[str]:
    found = set(words(Path(path).name.split(".")[0]))
    for line in lines:
        m = re.match(r"\s*(?:abstract |final |sealed )*class (\w+)", line)
        if m:
            found |= set(words(m[1]))
    return found


def declaration_below(path: str, lines: list[str], end: int) -> str:
    for line in lines[end:]:
        text = line.strip()
        if text and not text.startswith("@") and not MARKS.match(text):
            return line
    return ""


def provably_empty(
    path: str, lines: list[str], start: int, end: int, kept: set[str]
) -> str | None:
    """The class that proves comment `start`..`end` (1-based) of `lines` says nothing, or
    None. `kept`: the comments the same file keeps elsewhere, `normal`ised."""
    span = lines[start - 1 : end]
    if any(re.match(r"\s*[rR]?(\"\"\"|''')", line) for line in span):
        return None  # a docstring: a builder deletes it, never this
    bodies = [comment_text(path, line) for line in span]
    text = " ".join(bodies)
    if has_rule_word(text):
        return None
    if is_code(path, bodies):
        return "commented-out code"
    title = {stem(w) for w in words(text)} - SMALL
    if any(DIVIDER.search(b) for b in bodies):
        if title <= {stem(w) for w in names_of_file(path, lines)}:
            return "a banner"
    part = re.match(r"^Part of (\S+?)\.?$", text)
    if part and any(
        (m := DIRECTIVE.match(line)) and Path(m[1]).name == Path(part[1]).name
        for line in lines
    ):
        return "a repeated part of"
    content = {stem(w) for w in words(text)} - SMALL
    named = words(code_part(span[0])) if not MARKS.match(span[0].strip()) else []
    named += words(declaration_below(path, lines, end))
    if content and content <= {stem(w) for w in named}:
        return "it restates the names"
    if len(span) == 1 and normal(text) and normal(text) in kept:
        return "a copy of a comment kept in the file"
    return None
