"""Whether a table can be dealt, and what it would be dealt: the ONE rule.

``GameStartView._deal`` refuses a deal with ``deal_refusal`` and the lobby body's
``deal`` (``{"ok", "need", "have", "seats"}``) is computed from the same function,
so the phone never holds a "players + 3" rule and the button can never disagree
with the server. The deck is for the table's size (``table_size``: the number it is
set for, else the players here): ``deck_cards`` (every role it would deal, face up
for everyone) and ``deck_preview`` (the automatic deck, ``engine.decks.auto_deck``,
the deal's own call). ``lengths``, ``length_ranges`` and ``seats_range`` come from
``engine.validation``'s rule table, the one the settings check uses.

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
    clamp_night_timing,
    length_ranges,
    running_lengths,
    seats_of,
    seats_range,
    validate_onuw_settings,
)

NOT_WAITING = "Lobby is not in waiting state."


def _allow_untimed() -> bool:
    return getattr(django_settings, "ONUW_ALLOW_UNTIMED_NIGHT", False)


def dealt_settings(settings: Any) -> dict[str, Any]:
    """The settings a deal of a table with ``settings`` uses: stored timer values the
    server refuses today (a table older code wrote) clamped, so no stored table is
    stuck (``engine.validation.clamp_night_timing``). A ``night_protocol`` key an
    older table still stores is carried along and ignored. A new dict."""
    base = settings if isinstance(settings, dict) else {}
    return dict(clamp_night_timing(base, allow_untimed=_allow_untimed()))


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


def lengths(settings: Any) -> dict[str, int]:
    """Each length the game will run with if dealt now (seconds): the table's own,
    as the deal clamps it (``dealt_settings``), else the default, the minimum
    window cut to the window as the night cuts it (``engine.validation``'s rule
    table; the host handover's default is ``core.host``'s). So the set-up page
    shows what will run without the phone knowing a default."""
    now = running_lengths(dealt_settings(settings))
    now["host_handover_seconds"] = services.get_timer_value(
        settings, "host_handover_seconds", host.DEFAULT_HOST_HANDOVER_SECONDS
    )
    return now


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


def _dealt_deck(lobby: Lobby) -> dict[str, int] | None:
    """The deck the table's newest game was dealt (its ``settings.roles``), while
    the table is not waiting: the lobby body shows what was dealt, not a deck
    resized for whoever is here now."""
    if lobby.status == Lobby.Status.WAITING:
        return None
    game = lobby.games.order_by("-created_at", "-id").first()  # type: ignore[attr-defined]
    roles = None if game is None else (game.settings or {}).get("roles")
    if not isinstance(roles, dict):
        return None
    return {r: c for r, c in roles.items() if type(c) is int and c > 0}


def lobby_extras(lobby: Lobby) -> dict[str, Any]:
    """The lobby body's ONUW keys:

    - ``deck_cards``: the roles the table would deal, face up for everyone (in a
      game, the deck it was dealt);
    - ``deck_preview``: the automatic deck only, kept for older apps;
    - ``deal``: ``ok`` exactly as the deal would answer now; ``seats`` the number
      the table is set for (null: open); ``need`` the cards the deal needs,
      ``seats`` + 3, or the players here + 3 at an open table; ``have`` the cards
      in the deck. A table set for a number never changes ``need`` when people
      join or leave;
    - ``seats_range``: ``[least, most]`` the number may be set to now;
    - ``lengths`` and ``length_ranges``: every length as it would run, and the
      range a change of each takes now (the rule table's own ranges).
    """
    members = list(lobby.players.all())  # type: ignore[attr-defined]
    size = table_size(lobby.settings, len(members))
    dealt = _dealt_deck(lobby)
    cards = deck_cards(lobby.settings, size) if dealt is None else dealt
    have = _deck_size(lobby.settings, size) if dealt is None else sum(dealt.values())
    return {
        "deck_preview": deck_preview(lobby.settings, size),
        "deck_cards": cards,
        "deal": {
            "ok": deal_refusal(lobby, members) is None,
            "need": size + 3,
            "have": have,
            "seats": seats_of(lobby.settings),
        },
        "seats_range": seats_range(len(members), lobby.max_players),
        "lengths": lengths(lobby.settings),
        # From what the deal would run with, so every length sits in its range.
        "length_ranges": length_ranges(
            dealt_settings(lobby.settings), allow_untimed=_allow_untimed()
        ),
    }
