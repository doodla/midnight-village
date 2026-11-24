"""
Who is here, who is gone, who is done.

The reads that decide whether a stage may move on: a player's connection and how
long it has been down, whether the night's window or the vote still waits for
anyone, how far a stage has got (``stage_progress``), and when a dropped player's
grace timer is due. Everything here reads; the one write is scheduling those grace
timers after commit.
"""

from __future__ import annotations

import logging
from collections.abc import Callable
from typing import Any

from django.utils import timezone

from apps.onuw import presence

from . import basics, turns
from .engine.state import GameState
from .models import Game, Phase, PlayerRole
from .protocol import (
    in_look_stage,
)

logger = logging.getLogger(__name__)


def _progress(
    game: Game, stage: str, is_done: Callable[[PlayerRole], bool]
) -> dict[str, Any]:
    """``{"stage", "done", "needed"}``: ``needed`` is the players not gone past the
    grace period, ``done`` how many of them ``is_done``. Counts only: never who."""
    prs = _player_roles(game)
    grace = _grace_seconds(game)
    now = timezone.now()
    present = [pr for pr in prs if not _is_gone(pr, grace, now)]
    return {
        "stage": stage,
        "done": sum(1 for pr in present if is_done(pr)),
        "needed": len(present),
    }


def vote_progress(game: Game) -> dict[str, Any]:
    """The vote's count: players who have LOCKED in (a pick is not counted)."""
    return _progress(game, "vote", lambda pr: bool(pr.has_acted))


def talk_progress(game: Game) -> dict[str, Any]:
    """The talk's count: players who are ready to vote."""
    return _progress(game, "talk", lambda pr: bool(pr.phase_ready))


def look_progress(game: Game) -> dict[str, Any]:
    """The look stage's count: players who have looked at their card."""
    return _progress(game, "look", lambda pr: bool(pr.phase_ready))


def stage_progress(game: Game) -> dict[str, Any] | None:
    """The count for whichever stage the game is in (``/me/`` ``progress``), or
    None outside the stages that have one (look, talk, vote)."""
    if game.phase == Phase.VOTING:
        return vote_progress(game)
    if game.phase == Phase.DISCUSSION:
        return talk_progress(game)
    if in_look_stage(game):
        return look_progress(game)
    return None


def _grace_seconds(game: Game) -> int:
    return basics.get_timer_seconds(
        game, "disconnect_grace_seconds", basics.DEFAULT_DISCONNECT_GRACE_SECONDS
    )


def _pr_connected(pr: PlayerRole) -> bool:
    """Is the player connected now? Uses ``pr.is_connected`` when the caller
    annotated it (presence.annotate), else asks the database."""
    known = getattr(pr, "is_connected", None)
    if known is None:
        known = presence.fresh_rows(game_id=pr.game_id, user_id=pr.user_id).exists()  # type: ignore[attr-defined]
        pr.is_connected = known  # type: ignore[attr-defined]
    return bool(known)


def _player_roles(game: Game) -> list[PlayerRole]:
    """The game's PlayerRoles with ``is_connected`` set (one extra query)."""
    # pyrefly: ignore [missing-attribute]
    return presence.annotate(list(game.player_roles.all()), game.id)


def _seconds_disconnected(pr: PlayerRole, now: Any) -> float | None:
    """Seconds since the player was noticed to have no open socket, or None if
    connected / never seen disconnected."""
    if pr.disconnected_at is None or _pr_connected(pr):
        return None
    return (now - pr.disconnected_at).total_seconds()


def _is_gone(pr: PlayerRole, grace: int, now: Any) -> bool:
    """True once the player has been disconnected for at least the grace period."""
    if grace <= 0:
        return False
    away = _seconds_disconnected(pr, now)
    return away is not None and away >= grace


def _is_recently_dropped(pr: PlayerRole, grace: int, now: Any) -> bool:
    """True while the player is disconnected but still inside the grace period."""
    if grace <= 0:
        return False
    away = _seconds_disconnected(pr, now)
    return away is not None and away < grace


def _grace_timer_key(game_id: Any, user_id: int) -> str:
    return f"{game_id}:grace:{user_id}"


