#!/usr/bin/env python3
"""What a builder needs to start on a screen, printed from the sources themselves.

    just brief 09            a screen by its number (01, 01b, 02 ... 11)
    just brief end-board     or by a word its catalogue states hold

A brief written from memory was wrong (it told a builder to show something the
spec says is never shown), and a builder spent twenty to forty calls finding out
where things are. This prints the facts, word for word, so a brief can say
"run `just brief 09`" plus the task:

- the spec's own section for the screen, and where else the specs name it;
- every line the owner said about it (docs/dev/owner-feedback.md), with its date;
- its catalogue states, and the faults parked for them (not_yet_swept.dart);
- the app files that draw it, each with its size against the 600-line limit,
  the design-system parts it uses, and its copy classes;
- its tests; the branches on the remote that change the same files right now;
- the commands, and where they run.

Nothing here is kept by hand: files and parts come from walking each state's
widget tree (tool/piece_screens.py), the rest from the files named above.
"""

import importlib.util
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from brief_docs import DOCS, app_rules, capped

ROOT = Path(__file__).resolve().parents[1]
SPEC = "docs/specs/frontend/first-time-play.md"
SPECS = "docs/specs/frontend"
FEEDBACK = "docs/dev/owner-feedback.md"
PARKED = "frontend/test/screen_cases/not_yet_swept.dart"
LIMIT = 600
DESIGN_README = "frontend/lib/design_system/README.md"
# What in a state's tree says a finger is down, or a sheet is open.
HELD = {"HeldFace"}
SHEET = {"SheetScaffold"}
# Lines shown for one part before "and N more".
PART_LINES = 6
SCREEN_HEAD = re.compile(r"^\*\*(\d\d[a-z]?)(?: and (\d\d))?[ :]")
COPY_CLASS = re.compile(r"\b([A-Z]\w*Copy)\.\w+")
COMMANDS = """\
  just look <state>            one state at a phone's size, main beside your change
  just piece-check             while building: fast checks and the tests your change reaches
  just screens 390 strict      every state, strict (also 360)
  just copy-page               every word a player reads, on one page
  just handover <file>         LAST: the only way to hand over (checks, pictures, the file)
  just heavy --status          who holds a slot of the heavy queue, who waits
  (all from the repo root)"""


def tool(name: str):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tool" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.ROOT = ROOT
    return module


def spec_sections(text: str) -> dict[str, tuple[int, str]]:
    """{screen number: (line it starts at, its block word for word)}."""
    lines = text.splitlines()
    starts = [(i, m) for i, line in enumerate(lines) if (m := SCREEN_HEAD.match(line))]
    found: dict[str, tuple[int, str]] = {}
    for at, (i, match) in enumerate(starts):
        end = starts[at + 1][0] if at + 1 < len(starts) else len(lines)
        # the per-screen sheet ends at the next heading
        for j in range(i + 1, end):
            if lines[j].startswith("#"):
                end = j
                break
        block = "\n".join(lines[i:end]).rstrip()
        for number in (match.group(1), match.group(2)):
            if number:
                found[number] = (i + 1, block)
    return found


def screen_of(state: str) -> str:
    return state.split("-")[0]


def which_screens(asked: str, states: list[str], sections) -> list[str]:
    """The screen numbers `asked` means: a number, a word some states hold, or
    words of a spec section's name ("end-board": "10 and 11: the end board", and
    the states that hold "end")."""
    numbered = [s for s in states if re.match(r"\d\d", s)]
    known = sorted({screen_of(s) for s in numbered} | set(sections))
    if asked in known:
        return [asked]
    if re.fullmatch(r"\d", asked) and f"0{asked}" in known:
        return [f"0{asked}"]
    found = {screen_of(s) for s in numbered if asked.lower() in s.lower()}
    if not found:
        phrase = asked.lower().replace("-", " ")
        named = {
            n
            for n, (_, block) in sections.items()
            if phrase in block.splitlines()[0].lower().replace("-", " ")
        }
        if named:
            words = [w for w in phrase.split() if len(w) > 2]
            # the states are found by the name's first word ("end"), not by a
            # common one ("board" is also the night's)
            found = named | {
                screen_of(s)
                for s in numbered
                if words and words[0] in s.lower().split("-")
            }
    return sorted(found)


