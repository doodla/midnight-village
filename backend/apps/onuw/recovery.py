"""
Rebuilding the timers of running games.

A timer can be lost: the memory backend's with the process, a queue message with a
failed send. ``ensure_timers`` puts back what one game should have now (called from
``GET /me/``, so a phone that is looking repairs its own game); ``recover_timers`` does
it for every running game at start-up. Both work out the plan from the game's state
alone: what should be scheduled, for when.

This module uses the game's rules from ``services.py`` (each such call is written
``services.<name>``), and opens a night that never started through it; nothing in
``services.py`` depends on this module (``tests/onuw/test_module_directions.py``).
"""

from __future__ import annotations

import logging
import threading
from datetime import timedelta
from typing import Any

from django.conf import settings as django_settings
from django.db import DatabaseError
from django.db.models.functions import Now
from django.utils import timezone

from apps.core import timers

from . import basics, night_flow, night_window, readiness, voting
from .models import Game, Phase, PlayerRole
from .protocol import NIGHT_WINDOWS, in_look_stage

logger = logging.getLogger(__name__)

# Phases that run on a clock (and so need a timer to move on).
TIMED_PHASES = (Phase.NIGHT, Phase.DISCUSSION, Phase.VOTING)

# After a restart no phone is connected yet. A deadline that is overdue, or less
# than this many seconds away, is moved to this long from now when its timer is
# rebuilt, so phones can reconnect before the vote is revealed or the night closes.
RECOVERY_RECONNECT_ALLOWANCE_SECONDS = 15


def _grant_reconnect_allowance(game: Game) -> None:
    """Give a rebuilt timer room for phones to reconnect.

    If the game's deadline is overdue or closer than the allowance, move it to
    now + RECOVERY_RECONNECT_ALLOWANCE_SECONDS and persist it (so clients show
    the right countdown), updating ``game`` in place. The extension depends only
    on the clock and the stored deadline, never on what any player did, so it is
    the same for every game state (including the fixed Doppelganger window,
    whose length therefore still says nothing about her). Compare-and-set: if
    another worker already moved it, take its value.
    """
    deadline = game.phase_deadline
    if deadline is None:
        return
    now = timezone.now()
    floor = now + timedelta(seconds=RECOVERY_RECONNECT_ALLOWANCE_SECONDS)
    if deadline >= floor:
        return
    moved = Game.objects.filter(
        id=game.id,
        phase=game.phase,
        current_wave=game.current_wave,
        phase_deadline=deadline,
    ).update(phase_deadline=floor, updated_at=now)
    if moved:
        game.phase_deadline = floor
    else:
        game.phase_deadline = (
            Game.objects.filter(id=game.id)
            .values_list("phase_deadline", flat=True)
            .first()
        )


# A night still at window 0 after this long has not "just started": it is stuck.
NIGHT_START_STUCK_SECONDS = 15


def _night_start_is_stuck(game: Game) -> bool:
    """True if the game was created more than NIGHT_START_STUCK_SECONDS ago (by
    the database clock) and its night still has no window."""
    return Game.objects.filter(
        pk=game.pk,
        phase=Phase.NIGHT,
        current_wave=0,
        created_at__lt=Now() - timedelta(seconds=NIGHT_START_STUCK_SECONDS),
    ).exists()


def timer_prefixes(game: Game) -> tuple[str, ...]:
    """Key prefixes of every timer belonging to a game (for a scoped sweep)."""
    return (f"{game.id}:", f"presence:game:{game.id}:")


