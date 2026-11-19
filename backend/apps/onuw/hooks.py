"""What the shared lobby (``apps.core``) asks the ONUW app (see ``apps.core.games``)."""

from __future__ import annotations

from datetime import datetime

from apps.core.games import GameHooks

from . import presence
from .engine.validation import validate_onuw_settings
from .models import Game, Phase, PlayerRole


def _newest_game(lobby) -> Game | None:
    # pyrefly: ignore [missing-attribute]
    return lobby.games.order_by("-created_at", "-id").first()


class OnuwHooks(GameHooks):
    def validate_settings(self, settings, player_count: int) -> list[str]:
        return validate_onuw_settings(settings, player_count)

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
