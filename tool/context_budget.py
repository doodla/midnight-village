#!/usr/bin/env python3
"""Fails when what an agent must read before its first edit grows past what it can hold.

Too much to read is a smell: an agent told to read 108,000 tokens before a first
edit reads part of it, guesses the rest, and the rules it skipped are the ones it
breaks. So the reading is measured, as tokens (characters / 4), and held to limits:

- each CLAUDE.md, since it is loaded into every session that works below it;
- each brief (`just brief <x>`: every screen and every area);
- each role's read-first path: the CLAUDE.md files it works under, its agent
  definition, every document those or its brief tell it to read, and its brief;
- the whole instruction surface: every tracked Markdown file but the skills.

The rule is the file-size rule (tool/check_file_sizes.py), with no list to keep:
something under its limit on main may not pass it; something already over it on
main may shrink or stay, but may not GROW. "On main" is the main the change was
built on (tool/change_base.py), measured by this tool on main's documents.

A brief is measured from its documents alone (no widget trees, no Flutter): each
list a brief makes from code is capped (`CODE_CAPS` in tool/brief.py and
tool/brief_areas.py), and counted at its cap.

Run by `just check` and the commit gate (on the working tree; seconds).
usage: tool/context_budget.py [--report]
"""

import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import brief_docs
from brief_docs import DOCS, tokens
from change_base import change_base

ROOT = Path(__file__).resolve().parents[1]

# The limits, in tokens. A builder's whole path fits in a small part of one context
# and leaves the rest for code; a CLAUDE.md is paid for in every session.
CLAUDE_MD_LIMIT = 3_000
BRIEF_LIMIT = 10_000
ROLE_LIMIT = 15_000
SURFACE_LIMIT = 150_000

# Failures printed before "and N more" (one document on every path fails every role).
SHOWN = 6
ALWAYS = ["CLAUDE.md", "backend/CLAUDE.md", "frontend/CLAUDE.md"]
BACKEND = ["CLAUDE.md", "backend/CLAUDE.md"]
FRONTEND = ["CLAUDE.md", "frontend/CLAUDE.md"]
SCREENS = "<every screen>"
# role: (its agent definition, the CLAUDE.md files it works under, its briefs)
ROLES = {
    "backend builder": ("backend-developer", BACKEND, ["server"]),
    "tool builder": ("backend-developer", ["CLAUDE.md"], ["tool"]),
    "screen builder": ("frontend-developer", FRONTEND, [SCREENS]),
    "design-system builder": (
        "frontend-developer",
        FRONTEND,
        ["design-system", "copy"],
    ),
    "backend reviewer": ("backend-code-reviewer", BACKEND, ["server"]),
    "frontend reviewer": (
        "frontend-code-reviewer",
        FRONTEND,
        [SCREENS, "design-system"],
    ),
}
# A line that tells the reader to read what it names.
READ = re.compile(r"\b(read|start (?:at|from)|before you start|judge against)\b", re.I)
BACKTICKED = re.compile(r"`([^`\s]+)`")
# In a brief: "Read: doc.md:12  ## Heading" and "... Read it whole."
BRIEF_SECTION = re.compile(r"^Read: (\S+\.md):(\d+)\s")
BRIEF_WHOLE = re.compile(r"(\S+\.\w+) \(\d+ lines\)\. Read it whole")


