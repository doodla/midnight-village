"""
The night's loop: when a window opens and when it closes.

``start_night_phase`` opens the first window, ``_open_window`` arms its timer,
``_close_or_defer`` closes it when everyone present has acted (or holds it for its
minimum length), and ``advance_wave`` resolves it and opens the next, or moves on to
the discussion. What happens inside one window is ``night_window``.
"""

from __future__ import annotations

import logging

from django.db import transaction
from django.utils import timezone

from . import basics, night_window, readiness
from .models import Game, Phase
from .protocol import (
    NIGHT_WINDOWS,
)

logger = logging.getLogger(__name__)


def start_night_phase(game: Game) -> None:
    """
    Open the night.

    Window 1 (Doppelganger) runs whenever the Doppelganger card is in the deck,
    dealt or in the center, even if nobody can act in it (so a missing
    Doppelganger cannot be told from a present one by timing). Window 2 always
    runs. A window is never skipped because it has no actors.
    """
    first_window = 1 if night_window._doppelganger_in_deck(game) else 2
    with transaction.atomic():
        locked = Game.objects.select_for_update().get(id=game.id)
        if locked.phase == Phase.NIGHT and locked.current_wave == 0:
            # The look stage (if there was one) is over: its backstop is moot.
            basics._cancel_after_commit(night_window._look_timer_key(locked))
            _open_window(locked, first_window)
        # else: already opened (start-up recovery or a lazy ensure_timers got
        # there first); opening twice would re-prompt everyone.
    game.refresh_from_db()


def begin_night(game: Game) -> None:
    """The deal's last step: open the night, through the look stage if the game
    asks for one (``card_look_seconds`` > 0), else straight into the first window."""
    seconds = basics.get_timer_seconds(
        game, "card_look_seconds", basics.DEFAULT_CARD_LOOK_SECONDS
    )
    if seconds > 0:
        night_window._start_look_stage(game, seconds)
    else:
        start_night_phase(game)


def _open_night_after_look(game: Game) -> None:
    """The look backstop fired (the Game row is locked, the phase is night)."""
    if game.current_wave == 0:
        start_night_phase(game)


def _open_window(game: Game, window: int) -> None:
    """Open a night window: record it, prompt its actors, and arrange its close."""
    with transaction.atomic():
        game.current_wave = window
        game.save(update_fields=["current_wave", "updated_at"])
        # Fresh window: nobody has acted in it yet (and nobody is "ready").
        # pyrefly: ignore [missing-attribute]
        game.player_roles.update(has_acted=False, phase_ready=False)

    night_window.send_wave_prompts(game, window)
    basics._practice_after_commit(game)

    # With nobody to wait for (no actors, or every actor's phone has been gone
    # past the grace period), the window still lasts its minimum length.
    if readiness._night_ready_to_close(game):
        _close_or_defer(game)


def _close_or_defer(game: Game) -> None:
    """Close the current window now, or at its minimum length if that is later.

    Called with the Game row locked once every actor in the window is done.
    Rescheduling replaces the window's maximum timer under the same key; the
    callback is idempotent per window. A fixed-length window (window 1) never
    closes because its actors are done: only its own timer closes it.
    """
    window = game.current_wave
    if night_window._fixed_window_seconds(game, window) > 0:
        return
    delay = night_window._min_close_delay(game)
    if delay > 0:
        basics._schedule_after_commit(
            basics._window_timer_key(game, window),
            delay,
            "night_window",
            basics._window_job_params(game, window, deferred=True),
        )
        return
    advance_wave(game)


def _auto_advance_wave(game: Game, wave_number: int, deferred: bool = False) -> None:
    """Auto-advance a wave when its timer expires, marking non-actors as skipped.

    ``deferred`` marks the early close scheduled for a window's minimum length
    (everyone it waited for was done). Anything may have happened since: a
    player treated as gone may have reconnected. So it re-checks, under the
    lock, that the window may still close; if not, the window's normal deadline
    timer is put back instead. A deadline that has been reached always closes.
    In the ordinary case (still ready) this closes at exactly the same moment.
    """
    if game.current_wave != wave_number:
        return  # Wave already advanced — stale callback.
    if deferred:
        deadline = game.phase_deadline
        deadline_reached = deadline is not None and timezone.now() >= deadline
        if not deadline_reached and not readiness._night_ready_to_close(game):
            night_window._restore_deadline_timer(game)
            return
    advance_wave(game)


def advance_wave(game: Game) -> None:
    """
    Close the current night window.

    Resolves the whole window through the engine (window 2: team views, then
    Seer, Robber, Troublemaker, Drunk, then Insomniac, each seeing the table
    after the previous step) and persists the results; each phone reads its own
    from ``GET /me/``. Then opens window 2 or moves on to discussion.

    Closing here ignores the minimum length: the host and the maximum timer
    both come through this function. The minimum is enforced by
    _close_or_defer.

    At window 0 (the look stage, or a night that has not opened) there is nothing
    to close: the host's tap opens the first window instead.
    """
    window = game.current_wave
    if window == 0:
        start_night_phase(game)
        return
    basics._cancel_after_commit(basics._window_timer_key(game, window))
    if window == 1 and night_window._doppelganger_look_submitted(game):
        # A look that is stored but not resolved yet (the window job got the lock
        # first, or the step after the submission failed): resolve it now, so her
        # copied role is known and an unsubmitted follow-up (a Drunk must swap, a
        # Minion still looks) gets the same default as any other timeout.
        night_window._resolve_doppelganger_look(game)
    state = basics.build_game_state(game)
    night_actions = night_window._collect_window_actions(game, window)

    _, new_state, results = night_window._resolve_window_safely(
        game, state, night_actions, window
    )

    with transaction.atomic():
        night_window.persist_wave_results(game, new_state, results, window)

    if window < NIGHT_WINDOWS[-1]:
        _open_window(game, window + 1)
    else:
        night_window.transition_to_discussion(game)


def _advance_if_ready(game: Game) -> None:
    """Close the open night window if there is nothing left to wait for (the
    caller holds the Game row lock and has checked the phase is night). A
    fixed-length window 1 is never closed from here (``_close_or_defer``)."""
    if readiness._night_ready_to_close(game):
        _close_or_defer(game)
