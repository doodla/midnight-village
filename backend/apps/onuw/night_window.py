"""
One window of the night.

Who acts in a window and what they are asked, what a timeout does for a player who
did not act, collecting and resolving what happened (the Doppelganger's look
first), storing the results, the look stage before the night, and the move to the
discussion when the last window has closed. Nothing here decides WHEN a window
opens or closes: that is ``night_flow``.
"""

from __future__ import annotations

import logging
import random
from datetime import timedelta
from typing import Any

from django.db import transaction
from django.utils import timezone

from apps.core.wire import wire_time

from . import basics, readiness, turns
from .engine.behaviors import get_doppelganger_followup_wave
from .engine.night import (
    get_required_actions_for_window,
    resolve_wave,
    resolve_window,
)
from .engine.roles import ActionType, get_role
from .engine.state import ActionResult, GameState, NightAction
from .models import Game, Phase, PlayerRole

logger = logging.getLogger(__name__)


def get_wave_actors(game: Game, wave: int) -> list[int]:
    """Return user_ids of players who should act in the given night window."""
    state = basics.build_game_state(game)
    doppelganger_info = state.doppelganger_copied_role if wave > 1 else None
    prompts = get_required_actions_for_window(state, wave, doppelganger_info)
    return [p["player_id"] for p in prompts]


def _doppelganger_in_deck(game: Game) -> bool:
    """True if the Doppelganger card is in the deck: dealt to a player or in the center."""
    # pyrefly: ignore [missing-attribute]
    dealt = game.player_roles.filter(original_role="Doppelganger").exists()
    return dealt or "Doppelganger" in game.center_cards


def _look_timer_key(game: Game) -> str:
    return f"{game.id}:look"


def _start_look_stage(game: Game, seconds: int) -> None:
    """Hold the night at window 0 until everyone has looked at their card, or the
    backstop fires, or the host moves on. Shows nothing about roles."""
    with transaction.atomic():
        opened_at = timezone.now()
        # ``night_window_opened_at`` is the open time of whichever stage is open
        # (look, a night window, talk, vote): ``/me/`` ``stage_started_at``.
        game.night_window_opened_at = opened_at
        game.phase_deadline = opened_at + timedelta(seconds=seconds)
        game.save(
            update_fields=["phase_deadline", "night_window_opened_at", "updated_at"]
        )
    basics._schedule_after_commit(
        _look_timer_key(game), seconds, "card_look", {"game_id": str(game.id)}
    )
    basics._send_after_commit(
        [(f"game_{game.id}", {"type": "progress", **readiness.look_progress(game)})]
    )
    basics._practice_after_commit(game)


def _min_close_delay(game: Game) -> float:
    """Seconds until the current window may close (0 if its minimum has passed).

    The minimum never exceeds the window's maximum (night_wave_seconds).
    """
    min_seconds = basics.get_timer_seconds(
        game, "night_min_window_seconds", basics.DEFAULT_NIGHT_MIN_WINDOW_SECONDS
    )
    max_seconds = basics.get_timer_seconds(
        game, "night_wave_seconds", basics.DEFAULT_NIGHT_WAVE_SECONDS
    )
    if max_seconds > 0:
        min_seconds = min(min_seconds, max_seconds)
    opened_at = game.night_window_opened_at
    if min_seconds <= 0 or opened_at is None:
        return 0.0
    ready_at = opened_at + timedelta(seconds=min_seconds)
    return max(0.0, (ready_at - timezone.now()).total_seconds())


def _fixed_window_seconds(game: Game, window: int) -> int:
    """Exact length of a fixed-length window in seconds, or 0 if it is not fixed.

    Window 1 (the Doppelganger's) lasts exactly night_doppelganger_window_seconds
    whenever it runs, so its length says nothing about whether the Doppelganger
    is in play, copied a role, or has a follow-up. Setting it to 0 turns the
    fixed length off: window 1 then closes like window 2 (when its actors are
    done, no sooner than night_min_window_seconds, no later than
    night_wave_seconds).
    """
    if window != 1:
        return 0
    return basics.get_timer_seconds(
        game,
        "night_doppelganger_window_seconds",
        basics.DEFAULT_NIGHT_DOPPELGANGER_WINDOW_SECONDS,
    )


def drunk_timeout_center_index(
    random_seed: int, player_id: int, center_size: int
) -> int:
    """The center card the server swaps a timed-out Drunk with.

    Deterministic and independent of timing or of any other event: a dedicated
    RNG seeded from the game seed, a fixed label and the player id, so a replay
    of the same game reproduces it.
    """
    rng = random.Random(f"{random_seed}:drunk-timeout:{player_id}")  # noqa: S311 (seeded, not secret)
    return rng.randrange(center_size)


