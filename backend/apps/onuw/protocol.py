"""Which night a game plays, and which stage it is in (pure functions of a Game row).

Two things live here because both the services and the protocol-2 night module need
them and neither may import the other at module level:

* ``is_choose_night``: the one switch for night protocol 2 (``night_protocol: 2`` in
  the game's settings). Every other game plays the original night.
* The STAGE: a name for what a tap means right now (``look``, ``w1``, ``w2``,
  ``talk``, ``vote``) and the opaque token a client echoes back. Under
  protocol 2 every request that acts on a stage (``choose``, ``ready``, ``vote``, a
  host's advance / end-discussion / reveal) names the stage it was aimed at; the
  server compares it with the stage the game is in NOW, under the Game lock, and a
  request for a stage that has passed does nothing (409 ``wrong_stage``, the same
  for every role). So a late tap can never land in the next stage.

The token is the stage name plus a piece of the game's own id: a token from another
game (an earlier game of the same table, after play again) never matches, and within
a game every stage happens once, in order, so a token from an earlier stage never
matches either. Clients treat it as opaque.
"""

from __future__ import annotations

from typing import Any

from .models import Game, Phase

# The stages, in the order a game goes through them.
LOOK, W1, W2, TALK, VOTE = "look", "w1", "w2", "talk", "vote"
NIGHT_CHOOSE_STAGES = (W1, W2)

WRONG_STAGE_DETAIL = "That stage is over."
WRONG_STAGE_CODE = "wrong_stage"


class WrongStageError(Exception):
    """A request named a stage the game is no longer in (protocol 2)."""


def is_choose_night(game: Game) -> bool:
    """True if the game plays night protocol 2: every phone sends one ``choose`` per
    stage, the server reads it per role when the stage ends and answers everyone
    alike, a window opens with one group event and results are read from
    ``GET /me/``. Games whose settings do not say ``night_protocol: 2`` keep the
    original per-role night."""
    return isinstance(game.settings, dict) and game.settings.get("night_protocol") == 2


def in_look_stage(game: Game) -> bool:
    """Night, window 0, with a look deadline. (A night at window 0 with no deadline
    is a night that is about to open, or never did: the stuck rule's.)"""
    return (
        game.phase == Phase.NIGHT
        and game.current_wave == 0
        and game.phase_deadline is not None
    )


def stage_name(game: Game) -> str | None:
    """The stage the game is in, or None (lobby, results)."""
    if game.phase == Phase.NIGHT:
        if game.current_wave == 1:
            return W1
        if game.current_wave == 2:
            return W2
        return LOOK
    if game.phase == Phase.DISCUSSION:
        return TALK
    if game.phase == Phase.VOTING:
        return VOTE
    return None


def stage_token(game: Game) -> str | None:
    """The opaque token of the stage the game is in (``/me/`` ``stage``)."""
    name = stage_name(game)
    return None if name is None else f"{name}.{game.id.hex[:12]}"


def require_stage(
    game: Game, token: Any, *, expected: tuple[str, ...] | None = None
) -> None:
    """Raise ``WrongStageError`` unless ``token`` names the stage the game is in now.

    ``expected`` narrows it to some stage names (the talk for end-discussion). Call it
    with the Game row locked. Under protocol 1 there are no stages: it does nothing.
    """
    if not is_choose_night(game):
        return
    current = stage_token(game)
    if current is None or token != current:
        raise WrongStageError
    if expected is not None and stage_name(game) not in expected:
        raise WrongStageError