# A quoted line is quoted with the paragraph or list item it sits in, so the
# sentence that names a screen keeps the sentence that carries its rule ("... on
# 09. It must never truncate."). A block longer than WHOLE lines is quoted as the
# line with one before and AFTER after it, and says where it was cut.
WHOLE, AFTER = 6, 2
_ITEM = re.compile(r"^\s*([-*+]|\d+[.)])\s")


def quoted(lines: list[str], index: int) -> tuple[str, int]:
    """(the block around lines[index] as one text, the index of its last line used)."""

    def starts_block(i: int) -> bool:
        line = lines[i]
        return bool(_ITEM.match(line)) or line.startswith(("#", "|", "```"))

    first = index
    while first > 0 and lines[first - 1].strip() and not starts_block(first):
        first -= 1
    last = index
    while (
        last + 1 < len(lines) and lines[last + 1].strip() and not starts_block(last + 1)
    ):
        last += 1
    if last - first + 1 > WHOLE:
        cut_first, cut_last = max(first, index - 1), min(last, index + AFTER)
        text = " ".join(line.strip() for line in lines[cut_first : cut_last + 1])
        text = ("[...] " if cut_first > first else "") + text
        text += " [...]" if cut_last < last else ""
        return text, cut_last
    return " ".join(line.strip() for line in lines[first : last + 1]), last


def said_by_owner(
    text: str, numbers: list[str], names: list[str]
) -> list[tuple[str, int, str]]:
    """(the dated heading, line number, the line) for each line about the screen."""
    wanted = [
        # a number that ends a sentence ("... on 09.") is the screen; one inside a
        # figure ("0.9", "09.5", "9:41") is not
        re.compile(
            rf"(?<![\w.:-]){re.escape(n)}(?![\w:-]|\.\w|\s*(?:November|px|s\b|%))"
        )
        for n in numbers
    ]
    wanted += [re.compile(re.escape(name), re.I) for name in names if len(name) > 3]
    found, heading, done = [], "", -1
    lines = text.splitlines()
    for index, line in enumerate(lines):
        number = index + 1
        if line.startswith("## "):
            heading = line[3:].strip()
            if any(p.search(line) for p in wanted):
                found.append((heading, number, "(the whole section is about it)"))
            continue
        if index <= done:
            continue  # already quoted with the line before it
        if line.strip() and any(p.search(line) for p in wanted):
            block, done = quoted(lines, index)
            found.append((heading, number, block))
    return found


def state_line(state: str, mine: list[str], widgets: dict, kit: set[str]) -> str:
    """A state, and what its tree says its fixture did: held, a sheet open, the
    text size, and the parts it draws that the state it grows from does not."""
    said = []
    names = set(widgets[state])
    if HELD & names or "-held" in state:
        said.append("HELD (a finger is down and the held face or panel is drawn)")
    if SHEET & names:
        said.append("a SHEET is open")
    scale = re.search(r"-x(\d(?:\.\d)?)$", state)
    if scale:
        said.append(f"text x{scale.group(1)}")
    grows_from = max(
        (other for other in mine if state.startswith(other + "-")),
        key=len,
        default=None,
    )
    if grows_from:
        more = sorted((names - set(widgets[grows_from])) & kit)
        if more:
            said.append(
                f"beyond {grows_from}: {', '.join(more[:8])}"
                + (" ..." if len(more) > 8 else "")
            )
    return state + ("   <- " + "; ".join(said) if said else "")


def parked_faults(text: str, mine: list[str]) -> list[str]:
    """Each parked entry of `mine` whole (its reason runs over several lines), with
    the text of a constant it names."""
    lines, found = text.splitlines(), []
    for i, line in enumerate(lines):
        if not any(f"'{state}'" in line for state in mine):
            continue
        entry = [line.rstrip()]
        j = i
        while not lines[j].rstrip().endswith(",") and j + 1 < len(lines):
            j += 1
            entry.append(lines[j].rstrip())
        named = re.search(r":\s*(_\w+),", " ".join(entry))
        if named:
            start = next(
                (
                    k
                    for k, l in enumerate(lines)
                    if l.startswith(f"const {named.group(1)} =")
                ),
                None,
            )
            if start is not None:
                k = start
                while not lines[k].rstrip().endswith(";"):
                    k += 1
                entry.append(
                    "    where " + " ".join(l.strip() for l in lines[start : k + 1])
                )
        found.append("\n".join(entry))
    return found