def _timeout_action(game: Game, player_id: int, role_acting_as: str) -> NightAction:
    """What happens for a player who submitted nothing before the window closed.

    The Drunk (and a Doppelganger who copied the Drunk) MUST swap, so the
    server swaps with a seeded random center card and marks it
    ``made_by_server`` in the log. It looks exactly like a chosen swap to
    everyone else: it resolves when the window closes and the Drunk is sent the
    same result. Everything else is the automatic or skipped default.
    """
    if role_acting_as == "Drunk" and game.center_cards:
        index = drunk_timeout_center_index(
            game.random_seed, player_id, len(game.center_cards)
        )
        return NightAction(
            player_id=player_id,
            role_acting_as=role_acting_as,
            action_type="swap_with_center",
            targets={"center_index": index},
            made_by_server=True,
        )
    return NightAction(
        player_id=player_id,
        role_acting_as=role_acting_as,
        action_type=_timeout_action_type(role_acting_as),
        targets={},
    )


def _timeout_action_type(role_acting_as: str) -> str:
    """Determine the action type for a player who didn't submit before the timer.

    Automatic roles (Insomniac, see_team roles) are auto-resolved rather than
    skipped, because their actions require no player choice — the information
    is revealed automatically per the ONUW rules. Skipping these would lose
    information the player is entitled to (e.g., Insomniac not seeing their
    current card after swaps).

    Roles with an optional choice (Seer, Robber, Troublemaker, Doppelganger's
    look) are skipped — the player forfeited it by not submitting. The Drunk is
    never skipped: see _timeout_action, which swaps for them.
    """
    role_def = get_role(role_acting_as)
    if role_def.action_types == (ActionType.NONE,):
        return "none"
    if role_def.action_types == (ActionType.SEE_TEAM,):
        return "see_team"
    return "skip"


def _restore_deadline_timer(game: Game) -> None:
    """Re-arm the open night window's own deadline timer (after a deferred
    close turned out to be premature). No deadline means no timer: the host or
    the players moving it are all that is left, as before."""
    if game.phase_deadline is None:
        return
    window = game.current_wave
    delay = max(0.0, (game.phase_deadline - timezone.now()).total_seconds())
    basics._schedule_after_commit(
        basics._window_timer_key(game, window),
        delay,
        "night_window",
        basics._window_job_params(game, window),
    )


def announce_window(game: Game, window: int) -> None:
    """Tell the table a window opened with ONE group event, the same bytes for every
    phone and nothing per player (each phone reads its prompt from ``GET /me/``).
    The caller (``send_wave_prompts``) has set the deadline and the timer."""
    basics._send_after_commit(
        [
            (
                f"game_{game.id}",
                {
                    "type": "night.window",
                    "window": window,
                    "deadline": wire_time(game.phase_deadline)
                    if game.phase_deadline
                    else None,
                },
            )
        ]
    )


def send_wave_prompts(game: Game, wave: int) -> None:
    """
    Open the timing of a night window and tell the table.

    ``wave`` is the window number. Records when the window opened (the minimum
    length is measured from here) and its deadline, then, once the transaction
    commits: schedules the window's one timer (night_wave_seconds, or exactly
    night_doppelganger_window_seconds for window 1) and sends the ONE group event
    ``night.window`` (``announce_window``): every phone reads its own prompt
    from ``GET /me/``. A timer of 0 seconds means no timer and no deadline.
    """
    seconds = _fixed_window_seconds(game, wave) or basics.get_timer_seconds(
        game, "night_wave_seconds", basics.DEFAULT_NIGHT_WAVE_SECONDS
    )
    opened_at = timezone.now()
    game.night_window_opened_at = opened_at
    game.phase_deadline = (
        opened_at + timedelta(seconds=seconds) if seconds > 0 else None
    )
    game.save(update_fields=["phase_deadline", "night_window_opened_at", "updated_at"])

    if seconds > 0:
        basics._schedule_after_commit(
            basics._window_timer_key(game, wave),
            seconds,
            "night_window",
            basics._window_job_params(game, wave),
        )
    announce_window(game, wave)


def _doppelganger_player_role(game: Game) -> PlayerRole | None:
    """The PlayerRole of the player who was dealt the Doppelganger, if any."""
    # pyrefly: ignore [missing-attribute]
    return game.player_roles.filter(original_role="Doppelganger").first()


