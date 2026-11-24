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
            n for n, (_, block) in sections.items() if phrase in block.splitlines()[0].lower()
        }
        if named:
            words = [w for w in phrase.split() if len(w) > 2]
            # the states are found by the name's first word ("end"), not by a
            # common one ("board" is also the night's)
            found = named | {
                screen_of(s) for s in numbered if words and words[0] in s.lower().split("-")
            }
    return sorted(found)


def said_by_owner(
    text: str, numbers: list[str], names: list[str]
) -> list[tuple[str, int, str]]:
    """(the dated heading, line number, the line) for each line about the screen."""
    wanted = [
        re.compile(rf"(?<![\w.:-]){re.escape(n)}(?![\w.:-]|\s*(?:November|px|s\b|%))")
        for n in numbers
    ]
    wanted += [re.compile(re.escape(name), re.I) for name in names if len(name) > 3]
    found, heading = [], ""
    for number, line in enumerate(text.splitlines(), 1):
        if line.startswith("## "):
            heading = line[3:].strip()
            if any(p.search(line) for p in wanted):
                found.append((heading, number, "(the whole section is about it)"))
            continue
        if line.strip() and any(p.search(line) for p in wanted):
            found.append((heading, number, line.strip()))
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
        (other for other in mine if state.startswith(other + "-")), key=len, default=None
    )
    if grows_from:
        more = sorted((names - set(widgets[grows_from])) & kit)
        if more:
            said.append(f"beyond {grows_from}: {', '.join(more[:8])}" + (" ..." if len(more) > 8 else ""))
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
            start = next((k for k, l in enumerate(lines) if l.startswith(f"const {named.group(1)} =")), None)
            if start is not None:
                k = start
                while not lines[k].rstrip().endswith(";"):
                    k += 1
                entry.append("    where " + " ".join(l.strip() for l in lines[start : k + 1]))
        found.append("\n".join(entry))
    return found


def part_rules(name: str, documents: list[Path]) -> list[tuple[str, str]]:
    """(file:line, the line) for each line that names the part `name`, as its class
    name or as its words ("HeldFace": "held face", "held-face")."""
    words = re.sub(r"(?<!^)(?=[A-Z])", " ", name).lower().split()
    wanted = re.compile(
        rf"\b{re.escape(name)}\b|\b{'[ -]'.join(map(re.escape, words))}\b",
        re.I if len(words) > 1 else 0,
    )
    found = []
    for document in documents:
        lines = document.read_text().splitlines()
        for number, line in enumerate(lines, 1):
            if not wanted.search(line):
                continue
            text = line.strip()
            # a rule's heading line ("**The held-face frame** is ...:") carries its
            # rule in the list under it: that list is the rule
            if text.startswith("**") or text.endswith(":"):
                under = number
                while under < len(lines) and lines[under].lstrip().startswith(("- ", "* ")):
                    text += "\n      " + lines[under].strip()
                    under += 1
            found.append((f"{document.relative_to(ROOT)}:{number}", text))
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


