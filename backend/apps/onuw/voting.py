"""
The talk and the vote.

Ending the discussion, taking and changing votes, "ready" for a stage, moving a
stage on when everyone present is ready, and revealing the votes: who died, who won.
"""

from __future__ import annotations

import logging
from datetime import timedelta
from typing import Any

from django.db import transaction
from django.db.models import F
from django.utils import timezone

from apps.core import asked as ask
from apps.core import timers
from apps.core.models import Lobby
from apps.core.wire import wire_time

from . import basics, night_flow, readiness
from .engine.voting import apply_hunter, count_votes, determine_elimination
from .engine.win_conditions import evaluate_winner
from .models import Game, Phase, PlayerRole
from .protocol import (
    LOOK,
    TALK,
    VOTE,
    WrongStageError,
    in_look_stage,
    require_stage,
)

logger = logging.getLogger(__name__)

# ── Discussion & Voting ────────────────────────────────────────────────────


def _auto_transition_to_voting(game: Game) -> None:
    """Auto-transition to voting when discussion timer expires."""
    transition_to_voting(game)


def _auto_reveal_votes(game: Game) -> None:
    """Auto-reveal votes when the voting timer expires."""
    reveal_votes(game)


def transition_to_voting(game: Game) -> None:
    """Transition from discussion to voting phase."""
    from .engine.phases import validate_phase_transition

    if not validate_phase_transition(game.phase, Phase.VOTING):
        msg = f"Cannot transition from {game.phase} to voting."
        raise ValueError(msg)

    voting_seconds = basics.get_timer_seconds(
        game, "voting_seconds", basics.DEFAULT_VOTING_SECONDS
    )

    with transaction.atomic():
        game.phase = Phase.VOTING
        opened_at = timezone.now()
        game.night_window_opened_at = opened_at  # the vote's open time
        if voting_seconds > 0:
            game.phase_deadline = opened_at + timedelta(seconds=voting_seconds)
        else:
            game.phase_deadline = None
        game.save(
            update_fields=[
                "phase",
                "phase_deadline",
                "night_window_opened_at",
                "updated_at",
            ]
        )

        # Reset has_acted for all players (tracks vote submission)
        # pyrefly: ignore [missing-attribute]
        game.player_roles.update(has_acted=False, vote_target=None)

    if voting_seconds > 0:
        basics._schedule_after_commit(
            f"{game.id}:voting",
            voting_seconds,
            "voting_deadline",
            {"game_id": str(game.id)},
        )

    # A phone that dropped during the talk is already on the clock: the vote
    # stops waiting for it when its grace period ends.
    readiness._schedule_grace_timers_after_commit(game)

    # Broadcast phase change to all players
    basics._send_after_commit(
        [
            (
                f"game_{game.id}",
                {
                    "type": "phase.change",
                    "phase": "voting",
                    "deadline": wire_time(game.phase_deadline)
                    if game.phase_deadline
                    else None,
                },
            ),
            (f"game_{game.id}", {"type": "progress", **readiness.vote_progress(game)}),
        ]
    )
    basics._practice_after_commit(game)


def end_discussion(game: Game) -> None:
    """End discussion early (host action). Transitions to voting."""
    basics._cancel_after_commit(f"{game.id}:discussion")
    game.phase_deadline = None
    transition_to_voting(game)


VOTE_SELF = "You cannot vote for yourself."


VOTE_BAD_TARGET = "Invalid vote target."


VOTE_NOT_A_PLAYER = "You are not a player in this game."


VOTE_ERROR_CODES = {
    VOTE_SELF: "invalid_target",
    VOTE_BAD_TARGET: "invalid_target",
    VOTE_NOT_A_PLAYER: "not_a_player",
}


