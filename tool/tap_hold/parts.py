"""The parts the tap/hold check touches, and what in the code each one stands for.

Each part names the file under frontend/lib where its hold is used and the hold
primitive it uses there; `test_tap_hold_parts.py` fails when a file uses one that
no part covers. Its hold time is read from the code (`hold_ms`), never typed here.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "frontend" / "lib"

# What a hold is in the app's code: a primitive built, or a hold handed to one.
USES = re.compile(
    r"\b(FingerTimedLongPress|HoldToReveal|TeachingHold)\(|\b(onLongPress|onLabelLongPress):"
)


class Part:
    def __init__(
        self,
        name,
        file,
        use,
        hold,
        find,
        tap,
        held,
        at=(0.5, 0.5),
        while_held=False,
        most=0,
    ):
        self.name = name  # as a failure names it
        self.file = file  # under frontend/lib: where the hold is used
        self.use = use  # the primitive or argument it uses there
        self.hold = hold  # (file under frontend/lib or "flutter:<file>", constant)
        self.find = find  # the part's words in the semantics (a regex)
        self.tap = tap  # what a tap does: (kind, words); None: nothing
        self.held = held  # what a hold does: (kind, words)
        self.at = at  # where on the part's box the finger goes
        self.while_held = while_held  # what the hold shows goes when the finger lifts
        self.most = most  # touches of a kind per row at most (0: as asked)


# kind "shows": a semantics node says exactly the words while or after the finger
# is down (a held face's label is its target's, without "hidden").
# kind "flips": the words are there after the touch if they were not, and gone if they were.
# kind "count": the words show more or fewer times after the touch (a stepper comes or goes).
PARTS = [
    Part(
        "03 role card",
        "features/lobby/presentation/deck_parts.dart",
        "onLongPress",
        ("design_system/primitives/role_card.dart", "holdDelay"),
        "^Minion$",
        ("flips", "Take one Minion out"),
        ("shows", "Close"),
    ),
    Part(
        "03 players label",
        "features/lobby/presentation/deck_parts.dart",
        "onLabelLongPress",
        ("flutter:gestures/constants.dart", "kLongPressTimeout"),
        "^Lower$",  # the players stepper's (its words are not in the semantics)
        None,
        ("count", "Lower"),
        at=(-4.0, 0.5),  # on the words, left of the stepper
    ),
    Part(
        "04 your card",
        "features/game/presentation/shell/your_card_screen.dart",
        "TeachingHold",
        ("design_system/primitives/hold_to_reveal.dart", "holdDelay"),
        "^Your card, hidden",
        None,
        ("shows", "Your card"),
        while_held=True,
        most=2,  # every row within the look's 120 s, the most a table may set
    ),
    Part(
        "06 own night card",
        "design_system/night/night_board_pieces.dart",
        "TeachingHold",
        ("design_system/primitives/hold_to_reveal.dart", "holdDelay"),
        "^You$",
        (
            "flips",
            "Choose for me",
        ),  # the Drunk's (the check deals this phone the Drunk)
        ("shows", "You"),
        while_held=True,
    ),
    Part(
        "08 My night",
        "features/game/presentation/shell/talk_screen.dart",
        "HoldToReveal",
        ("design_system/primitives/hold_to_reveal.dart", "holdDelay"),
        "My night",
        None,
        ("shows", "My night"),
        while_held=True,
    ),
]


def flutter_root():
    import shutil

    flutter = shutil.which("flutter")
    if not flutter:
        raise LookupError(
            "no flutter on PATH: the Flutter SDK's hold time cannot be read"
        )
    return Path(flutter).resolve().parents[1]


def hold_ms(part):
    """The part's hold time in ms, from the Duration constant its code names."""
    where, name = part.hold
    if where.startswith("flutter:"):
        path = flutter_root() / "packages/flutter/lib/src" / where.split(":", 1)[1]
    else:
        path = LIB / where
    text = path.read_text()
    m = re.search(rf"\b{name}\s*=\s*Duration\(\s*milliseconds:\s*(\d+)\s*\)", text)
    if not m:
        raise LookupError(f"{path}: no `{name} = Duration(milliseconds: n)`")
    return int(m.group(1))


def lift_frames():
    """The frames a hold waits for a lift on a blocked page, from the code."""
    path = LIB / "design_system/primitives/finger_hold.dart"
    m = re.search(r"static const liftFrames = (\d+);", path.read_text())
    if not m:
        raise LookupError(f"{path}: no `static const liftFrames = n;`")
    return int(m.group(1))


def same_both_ways(text, start):
    """Whether the call around `start` hands its tap and its hold the same thing
    (`onTap: f, onLongPress: f`): a quick touch taken for a hold does what it would."""
    depth, i = 0, start
    while i > 0:
        i -= 1
        c = text[i]
        if c == ")":
            depth += 1
        elif c == "(":
            if depth == 0:
                break
            depth -= 1
    depth, j = 0, i + 1
    while j < len(text):
        c = text[j]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            if depth == 0:
                break
            depth -= 1
        j += 1
    call = text[i + 1 : j]

    def arg(key):
        m = re.search(rf"\b{key}:\s*(.+?),?\s*$", call, re.M)
        return m.group(1).strip().rstrip(",") if m else None

    tap, hold = arg("onTap"), arg("onLongPress")
    return tap is not None and tap == hold


PRIMITIVE = re.compile(
    r"\bclass\s+(FingerTimedLongPress|HoldToReveal|TeachingHold)\b"
    r"|\bfinal\s+\w+\??\s+(onLongPress|onLabelLongPress);"
)


def uses():
    """Every hold used under frontend/lib: (file, what, line). Not counted: a hold
    primitive's own file (it is one, or takes a hold from its caller and forwards
    it: covered where it is used), a type pattern (`HoldToReveal() =>`), and a call
    whose tap and hold do the same (`same_both_ways`)."""
    found = []
    for path in sorted(LIB.rglob("*.dart")):
        if path.name.endswith(".g.dart"):
            continue
        text = path.read_text()
        if PRIMITIVE.search(text):
            continue
        for m in USES.finditer(text):
            name = m.group(1) or m.group(2)
            line_start = text.rfind("\n", 0, m.start()) + 1
            if text[line_start : m.start()].lstrip().startswith("//"):
                continue
            if re.match(r"\)\s*=>", text[m.end() :]):
                continue
            if name == "onLongPress" and same_both_ways(text, m.start()):
                continue
            rel = path.relative_to(LIB).as_posix()
            found.append((rel, name, text.count("\n", 0, m.start()) + 1))
    return found


def reached_by(changed):
    """Whether a change (paths from the repo root) reaches a hold: a hold
    primitive's file, a part's file, or this check."""
    files = {f"frontend/lib/{p.file}" for p in PARTS}
    for path in LIB.rglob("*.dart"):
        if PRIMITIVE.search(path.read_text(errors="ignore")):
            files.add(path.relative_to(ROOT).as_posix())
    return any(c in files or c.startswith("tool/tap_hold/") for c in changed)
