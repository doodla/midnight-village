"""
Who is connected to a GAME, from socket rows (``SocketPresence``).

The generic machinery (staleness timeout, heartbeat, durable presence checks,
lobby sockets) lives in ``apps.core.presence``; this module adds the game's reads
(who is connected) and re-exports the generic helpers so game code has one place
to import from. The game's presence CHECK is registered in ``services.py``, with
the timer jobs.
See ``apps/core/presence.py`` for the design (rows with heartbeats, a durable
``presence_check`` timer that notices silent deaths, nothing reset at start-up).
"""

from __future__ import annotations

import logging
from typing import Any

from apps.core.presence import (  # noqa: F401  (re-exported)
    beat_frame,
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


def online_sockets():
    """(user id, lobby id) of every fresh game socket: this game's share of
    ``GET /api/stats/online/`` (registered with ``apps.core.online``)."""
    from .models import SocketPresence

    return SocketPresence.objects.filter(last_seen__gte=cutoff()).values_list(
        "user_id", "game__lobby_id"
    )


def connected_user_ids(*, game_id: Any) -> set[int]:
    """Users with at least one fresh socket on the game."""
    return set(fresh_rows(game_id=game_id).values_list("user_id", flat=True))


def annotate(player_roles: list, game_id: Any) -> list:
    """Set ``is_connected`` on each PlayerRole from ONE query (returns the list)."""
    connected = connected_user_ids(game_id=game_id)
    for pr in player_roles:
        pr.is_connected = pr.user_id in connected
    return player_roles