def _doppelganger_look_submitted(game: Game) -> bool:
    """True if the Doppelganger submitted the look and it is not resolved yet."""
    pr = _doppelganger_player_role(game)
    if pr is None or not pr.has_acted:
        return False
    data = pr.night_action_data
    return (
        data.get("role_acting_as") == "Doppelganger"
        and isinstance(
            data.get("action_type"), str
        )  # a choose that read as nothing has none
        and "copied_role" not in data
    )


def _resolve_doppelganger_look(game: Game) -> bool:
    """Resolve the Doppelganger's stored look now (the Game row is locked).

    Called in the request that stores her look (``choose_night.submit_choose``): she
    needs the copied role to choose her follow-up, and the window close needs it to
    know who acts as what. Nothing is sent: she reads the look from ``GET /me/``.
    Returns True if the copied role has a follow-up in window 1 (Seer, Robber,
    Troublemaker, Drunk, Minion).
    """
    pr = _doppelganger_player_role(game)
    if pr is None:
        return False
    data = pr.night_action_data
    look = NightAction(
        player_id=pr.user_id,
        role_acting_as="Doppelganger",
        action_type=data["action_type"],
        targets=data.get("targets", {}),
    )
    state = basics.build_game_state(game)
    new_state, results = resolve_wave(state, [look], 1)
    with transaction.atomic():
        persist_wave_results(game, new_state, results, 1)
    copied = new_state.doppelganger_copied_role.get(pr.user_id)
    return copied is not None and get_doppelganger_followup_wave(copied) == 1


def _collect_window_actions(game: Game, window: int) -> list[NightAction]:
    """Gather the window's actions: what each actor submitted, else their default.

    A player who submitted nothing gets the automatic action for their role:
    team views and the Insomniac's look still happen (they need no choice),
    anything with a choice is skipped.
    """
    # pyrefly: ignore [missing-attribute]
    player_roles = {pr.user_id: pr for pr in game.player_roles.all()}
    actions: list[NightAction] = []
    for pid in get_wave_actors(game, window):
        pr = player_roles[pid]
        role_acting_as = _determine_acting_role(pr, window)
        if role_acting_as is None:
            continue  # Already fully resolved earlier (the Doppelganger's look).
        data = pr.night_action_data
        if (
            pr.has_acted
            and data.get("wave") == window
            and data.get("role_acting_as") == role_acting_as
        ):
            action_type, targets = data.get("action_type"), data.get("targets", {})
            if action_type is None and turns.chose_count(pr, window):
                # They chose, and nothing they picked means anything for their
                # role. The role's timeout default applies (a Drunk is swapped by
                # the server), silently: not an error.
                actions.append(_timeout_action(game, pid, role_acting_as))
                continue
            if isinstance(action_type, str) and isinstance(targets, dict):
                actions.append(
                    NightAction(
                        player_id=pid,
                        role_acting_as=role_acting_as,
                        action_type=action_type,
                        targets=targets,
                    )
                )
                continue
            logger.error(
                "Malformed stored night action for player %s in game %s: "
                "treated as a timeout",
                pid,
                game.id,
            )
        actions.append(_timeout_action(game, pid, role_acting_as))
    return actions


def _resolve_window_safely(
    game: Game, state: GameState, actions: list[NightAction], window: int
) -> tuple[list[NightAction], GameState, list[ActionResult]]:
    """Resolve a window; one player's stored action can never block the close.

    If resolving raises, each stored action is tried alone; one that raises is
    replaced by its role's timeout default (logged loudly) and the window closes.
    As a last resort every action falls back to its default. Returns the actions
    that were really resolved (the results are labelled with them).
    """
    try:
        new_state, results = resolve_window(state, actions, window)
        return actions, new_state, results
    except Exception:
        logger.exception(
            "Resolving night window %s of game %s failed; finding the stored "
            "action that breaks it",
            window,
            game.id,
        )
    safe: list[NightAction] = []
    for action in actions:
        try:
            resolve_window(state, [action], window)
            safe.append(action)
        except Exception:
            logger.error(
                "Stored night action of player %s (%s as %s) cannot be resolved "
                "in game %s: treated as a timeout",
                action.player_id,
                action.action_type,
                action.role_acting_as,
                game.id,
                exc_info=True,
            )
            safe.append(_timeout_action(game, action.player_id, action.role_acting_as))
    try:
        new_state, results = resolve_window(state, safe, window)
        return safe, new_state, results
    except Exception:
        logger.exception(
            "Night window %s of game %s still fails; every stored action is "
            "treated as a timeout",
            window,
            game.id,
        )
    defaults = [_timeout_action(game, a.player_id, a.role_acting_as) for a in actions]
    new_state, results = resolve_window(state, defaults, window)
    return defaults, new_state, results


