#!/usr/bin/env python3
"""Every word a player reads, on one page, made from the code; and a check that
the spec only names copy that exists.

The words live in one place: frontend/lib/design_system/copy/ (`JoinCopy.title`,
`TalkCopy.ready`, ...). The spec used to quote them, and was left describing the
old screen. Two things replace the quoting:

- `just copy-page` writes frontend/build/copy.md: every copy class, each key and
  its words, a template shown with an example filled in. It is not committed (a
  generated file two branches both regenerate collides on merge): it is made
  when someone wants to read it, and GitHub attaches it to each run.
- `--check-spec` (in `just check`): every copy class and key that a spec under
  docs/specs/frontend/ names in backticks (`TalkCopy`, `TalkCopy.ready`) exists.
  A key renamed or removed fails here, with the line that names it. And section 3
  of first-time-play.md never quotes the words of a key (a line in double quotes
  that equals a key's words, or is one filled in: "See Cleo" for `NightCopy.see`):
  it names the key, so a wording change is one edit, in the code.

usage: tool/copy_page.py [--out <file>] | --check-spec
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COPY = ROOT / "frontend" / "lib" / "design_system" / "copy"
SPECS = ROOT / "docs" / "specs" / "frontend"
CLASS = re.compile(r"^(?:abstract |final |sealed |base )*(?:class|enum)\s+(\w+)")
MEMBER = re.compile(
    r"^\s+static\s+(?:const|final)\s+(?:[\w<>?, ]+\s+)?(\w+)\s*=\s*(.*)$"
)
FUNCTION = re.compile(r"^\s+static\s+[\w<>?, ]+\s+(\w+)\s*\(")
STRING = re.compile(r"""'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)\"""")
NAMED = re.compile(r"`([A-Z]\w*Copy)(?:\.(\w+))?`")
# Specs whose section may not repeat the words of a key: {file: heading start}.
NO_QUOTES = {"first-time-play.md": "## 3."}
QUOTED = re.compile(r'"([^"\n]+)"|“([^”\n]+)”')
GAP = re.compile(r"\{\w+\}")
# What a gap is filled with on the page, so a template reads as a sentence.
EXAMPLES = {"n": "5", "d": "2", "name": "Cleo", "role": "Seer", "a": "Ana", "b": "Ben"}


def unquote(match: re.Match) -> str:
    text = match.group(1) if match.group(1) is not None else match.group(2)
    return text.replace("\\'", "'").replace('\\"', '"').replace("\\n", " / ")


def parse(path: Path) -> list[dict]:
    """[{name, doc, members: [{name, doc, words, template, built}]}] for one file."""
    classes: list[dict] = []
    doc: list[str] = []
    current = None
    lines = path.read_text().splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if stripped.startswith("///"):
            doc.append(stripped[3:].strip())
            i += 1
            continue
        found = CLASS.match(line)
        if found:
            current = {"name": found.group(1), "doc": " ".join(doc), "members": []}
            classes.append(current)
        elif current is not None and (member := MEMBER.match(line)):
            # the value runs to the `;` that ends it (a string may hold one)
            value = member.group(2)
            while not re.search(r";\s*(//.*)?$", lines[i]) and i + 1 < len(lines):
                i += 1
                value += " " + lines[i].strip()
            words = [unquote(m) for m in STRING.finditer(value)]
            current["members"].append(
                {
                    "name": member.group(1),
                    "doc": " ".join(doc),
                    "words": words,
                    "template": "Template(" in value,
                    "built": False,
                    # with no words of its own it points at another key
                    "same_as": "" if words else value.rstrip("; ").strip(),
                }
            )
        elif current is not None and (function := FUNCTION.match(line)):
            current["members"].append(
                {
                    "name": function.group(1),
                    "doc": " ".join(doc),
                    "words": [],
                    "template": False,
                    "built": True,
                    "same_as": "",
                }
            )
        if stripped and not stripped.startswith("@"):
            doc = []
        i += 1
    return classes


def all_copy() -> list[dict]:
    found = []
    for path in sorted(COPY.glob("*.dart")):
        for item in parse(path):
            if item["members"]:
                found.append({**item, "file": path.name})
    return found


def example(template: str) -> str:
    return re.sub(
        r"\{(\w+)\}", lambda m: EXAMPLES.get(m.group(1), m.group(1).upper()), template
    )