def submit_vote(
    game: Game,
    voter_id: int,
    target_player_id: int,
    *,
    lock: bool = True,
    stage: str | None = None,
    asked: int | None = None,
) -> list[str]:
    """
    Pick (``lock=False``) or lock in (``lock=True``) a vote. Returns the list of
    errors (empty = success); ``VOTE_ERROR_CODES`` maps each to its API code.

    A vote is *picked* (``vote_target`` set, changeable, never announced) and then
    *locked* (``has_acted``, final: ``AlreadyActedError``). Everything happens in
    ONE transaction taking the Game row lock first and the voter's PlayerRole
    second (the project's lock order), so the phase cannot change between the
    check and the write and two last locks cannot both reveal.

    Validates: the game is in VOTING (re-read under the lock), the voter plays in
    it, has not locked, does not vote for themselves, and the target plays in it.

    A pick sends nothing. A lock sends the count-only ``progress`` after the
    commit (never who locked) and reveals the vote when everyone being waited for
    has locked (``_votes_ready``). The request names its ``stage`` (compared under
    the Game lock: a pick or lock for a stage that is over, a late lock after the
    reveal, raises ``WrongStageError`` and stores nothing), and a lock that repeats
    the stored locked vote (a resend whose answer was lost) succeeds again doing
    nothing. ``asked`` (the phone's tap time, ``apps.core.asked``) is checked
    last, under the same locks: a pick or lock tapped before the newest one
    applied in this stage raises ``StaleRequestError`` and stores nothing.
    """
    with transaction.atomic():
        game = Game.objects.select_for_update().get(id=game.id)
        require_stage(game, stage, expected=(VOTE,))  # the vote stage: VOTING

        try:
            voter_pr = PlayerRole.objects.select_for_update().get(
                game=game, user_id=voter_id
            )
        except PlayerRole.DoesNotExist:
            return [VOTE_NOT_A_PLAYER]

        if voter_pr.has_acted:
            # The SAME lock again is a resend whose answer was lost: the answer the
            # original got, and nothing stored or sent. Any other pick or lock after
            # locking in is refused.
            # pyrefly: ignore [missing-attribute]
            if lock and voter_pr.vote_target_id == target_player_id:
                return []
            raise basics.AlreadyActedError("You have already locked in your vote.")

        # No self-votes per spec
        if voter_id == target_player_id:
            return [VOTE_SELF]

        # pyrefly: ignore [missing-attribute]
        game_player_ids = set(game.player_roles.values_list("user_id", flat=True))
        if target_player_id not in game_player_ids:
            return [VOTE_BAD_TARGET]
        newest = ask.newer(voter_pr.asked, "vote", stage, asked)
        if newest is not None:
            raise ask.StaleRequestError(newest)

        # pyrefly: ignore [missing-attribute]
        voter_pr.vote_target_id = target_player_id
        voter_pr.asked = ask.noted(voter_pr.asked, ["vote"], stage, asked)
        noted = [] if asked is None else ["asked"]
        if not lock:
            voter_pr.save(update_fields=["vote_target", *noted])
            return []

        voter_pr.has_acted = True
        voter_pr.save(update_fields=["vote_target", "has_acted", *noted])
        basics._send_after_commit(
            [(f"game_{game.id}", {"type": "progress", **readiness.vote_progress(game)})]
        )
        # Reveal once everyone has locked, or everyone still being waited for has
        # (a player gone past the grace period is a non-voter at the deadline too).
        if readiness._votes_ready(game):
            reveal_votes(game)

    return []


def _stage_is_ready(game: Game) -> bool:
    """True when every player the current "ready" stage (the look, the talk) waits
    for has tapped: all who are not gone past the grace period, and at least one.

    The ONE readiness rule. ``set_ready`` (a tap), ``_evaluate_presence`` (a grace
    period ended, a phone came back) and ``ensure_timers`` (the look timer was lost)
    all ask it, so what "everyone is ready" means cannot differ between them.
    """
    progress = readiness.stage_progress(game)
    if progress is None or progress["stage"] == "vote":
        return False
    return progress["needed"] >= 1 and progress["done"] == progress["needed"]


def _advance_stage_if_ready(game: Game) -> bool:
    """Move past the look stage (open the night) or the talk (open the vote) if
    ``_stage_is_ready``. The caller holds the Game lock. Returns whether it did."""
    if not _stage_is_ready(game):
        return False
    if game.phase == Phase.DISCUSSION:
        end_discussion(game)
    else:
        night_flow.start_night_phase(game)
    return True


READY_ONE_WAY = "Looking at your card cannot be undone."


READY_ERROR_CODES = {
    READY_ONE_WAY: "bad_request",
}


def set_ready(
    game: Game,
    user_id: int,
    ready: bool,
    stage: str | None = None,
    asked: int | None = None,
) -> list[str]:
    """Mark the caller ready at the stage that asks for it. Returns the list of
    errors (empty = success); ``READY_ERROR_CODES`` maps them to codes.

    Two stages ask: the look at the card (night, window 0: ``True`` only, looking is
    one way) and the talk (``True`` or ``False``). When every player not gone past
    the grace period is ready, the look opens the night and the talk ends with the
    function the host's button uses. One transaction, Game lock then PlayerRole
    lock, the stage re-checked, so a tap racing the host, the backstop or the
    talk's deadline moves on once. Every tap recounts ``needed`` and sends the
    count. The request names its ``stage`` (compared under the lock: a tap for a
    stage that is over raises ``WrongStageError``). ``asked`` (the phone's tap
    time, ``apps.core.asked``) is checked last, under the same locks: a tap made
    before the newest one applied in this stage raises ``StaleRequestError``.
    """
    with transaction.atomic():
        game = Game.objects.select_for_update().get(id=game.id)
        require_stage(game, stage, expected=(LOOK, TALK))
        looking = in_look_stage(game)
        if not looking and game.phase != Phase.DISCUSSION:
            # A night at window 0 with no look deadline is opening its first window,
            # not asking for taps: the same refusal as any stage that does not.
            raise WrongStageError
        # The caller is known to play in this game (the view checked), so the row
        # exists; it is locked after the Game row as everywhere.
        pr = PlayerRole.objects.select_for_update().get(game=game, user_id=user_id)
        if looking and not ready:
            return [READY_ONE_WAY]
        newest = ask.newer(pr.asked, "ready", stage, asked)
        if newest is not None:
            raise ask.StaleRequestError(newest)

        changed = ["phase_ready"] if pr.phase_ready != ready else []
        if asked is not None:
            changed.append("asked")
        if changed:
            pr.phase_ready = ready
            pr.asked = ask.noted(pr.asked, ["ready"], stage, asked)
            pr.save(update_fields=changed)
        progress = readiness.stage_progress(game)
        if progress is not None:  # looking or in the talk: both have a count
            basics._send_after_commit(
                [(f"game_{game.id}", {"type": "progress", **progress})]
            )
        _advance_stage_if_ready(game)
    return []


