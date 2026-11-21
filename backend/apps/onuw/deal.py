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

from apps.core.models import Lobby, LobbyMember

from .engine.decks import auto_deck
from .engine.validation import clamp_night_timing, validate_onuw_settings

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
    and the settings are valid for this many players (3 to 10, the deck the right
    size and legal, the automatic deck existing for the count, the timers)."""
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


def lobby_extras(lobby: Lobby) -> dict[str, Any]:
    """The lobby body's ONUW keys: ``deck_preview`` and ``deal`` (``ok`` exactly as the deal would answer now;
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