def _night_timer_plan(game: Game) -> tuple[float, dict[str, Any]] | None:
    """(delay, callback) for the open night window's one timer, or None.

    Normally the window's deadline. If everyone it waits for is done and the
    window may close, the close is due at its minimum length instead (that is
    what the lost "deferred close" timer was for; it re-checks when it fires);
    a window whose minimum has passed is due at once. A fixed-length window (Doppelganger) only ever has
    its deadline. A window with no deadline and nothing to close has no timer:
    only the host moves it.
    """
    window = game.current_wave
    deadline_delay: float | None = None
    if game.phase_deadline is not None:
        deadline_delay = max(
            0.0, (game.phase_deadline - timezone.now()).total_seconds()
        )
    ready_delay: float | None = None
    if night_window._fixed_window_seconds(
        game, window
    ) == 0 and readiness._night_ready_to_close(game, ignore_recent_drops=True):
        ready_delay = night_window._min_close_delay(game)
    delays = [d for d in (deadline_delay, ready_delay) if d is not None]
    if not delays:
        return None
    delay = min(delays)
    # The early (minimum-length) close re-checks readiness when it fires; the
    # deadline timer closes unconditionally.
    closes_early = ready_delay is not None and (
        deadline_delay is None or ready_delay < deadline_delay
    )
    return delay, basics._window_job_params(game, window, deferred=closes_early)


def _phase_timer_plan(
    game: Game,
) -> tuple[str, float, str, dict[str, Any]] | None:
    """(key, delay, job, params) for the timer the game's stored state calls for.

    Only asked for when the timer is missing (after a restart, or lost), so an
    overdue / nearly due deadline is first given the reconnect allowance.
    """
    _grant_reconnect_allowance(game)
    if in_look_stage(game) and game.phase_deadline is not None:
        # The look backstop (the allowance above never clears a deadline).
        delay = max(0.0, (game.phase_deadline - timezone.now()).total_seconds())
        return (
            night_window._look_timer_key(game),
            delay,
            "card_look",
            {"game_id": str(game.id)},
        )
    if game.phase == Phase.NIGHT and game.current_wave in NIGHT_WINDOWS:
        key = basics._window_timer_key(game, game.current_wave)
        plan = _night_timer_plan(game)
        return None if plan is None else (key, plan[0], "night_window", plan[1])
    if game.phase_deadline is None:
        return None
    delay = max(0.0, (game.phase_deadline - timezone.now()).total_seconds())
    if game.phase == Phase.DISCUSSION:
        return (
            f"{game.id}:discussion",
            delay,
            "discussion_deadline",
            {"game_id": str(game.id)},
        )
    if game.phase == Phase.VOTING:
        return (
            f"{game.id}:voting",
            delay,
            "voting_deadline",
            {"game_id": str(game.id)},
        )
    return None


def ensure_timers(game: Game, player_roles: list[PlayerRole] | None = None) -> None:
    """Make sure the timers the game's stored state calls for are registered.

    Re-creates, if missing: the phase / night-window timer (an overdue deadline
    fires promptly, not never), the deferred "everyone has acted but the
    minimum length has not passed" close, and the grace timers of dropped
    players. Cheap when the timers are already registered: no database access
    beyond ``player_roles`` if given. (A night that never opened its first
    window is only repaired by recover_timers at start-up, never lazily.)
    """
    if game.phase not in TIMED_PHASES:
        return
    looking = in_look_stage(game)
    if game.phase == Phase.NIGHT and game.current_wave not in NIGHT_WINDOWS:
        # A committed night whose first window never opened (the instance died
        # between creating the game and opening it): open it, once the game has
        # had time to open on its own. start_night_phase is idempotent under
        # the Game lock, so a race with the starter is harmless. A night in the
        # look stage (it has a deadline) is not stuck: it is waiting for the taps.
        if not looking:
            if game.current_wave == 0 and _night_start_is_stuck(game):
                night_flow.start_night_phase(game)
            return

    if looking:
        plan_key = night_window._look_timer_key(game)
    elif game.phase == Phase.NIGHT:
        plan_key = basics._window_timer_key(game, game.current_wave)
    else:
        plan_key = f"{game.id}:{game.phase}"
    if not timers.is_scheduled(plan_key):
        if looking and voting._stage_is_ready(game):
            # Everyone present had looked (a grace period ended while nothing was
            # running): the stage is over, not waiting for a timer.
            night_flow.start_night_phase(game)
            return
        plan = _phase_timer_plan(game)
        if plan is not None:
            key, delay, job, params = plan
            timers.schedule(key, delay, job, params)

    if game.phase in (Phase.NIGHT, Phase.VOTING):
        prs = (
            player_roles
            if player_roles is not None
            # pyrefly: ignore [missing-attribute]
            else readiness._player_roles(game)
        )
        for user_id, delay in readiness._grace_timer_plan(
            game, prs, include_expired=True
        ):
            key = readiness._grace_timer_key(game.id, user_id)
            if not timers.is_scheduled(key):
                timers.schedule(
                    key,
                    delay,
                    "grace_expired",
                    {"game_id": str(game.id), "user_id": user_id},
                )