def load(name: str):
    import importlib.util

    spec = importlib.util.spec_from_file_location(name, ROOT / "tool" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def surface(problems: list[str] | None = None) -> list[str]:
    """Every instruction file: tracked Markdown, the skills left out (third-party).
    (A role path adds any other text file it is told to read: `measure`.) Every
    read sentence in them is checked for a file the budget cannot count."""
    docs = [p for p in DOCS.glob("*.md") if not p.startswith(".claude/skills/")]
    for path in docs:
        named_reads(path, DOCS.text(path), problems)
    return docs


def sentences(text: str) -> list[str]:
    """The sentences of `text`: a sentence wrapped over lines is one, a list item or
    a heading ends one."""
    out, block = [], []
    for line in text.splitlines() + [""]:
        starts = line.lstrip().startswith(("- ", "* ", "#", "|")) or not line.strip()
        if starts and block:
            out += re.split(r"(?<=[.!?])\s+(?=[A-Z`(])", " ".join(block))
            block = []
        if line.strip():
            block.append(line.strip())
    return out


def named_reads(path: str, text: str, problems: list[str] | None = None) -> list[str]:
    """The files `text` (the file `path`) tells its reader to read: any backticked
    tracked text file, or a folder (its Markdown), on a line that says read. A named
    file that is ignored by git or is not text is one of `problems`: it cannot be
    measured, so it may not be required reading."""
    here = path.rsplit("/", 1)[0] if "/" in path else ""
    listed = set(DOCS.files())
    found = []
    for line in sentences(text):
        if not READ.search(line):
            continue
        for token in BACKTICKED.findall(line):
            token = token.rstrip(".,:;")
            for base in ("", here):
                candidate = os.path.normpath(f"{base}/{token}" if base else token)
                on_disk = DOCS.ref is None and (DOCS.root / candidate).is_file()
                if candidate in listed or on_disk:
                    if candidate in listed and DOCS.is_text(candidate):
                        found.append(candidate)
                    elif problems is not None:
                        why = (
                            "not text" if candidate in listed else "not tracked by git"
                        )
                        problems.append(
                            f"{path} tells its reader to read `{candidate}`, which is {why}:"
                            " the reading budget cannot count it. Name a tracked text file."
                        )
                    break
                if token.endswith("/") or "." not in token.rsplit("/", 1)[-1]:
                    under = [p for p in DOCS.glob(f"{candidate}/*.md")]
                    if under:
                        found += under
                        break
    return found


def section_at(text: str, line: int) -> str:
    """The section of `text` whose heading is at `line` (1-based), to the next of its rank."""
    lines = text.splitlines()
    if not 0 < line <= len(lines):
        return ""
    head = lines[line - 1]
    depth = len(head) - len(head.lstrip("#")) or 6
    end = line
    while end < len(lines):
        other = lines[end]
        if other.startswith("#") and len(other) - len(other.lstrip("#")) <= depth:
            break
        end += 1
    return "\n".join(lines[line - 1 : end])


class Briefs:
    """Every brief's text from the documents, and what its code lists may add."""

    def __init__(self):
        self.screens, self.areas = load("brief"), load("brief_areas")

    def names(self, which: str) -> list[str]:
        if which == SCREENS:
            return self.screens.screen_names()
        return [which] if which in self.areas.AREAS else []

    def text(self, name: str) -> tuple[str, int]:
        """(the brief's documents part, the tokens its capped code lists may add)."""
        if name in self.areas.AREAS:
            return self.areas.brief(name, None, code=False), sum(
                self.areas.CODE_CAPS.values()
            )
        sections = self.screens.spec_sections(DOCS.text(self.screens.SPEC))
        numbers = self.screens.which_screens(name, [], sections)
        text = self.screens.screen_brief(name, numbers, None)
        return text, sum(self.screens.CODE_CAPS.values())

    def reads(self, text: str) -> list[tuple[str, str]]:
        """(document, the part of it) that a brief tells its reader to read."""
        out = []
        for line in text.splitlines():
            if m := BRIEF_SECTION.match(line):
                out.append((f"{m[1]}:{m[2]}", section_at(DOCS.text(m[1]), int(m[2]))))
            elif m := BRIEF_WHOLE.search(line):
                out.append((m[1], DOCS.text(m[1])))
        return out


def measure(problems: list[str] | None = None) -> dict[str, tuple[int, int, str]]:
    """{what: (tokens, its limit, how it adds up)} on the documents DOCS reads now;
    a required read it cannot count goes into `problems`."""
    found: dict[str, tuple[int, int, str]] = {"the instruction surface": (0, 0, "")}
    files = surface(problems)
    read_on_a_path: set[str] = set()
    for path in ALWAYS:
        if DOCS.read(path) is not None:
            found[path] = (
                tokens(DOCS.text(path)),
                CLAUDE_MD_LIMIT,
                "loaded in every session below it",
            )
    briefs = Briefs()
    for role, (agent, claude, which) in ROLES.items():
        definition = f".claude/agents/{agent}.md"
        base: dict[str, str] = {
            p: DOCS.text(p) for p in [*claude, definition] if DOCS.read(p) is not None
        }
        for path, text in list(base.items()):
            for other in named_reads(path, text):
                base.setdefault(other, DOCS.text(other))
        for name in [n for w in which for n in briefs.names(w)]:
            text, code = briefs.text(name)
            brief_tokens = tokens(text) + code
            found.setdefault(
                f"brief {name}",
                (brief_tokens, BRIEF_LIMIT, f"{code} of it its code lists' caps"),
            )
            reads = dict(base)
            for where, part in briefs.reads(text):
                reads.setdefault(where, part)
            path_tokens = sum(tokens(t) for t in reads.values()) + brief_tokens
            biggest = sorted(reads, key=lambda p: -tokens(reads[p]))[:3]
            how = f"{len(reads)} documents + the brief; most: " + ", ".join(
                f"{p} {tokens(reads[p])}" for p in biggest
            )
            found[f"{role}, brief {name}"] = (path_tokens, ROLE_LIMIT, how)
            read_on_a_path |= {p for p in reads if ":" not in p}
    files += sorted(read_on_a_path - set(files))
    total = sum(tokens(DOCS.text(p)) for p in files)
    found["the instruction surface"] = (total, SURFACE_LIMIT, f"{len(files)} files")
    return found


def judge(now: dict, before: dict) -> list[str]:
    """Why the measures `now` fail against the same measures on main (`before`)."""
    problems = []
    for what, (count, limit, how) in now.items():
        if count <= limit:
            continue
        was = before.get(what, (None,))[0]
        if was is None or was <= limit:
            problems.append(
                f"{what} is {count} tokens, past its limit of {limit} ({how}):"
                " cut, or point at the source instead of copying it."
            )
        elif count > was:
            problems.append(
                f"{what} is already over its limit of {limit} ({was} tokens on main) and this"
                f" change grows it to {count} ({how}): take something out first, then add."
            )
    return problems


def base_ref() -> str | None:
    return change_base(ROOT, os.environ.get("CONTEXT_BUDGET_BASE", "origin/main"))


def main(argv: list[str]) -> int:
    unreadable: list[str] = []
    now = measure(unreadable)
    base = base_ref()
    before: dict[str, tuple[int, int, str]] = {}
    if base:
        DOCS.use(base)
        try:
            before = measure()
        finally:
            DOCS.use(None)
    if "--report" in argv:
        width = max(len(k) for k in now)
        print(f"{'what':<{width}}  {'tokens':>7}  {'limit':>7}  {'main':>7}")
        for what, (count, limit, how) in now.items():
            was = before.get(what, (None,))[0]
            mark = "  OVER" if count > limit else ""
            print(
                f"{what:<{width}}  {count:7d}  {limit:7d}  {was if was is not None else '-':>7}{mark}  ({how})"
            )
    problems = sorted(set(unreadable)) + judge(now, before)
    for problem in problems[:SHOWN]:
        print(problem, file=sys.stderr)
    if len(problems) > SHOWN:
        print(f"... and {len(problems) - SHOWN} more like these.", file=sys.stderr)
    if problems:
        print("(tool/context_budget.py --report shows every measure)", file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    brief_docs.DOCS = DOCS
    sys.exit(main(sys.argv[1:]))