def page(classes: list[dict]) -> str:
    out = [
        "# Every word a player reads",
        "",
        "Made from `frontend/lib/design_system/copy/` by `just copy-page`. Not committed:",
        "the code is the one home of the words. A `{gap}` is filled where the line is",
        "shown; the example beside it uses stand-in values.",
        "",
    ]
    for item in classes:
        out += [f"## {item['name']}", ""]
        if item["doc"]:
            out += [item["doc"], ""]
        out += ["| Key | Words | Note |", "|---|---|---|"]
        for member in item["members"]:
            if member["built"]:
                words = "(put together in code)"
            elif not member["words"]:
                words = (
                    f"same as `{member['same_as'][:80]}`"
                    if member["same_as"]
                    else "(no words)"
                )
            else:
                shown = []
                for text in member["words"]:
                    cell = f"“{text}”"
                    if member["template"] and "{" in text:
                        cell += f" e.g. “{example(text)}”"
                    shown.append(cell)
                words = " · ".join(shown)
            note = member["doc"]
            words, note = (c.replace("|", "\\|") for c in (words, note))
            out.append(f"| `{item['name']}.{member['name']}` | {words} | {note} |")
        out.append("")
    return "\n".join(out)


def check_spec(classes: list[dict]) -> list[str]:
    """One line per copy class or key a spec names that does not exist."""
    known = {item["name"]: {m["name"] for m in item["members"]} for item in classes}
    problems = []
    for spec in sorted(SPECS.glob("*.md")):
        for number, line in enumerate(spec.read_text().splitlines(), 1):
            for name, key in NAMED.findall(line):
                where = f"{spec.relative_to(ROOT)}:{number}"
                if name not in known:
                    problems.append(
                        f"{where} names `{name}`, which is not a copy class"
                    )
                elif key and key not in known[name]:
                    problems.append(
                        f"{where} names `{name}.{key}`, which is not in {name}"
                    )
    return problems


def key_words(classes: list[dict]) -> list[tuple[str, str, re.Pattern | None]]:
    """[(`Class.key`, its words with gaps as `{}`, a pattern for it filled in)].
    A template with fewer than 3 letters of its own ("{n} {roles}") would match
    anything, so it has no pattern: only its exact words count."""
    found = []
    for item in classes:
        for member in item["members"]:
            for text in member["words"]:
                if not re.search(r"[A-Za-z]", text):
                    continue  # ", " between names: no words
                parts = GAP.split(" ".join(text.split()))
                letters = len(re.findall(r"[A-Za-z]", "".join(parts)))
                filled = None
                if len(parts) > 1 and letters >= 3:
                    gap = r"(?:\{\w+\}|[^.:;{}]+)"
                    filled = re.compile(gap.join(map(re.escape, parts)) + r"\Z")
                key = f"{item['name']}.{member['name']}"
                found.append((key, "{}".join(parts), filled))
    return found


def named_by(quoted: str, words: list) -> str | None:
    """The key whose words `quoted` is: its exact words first, else filled in."""
    shape = GAP.sub("{}", quoted)
    for key, text, _ in words:
        if text == shape:
            return key
    for key, _, filled in words:
        if filled and filled.match(quoted):
            return key
    return None


def section(text: str, start: str) -> list[tuple[int, str]]:
    """(line number, line) for the lines of the `## ` section that begins with `start`."""
    lines = []
    inside = False
    for number, line in enumerate(text.splitlines(), 1):
        if line.startswith("## "):
            inside = line.startswith(start)
        if inside:
            lines.append((number, line))
    return lines


def check_quotes(classes: list[dict]) -> list[str]:
    """One line per quote in a spec's no-quote section that repeats a key's words."""
    words = key_words(classes)
    problems = []
    for name, start in NO_QUOTES.items():
        spec = SPECS / name
        if not spec.exists():
            continue
        for number, line in section(spec.read_text(), start):
            for match in QUOTED.finditer(line):
                quoted = " ".join((match.group(1) or match.group(2)).split())
                key = named_by(quoted, words)
                if key:
                    problems.append(
                        f'{spec.relative_to(ROOT)}:{number} quotes "{quoted}":'
                        f" name `{key}` instead"
                    )
    return problems


def main(argv: list[str]) -> int:
    classes = all_copy()
    if "--check-spec" in argv:
        problems = check_spec(classes) + check_quotes(classes)
        for problem in problems:
            print(problem, file=sys.stderr)
        if problems:
            print(
                "The spec and the code disagree about words: a key it names must exist,"
                " and a key's words are never quoted in it (name the key: the code is"
                " the one home of the words).",
                file=sys.stderr,
            )
        return 1 if problems else 0
    out = (
        Path(argv[argv.index("--out") + 1])
        if "--out" in argv
        else ROOT / "frontend" / "build" / "copy.md"
    )
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(page(classes) + "\n")
    keys = sum(len(item["members"]) for item in classes)
    print(f"copy page: {out} ({len(classes)} groups, {keys} keys)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