def main(argv: list[str]) -> int:
    if len(argv) != 1:
        print(
            "usage: just brief <screen>     e.g. just brief 09, just brief end-board",
            file=sys.stderr,
        )
        return 2
    screens, piece = tool("piece_screens"), tool("piece_check")
    widgets = screens.state_widgets()
    states = sorted(widgets)
    sections = spec_sections((ROOT / SPEC).read_text())
    numbers = which_screens(argv[0], states, sections)
    if not numbers:
        known = sorted(
            {screen_of(s) for s in states if re.match(r"\d\d", s)} | set(sections)
        )
        print(
            f"brief: no screen '{argv[0]}'. Screens: {' '.join(known)}; or a word from a state's id (`just screens` lists them).",
            file=sys.stderr,
        )
        return 1
    mine = [s for s in states if screen_of(s) in numbers]
    owner = screens.owners()

    # the files whose widgets these states draw, and how many OTHER screens draw each
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
        return f"  (also drawn by {', '.join(others)})" if others else "  (this screen only)"

    def size(path: str) -> str:
        lines = len((ROOT / path).read_text().splitlines())
        flag = (
            "  OVER THE LIMIT: may shrink, never grow"
            if lines > LIMIT
            else ("  near the limit" if lines > LIMIT - 60 else "")
        )
        return f"{lines:4d} lines  {path}{flag}"

    print(f"# Brief: screen {' and '.join(numbers)}\n")
    print(
        "Everything below is copied from the sources named. Read the source before changing what it says.\n"
    )
    whole = ROOT / SPECS / f"{argv[0]}.md"
    if whole.is_file():
        print(
            f"This has a spec file of its own: {whole.relative_to(ROOT)}"
            f" ({len(whole.read_text().splitlines())} lines). Read it whole.\n"
        )

    print(f"## The spec ({SPEC})\n")
    names = []
    for number in numbers:
        if number in sections:
            line, block = sections[number]
            names.append(
                re.sub(
                    r"^\*\*\d\d[a-z]?(?: and \d\d)?:? ?|\*\*.*$",
                    "",
                    block.splitlines()[0],
                ).strip()
            )
            print(f"(line {line})\n\n{block}\n")
        else:
            print(f"No per-screen section for {number} in {SPEC}.\n")
    elsewhere = []
    for spec in sorted((ROOT / SPECS).glob("*.md")):
        for n, line in enumerate(spec.read_text().splitlines(), 1):
            if line.startswith("#") and any(
                re.search(rf"(?<!\d){re.escape(x)}(?!\d)", line) for x in numbers
            ):
                elsewhere.append(f"  {spec.relative_to(ROOT)}:{n}  {line.strip()}")
    if elsewhere:
        print(
            "Headings elsewhere in the specs that name it:\n"
            + "\n".join(elsewhere)
            + "\n"
        )

    print(f"## What the owner said ({FEEDBACK})\n")
    print("Every line that names the screen by number or by name (so some are about another screen: read them).")
    said = said_by_owner((ROOT / FEEDBACK).read_text(), numbers, names)
    if not said:
        print("Nothing names this screen.\n")
    heading = None
    for under, number, line in said:
        if under != heading:
            print(f"\n### {under}")
            heading = under
        print(f"  {number}: {line}")
    print()

    print(f"## Catalogue states ({len(mine)})\n")
    print("What a state draws beyond the plain one it grows from says what its fixture did.\n")
    kit = {name for name, paths in owner.items() if not name.startswith("_")}
    for state in mine:
        print("  " + state_line(state, mine, widgets, kit))
    print()
    parked = ROOT / PARKED
    if parked.is_file():
        held = parked_faults(parked.read_text(), mine)
        print(f"Parked faults ({PARKED}): " + (f"{len(held)}" if held else "none"))
        print("".join(f"\n{entry}\n" for entry in held))

    print("## Rules about the parts it draws\n")
    special = sorted(
        name
        for name in {n for state in mine for n in widgets[state]} & kit
        if any("/design_system/" in path for path in owner[name])
        and len({screen_of(s) for s in states if name in widgets[s]}) <= max(3, every // 2)
    )
    print(
        "Lines of the specs and of the design system's README that name a part this"
        " screen draws and most screens do not (so a rule written in a general section"
        " is not missed). Word for word; read around them.\n"
    )
    documents = [*sorted((ROOT / SPECS).glob("*.md")), ROOT / DESIGN_README]
    for name in special:
        found = part_rules(name, documents)
        if not found:
            continue
        print(f"### {name}")
        for where, line in found[:PART_LINES]:
            print(f"  {where}  {line}")
        if len(found) > PART_LINES:
            print(f"  ... and {len(found) - PART_LINES} more lines name it (search for it).")
        print()

    print(f"## The design system's README about this screen ({DESIGN_README})\n")
    noted = said_by_owner((ROOT / DESIGN_README).read_text(), numbers, [])
    print("\n".join(f"  {number}: {line}" for _, number, line in noted) or "Nothing names it by number.")
    print()

    print("## App files\n")
    print("Feature files that draw it:")
    print("\n".join("  " + size(p) + also(p) for p in features) or "  (none)")
    print(f"\nDesign-system parts it uses ({len(parts)}):")
    print("\n".join(f"  {p}" for p in parts))
    copy = sorted(
        {
            m
            for p in own
            for m in COPY_CLASS.findall((ROOT / p).read_text())
        }
    )
    print(
        "\nCopy classes its own files read: "
        + (", ".join(copy) or "none")
        + "  (the words: `just copy-page`)\n"
    )

    print("## Tests\n")
    top = ROOT / "frontend"
    targets = {(ROOT / p).resolve() for p in own}
    package = "midnight_village"
    near = []
    for test in sorted((top / "test").rglob("*_test.dart")):
        if {
            p.resolve() for p in piece.dart_imports(test, top / "lib", package)
        } & targets:
            near.append(str(test.relative_to(ROOT)))
    print(
        "Import this screen's files directly:\n"
        + ("\n".join(f"  {t}" for t in near) or "  (none)")
    )
    print(
        "Every state is also swept (frontend/test/screen_cases/) and drawn (`just screens`).\n"
    )

    print("## Who else is in these files (branches on the remote, not merged)\n")
    others = others_in(set(own))
    if not others:
        print("Nobody.\n")
    for branch, files in others.items():
        print(f"  {branch}: " + ", ".join(files))
    print("\n## Commands\n\n" + COMMANDS)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