def part_rules(name: str, documents: list[str]) -> list[tuple[str, str]]:
    """(file:line, the line) for each line that names the part `name`, as its class
    name or as its words ("HeldFace": "held face", "held-face")."""
    words = re.sub(r"(?<!^)(?=[A-Z])", " ", name).lower().split()
    wanted = re.compile(
        rf"\b{re.escape(name)}\b|\b{'[ -]'.join(map(re.escape, words))}\b",
        re.I if len(words) > 1 else 0,
    )
    found = []
    for document in documents:
        lines = DOCS.text(document).splitlines()
        done = -1
        for number, line in enumerate(lines, 1):
            if number - 1 <= done or not wanted.search(line):
                continue
            text, done = quoted(lines, number - 1)
            # a rule's heading line ("**The held-face frame** is ...:") carries its
            # rule in the list under it: that list is the rule
            if text.startswith("**") or text.endswith(":"):
                under = done + 1
                while under < len(lines) and lines[under].lstrip().startswith(
                    ("- ", "* ")
                ):
                    text += "\n      " + lines[under].strip()
                    under += 1
            found.append((f"{document}:{number}", text))
    return found


def others_in(files: set[str]) -> dict[str, list[str]]:
    """{remote branch: the files of `files` it changes} for branches not yet merged."""
    subprocess.run(
        ["git", "-C", str(ROOT), "fetch", "--quiet", "--no-tags", "--prune", "origin"],
        capture_output=True,
    )
    refs = subprocess.run(
        [
            "git",
            "-C",
            str(ROOT),
            "for-each-ref",
            "--format=%(refname:short)",
            "--no-merged",
            "origin/main",
            "refs/remotes/origin",
        ],
        capture_output=True,
        text=True,
    ).stdout.split()
    mine = subprocess.run(
        ["git", "-C", str(ROOT), "rev-parse", "--abbrev-ref", "HEAD"],
        capture_output=True,
        text=True,
    ).stdout.strip()
    found = {}
    for ref in refs:
        if ref in ("origin/HEAD", f"origin/{mine}") or ref.startswith(
            ("origin/live-",)
        ):
            continue
        changed = subprocess.run(
            ["git", "-C", str(ROOT), "diff", "--name-only", f"origin/main...{ref}"],
            capture_output=True,
            text=True,
        ).stdout.split()
        both = sorted(files & set(changed))
        if both:
            found[ref.removeprefix("origin/")] = both
    return found


# What each list a screen's brief makes from code may cost, in tokens: the budget
# (tool/context_budget.py) counts these caps, since it measures without building
# the widget trees.
CODE_CAPS = {
    "states": 400,
    "parked": 500,
    "parts": 1500,
    "files": 500,
    "tests": 400,
    "others": 200,
}


def the_names(numbers: list[str], sections) -> list[str]:
    """The screens' names, from their spec sections' first lines."""
    names = []
    for number in numbers:
        if number in sections:
            first = sections[number][1].splitlines()[0]
            names.append(
                re.sub(r"^\*\*\d\d[a-z]?(?: and \d\d)?:? ?|\*\*.*$", "", first).strip()
            )
    return names


def doc_part(asked: str, numbers: list[str], sections) -> list[str]:
    """The part of a screen's brief quoted from documents: the spec, the owner."""
    out = [f"# Brief: screen {' and '.join(numbers)}\n"]
    out.append(
        "Everything below is copied from the sources named. "
        "Read the source before changing what it says.\n"
    )
    whole = f"{SPECS}/{asked}.md"
    if DOCS.read(whole) is not None:
        out.append(
            f"This has a spec file of its own: {whole}"
            f" ({len(DOCS.text(whole).splitlines())} lines). Read it whole.\n"
        )
    out.append(f"## The spec ({SPEC})\n")
    for number in numbers:
        if number in sections:
            line, block = sections[number]
            out.append(f"(line {line})\n\n{block}\n")
        else:
            out.append(f"No per-screen section for {number} in {SPEC}.\n")
    elsewhere = []
    for spec in DOCS.glob(f"{SPECS}/*.md"):
        for n, line in enumerate(DOCS.text(spec).splitlines(), 1):
            if line.startswith("#") and any(
                re.search(rf"(?<!\d){re.escape(x)}(?!\d)", line) for x in numbers
            ):
                elsewhere.append(f"  {spec}:{n}  {line.strip()}")
    if elsewhere:
        out.append(
            "Headings elsewhere in the specs that name it:\n"
            + "\n".join(elsewhere)
            + "\n"
        )

    out.append(f"## What the owner said ({FEEDBACK})\n")
    out.append(
        "Every line that names the screen by number or by name"
        " (so some are about another screen: read them)."
    )
    said = said_by_owner(DOCS.text(FEEDBACK), numbers, the_names(numbers, sections))
    if not said:
        out.append("Nothing names this screen.\n")
    heading = None
    for under, number, line in said:
        if under != heading:
            out.append(f"\n### {under}")
            heading = under
        out.append(f"  {number}: {line}")
    out.append("")
    out.append(f"## The design system's README about this screen ({DESIGN_README})\n")
    noted = said_by_owner(DOCS.text(DESIGN_README), numbers, [])
    out.append(
        "\n".join(f"  {number}: {line}" for _, number, line in noted)
        or "Nothing names it by number."
    )
    out.append("")
    return out + app_rules()


