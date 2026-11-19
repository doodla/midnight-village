"""
Who is connected to a GAME, from socket rows (``SocketPresence``).

The generic machinery (staleness timeout, heartbeat, durable presence checks,
lobby sockets) lives in ``apps.core.presence``; this module adds the game scope
and re-exports the generic helpers so game code has one place to import from.
See ``apps/core/presence.py`` for the design (rows with heartbeats, a durable
``presence_check`` timer that notices silent deaths, nothing reset at start-up).
"""

from __future__ import annotations

import logging
from typing import Any

from apps.core import presence as _core
from apps.core.presence import (  # noqa: F401  (re-exported)
    check_key,
    check_params,
    cutoff,
    ensure_check_timer,
    heartbeat_loop,
    heartbeat_seconds,
    next_check_delay,
    seconds_since_newest,
    stale_seconds,
)

logger = logging.getLogger(__name__)


def fresh_rows(*, game_id: Any, user_id: int | None = None):
    """Game socket rows seen within the staleness timeout."""
    from .models import SocketPresence

    queryset = SocketPresence.objects.filter(game_id=game_id, last_seen__gte=cutoff())
    if user_id is not None:
        queryset = queryset.filter(user_id=user_id)
    return queryset


def connected_user_ids(*, game_id: Any) -> set[int]:
    """Users with at least one fresh socket on the game."""
    return set(fresh_rows(game_id=game_id).values_list("user_id", flat=True))


def annotate(player_roles: list, game_id: Any) -> list:
    """Set ``is_connected`` on each PlayerRole from ONE query (returns the list)."""
    connected = connected_user_ids(game_id=game_id)
    for pr in player_roles:
        pr.is_connected = pr.user_id in connected
    return player_roles


def _check_game(scope_id: str, user_id: int) -> None:
    """Scope checker of the durable presence check: a game socket may have died."""
    from apps.core.effects import after_commit

    from . import services

    if services.check_game_presence(scope_id, user_id):
        # Host handover has its own transaction and lock order (Lobby then
        # LobbyMember): it runs only after this one has committed.
        after_commit(lambda: services.report_game_presence(scope_id, user_id, False))


_core.register_scope("game", _check_game)
