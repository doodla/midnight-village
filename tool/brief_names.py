"""Everyday names for screens ("lobby", "your card", "set-up page"), found in the code.

`just brief lobby` once answered nothing: a builder says what the owner says, not a
screen's number. Nothing here is a list kept by hand:

- the app's own names: `AppScreen` in frontend/lib/features/game/domain/screen_table.dart
  (`yourCard('04', 'Your card')` answers "yourCard", "your card", "your-card");
- a feature folder (`frontend/lib/features/lobby/`): the screens whose states draw a
  widget declared in it.

(tool/brief.py also reads the words of each spec section's first line, "the set-up page".)
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TABLE = "frontend/lib/features/game/domain/screen_table.dart"
FEATURES = "frontend/lib/features"


def plain(text: str) -> str:
    return (
        re.sub(r"[\s_-]+", " ", re.sub(r"(?<=[a-z])(?=[A-Z])", " ", text))
        .strip()
        .lower()
    )


def by_app_name(asked: str, table: str) -> list[str]:
    """The screen `AppScreen` calls `asked`, by its enum name or its own name."""
    want = plain(asked)
    return sorted(
        number
        for enum, number, name in re.findall(r"(\w+)\('(\d\d\w?)', '([^']+)'\)", table)
        if want in (plain(enum), plain(name))
    )


def by_feature(asked: str, widgets: dict, owners: dict, screen_of) -> list[str]:
    """The screens whose states draw a widget declared under features/<asked>/."""
    folder = f"{FEATURES}/{plain(asked).replace(' ', '_')}/"
    if not (ROOT / folder).is_dir():
        return []
    found = set()
    for state, names in widgets.items():
        if re.match(r"\d\d", state) and any(
            path.startswith(folder) for name in names for path in owners.get(name, ())
        ):
            found.add(screen_of(state))
    return sorted(found)


def lookup(asked: str, widgets: dict, owners: dict, screen_of) -> list[str]:
    table = (ROOT / TABLE).read_text() if (ROOT / TABLE).is_file() else ""
    return by_app_name(asked, table) or by_feature(asked, widgets, owners, screen_of)
