"""What the shared lobby (``apps.core``) asks the ONUW app (see ``apps.core.games``)."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from django.conf import settings as django_settings

from apps.core.games import GameHooks

from . import deal, presence
from .basics import DEFAULT_DISCONNECT_GRACE_SECONDS
from .engine.validation import seats_of, validate_onuw_settings
from .models import Game, Phase, PlayerRole

# What a lobby made with ``defaults: "v2"`` (the app's name for its starting set)
# starts with: a look at the cards and the automatic Simple deck. It writes no timer
# value the server already defaults and never the Doppelganger's window: every length
# is the table's own setting or the server's existing default. Nothing is written
# unless the create body asks for it.
APP_DEFAULTS: dict[str, Any] = {
    "card_look_seconds": 30,
    "deck": "auto",
    "deck_chip": "simple",
}


def _newest_game(lobby) -> Game | None:
    # pyrefly: ignore [missing-attribute]
    return lobby.games.order_by("-created_at", "-id").first()


class OnuwHooks(GameHooks):
    def validate_settings(
        self, settings, player_count: int, changed=None, max_players=None
    ) -> list[str]:
        return validate_onuw_settings(
            settings,
            player_count,
            max_players=max_players,
            check_deck=changed is None or "roles" in changed,
            allow_untimed=getattr(django_settings, "ONUW_ALLOW_UNTIMED_NIGHT", False),
            changed=None if changed is None else frozenset(changed),
        )

    def default_settings(self, name: str) -> dict[str, Any] | None:
        return dict(APP_DEFAULTS) if name == "v2" else None

    def newest_game_group(self, lobby) -> str | None:
        game = _newest_game(lobby)
        return None if game is None else f"game_{game.id}"

    def connected_user_ids(self, lobby) -> set[int]:
        game = _newest_game(lobby)
        return set() if game is None else presence.connected_user_ids(game_id=game.id)

    def disconnect_stamps(self, lobby) -> dict[int, datetime]:
        game = _newest_game(lobby)
        if game is None:
            return {}
        return dict(
            PlayerRole.objects.filter(
                game=game, disconnected_at__isnull=False
            ).values_list("user_id", "disconnected_at")
        )

    def newest_game_finished(self, lobby) -> bool:
        game = _newest_game(lobby)
        return game is not None and game.phase == Phase.RESULTS

    def shows_table_extras(self, lobby) -> bool:
        return True  # every ONUW table: deck_preview, deal and presence

    def lobby_extras(self, lobby) -> dict[str, Any]:
        return deal.lobby_extras(lobby)

    def seat_limit(self, lobby) -> int | None:
        """The number of players the table is set for (``seats``; None when open)."""
        return seats_of(lobby.settings)

    def presence_grace_seconds(self, lobby) -> int:
        """The table's ``disconnect_grace_seconds`` (the game's own grace)."""
        stored = (
            lobby.settings.get("disconnect_grace_seconds")
            if isinstance(lobby.settings, dict)
            else None
        )
        if isinstance(stored, int) and not isinstance(stored, bool) and stored >= 0:
            return stored
        return DEFAULT_DISCONNECT_GRACE_SECONDS

    def member_game(self, lobby, user_id: int) -> dict[str, Any] | None:
        game = _newest_game(lobby)
        if (
            game is None
            or not PlayerRole.objects.filter(game=game, user_id=user_id).exists()
        ):
            return None
        return {"game_id": str(game.id), "phase": game.phase}

    def practice_seats(self, lobby) -> bool:
        """Every ONUW table may seat practice players (``apps/onuw/practice.py``
        plays them)."""
        return True

    def played_user_ids(self, lobby, username_prefix: str = "") -> set[int]:
        return set(
            PlayerRole.objects.filter(
                game__lobby=lobby, user__username__startswith=username_prefix
            ).values_list("user_id", flat=True)
        )
