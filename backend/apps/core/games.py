"""
How a game app plugs into the shared lobby.

``apps.core`` owns lobbies, lobby sockets, host handover, play again and durable
timers, and must not import any game app. A game app registers a ``GameHooks``
for its ``game_type`` (from ``AppConfig.ready``); core asks the hooks for the few
things only the game knows: whether its settings are valid, which socket group
the lobby's newest game listens on, who is connected to that game, and whether
that game is over, and which game (if any) a member plays in.
"""

from __future__ import annotations

from collections.abc import Collection
from datetime import datetime
from typing import Any


class GameHooks:
    """Defaults for a lobby with no game app behind it (everything "nothing")."""

    def validate_settings(
        self, settings: Any, player_count: int, changed: Collection[str] | None = None
    ) -> list[str]:
        """Errors in the lobby settings for this many players (empty = fine).

        ``changed`` names the keys a PATCH just set (None: validate everything, as a
        deal does), so a game can leave alone checks that depend on who is at the
        table when the change cannot affect them."""
        return []

    def newest_game_group(self, lobby) -> str | None:
        """Channel group of the lobby's newest game, or None if it has none."""
        return None

    def connected_user_ids(self, lobby) -> set[int]:
        """Users with a live socket on the lobby's newest game."""
        return set()

    def disconnect_stamps(self, lobby) -> dict[int, datetime]:
        """When each user of the newest game was noticed disconnected."""
        return {}

    def newest_game_finished(self, lobby) -> bool:
        """True if the lobby's newest game exists and is over (results shown)."""
        return False

    def member_game(self, lobby, user_id: int) -> dict[str, Any] | None:
        """The lobby's newest game as ``{"game_id", "phase"}`` if this user plays in it.

        None if the lobby has no game or the user is not in its newest one.
        """
        return None


_NO_GAME = GameHooks()
_registry: dict[str, GameHooks] = {}


def register(game_type: str, hooks: GameHooks) -> None:
    """Plug a game app in for a ``Lobby.game_type``."""
    _registry[game_type] = hooks


def hooks_for(lobby) -> GameHooks:
    """The hooks of the lobby's game app (do-nothing hooks if none registered)."""
    return _registry.get(lobby.game_type, _NO_GAME)