def reveal_votes(game: Game) -> None:
    """
    Reveal all votes simultaneously, compute win conditions, and
    transition to results.

    Collects all votes (including None for abstainers).
    Broadcasts vote_reveal event with full vote data.
    Computes elimination and win conditions.
    Stores results in game.results.
    Transitions game to RESULTS phase.
    Broadcasts game_results event.
    """
    # Cancel the voting timer — covers both the host force-reveal and
    # the all-voted path (double-cancel is safe). After commit, like every
    # other side effect, so a rollback leaves the vote running.
    basics._cancel_after_commit(f"{game.id}:voting")

    # Collect vote data
    # pyrefly: ignore [missing-attribute]
    player_roles_qs = game.player_roles.all()
    votes_broadcast: dict[str, int | None] = {}
    votes_dict: dict[int, int | None] = {}
    current_roles: dict[int, str] = {}
    doppelganger_copied: dict[int, str] = {}

    for pr in player_roles_qs:
        # pyrefly: ignore [missing-attribute]
        votes_broadcast[str(pr.user_id)] = pr.vote_target_id
        # pyrefly: ignore [missing-attribute]
        votes_dict[pr.user_id] = pr.vote_target_id
        current_roles[pr.user_id] = pr.current_role
        if pr.original_role == "Doppelganger" and pr.night_action_data.get(
            "copied_role"
        ):
            doppelganger_copied[pr.user_id] = pr.night_action_data["copied_role"]

    messages: list[tuple[str, dict[str, Any]]] = [
        (f"game_{game.id}", {"type": "vote.reveal", "votes": votes_broadcast})
    ]

    # Compute elimination
    vote_counts = count_votes(votes_dict)
    vote_eliminated = determine_elimination(vote_counts)

    # Apply Hunter chain — adds hunter targets on top of vote-eliminated
    eliminated = apply_hunter(
        vote_eliminated, current_roles, votes_dict, doppelganger_copied
    )

    # Build elimination_reasons: vote for vote-eliminated, hunter_chain for the rest
    vote_eliminated_set = set(vote_eliminated)
    elimination_reasons: dict[str, str] = {}
    for pid in eliminated:
        elimination_reasons[str(pid)] = (
            "vote" if pid in vote_eliminated_set else "hunter_chain"
        )

    # Compute win conditions
    result = evaluate_winner(eliminated, current_roles, doppelganger_copied)

    # Transition to results phase, store results, and finalize the lobby
    # atomically so game and lobby state are always consistent.
    with transaction.atomic():
        game.phase = Phase.RESULTS
        game.phase_deadline = None
        game.results = {
            "winning_teams": result.winning_teams,
            "reason": result.reason,
            "eliminated_players": result.eliminated_players,
            "elimination_reasons": elimination_reasons,
            "player_outcomes": {str(k): v for k, v in result.player_outcomes.items()},
        }
        game.save(update_fields=["phase", "phase_deadline", "results", "updated_at"])

        # The table's body changed (``status``): a higher ``rev`` (``Lobby.rev``).
        Lobby.objects.filter(id=game.lobby_id).update(
            status=Lobby.Status.FINISHED, updated_at=timezone.now(), rev=F("rev") + 1
        )

    # Clean up all remaining timers for this game (safety net — individual
    # timers are cancelled at each phase transition, but this catches any
    # that were missed due to unusual flow, and the grace timers).
    game_id = str(game.id)
    basics._after_commit(lambda: timers.cancel_all_for_game(game_id))

    # Broadcast the reveal, then the results, once the transition has committed.
    messages.append(
        (
            f"game_{game.id}",
            {
                "type": "game.results",
                "data": {
                    "winning_teams": result.winning_teams,
                    "reason": result.reason,
                    "eliminated_players": result.eliminated_players,
                },
            },
        )
    )
    basics._send_after_commit(messages)
