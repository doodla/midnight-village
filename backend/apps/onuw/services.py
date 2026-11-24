"""
ONUW game service layer: the top of it.

The service is split by what it is about, each part importing only the ones before
it: ``basics`` (lengths, after-commit helpers, the engine's view of a game),
``readiness`` (who is here, who is done), ``night_window`` (one window of the night),
``night_flow`` (when windows open and close),
``voting`` (the talk and the vote), ``game_presence`` (phones coming and going).
Beside them: ``night_results`` (what a player is shown of the night) and ``recovery``
(rebuilding lost timers).

What is left here is what sits on top of all of them: the timer jobs (registered
from this module by name, ``apps.py``), the game's presence check (its scope is
registered at the foot of this file) and the lobby's current game.
"""

from __future__ import annotations

import functools
import logging
from typing import Any

from apps.core import presence as core_presence
from apps.core import timers
from apps.core.models import Lobby

from . import game_presence, night_flow, voting
from .models import Game, Phase

logger = logging.getLogger(__name__)


@timers.job("night_window")
def _job_night_window(game_id: str, wave: int, deferred: bool = False) -> None:
    game_presence.make_idempotent_callback(
        game_id,
        Phase.NIGHT,
        functools.partial(
            night_flow._auto_advance_wave, wave_number=wave, deferred=deferred
        ),
        reraise=True,
    )()


@timers.job("discussion_deadline")
def _job_discussion_deadline(game_id: str) -> None:
    game_presence.make_idempotent_callback(
        game_id, Phase.DISCUSSION, voting._auto_transition_to_voting, reraise=True
    )()


@timers.job("voting_deadline")
def _job_voting_deadline(game_id: str) -> None:
    game_presence.make_idempotent_callback(
        game_id, Phase.VOTING, voting._auto_reveal_votes, reraise=True
    )()


@timers.job("card_look")
def _job_card_look(game_id: str) -> None:
    """The look stage's backstop: open the night (a no-op if it already opened)."""
    game_presence.make_idempotent_callback(
        game_id, Phase.NIGHT, night_flow._open_night_after_look, reraise=True
    )()


@timers.job("grace_expired")
def _job_grace_expired(game_id: str, user_id: int) -> None:
    game_presence._grace_expired(game_id, user_id)


# ── The lobby's current game ──────────────────────────────────────────────


def latest_game(lobby: Lobby) -> Game | None:
    """The lobby's current game: its newest one."""
    # pyrefly: ignore [missing-attribute]
    return lobby.games.order_by("-created_at", "-id").first()


def report_game_presence(game_id: Any, user_id: int, connected: bool) -> None:
    """Tell the lobby (host handover) that a player's socket on this game opened
    (0 -> 1) or closed (1 -> 0). Call only after the game presence transaction
    has committed. Only the lobby's newest game counts."""
    from apps.core import host

    game = Game.objects.filter(id=game_id).only("lobby_id").first()
    if game is None:
        return
    newest = (
        Game.objects.filter(lobby_id=game.lobby_id)
        .order_by("-created_at", "-id")
        .first()
    )
    if newest is None or newest.id != game.id:
        return
    host.member_presence_changed(game.lobby_id, user_id, connected)


# ── The game's presence check ─────────────────────────────────────────────


def _check_game(scope_id: str, user_id: int) -> None:
    """Scope checker of the durable presence check: a game socket may have died."""
    from apps.core.effects import after_commit

    if game_presence.check_game_presence(scope_id, user_id):
        # Host handover has its own transaction and lock order (Lobby then
        # LobbyMember): it runs only after this one has committed.
        after_commit(lambda: report_game_presence(scope_id, user_id, False))


# Registered when this module is imported, which the timers do before any job
# runs (``timers.register_job_module("apps.onuw.services")``).
core_presence.register_scope("game", _check_game)
