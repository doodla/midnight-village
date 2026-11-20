"""What the shared lobby (``apps.core``) asks the ONUW app (see ``apps.core.games``)."""

from __future__ import annotations

from datetime import datetime
from typing import Any

from django.conf import settings as django_settings

from apps.core.games import GameHooks

from . import presence
from .engine.validation import validate_onuw_settings
from .models import Game, Phase, PlayerRole

# What a lobby made with ``defaults: "v2"`` starts with: ONLY what the new screens need
# to work (a look at the cards, the choose night, the automatic Simple deck). It writes
# no timer value the server already defaults and never the Doppelganger's window:
# every length is the table's own setting or the server's existing default. Nothing is
# written unless the create body asks for it.
V2_DEFAULTS: dict[str, Any] = {
    "card_look_seconds": 30,
    "night_protocol": 2,
    "deck": "auto",
    "deck_chip": "simple",
}


def _newest_game(lobby) -> Game | None:
    # pyrefly: ignore [missing-attribute]
    return lobby.games.order_by("-created_at", "-id").first()


class OnuwHooks(GameHooks):
    def validate_settings(self, settings, player_count: int, changed=None) -> list[str]:
        return validate_onuw_settings(
            settings,
            player_count,
            check_deck=changed is None or "roles" in changed,
            allow_untimed=getattr(django_settings, "ONUW_ALLOW_UNTIMED_NIGHT", False),
        )

    def default_settings(self, name: str) -> dict[str, Any] | None:
        return dict(V2_DEFAULTS) if name == "v2" else None

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

    def member_game(self, lobby, user_id: int) -> dict[str, Any] | None:
        game = _newest_game(lobby)
        if (
            game is None
            or not PlayerRole.objects.filter(game=game, user_id=user_id).exists()
        ):
            return None
        return {"game_id": str(game.id), "phase": game.phase}
