"""A game socket's heartbeat, in one statement: its row refreshed, whether it is
the game's oldest fresh socket (the one whose beat runs the lazy repair,
``repair.py``), and the table's token for the next beat frame.

The token is what every seat at the table already knows of where the game is,
the same for every socket of the game: ``phase`` and ``window`` (what
``phase_change`` and ``night_window`` tell the table) and ``moved_on`` (the
table has moved past this finished game: play again, or a later deal; what
``play_again`` tells it). It only moves forward, so a token one beat old never
makes a phone read; a phone holding less than it reads once (contract,
section 8).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from django.db import connection

from apps.core.models import Lobby

from . import presence
from .models import Game, Phase, SocketPresence


@dataclass(frozen=True)
class Beat:
    """What one beat's statement found."""

    found: bool  # the socket's row was there (else it is registered again)
    oldest: bool  # the game's oldest fresh socket: its beat repairs the game
    token: dict[str, Any] | None


def _token(phase: str, window: int, moved_on: bool | None) -> dict[str, Any]:
    return {"phase": phase, "window": window, "moved_on": bool(moved_on)}


def refresh(channel_name: str, *, elect: bool) -> Beat:
    """Refresh the row of socket ``channel_name`` and read its game's token, in
    one statement; with ``elect``, also whether it is the oldest fresh socket
    (at the results nothing is repaired, so the consumer stops asking). Leaves
    the database connection open (the caller closes it)."""
    sockets = SocketPresence._meta.db_table
    games = Game._meta.db_table
    lobbies = Lobby._meta.db_table
    sql = f"""
        UPDATE {sockets} AS s SET last_seen = STATEMENT_TIMESTAMP()
        FROM {games} AS g LEFT JOIN {lobbies} AS l ON l.id = g.lobby_id
        WHERE s.channel_name = %s AND g.id = s.game_id
        RETURNING g.phase, g.current_wave,
          g.phase = %s AND (l.status IS DISTINCT FROM %s OR EXISTS (
            SELECT 1 FROM {games} AS n
            WHERE n.lobby_id = g.lobby_id AND n.created_at > g.created_at)),
          %s AND s.id = (
            SELECT min(f.id) FROM {sockets} AS f
            WHERE f.game_id = s.game_id
              AND f.last_seen >= STATEMENT_TIMESTAMP() - make_interval(secs => %s))
    """  # noqa: S608 (table names from the models, values as parameters)
    params = [
        channel_name,
        Phase.RESULTS.value,
        Lobby.Status.FINISHED.value,
        elect,
        presence.stale_seconds(),
    ]
    with connection.cursor() as cursor:
        cursor.execute(sql, params)
        row = cursor.fetchone()
    if row is None:
        return Beat(found=False, oldest=False, token=None)
    phase, window, moved_on, oldest = row
    return Beat(found=True, oldest=bool(oldest), token=_token(phase, window, moved_on))


def token(game_id: Any) -> dict[str, Any] | None:
    """The game's token, read alone (a socket opening, or one registered again)."""
    game = (
        Game.objects.filter(id=game_id)
        .values("phase", "current_wave", "lobby_id", "created_at")
        .first()
    )
    if game is None:
        return None
    moved_on = game["phase"] == Phase.RESULTS and (
        Lobby.objects.filter(pk=game["lobby_id"])
        .exclude(status=Lobby.Status.FINISHED)
        .exists()
        or Game.objects.filter(
            lobby_id=game["lobby_id"], created_at__gt=game["created_at"]
        ).exists()
    )
    return _token(game["phase"], game["current_wave"], moved_on)
