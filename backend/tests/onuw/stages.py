"""Test helpers for night protocol 2's stage tokens.

Under protocol 2 every stage-scoped request echoes the ``stage`` that ``GET /me/``
carries. Tests that are about something else add the CURRENT stage with ``staged``;
tests about stages pass an explicit (old) token instead.
"""

from __future__ import annotations

from typing import Any

from apps.onuw.models import Game
from apps.onuw.protocol import is_choose_night, stage_token


def current_stage(game_id: Any) -> str | None:
    """The stage token the game is in right now (read from the database)."""
    return stage_token(Game.objects.get(id=game_id))


def staged(night: Any, body: Any) -> Any:
    """``body`` with the game's current ``stage`` added, if the game plays protocol 2
    and the body is an object that does not name one."""
    game = Game.objects.get(id=night.game.id)
    if isinstance(body, dict) and "stage" not in body and is_choose_night(game):
        return {**body, "stage": stage_token(game)}
    return body