def tail_part() -> list[str]:
    return [
        "## Commands\n\n" + COMMANDS,
        "## Waiting\n\n" + tool("brief_areas").WAITING + "\n",
        "## Handing back\n\n" + tool("brief_areas").HANDBACK + "\n",
    ]


def code_part(numbers: list[str], widgets: dict, states: list[str]) -> list[str]:
    """The part of a screen's brief made from code: states, parts, files, tests.
    Each list is capped (CODE_CAPS)."""
    screens, piece = tool("piece_screens"), tool("piece_check")
    mine = [s for s in states if screen_of(s) in numbers]
    owner = screens.owners()
    drawn_by: dict[str, set[str]] = defaultdict(set)
    for state, names in widgets.items():
        for name in names:
            for path in owner.get(name, ()):
                drawn_by[path].add(screen_of(state))
    used = {path for path, by in drawn_by.items() if by & set(numbers)}
    every = len({screen_of(s) for s in states})
    features = sorted(p for p in used if "/features/" in p)
    # a file most screens draw (the game's shell) is not this screen's own
    own = [p for p in features if len(drawn_by[p]) <= max(3, every // 3)]
    parts = sorted(p for p in used if "/design_system/" in p)

    def also(path: str) -> str:
        others = sorted(n for n in drawn_by[path] - set(numbers) if n[:1].isdigit())
        if others:
            return f"  (also drawn by {', '.join(others)})"
        return "  (this screen only)"

    def size(path: str) -> str:
        lines = len((ROOT / path).read_text().splitlines())
        flag = (
            "  OVER THE LIMIT: may shrink, never grow"
            if lines > LIMIT
            else ("  near the limit" if lines > LIMIT - 60 else "")
        )
        return f"{lines:4d} lines  {path}{flag}"

    out = [f"## Catalogue states ({len(mine)})\n"]
    out.append(
        "What a state draws beyond the plain one it grows from says what its fixture did.\n"
    )
    kit = {name for name, paths in owner.items() if not name.startswith("_")}
    out += capped(
        ["  " + state_line(s, mine, widgets, kit) for s in mine],
        CODE_CAPS["states"],
        "`just screens` lists them",
    )
    out.append("")
    parked = ROOT / PARKED
    if parked.is_file():
        held = parked_faults(parked.read_text(), mine)
        out.append(f"Parked faults ({PARKED}): " + (f"{len(held)}" if held else "none"))
        out += capped(
            [f"\n{entry}\n" for entry in held], CODE_CAPS["parked"], f"read {PARKED}"
        )

    out.append("## Rules about the parts it draws\n")
    special = sorted(
        name
        for name in {n for state in mine for n in widgets[state]} & kit
        if any("/design_system/" in path for path in owner[name])
        and len({screen_of(s) for s in states if name in widgets[s]})
        <= max(3, every // 2)
    )
    out.append(
        "Lines of the specs and of the design system's README that name a part this"
        " screen draws and most screens do not (so a rule written in a general section"
        " is not missed). Word for word; read around them.\n"
    )
    documents = [*DOCS.glob(f"{SPECS}/*.md"), DESIGN_README]
    rules = []
    for name in special:
        found = part_rules(name, documents)
        if not found:
            continue
        rules.append(f"### {name}")
        rules += [f"  {where}  {line}" for where, line in found[:PART_LINES]]
        if len(found) > PART_LINES:
            rules.append(
                f"  ... and {len(found) - PART_LINES} more lines name it (search for it)."
            )
        rules.append("")
    out += capped(rules, CODE_CAPS["parts"], "search the specs for the part's name")

    out.append("## App files\n")
    files = ["Feature files that draw it:"]
    files += ["  " + size(p) + also(p) for p in features] or ["  (none)"]
    files.append(f"\nDesign-system parts it uses ({len(parts)}):")
    files += [f"  {p}" for p in parts]
    copy = sorted({m for p in own for m in COPY_CLASS.findall((ROOT / p).read_text())})
    files.append(
        "\nCopy classes its own files read: "
        + (", ".join(copy) or "none")
        + "  (the words: `just copy-page`)\n"
    )
    out += capped(files, CODE_CAPS["files"])

    out.append("## Tests\n")
    top = ROOT / "frontend"
    targets = {(ROOT / p).resolve() for p in own}
    near = [
        str(test.relative_to(ROOT))
        for test in sorted((top / "test").rglob("*_test.dart"))
        if {
            p.resolve()
            for p in piece.dart_imports(test, top / "lib", "midnight_village")
        }
        & targets
    ]
    out.append("Import this screen's files directly:")
    out += capped([f"  {t}" for t in near] or ["  (none)"], CODE_CAPS["tests"])
    out.append(
        "Every state is also swept (frontend/test/screen_cases/) and drawn (`just screens`).\n"
    )

    out.append("## Who else is in these files (branches on the remote, not merged)\n")
    others = others_in(set(own))
    out += capped(
        [f"  {branch}: " + ", ".join(files) for branch, files in others.items()]
        or ["Nobody.\n"],
        CODE_CAPS["others"],
    )
    return out


def screen_brief(asked: str, numbers: list[str], widgets: dict | None) -> str:
    """The brief of the screens `numbers`. With no widget trees (the budget's
    measure) only the parts quoted from documents are built."""
    sections = spec_sections(DOCS.text(SPEC))
    out = doc_part(asked, numbers, sections)
    if widgets is not None:
        out += code_part(numbers, widgets, sorted(widgets))
    out += tail_part()
    return "\n".join(out)


def screen_names() -> list[str]:
    """Every brief of a screen, read from the documents alone (no widget trees):
    each screen the spec has a section for, and each spec file of its own."""
    sections = spec_sections(DOCS.text(SPEC))
    own = [p.rsplit("/", 1)[1][:-3] for p in DOCS.glob(f"{SPECS}/*.md")]
    return sorted(sections) + [n for n in own if which_screens(n, [], sections)]


def main(argv: list[str]) -> int:
    areas = tool("brief_areas")
    if len(argv) == 1 and argv[0] in areas.AREAS:
        print(areas.brief(argv[0], others_in))
        return 0
    sections = spec_sections(DOCS.text(SPEC))

    def every() -> str:
        # the spec's screens and the catalogue's state numbers, read as text (no widget trees)
        catalogue = (ROOT / "frontend/test_screens/catalogue").glob("*.dart")
        ids = {
            n for f in catalogue for n in re.findall(r"'(\d\d[a-z]?)-", f.read_text())
        }
        return (
            f"Screens (just brief 09):\n  {' '.join(sorted(ids | set(sections)))}\n"
            "  or a word from a state's id (`just screens` lists them), e.g. end-board\n\n"
            f"Areas that are not a screen (just brief copy):\n{areas.listing()}"
        )

    if len(argv) != 1:
        # no argument is a question, not a mistake: what briefs are there? (at once:
        # the screens the spec names, without reading every state's widgets)
        print("usage: just brief <screen or area>\n\n" + every())
        return 0 if not argv else 2
    widgets = tool("piece_screens").state_widgets()
    states = sorted(widgets)
    # an everyday name ("lobby", "your card"): the app's own names, a feature folder
    numbers = which_screens(argv[0], states, sections) or tool("brief_names").lookup(
        argv[0], widgets, tool("piece_screens").owners(), screen_of
    )
    if not numbers:
        print(f"brief: no screen or area '{argv[0]}'.\n\n{every()}", file=sys.stderr)
        return 1
    print(screen_brief(argv[0], numbers, widgets))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
