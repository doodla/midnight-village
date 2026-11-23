"""
What every part of the game service stands on.

The table's lengths and their defaults, the one error a second action raises, the
helpers that run a side effect only after the transaction commits, the keys and
params of the night's timers, and the engine's view of a stored game
(``build_game_state``). Nothing here moves a game on, and nothing here imports
another part of the service.
"""

from __future__ import annotations

import logging
from typing import Any

from apps.core import effects

from .engine.state import GameState
from .engine.validation import (
    LENGTH_DEFAULTS,
    is_valid_timer_value,
    max_seconds_for,
)
from .models import Game

logger = logging.getLogger(__name__)


class AlreadyActedError(Exception):
    """Raised when a player tries to act again after already submitting."""


# Default maximum length of a night window (seconds). 0 disables the timer.
DEFAULT_NIGHT_WAVE_SECONDS = LENGTH_DEFAULTS["night_wave_seconds"]


# Default minimum length of a night window (seconds). A window never closes
# sooner than this after it opened, so a fast window gives nothing away.
DEFAULT_NIGHT_MIN_WINDOW_SECONDS = LENGTH_DEFAULTS["night_min_window_seconds"]


# Exact length of window 1 (the Doppelganger's), whatever happens in it. 0
# turns the fixed length off: window 1 then behaves like any other window.
DEFAULT_NIGHT_DOPPELGANGER_WINDOW_SECONDS = LENGTH_DEFAULTS[
    "night_doppelganger_window_seconds"
]


# How long a player's phone may be disconnected before the game stops waiting
# for them at night and in the vote (0 turns the feature off).
DEFAULT_DISCONNECT_GRACE_SECONDS = LENGTH_DEFAULTS["disconnect_grace_seconds"]


# The talk and the vote when the table sets no length; no look stage unless set.
# Every default is the rule table's (``engine.validation.LENGTH_DEFAULTS``).
DEFAULT_DISCUSSION_SECONDS = LENGTH_DEFAULTS["discussion_seconds"]


DEFAULT_VOTING_SECONDS = LENGTH_DEFAULTS["voting_seconds"]


DEFAULT_CARD_LOOK_SECONDS = LENGTH_DEFAULTS["card_look_seconds"]


def get_timer_seconds(game: Game, key: str, default: int) -> int:
    """Read a timer duration from game settings.

    Returns default if the key is not set or the stored value is not a valid
    number of seconds (settings are validated on the way in, but a bad row must
    never be able to crash a window close).
    """
    return get_timer_value(game.settings, key, default)


def get_timer_value(settings: Any, key: str, default: int) -> int:
    """A timer duration from a settings dict (``get_timer_seconds``'s rule)."""
    stored = settings.get(key, default) if isinstance(settings, dict) else default
    return stored if is_valid_timer_value(stored, max_seconds_for(key)) else default


def _window_timer_key(game: Game, window: int) -> str:
    return f"{game.id}:wave:{window}"


_after_commit = effects.after_commit


_send_after_commit = effects.send_after_commit


_schedule_after_commit = effects.schedule_after_commit


_cancel_after_commit = effects.cancel_after_commit


def _window_job_params(game: Game, window: int, *, deferred: bool = False) -> dict:
    return {"game_id": str(game.id), "wave": window, "deferred": deferred}


def _practice_after_commit(game: Game) -> None:
    """Once the transaction that opened a stage commits, the practice players act
    in it (``apps/onuw/practice.py``: the same requests a phone sends, at once).
    Called by every stage opening: the look, each night window, the talk, the
    vote."""
    game_id = game.id

    def run() -> None:
        from . import practice

        practice.drive(game_id)

    _after_commit(run)


def build_game_state(game: Game) -> GameState:
    """
    Build an engine GameState from DB models.

    Reads all PlayerRole rows for the game and constructs the immutable
    state snapshot the engine needs.
    """
    player_roles: dict[int, str] = {}
    original_roles: dict[int, str] = {}
    doppelganger_copied: dict[int, str] = {}

    # pyrefly: ignore [missing-attribute]
    for pr in game.player_roles.all():
        player_roles[pr.user_id] = pr.current_role
        original_roles[pr.user_id] = pr.original_role
        if pr.original_role == "Doppelganger" and pr.night_action_data.get(
            "copied_role"
        ):
            doppelganger_copied[pr.user_id] = pr.night_action_data["copied_role"]

    return GameState(
        player_roles=player_roles,
        center_cards=list(game.center_cards),
        original_roles=original_roles,
        doppelganger_copied_role=doppelganger_copied,
    )
