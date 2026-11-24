"""How values are written into what the server sends.

One form each, everywhere (issue #17): a body or an event never has to be read
knowing which code path made it.
"""

from datetime import UTC, datetime
from typing import Any


def wire_time(moment: datetime) -> str:
    """A moment as every payload writes it: UTC, ISO 8601, ending in ``Z``
    (``2024-03-07T20:57:30Z``), the form DRF's own date fields use.

    ``datetime.isoformat()`` writes the same moment as ``...+00:00``. Both parse,
    but two spellings of one instant made a client that compared the strings
    wrong.
    """
    if moment.tzinfo is None:
        # a time with no zone would be read as this machine's local time
        raise ValueError("wire_time needs a time that says its zone")
    return moment.astimezone(UTC).isoformat().replace("+00:00", "Z")


NAMELESS = "Player"


def public_name(user: Any) -> str:
    """The name of ``user`` that other players may read: its display name, or
    ``"Player"`` when it has none. NEVER its username.

    A guest's username is its account's id. ``display_name or username`` sent
    that id to the whole table as a name for an account with no display name
    (one made by hand: every guest and practice player is given a name).
    """
    return (getattr(user, "display_name", "") or "").strip() or NAMELESS
