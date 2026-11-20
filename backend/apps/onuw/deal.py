"""Whether a table can be dealt, and what it would be dealt: the ONE rule.

``GameStartView._deal`` refuses a deal with ``deal_refusal`` and the lobby body's
``deal`` (``{"ok", "need", "have"}``) is computed from the same function, so the
phone never holds a "players + 3" rule and the button can never disagree with the
server. ``deck_preview`` is the automatic deck the deal would build for the
players at the table now (``engine.decks.auto_deck``, the deal's own call).

A night protocol 2 table (``night_protocol: 2``) has no ready check at the deal:
everyone at the table is dealt in, so a guest who closes the app right after
joining cannot block it. The original night keeps "every member ready".
"""

from __future__ import annotations

from typing import Any

from django.conf import settings as django_settings

from apps.core.models import Lobby, LobbyMember

from .engine.decks import auto_deck
from .engine.validation import validate_onuw_settings

NOT_WAITING = "Lobby is not in waiting state."
NOT_READY = "Not all players are ready."


def is_v2_table(settings: Any) -> bool:
    """The lobby plays night protocol 2 (the rebuilt screens' tables)."""
    return isinstance(settings, dict) and settings.get("night_protocol") == 2


def deal_refusal(lobby: Lobby, members: list[LobbyMember]) -> Any | None:
    """Why the table cannot be dealt now (the 400 body's ``detail``), or None.

    Everything the deal checks except who taps (host only): the table is waiting,
    every member is ready (the original night only), and the settings are valid
    for this many players (3 to 10, the deck the right size and legal, the
    automatic deck existing for the count, the timers)."""
    if lobby.status != Lobby.Status.WAITING:
        return NOT_WAITING
    if not is_v2_table(lobby.settings) and not all(m.is_ready for m in members):
        return NOT_READY
    errors = validate_onuw_settings(
        lobby.settings,
        len(members),
        allow_untimed=getattr(django_settings, "ONUW_ALLOW_UNTIMED_NIGHT", False),
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


def lobby_extras(lobby: Lobby) -> dict[str, Any]:
    """The lobby body's ONUW keys for a protocol-2 table (asked only for one):
    ``deck_preview`` and ``deal`` (``ok`` exactly as the deal would answer now;
    ``need`` the cards the deal needs, players + 3; ``have`` the cards in the
    deck)."""
    members = list(lobby.players.all())  # type: ignore[attr-defined]
    count = len(members)
    return {
        "deck_preview": deck_preview(lobby.settings, count),
        "deal": {
            "ok": deal_refusal(lobby, members) is None,
            "need": count + 3,
            "have": _deck_size(lobby.settings, count),
        },
    }
