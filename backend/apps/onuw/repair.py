"""The game's lazy repair: what a lost message or a restart can leave undone, done.

Three things can be lost between a commit and what should follow it: a practice
player's move at a stage's opening (``practice.drive`` failed), a timer this
process never registered (a restart) and a timer whose firing was lost (a queue
message). Each would leave a stage waiting for good at an untimed table.

The repair runs in two places, so it never depends on a phone reading:

- ``GET /me/`` (``views.GameMeView``), as before;
- the game socket's heartbeat (``GameConsumer._beat``), every
  ``heartbeat_seconds`` while anyone sits at the table. Each beat only the game's
  oldest fresh socket runs it (``runs_the_repair``: one query), so it runs about
  once per game per beat, whichever process holds the sockets, with nothing new
  stored.
"""

from __future__ import annotations

import logging
from typing import Any

from apps.core import timers

from . import practice, presence
from .models import Game, Phase, PlayerRole
from .recovery import ensure_timers, timer_prefixes

logger = logging.getLogger(__name__)


def lazy_repair(
    game: Game, all_player_roles: list[PlayerRole]
) -> list[PlayerRole] | None:
    """Repair ``game`` (its rows given in seat order, ``user`` loaded). When the
    practice players acted, ``game`` is read again and the game's rows, read
    again, are returned; else None. A failure of the timers' part is logged and
    never raised."""
    reread = None
    # The backstop for practice players (no query at a table without them): one
    # that has not done its part in the stage open now (the drive after the
    # stage opened was lost) acts now.
    if practice.behind(game, all_player_roles):
        practice.drive(game.id)
        game.refresh_from_db()
        # pyrefly: ignore [missing-attribute]
        reread = list(game.player_roles.select_related("user").all())
        all_player_roles = reread
    try:
        # Re-create a timer this process lost (cheap when all are registered),
        # then re-publish this game's timers whose firing was lost.
        ensure_timers(game, all_player_roles)
        timers.sweep(timer_prefixes(game))
    except Exception:
        logger.exception("ensure_timers failed for game %s", game.id)
    return reread


def runs_the_repair(game_id: Any, channel_name: str) -> bool:
    """Whether the socket ``channel_name`` is the game's oldest fresh one: the
    one whose beat repairs the game."""
    first = (
        presence.fresh_rows(game_id=game_id)
        .order_by("id")
        .values_list("channel_name", flat=True)
        .first()
    )
    return first == channel_name


def repair_on_beat(game_id: Any, channel_name: str) -> None:
    """A heartbeat of socket ``channel_name``: the repair, if this socket is the
    one that runs it and the game is still being played. Never raises. The
    database connection is left to the caller: the beat's presence refresh runs
    next on it and closes it, so a beat opens one connection, as before."""
    try:
        if not runs_the_repair(game_id, channel_name):
            return
        game = Game.objects.select_related("lobby").filter(id=game_id).first()
        if game is None or game.phase == Phase.RESULTS:
            return
        # pyrefly: ignore [missing-attribute]
        lazy_repair(game, list(game.player_roles.select_related("user").all()))
    except Exception:
        logger.exception("The beat's repair failed for game %s", game_id)
