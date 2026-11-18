"""
In-process timer registry for ONUW phase transitions.

Uses threading.Timer from the standard library (no external dependencies).
Thread safety is ensured by a module-level Lock guarding all registry mutations.

Key format convention: "{game_id}:discussion", "{game_id}:voting",
"{game_id}:wave:{n}" and "{game_id}:grace:{user_id}" (a dropped player's grace period).

The registry lives in one process and is lost on restart; the stored deadlines
on Game are the source of truth and services.recover_timers() / ensure_timers()
rebuild the timers from them.
"""

import logging
import threading
from collections.abc import Callable
from typing import Any

logger = logging.getLogger(__name__)

_registry: dict[str, threading.Timer] = {}
_lock = threading.Lock()


def schedule(
    key: str, delay_seconds: float, callback: Callable[..., None], *args: Any
) -> None:
    """
    Schedule a callback to fire after delay_seconds.

    If a timer already exists for key, it is cancelled first (idempotent re-schedule).
    The timer thread is daemonised so it does not block process exit.
    """
    with _lock:
        if key in _registry:
            _registry[key].cancel()
        timer = threading.Timer(delay_seconds, callback, args=args)
        timer.daemon = True
        _registry[key] = timer
        timer.start()


def cancel(key: str) -> None:
    """
    Cancel and remove the timer registered under key.

    Safe to call on a non-existent key (no-op).
    """
    with _lock:
        if key in _registry:
            _registry[key].cancel()
            del _registry[key]


def is_scheduled(key: str) -> bool:
    """True if a timer under key is registered and has neither fired nor been cancelled.

    A Timer stays in the registry after it fires, so presence alone is not
    enough. Cheap: one dict lookup under the lock, no database access.
    """
    with _lock:
        timer = _registry.get(key)
        return timer is not None and timer.is_alive() and not timer.finished.is_set()


def cancel_all_for_game(game_id: int | str) -> None:
    """
    Cancel all timers whose key starts with "{game_id}:".

    Used when a game ends or is aborted to clean up all pending phase timers.
    """
    prefix = f"{game_id}:"
    with _lock:
        keys_to_cancel = [k for k in _registry if k.startswith(prefix)]
        for key in keys_to_cancel:
            _registry[key].cancel()
            del _registry[key]


def make_idempotent_callback(
    game_id: Any,
    expected_phase: str,
    action: Callable[["Any"], None],  # action receives Game instance
) -> Callable[[], None]:
    """
    Wrap a phase-transition action so it is a no-op if the phase has already changed.

    Uses select_for_update() to serialise concurrent callbacks — if two timer threads
    race, only one proceeds. The other will find the phase already changed and return.

    Exceptions are logged (with the game id and phase) rather than left to die in
    the timer thread. A failed callback rolls its transaction back, so the game
    is left exactly as it was and the host can still advance it.
    """

    def _callback() -> None:
        # Import inside function to avoid circular imports at module load time.
        from django.db import transaction

        from apps.onuw.models import Game

        try:
            with transaction.atomic():
                try:
                    game = Game.objects.select_for_update().get(id=game_id)
                except Game.DoesNotExist:
                    return  # Game was deleted — nothing to do.
                if game.phase != expected_phase:
                    return  # Phase already advanced — stale callback, skip.
                action(game)
        except Exception:
            logger.exception(
                "Timer callback failed for game %s (expected phase %s)",
                game_id,
                expected_phase,
            )

    return _callback
