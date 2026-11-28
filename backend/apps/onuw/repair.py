"""The game's lazy repair: what a lost message or a restart can leave undone, done.

Three things can be lost between a commit and what should follow it: a practice
player's move at a stage's opening (``practice.drive`` failed), a timer this
process never registered (a restart) and a timer whose firing was lost (a queue
message). Each would leave a stage waiting for good at an untimed table.

The repair runs in two places, so it never depends on a phone reading:

- ``GET /me/`` (``views.GameMeView``), as before;
- the game socket's heartbeat (``GameConsumer._beat_work``), every
  ``heartbeat_seconds`` while anyone sits at the table and the game is not at its
  results. Each beat only the game's oldest fresh socket runs it (asked in the
  beat's own statement, ``beat.refresh``), so it runs about once per game per
  beat, whichever process holds the sockets, with nothing new stored.

A repair that fails is counted where the owner looks (``repair_failed`` in the
observe report, no ids) and logged: at ERROR the first time for a game, then at
most every ``LOG_EVERY`` seconds.
"""

from __future__ import annotations

import logging
import time
from typing import Any

from apps.core import timers
from apps.observe import counts

from . import practice
from .models import Game, Phase, PlayerRole
from .recovery import ensure_timers, timer_prefixes

logger = logging.getLogger(__name__)

LOG_EVERY = 600.0
_logged: dict[str, float] = {}  # game id -> when its repair failure was last logged


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
        _failed(game.id)
    return reread


def repair_on_beat(game_id: Any) -> None:
    """The beat's repair of ``game_id`` (its oldest fresh socket's beat), while
    the game is being played. Never raises. The database connection is left to
    the caller (``GameConsumer._beat_work`` closes it)."""
    try:
        game = Game.objects.select_related("lobby").filter(id=game_id).first()
        if game is None or game.phase == Phase.RESULTS:
            return
        # pyrefly: ignore [missing-attribute]
        lazy_repair(game, list(game.player_roles.select_related("user").all()))
    except Exception:
        _failed(game_id)


def _failed(game_id: Any) -> None:
    """A repair failed (called inside the ``except``): counted for the owner,
    logged with its stack the first time for a game, then at most every
    ``LOG_EVERY`` seconds, so a repair that always fails is seen, not buried."""
    try:
        counts.add("repair_failed")
    except Exception:
        logger.warning("Could not count a failed repair", exc_info=True)
    now = time.monotonic()
    key = str(game_id)
    last = _logged.get(key)
    if last is None or now - last >= LOG_EVERY:
        if len(_logged) > 1000:
            _logged.clear()
        _logged[key] = now
        logger.exception("The lazy repair failed for game %s", game_id)
