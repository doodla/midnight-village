"""
The server plays the practice players (``apps.core.practice``) of a game.

There is no fake phone and no socket: when a stage opens, once its transaction has
committed (``services._practice_after_commit``, at the look stage, each night
window, the talk and the vote), ``drive`` acts for every practice player who still
has something to do in the stage the game is in NOW, through the very functions a
phone's request calls (``services.set_ready``, ``choose_night.submit_choose``,
``services.submit_vote``), each with the stage token and the prompt's ``chosen`` a
phone would echo. So the game cannot tell them from a person, and every rule
(stages, resends, the window close, the minimum length, the vote's reveal) holds
for them as for anyone. ``GET /me/`` drives too when a practice player is behind
(``behind``): the backstop if an instance died between the commit and the drive.

What a practice player does, at once (it never makes anyone wait, and nothing
here adds a wait):

* the look: "ready";
* each night window: exactly ONE ``choose`` whatever it holds, the picks a
  legal random choice for its prompt (``engine.practice.practice_picks``), empty
  when it has nothing to choose (taken alike and read as nothing, as the server
  takes any phone's); a Doppelganger sends her follow-up when her prompt arms one.
  One choose per practice player per window, so the work done after a window opens
  does not depend on the practice players' cards (her look resolving in her
  request is the one difference, the same accepted tell as a person's);
* the talk: "ready to vote";
* the vote: a random other player, locked.

Every draw is seeded from the game's seed, the step and the player's seat
(``engine.practice.practice_rng``) and logged at INFO, like the deal. Nothing a
practice player picks is sent to anyone: the night has no per-player event, the
vote announces counts only, and its role shows in the results like anyone's.

A failure is logged and never raised: the stage's own clock (or the host) still
moves the game, as for a person who did nothing.
"""

from __future__ import annotations

import logging
from typing import Any

from apps.core.practice import USERNAME_PREFIX, is_practice

from . import choose_night
from . import services as svc
from .engine.practice import practice_picks, practice_rng, practice_vote
from .models import Game, Phase, PlayerRole
from .protocol import (
    LOOK,
    TALK,
    VOTE,
    W1,
    W2,
    WrongStageError,
    in_look_stage,
    stage_name,
    stage_token,
)

logger = logging.getLogger(__name__)

# The most chooses a practice player sends in one window (a Doppelganger's look
# and her follow-up); the server takes no more from anyone.
_MAX_CHOOSES = 2


def drive(game_id: Any) -> None:
    """Act for every practice player of the game who is behind in the stage open
    now. Safe to call any number of times, from anywhere, at any moment: each step
    is a request the server would take once."""
    try:
        _drive(game_id)
    except Exception:
        logger.exception("Practice players could not act in game %s", game_id)


def _drive(game_id: Any) -> None:
    user_ids = list(
        PlayerRole.objects.filter(
            game_id=game_id, user__username__startswith=USERNAME_PREFIX
        )
        .order_by("seat", "user_id")
        .values_list("user_id", flat=True)
    )
    for user_id in user_ids:
        if not _act(game_id, user_id):
            # The stage moved on under us; its own opening drives the next one.
            return


def _act(game_id: Any, user_id: int) -> bool:
    """One practice player's part in the stage open now. False when the stage is
    over (the next one's opening acts for it)."""
    game = Game.objects.get(id=game_id)
    pr = PlayerRole.objects.get(game=game, user_id=user_id)
    stage = stage_name(game)
    token = stage_token(game)
    try:
        if stage == LOOK and in_look_stage(game) and not pr.phase_ready:
            svc.set_ready(game, user_id, True, token)
        elif stage == TALK and not pr.phase_ready:
            svc.set_ready(game, user_id, True, token)
        elif stage in (W1, W2):
            _choose(game, pr, stage)
        elif stage == VOTE and not pr.has_acted:
            _vote(game, pr, token)
    except WrongStageError:
        return False
    except svc.AlreadyActedError:
        pass  # done already (a drive racing another): nothing to do
    return True


def _choose(game: Game, pr: PlayerRole, stage: str) -> None:
    """Exactly one choose in the window, and a Doppelganger's follow-up."""
    for _ in range(_MAX_CHOOSES):
        window = game.current_wave
        chosen = choose_night.chose_count(pr, window)
        prompt = choose_night.prompt_for(game, pr)
        if prompt is None or (chosen >= 1 and prompt["chooses_left"] <= 0):
            return
        rng = practice_rng(game.random_seed, f"{stage}:{chosen}", _seat(pr))
        picks = practice_picks(prompt, rng)
        logger.info(
            "game %s: practice player %s, %s choose %s: %s",
            game.id,
            pr.user_id,
            stage,
            chosen,
            picks,
        )
        errors = choose_night.submit_choose(
            game, pr.user_id, picks, stage_token(game) or "", chosen
        )
        if errors:
            logger.error(
                "game %s: practice player %s's choose refused: %s",
                game.id,
                pr.user_id,
                errors,
            )
            return
        game = Game.objects.get(id=game.id)
        if stage_name(game) != stage:
            return  # that choose closed the window
        pr = PlayerRole.objects.get(game=game, user_id=pr.user_id)


def _seat(pr: PlayerRole) -> int:
    """Where the player sits (a game dealt before seats: its id)."""
    return pr.seat if pr.seat is not None else pr.user_id


def _vote(game: Game, pr: PlayerRole, token: str | None) -> None:
    targets = [
        uid
        for uid in PlayerRole.objects.filter(game=game)
        .order_by("seat", "user_id")
        .values_list("user_id", flat=True)
        if uid != pr.user_id
    ]
    target = practice_vote(targets, practice_rng(game.random_seed, "vote", _seat(pr)))
    if target is None:
        return
    logger.info("game %s: practice player %s votes %s", game.id, pr.user_id, target)
    svc.submit_vote(game, pr.user_id, target, lock=True, stage=token)


def behind(game: Game, player_roles: list[PlayerRole]) -> bool:
    """Whether a practice player has not done its part in the stage open now
    (``player_roles`` with ``user`` loaded: no query unless one is there)."""
    practice = [pr for pr in player_roles if is_practice(pr.user)]
    if not practice:
        return False
    if game.phase == Phase.DISCUSSION or in_look_stage(game):
        return any(not pr.phase_ready for pr in practice)
    if game.phase == Phase.VOTING:
        return any(not pr.has_acted for pr in practice)
    if game.phase == Phase.NIGHT and game.current_wave in (1, 2):
        return any(
            choose_night.chose_count(pr, game.current_wave) == 0 for pr in practice
        )
    return False
