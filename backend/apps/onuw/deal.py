"""Whether a table can be dealt, and what it would be dealt: the ONE rule.

``GameStartView._deal`` refuses a deal with ``deal_refusal`` and the lobby body's
``deal`` (``{"ok", "need", "have"}``) is computed from the same function, so the
phone never holds a "players + 3" rule and the button can never disagree with the
server. ``deck_preview`` is the automatic deck the deal would build for the
players at the table now (``engine.decks.auto_deck``, the deal's own call).

There is no ready check at the deal: everyone at the table is dealt in, so a
guest who closes the app right after joining cannot block it.
"""

from __future__ import annotations

from typing import Any

from django.conf import settings as django_settings

from apps.core import host
from apps.core.models import Lobby, LobbyMember

from . import services
from .engine.decks import MIN_AUTO_PLAYERS, auto_deck
from .engine.validation import (
    MIN_WINDOW_FLOOR_SECONDS,
    TIMED_NIGHT_KEYS,
    clamp_night_timing,
    max_seconds_for,
    seats_of,
    validate_onuw_settings,
)

NOT_WAITING = "Lobby is not in waiting state."

# ``night_protocol: 2``, written for the code BEFORE the cleanup, which still serves
# for a moment while a deploy is promoted: it reads a table or game without it as the
# old night (a refused look, a ready check at the deal, a ``/me/`` with no stage). This
# code ignores the key. ``hooks.APP_DEFAULTS`` writes it on a new table and
# ``dealt_settings`` on every dealt game. Stop writing it in a later push, once no
# instance of the older code is left (``docs/dev/status.md``).
OLD_CODE_NIGHT_FLAG: dict[str, Any] = {"night_protocol": 2}


def _allow_untimed() -> bool:
    return getattr(django_settings, "ONUW_ALLOW_UNTIMED_NIGHT", False)


def dealt_settings(settings: Any) -> dict[str, Any]:
    """The settings a deal of a table with ``settings`` uses: stored timer values the
    server refuses today (a table older code wrote) clamped, so no stored table is
    stuck (``engine.validation.clamp_night_timing``), and ``night_protocol: 2`` for
    the code before the cleanup, which reads a game without it as the old night
    while a deploy is promoted (``OLD_CODE_NIGHT_FLAG``; this code ignores it).
    A new dict."""
    base = settings if isinstance(settings, dict) else {}
    return {
        **clamp_night_timing(base, allow_untimed=_allow_untimed()),
        **OLD_CODE_NIGHT_FLAG,
    }


def deal_refusal(lobby: Lobby, members: list[LobbyMember]) -> Any | None:
    """Why the table cannot be dealt now (the 400 body's ``detail``), or None.

    Everything the deal checks except who taps (host only): the table is waiting
    and the settings are valid for this many players (3 to 10 and, at a table set
    for a number, exactly that many; the deck the right size and legal, the
    automatic deck existing for the count, the timers)."""
    if lobby.status != Lobby.Status.WAITING:
        return NOT_WAITING
    if not isinstance(lobby.settings, dict):
        return ["Settings must be an object."]
    errors = validate_onuw_settings(
        dealt_settings(lobby.settings),
        len(members),
        allow_untimed=_allow_untimed(),
    )
    return errors or None


def deck_preview(settings: Any, player_count: int) -> dict[str, int] | None:
    """The automatic deck the deal would build for ``player_count`` players and
    the table's chip (``{role: count}``, the shape of ``settings.roles``), or None
    for a custom deck or a count with no automatic deck."""
    if not isinstance(settings, dict) or settings.get("deck") != "auto":
        return None
    return auto_deck(player_count, settings.get("deck_chip"))


def _deck_size(settings: Any, player_count: int) -> int:
    """Cards in the deck the deal would use (0 if there is none)."""
    if not isinstance(settings, dict):
        return 0
    if settings.get("deck") == "auto":
        deck = deck_preview(settings, player_count) or {}
    else:
        deck = settings.get("roles")
    if not isinstance(deck, dict):
        return 0
    return sum(c for c in deck.values() if isinstance(c, int) and c > 0)