def ready_to_close(
    state: GameState, prs: list[PlayerRole], window: int, grace: int, now: Any
) -> bool:
    """Every present phone with a choice has sent its choose (``turn_open`` is false
    for it), so the stage ends the moment everyone has done their part. A phone with
    nothing to choose is never waited for, nor is one gone past the grace period.
    (Window 1 is fixed-length; this is only asked of it when its length was switched
    off, in development, and then a Doppelganger who copied a role that chooses in
    window 1 is also waited for until she has sent her follow-up.)"""
    return all(
        not turns.turn_open(state, pr, window) or _is_gone(pr, grace, now) for pr in prs
    )


def _night_ready_to_close(game: Game, *, ignore_recent_drops: bool = False) -> bool:
    """True when the open night window has nothing left to wait for.

    Every phone with a choice has chosen (``ready_to_close``); a phone
    with nothing to choose is never waited for, and a phone gone past the grace
    period is treated as a timeout (through the normal close path, so the minimum
    window length still applies). A phone with a choice still inside its grace
    period holds the window open; so does a table where every phone is away (gone,
    or dropped and still inside its grace period): nobody is there to be told, so
    only a phone coming back, the window's own deadline or the host closes it.

    ``ignore_recent_drops`` is for rebuilding timers after a restart, where
    every player has just been stamped disconnected only because no socket
    survived: that is not a real drop and must not defer a close that was
    already due.
    """
    prs = _player_roles(game)
    grace = _grace_seconds(game)
    now = timezone.now()
    window = game.current_wave
    state = basics.build_game_state(game)
    if not ignore_recent_drops and any(
        _is_recently_dropped(pr, grace, now) and turns.turn_open(state, pr, window)
        for pr in prs
    ):
        return False
    if prs and all(_is_gone(pr, grace, now) for pr in prs):
        return False
    if not ignore_recent_drops and all(
        _is_gone(pr, grace, now) or _is_recently_dropped(pr, grace, now) for pr in prs
    ):
        return False  # every phone is away: nobody is there to be told yet
    return ready_to_close(state, prs, window, grace, now)


def _votes_ready(game: Game) -> bool:
    """True when the vote can be revealed: everyone has voted, or everyone the
    vote still waits for has (a player gone past the grace period is a non-voter,
    exactly as at the voting deadline). Needs someone present to be told."""
    prs = _player_roles(game)
    if all(pr.has_acted for pr in prs):
        return True
    grace = _grace_seconds(game)
    now = timezone.now()
    present = [pr for pr in prs if not _is_gone(pr, grace, now)]
    return bool(present) and all(pr.has_acted for pr in present)


def _grace_timer_plan(
    game: Game, prs: list[PlayerRole], *, include_expired: bool
) -> list[tuple[int, float]]:
    """(user_id, delay) for each disconnected player who needs a grace timer.

    A player still inside their grace period is timed for the rest of it. One
    already past it is timed for "now" when include_expired is set, so a lost
    timer cannot leave the game waiting for someone it has stopped waiting for.
    """
    grace = _grace_seconds(game)
    if grace <= 0 or game.phase not in (Phase.NIGHT, Phase.VOTING):
        return []
    now = timezone.now()
    plan: list[tuple[int, float]] = []
    for pr in prs:
        away = _seconds_disconnected(pr, now)
        if away is None:
            continue
        remaining = grace - away
        if remaining > 0:
            plan.append((pr.user_id, remaining))
        elif include_expired:
            plan.append((pr.user_id, 0.0))
    return plan


def _schedule_grace_timers_after_commit(game: Game) -> None:
    """Time the grace period of every player who is already disconnected.

    Used when voting opens: a phone that dropped during the talk had no timer.
    """
    # pyrefly: ignore [missing-attribute]
    prs = list(game.player_roles.filter(disconnected_at__isnull=False))
    for user_id, delay in _grace_timer_plan(game, prs, include_expired=False):
        basics._schedule_after_commit(
            _grace_timer_key(game.id, user_id),
            delay,
            "grace_expired",
            {"game_id": str(game.id), "user_id": user_id},
        )
