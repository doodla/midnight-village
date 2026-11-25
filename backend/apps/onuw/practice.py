"""
The server plays the practice players (``apps.core.practice``) of a game.

There is no fake phone and no socket: when a stage opens, once its transaction has
committed (``basics._practice_after_commit``, at the look stage, each night
window, the talk and the vote), ``drive`` acts for every practice player who still
has something to do in the stage the game is in NOW, through the very functions a
phone's request calls (``voting.set_ready``, ``choose_night.submit_choose``,
``voting.submit_vote``), each with the stage token and the prompt's ``chosen`` a
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
moves the game, as for a person who did nothing. A refused choose is sent again
once as an empty one (which the server takes from anyone and reads as nothing);
a practice player whose part is still refused, or fails, is given up for that
stage (``_given_up``, this instance's memory), so the ``GET /me/`` backstop does
not re-drive and re-log it at every poll for the rest of the stage.
"""

from __future__ import annotations

import logging
from collections import OrderedDict
from typing import Any

from apps.core.practice import USERNAME_PREFIX, is_practice

from . import basics, choose_night, turns, voting
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

# (game, stage token, player) given up for that stage: refused even when empty, or
# failed. Kept in this instance's memory, the newest ``_GIVEN_UP_MOST`` only (a
# stage token never comes back, so an old entry is dead weight).
_GIVEN_UP_MOST = 512
_given_up: OrderedDict[tuple[str, str, int], None] = OrderedDict()


def _give_up(game: Game, user_id: int) -> None:
    key = (str(game.id), stage_token(game) or "", user_id)
    _given_up[key] = None
    while len(_given_up) > _GIVEN_UP_MOST:
        _given_up.popitem(last=False)


def _gave_up(game: Game, user_id: int) -> bool:
    return (str(game.id), stage_token(game) or "", user_id) in _given_up


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
    if _gave_up(game, user_id):
        return True
    try:
        if stage == LOOK and in_look_stage(game) and not pr.phase_ready:
            voting.set_ready(game, user_id, True, token)
        elif stage == TALK and not pr.phase_ready:
            voting.set_ready(game, user_id, True, token)
        elif stage in (W1, W2):
            _choose(game, pr, stage)
        elif stage == VOTE and not pr.has_acted:
            _vote(game, pr, token)
    except WrongStageError:
        return False
    except basics.AlreadyActedError:
        pass  # done already (a drive racing another): nothing to do
    except Exception:
        # Given up for this stage; the others still act.
        logger.exception(
            "game %s: practice player %s could not act in %s; given up for it",
            game.id,
            user_id,
            stage,
        )
        _give_up(game, user_id)
    return True


def _choose(game: Game, pr: PlayerRole, stage: str) -> None:
    """Exactly one choose in the window, and a Doppelganger's follow-up."""
    for _ in range(_MAX_CHOOSES):
        window = game.current_wave
        chosen = turns.chose_count(pr, window)
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
        errors, _ = choose_night.submit_choose(
            game, pr.user_id, picks, stage_token(game) or "", chosen, answer=False
        )
        if errors and picks:
            # Never expected (the picks are the prompt's own); an empty choose is
            # taken from anyone and read as nothing.
            logger.error(
                "game %s: practice player %s's choose %s refused (%s); "
                "sending an empty one",
                game.id,
                pr.user_id,
                picks,
                errors,
            )
            errors, _ = choose_night.submit_choose(
                game, pr.user_id, [], stage_token(game) or "", chosen, answer=False
            )
        if errors:
            logger.error(
                "game %s: practice player %s's choose refused: %s; given up for "
                "this window",
                game.id,
                pr.user_id,
                errors,
            )
            _give_up(game, pr.user_id)
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
    voting.submit_vote(game, pr.user_id, target, lock=True, stage=token)


def behind(game: Game, player_roles: list[PlayerRole]) -> bool:
    """Whether a practice player has not done its part in the stage open now
    (``player_roles`` with ``user`` loaded: no query unless one is there)."""
    practice = [
        pr
        for pr in player_roles
        if is_practice(pr.user) and not _gave_up(game, pr.user_id)
    ]
    if not practice:
        return False
    if game.phase == Phase.DISCUSSION or in_look_stage(game):
        return any(not pr.phase_ready for pr in practice)
    if game.phase == Phase.VOTING:
        return any(not pr.has_acted for pr in practice)
    if game.phase == Phase.NIGHT and game.current_wave in (1, 2):
        return any(_behind_at_night(game, pr) for pr in practice)
    return False


def _behind_at_night(game: Game, pr: PlayerRole) -> bool:
    """Not chosen in the window yet, or a Doppelganger whose copy armed a
    follow-up she has not sent (the only player with a second choose)."""
    chosen = turns.chose_count(pr, game.current_wave)
    if chosen == 0:
        return True
    if game.current_wave != 1 or pr.original_role != "Doppelganger":
        return False
    prompt = choose_night.prompt_for(game, pr)
    return prompt is not None and prompt["chooses_left"] > 0