# Every length a host sets on the set-up page (every timer setting the server
# reads, ``TIMER_SETTING_KEYS``), and what each is when the table sets none (the
# game's own defaults, ``services``; the host handover's, ``core.host``): the lobby
# body's ``lengths``.
LENGTH_DEFAULTS: dict[str, int] = {
    "discussion_seconds": services.DEFAULT_DISCUSSION_SECONDS,
    "voting_seconds": services.DEFAULT_VOTING_SECONDS,
    "night_wave_seconds": services.DEFAULT_NIGHT_WAVE_SECONDS,
    "night_min_window_seconds": services.DEFAULT_NIGHT_MIN_WINDOW_SECONDS,
    "night_doppelganger_window_seconds": (
        services.DEFAULT_NIGHT_DOPPELGANGER_WINDOW_SECONDS
    ),
    "card_look_seconds": services.DEFAULT_CARD_LOOK_SECONDS,
    "disconnect_grace_seconds": services.DEFAULT_DISCONNECT_GRACE_SECONDS,
    "host_handover_seconds": host.DEFAULT_HOST_HANDOVER_SECONDS,
}


def lengths(settings: Any) -> dict[str, int]:
    """Each length the game will run with if dealt now (seconds): the table's own
    value, as the deal would clamp it, else the game's default. So the set-up page
    shows every length without the phone knowing a default."""
    dealt = dealt_settings(settings)
    return {
        key: services.get_timer_value(dealt, key, default)
        for key, default in LENGTH_DEFAULTS.items()
    }


def length_ranges(now: dict[str, int]) -> dict[str, list[int]]:
    """``[least, most]`` seconds a PATCH of each length would take now, given the
    lengths ``now`` (``lengths``): ``engine.validation``'s ranges, with this
    server's night rules (no untimed night window, a minimum window of at least
    5 s, unless the server allows untimed nights) and the minimum window never
    longer than the window. So the phone holds no range rule."""
    untimed = _allow_untimed()
    ranges = {key: [0, max_seconds_for(key)] for key in LENGTH_DEFAULTS}
    if not untimed:
        for key in TIMED_NIGHT_KEYS:
            ranges[key][0] = 1
        ranges["night_min_window_seconds"][0] = MIN_WINDOW_FLOOR_SECONDS
    wave = now["night_wave_seconds"]
    if wave > 0:
        window_min = ranges["night_min_window_seconds"]
        window_min[1] = max(window_min[0], min(window_min[1], wave))
        ranges["night_wave_seconds"][0] = max(
            ranges["night_wave_seconds"][0], now["night_min_window_seconds"]
        )
    return ranges


def deck_cards(settings: Any, size: int) -> dict[str, int]:
    """The roles the table would deal, face up for everyone at the table (which
    roles are in the game is public, as in the card game): a custom deck's cards as
    picked so far; an automatic deck's for the table's size, and for an open table
    of fewer than 3 the smallest game's (3 players), which is the deck it deals
    first. ``{role: count}``, counts above 0; empty when there is none."""
    if not isinstance(settings, dict):
        return {}
    if settings.get("deck") == "auto":
        deck = auto_deck(max(size, MIN_AUTO_PLAYERS), settings.get("deck_chip"))
    else:
        deck = settings.get("roles")
    if not isinstance(deck, dict):
        return {}
    return {
        role: count
        for role, count in deck.items()
        if isinstance(role, str) and type(count) is int and count > 0
    }


def table_size(settings: Any, present: int) -> int:
    """The players the deck is for: the number the table is set for (``seats``),
    else (an open table) the players at the table now."""
    seats = seats_of(settings)
    return present if seats is None else seats


def lobby_extras(lobby: Lobby) -> dict[str, Any]:
    """The lobby body's ONUW keys: ``deck_cards`` (the roles the table would deal,
    face up for everyone, ``deck_cards``), ``lengths``, ``deck_preview`` (the automatic
    deck only, kept for older apps) and ``deal`` (``ok`` exactly as
    the deal would answer now; ``seats`` the players the table is set for, null for
    an open table; ``need`` the cards the deal needs, ``seats`` + 3, or the players
    here + 3 at an open table; ``have`` the cards in the deck). A table set for a
    number never changes ``need`` or ``deck_preview`` when people join or leave."""
    members = list(lobby.players.all())  # type: ignore[attr-defined]
    size = table_size(lobby.settings, len(members))
    now = lengths(lobby.settings)
    return {
        "deck_preview": deck_preview(lobby.settings, size),
        "deck_cards": deck_cards(lobby.settings, size),
        "deal": {
            "ok": deal_refusal(lobby, members) is None,
            "need": size + 3,
            "have": _deck_size(lobby.settings, size),
            "seats": seats_of(lobby.settings),
        },
        "lengths": now,
        "length_ranges": length_ranges(now),
    }