def recover_timers() -> int:
    """Rebuild every running game's timers after a server start (memory backend
    only). Returns the number of games looked at.

    Presence is NOT reset: socket rows left by the dead process go stale (no
    heartbeat) and the presence checks re-armed from the table notice them, so
    a player whose phone reconnects within seconds is never marked gone. Each
    game in night / discussion / voting gets its timers back via ensure_timers
    (a night stuck before its first window is opened), then whatever else is
    stored but not armed in this process is re-armed from the table.
    """
    logger.info(
        "Start-up recovery (memory timer backend): re-arming timers from the "
        "database. Presence is not reset; socket rows that went stale are noticed "
        "by their presence checks. Only ONE server process is supported with this "
        "backend: its timers live in this process (use ONUW_TIMER_BACKEND="
        "vercel_queue for several instances)."
    )
    from apps.core import host

    host.ensure_timers_after_restart()
    count = 0
    for game in Game.objects.filter(phase__in=TIMED_PHASES):
        count += 1
        try:
            if (
                game.phase == Phase.NIGHT
                and game.current_wave == 0
                and not in_look_stage(game)
            ):
                # Crashed between creating the game and opening its first
                # window: open it now (a no-op if another worker already did).
                # A look stage is not that: ensure_timers rebuilds its backstop.
                night_flow.start_night_phase(game)
            else:
                ensure_timers(game)
        except Exception:
            logger.exception("Could not recover timers for game %s", game.id)
    # Whatever else is stored but not armed in this process (presence checks,
    # timers of games that are no longer running: their jobs are no-ops).
    timers.rearm_from_table()
    return count


def run_startup_recovery() -> None:
    """Recover timers once, at real server start (called from the ASGI module).

    Skipped when ONUW_RECOVER_TIMERS_ON_START is False (the test settings), and
    never allowed to stop the server from starting: an unmigrated or
    unreachable database just means there is nothing to recover yet.

    The work runs in a short-lived thread that is joined here. An ASGI server
    may import the application inside a running event loop, where Django
    refuses synchronous database access (SynchronousOnlyOperation); a plain
    thread has no running loop, so this works the same either way. The thread's
    own database connections are closed when it ends.
    """
    if not getattr(django_settings, "ONUW_RECOVER_TIMERS_ON_START", True):
        return
    if timers.backend() == timers.BACKEND_QUEUE:
        # No process owns timers there: a queue message fires each one, and
        # any instance starting or stopping at any time must change nothing.
        return

    def _run() -> None:
        from django.db import connections

        try:
            recovered = recover_timers()
        except DatabaseError:
            logger.warning("Timer recovery skipped: database not ready.", exc_info=True)
        except Exception:
            logger.exception("Timer recovery failed.")
        else:
            logger.info("Timer recovery looked at %d running game(s).", recovered)
        finally:
            connections.close_all()

    thread = threading.Thread(target=_run, name="onuw-timer-recovery", daemon=True)
    thread.start()
    thread.join(timeout=60)
    if thread.is_alive():
        logger.warning("Timer recovery is still running after 60 seconds; carrying on.")