def _determine_acting_role(pr: PlayerRole, wave: int) -> str | None:
    """
    Role a player acts as in a night window, or None if they do not act in it.

    Decided from the DEALT card (original_role), never the card held now;
    a Doppelganger acts as the role she copied.
    """
    return turns.get_player_acting_role_for_wave(pr, wave)


def persist_wave_results(
    game: Game,
    new_state: GameState,
    results: list[ActionResult],
    wave: int,
) -> None:
    """Write engine results back to DB within an atomic transaction.

    ``wave`` is the night window. Results are stored per window
    (``wave_<window>_result``); a player gets at most one in window 2. Log
    entries keep the order group they were resolved in, so the night log stays
    in wake order.
    """
    # Update center cards
    game.center_cards = new_state.center_cards

    # Append the action log entries produced by this resolution
    log = list(game.night_actions_log)
    log.extend(entry.to_dict() for entry in new_state.action_log)
    game.night_actions_log = log
    game.save(update_fields=["center_cards", "night_actions_log", "updated_at"])

    # Write only the rows that changed, all in one statement: one read, then one
    # update for every row whose card moved or whose player got a result (none
    # when nothing changed), not one per player.
    rows = {pr.user_id: pr for pr in PlayerRole.objects.filter(game=game)}
    touched: dict[int, PlayerRole] = {}
    for pid, role in new_state.player_roles.items():
        pr = rows.get(pid)
        if pr is not None and pr.current_role != role:
            pr.current_role = role
            touched[pid] = pr

    # Store action results in each player's night_action_data
    changed: dict[int, dict[str, Any]] = {}
    for result in results:
        if result.revealed_info and result.player_id in rows:
            data = changed.get(result.player_id)
            if data is None:
                data = dict(rows[result.player_id].night_action_data)
                changed[result.player_id] = data
            data[f"wave_{wave}_result"] = result.revealed_info
            # For Doppelganger, also store copied_role at top level
            if "copied_role" in result.revealed_info:
                data["copied_role"] = result.revealed_info["copied_role"]
    for pid, data in changed.items():
        rows[pid].night_action_data = data
        touched[pid] = rows[pid]
    # Both fields are written for every touched row (one read a moment ago): safe
    # because every writer of a PlayerRole holds the Game row lock first, as this does.
    PlayerRole.objects.bulk_update(
        list(touched.values()), ["current_role", "night_action_data"]
    )


def transition_to_discussion(game: Game) -> None:
    """Transition the game from night to discussion phase."""
    discussion_seconds = basics.get_timer_seconds(
        game, "discussion_seconds", basics.DEFAULT_DISCUSSION_SECONDS
    )

    with transaction.atomic():
        game.phase = Phase.DISCUSSION
        game.current_wave = 0
        # The talk's open time (``/me/`` ``stage_started_at``); the night's
        # minimum-length rule never reads it outside a night window.
        opened_at = timezone.now()
        game.night_window_opened_at = opened_at
        if discussion_seconds > 0:
            game.phase_deadline = opened_at + timedelta(seconds=discussion_seconds)
        else:
            game.phase_deadline = None
        game.save(
            update_fields=[
                "phase",
                "current_wave",
                "night_window_opened_at",
                "phase_deadline",
                "updated_at",
            ]
        )

        # Reset has_acted for voting phase later, and "ready to vote" for the talk.
        # pyrefly: ignore [missing-attribute]
        game.player_roles.update(has_acted=False, phase_ready=False)

    if discussion_seconds > 0:
        basics._schedule_after_commit(
            f"{game.id}:discussion",
            discussion_seconds,
            "discussion_deadline",
            {"game_id": str(game.id)},
        )

    # Broadcast phase change to all players
    basics._send_after_commit(
        [
            (
                f"game_{game.id}",
                {
                    "type": "phase.change",
                    "phase": "discussion",
                    "deadline": wire_time(game.phase_deadline)
                    if game.phase_deadline
                    else None,
                },
            ),
            (f"game_{game.id}", {"type": "progress", **readiness.talk_progress(game)}),
        ]
    )
    basics._practice_after_commit(game)
