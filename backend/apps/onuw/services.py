"""
ONUW game service layer.

Coordinates between HTTP/WS (views, consumers) and the pure-Python engine.
All game state transitions go through this module.
"""

from __future__ import annotations

import functools
from datetime import timedelta
from typing import Any

from django.db import transaction
from django.utils import timezone

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

from apps.onuw import timers

from .engine.behaviors import get_doppelganger_followup_wave
from .engine.night import get_required_actions, resolve_wave
from .engine.roles import get_role
from .engine.state import ActionResult, GameState, NightAction
from .engine.voting import apply_hunter, count_votes, determine_elimination
from .engine.win_conditions import evaluate_winner
from .models import Game, Phase, PlayerRole


def get_timer_seconds(game: Game, key: str, default: int) -> int:
    """Read a timer duration from game settings, returning default if not set."""
    return game.settings.get(key, default)


def _get_player_names(game: Game) -> dict[int, str]:
    """Build a player_id -> display_name lookup for the game."""
    # pyrefly: ignore [missing-attribute]
    return {
        pr.user_id: pr.user.display_name or pr.user.username
        for pr in game.player_roles.select_related("user").all()
    }


def _client_action_type(action: NightAction) -> str:
    """Map engine action to the action_type string the frontend expects.

    The Insomniac role uses peek_player in the engine (since it peeks at
    its own card), but the frontend routes on "insomniac" to display the
    correct result view.
    """
    if action.role_acting_as == "Insomniac":
        return "insomniac"
    return action.action_type


def _transform_revealed_info(
    action: NightAction,
    result: ActionResult,
    player_names: dict[int, str],
) -> dict[str, Any]:
    """Transform engine revealed_info into the format the frontend expects.

    The engine returns raw data (player IDs, internal key names). The frontend
    expects display names and a consistent key schema per action type.
    """
    raw = result.revealed_info
    action_type = action.action_type
    targets = action.targets

    # Insomniac sees their current role (may have changed via swap).
    if action.role_acting_as == "Insomniac":
        current = raw.get("current_role", "")
        return {
            "current_role": current.lower() if isinstance(current, str) else current
        }

    if action_type == "peek_player":
        # Seer peek at a player, or Doppelganger copy.
        target_id = int(targets.get("player_id", 0))
        target_name = player_names.get(target_id, "Unknown")
        # Engine uses "peeked_role" for Seer, "copied_role" for Doppelganger.
        role = raw.get("peeked_role") or raw.get("copied_role", "")
        out: dict[str, Any] = {
            "target_name": target_name,
            "role": role.lower() if isinstance(role, str) else role,
        }
        # Preserve copied_role for Doppelganger follow-up logic.
        if "copied_role" in raw:
            out["copied_role"] = raw["copied_role"]
        return out

    if action_type == "peek_center":
        # Seer peek at 2 center cards.
        peeked = raw.get("peeked_center", [])
        roles = [
            entry["role"].lower()
            for entry in peeked
            if isinstance(entry, dict) and "role" in entry
        ]
        return {"roles": roles}

    if action_type == "swap_with_player":
        # Robber swaps with target, learns their role.
        target_id = int(targets.get("player_id", 0))
        target_name = player_names.get(target_id, "Unknown")
        new_role = raw.get("new_role", "")
        return {
            "target_name": target_name,
            "new_role": new_role.lower() if isinstance(new_role, str) else new_role,
        }

    if action_type == "swap_with_center":
        # Drunk swaps with a center card, learns nothing.
        center_index = targets.get("center_index")
        return {"card_index": int(center_index) if center_index is not None else 0}

    if action_type == "swap_others":
        # Troublemaker swaps two other players, learns nothing.
        player_ids = targets.get("player_ids", [])
        name1 = (
            player_names.get(int(player_ids[0]), "Unknown")
            if len(player_ids) > 0
            else "Unknown"
        )
        name2 = (
            player_names.get(int(player_ids[1]), "Unknown")
            if len(player_ids) > 1
            else "Unknown"
        )
        return {"player1_name": name1, "player2_name": name2}

    if action_type == "see_team":
        # Werewolf, Mason, or Minion see teammates.
        # Engine sends "werewolves" for Werewolf/Minion, "masons" for Mason.
        teammate_ids: list[int] = raw.get("werewolves", raw.get("masons", []))
        teammate_names = [player_names.get(pid, "Unknown") for pid in teammate_ids]
        see_team_out: dict[str, Any] = {
            "teammate_names": teammate_names,
            "role_acting_as": action.role_acting_as,
        }
        # Lone werewolf center card peek (optional).
        if "center_card" in raw:
            cc = raw["center_card"]
            see_team_out["center_card"] = {
                "index": cc["index"],
                "role": cc["role"].lower()
                if isinstance(cc.get("role"), str)
                else cc.get("role", ""),
            }
        return see_team_out

    if action_type == "skip":
        return {}

    # Unknown action — pass through as-is.
    return dict(raw)


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


def get_wave_actors(game: Game, wave: int) -> list[int]:
    """Return user_ids of players who should act in the given wave."""
    state = build_game_state(game)
    doppelganger_info = state.doppelganger_copied_role if wave > 1 else None
    prompts = get_required_actions(state, wave, doppelganger_info)
    return [p["player_id"] for p in prompts]


def get_next_active_wave(game: Game, after_wave: int) -> int | None:
    """
    Find the next wave (after after_wave) that has actors.

    Returns None if no more waves need processing.
    """
    state = build_game_state(game)
    for wave in range(after_wave + 1, 5):  # waves 1-4
        doppelganger_info = state.doppelganger_copied_role if wave > 1 else None
        prompts = get_required_actions(state, wave, doppelganger_info)
        if prompts:
            return wave
    return None


def start_night_phase(game: Game) -> None:
    """
    Initialize the night phase: find the first active wave, set current_wave,
    and send prompts to players.

    Called after the game is created. If no night actions exist at all,
    transitions directly to discussion.
    """
    first_wave = get_next_active_wave(game, 0)
    if first_wave is None:
        # No night actions at all -- skip straight to discussion
        transition_to_discussion(game)
        return

    game.current_wave = first_wave
    game.save(update_fields=["current_wave", "updated_at"])

    send_wave_prompts(game, first_wave)


def _auto_advance_wave(game: Game, wave_number: int) -> None:
    """Auto-advance a wave when its timer expires, marking non-actors as skipped."""
    if game.current_wave != wave_number:
        return  # Wave already advanced — stale callback.
    advance_wave(game)


def send_wave_prompts(game: Game, wave: int) -> None:
    """
    Send action prompts to players who act in this wave, and
    waiting messages to non-acting players.

    Schedules a wave timer when night_wave_seconds > 0.
    """
    wave_seconds = get_timer_seconds(game, "night_wave_seconds", 30)
    if wave_seconds > 0:
        game.phase_deadline = timezone.now() + timedelta(seconds=wave_seconds)
        callback = timers.make_idempotent_callback(
            game.id,
            Phase.NIGHT,
            functools.partial(_auto_advance_wave, wave_number=wave),
        )
        timers.schedule(f"{game.id}:wave:{wave}", wave_seconds, callback)
    else:
        game.phase_deadline = None
    game.save(update_fields=["phase_deadline", "updated_at"])

    channel_layer = get_channel_layer()
    if channel_layer is None:
        return

    state = build_game_state(game)
    doppelganger_info = state.doppelganger_copied_role if wave > 1 else None
    prompts = get_required_actions(state, wave, doppelganger_info)
    acting_player_ids = {p["player_id"] for p in prompts}

    send = async_to_sync(channel_layer.group_send)

    # Broadcast wave_start to all players
    send(
        f"game_{game.id}",
        {
            "type": "wave.start",
            "wave": wave,
            "deadline": game.phase_deadline.isoformat()
            if game.phase_deadline
            else None,
        },
    )

    # Send action prompts to acting players (player-specific channels)
    for prompt in prompts:
        pid = prompt["player_id"]
        send(
            f"game_{game.id}_player_{pid}",
            {
                "type": "action.prompt",
                "wave": wave,
                "role_acting_as": prompt["role_acting_as"],
                "action_types": prompt["action_types"],
                "valid_targets": prompt["valid_targets"],
            },
        )

    # Send waiting messages to non-acting players
    for pid in state.player_roles:
        if pid not in acting_player_ids:
            send(
                f"game_{game.id}_player_{pid}",
                {
                    "type": "wave.waiting",
                    "wave": wave,
                },
            )


def advance_wave(game: Game) -> None:
    """
    Resolve the current wave, persist results, send player-scoped results,
    then advance to the next wave or transition to discussion.
    """
    wave = game.current_wave
    timers.cancel(f"{game.id}:wave:{wave}")
    state = build_game_state(game)

    # Collect actions from PlayerRole rows
    night_actions: list[NightAction] = []
    actor_ids = set(get_wave_actors(game, wave))

    # pyrefly: ignore [missing-attribute]
    for pr in game.player_roles.filter(user_id__in=actor_ids):
        if pr.has_acted and pr.night_action_data.get("wave") == wave:
            role_acting_as = pr.night_action_data.get("role_acting_as", pr.current_role)
            night_actions.append(
                NightAction(
                    player_id=pr.user_id,
                    role_acting_as=role_acting_as,
                    action_type=pr.night_action_data["action_type"],
                    targets=pr.night_action_data.get("targets", {}),
                )
            )
        else:
            # Player did not submit -- mark as skip
            role_acting_as = _determine_acting_role(pr, wave)
            night_actions.append(
                NightAction(
                    player_id=pr.user_id,
                    role_acting_as=role_acting_as,
                    action_type="skip",
                    targets={},
                )
            )

    # Resolve the wave through the engine
    new_state, results = resolve_wave(state, night_actions, wave)

    # Persist results atomically
    with transaction.atomic():
        persist_wave_results(game, new_state, results, wave)

    # Send player-scoped results via WebSocket
    send_wave_results(game, results, night_actions, wave)

    # Doppelganger wave-1 follow-up: after the initial peek resolves,
    # check if the copied role requires an immediate follow-up action
    # (Seer, Robber, Troublemaker, Drunk, Minion all follow up in wave 1).
    # If so, stay in wave 1 and prompt the follow-up before advancing.
    if wave == 1:
        just_resolved_initial = any(
            a.role_acting_as == "Doppelganger" for a in night_actions
        )
        if just_resolved_initial:
            followup = _get_doppelganger_wave1_followup(game)
            if followup is not None:
                doppel_id, copied_role = followup
                _send_doppelganger_followup_prompt(game, doppel_id, copied_role)
                return

    # Advance to next wave or end night
    next_wave = get_next_active_wave(game, wave)
    if next_wave is not None:
        with transaction.atomic():
            game.current_wave = next_wave
            game.save(update_fields=["current_wave", "updated_at"])
            # Reset has_acted for all players for the new wave
            # pyrefly: ignore [missing-attribute]
            game.player_roles.update(has_acted=False)
        send_wave_prompts(game, next_wave)
    else:
        transition_to_discussion(game)


def _get_doppelganger_wave1_followup(game: Game) -> tuple[int, str] | None:
    """Check if a Doppelganger copied a role with a wave-1 follow-up.

    Returns (doppelganger_user_id, copied_role) if a follow-up is needed,
    or None if there's nothing to follow up on.
    """
    state = build_game_state(game)
    for doppel_id, copied_role in state.doppelganger_copied_role.items():
        followup_wave = get_doppelganger_followup_wave(copied_role)
        if followup_wave == 1:
            return (doppel_id, copied_role)
    return None


def _send_doppelganger_followup_prompt(
    game: Game, doppel_id: int, copied_role: str
) -> None:
    """Send a follow-up action prompt to the Doppelganger and reset has_acted.

    After the Doppelganger's initial peek resolves and the copied role has a
    wave-1 follow-up, we stay in wave 1 and prompt the follow-up action.
    """
    from .engine.night import build_prompt
    from .engine.roles import get_role

    # Reset has_acted so the Doppelganger can submit the follow-up
    with transaction.atomic():
        PlayerRole.objects.filter(game=game, user_id=doppel_id).update(has_acted=False)

    # Build and send the follow-up prompt
    state = build_game_state(game)
    role_def = get_role(copied_role)
    prompt = build_prompt(state, doppel_id, copied_role, role_def.action_types)

    channel_layer = get_channel_layer()
    if channel_layer is not None:
        send = async_to_sync(channel_layer.group_send)
        send(
            f"game_{game.id}_player_{doppel_id}",
            {
                "type": "action.prompt",
                "wave": 1,
                "role_acting_as": prompt["role_acting_as"],
                "action_types": prompt["action_types"],
                "valid_targets": prompt["valid_targets"],
            },
        )

    # Schedule a timer for the follow-up action
    wave_seconds = get_timer_seconds(game, "night_wave_seconds", 30)
    if wave_seconds > 0:
        callback = timers.make_idempotent_callback(
            game.id, Phase.NIGHT, functools.partial(_auto_advance_wave, wave_number=1)
        )
        timers.schedule(f"{game.id}:wave:1", wave_seconds, callback)


def _determine_acting_role(pr: PlayerRole, wave: int) -> str:
    """
    Determine what role a player is acting as in a given wave.

    Handles Doppelganger follow-up: if the player is originally
    Doppelganger and copied a role whose follow-up wave matches,
    they act as that copied role.
    """
    if pr.original_role == "Doppelganger" and pr.night_action_data.get("copied_role"):
        copied = pr.night_action_data["copied_role"]
        followup = get_doppelganger_followup_wave(copied)
        if followup == wave:
            return copied

    return pr.current_role


def persist_wave_results(
    game: Game,
    new_state: GameState,
    results: list[ActionResult],
    wave: int,
) -> None:
    """Write engine results back to DB within an atomic transaction."""
    # Update center cards
    game.center_cards = new_state.center_cards

    # Append action log entries for this wave
    log = list(game.night_actions_log)
    for entry in new_state.action_log:
        if entry.wave == wave:
            log.append(
                {
                    "wave": entry.wave,
                    "player_id": entry.player_id,
                    "action_type": entry.action_type,
                    "targets": entry.targets,
                    "result": entry.result,
                    "timestamp_order": entry.timestamp_order,
                }
            )
    game.night_actions_log = log
    game.save(update_fields=["center_cards", "night_actions_log", "updated_at"])

    # Update player roles (swaps may have occurred)
    for pid, role in new_state.player_roles.items():
        PlayerRole.objects.filter(game=game, user_id=pid).update(current_role=role)

    # Store action results in each player's night_action_data
    for result in results:
        if result.revealed_info:
            pr = PlayerRole.objects.get(game=game, user_id=result.player_id)
            data = dict(pr.night_action_data)
            data[f"wave_{wave}_result"] = result.revealed_info
            # For Doppelganger, also store copied_role at top level
            if "copied_role" in result.revealed_info:
                data["copied_role"] = result.revealed_info["copied_role"]
            pr.night_action_data = data
            pr.save(update_fields=["night_action_data"])


def send_wave_results(
    game: Game,
    results: list[ActionResult],
    night_actions: list[NightAction],
    wave: int,
) -> None:
    """Send player-scoped results via WebSocket.

    Transforms the engine's raw revealed_info into the client-friendly
    format the frontend expects (display names, consistent keys, action_type).
    """
    channel_layer = get_channel_layer()
    if channel_layer is None:
        return

    send = async_to_sync(channel_layer.group_send)
    player_names = _get_player_names(game)
    action_map = {a.player_id: a for a in night_actions}

    # Send each player their own result only
    for result in results:
        action = action_map.get(result.player_id)
        if action is not None:
            client_info = _transform_revealed_info(action, result, player_names)
            action_type = _client_action_type(action)
        else:
            client_info = result.revealed_info
            action_type = "unknown"

        send(
            f"game_{game.id}_player_{result.player_id}",
            {
                "type": "action.result",
                "wave": wave,
                "action_type": action_type,
                "revealed_info": client_info,
            },
        )

    # Broadcast wave_complete to all players
    send(f"game_{game.id}", {"type": "wave.complete", "wave": wave})


def transition_to_discussion(game: Game) -> None:
    """Transition the game from night to discussion phase."""
    discussion_seconds = get_timer_seconds(game, "discussion_seconds", 300)

    with transaction.atomic():
        game.phase = Phase.DISCUSSION
        game.current_wave = 0
        if discussion_seconds > 0:
            game.phase_deadline = timezone.now() + timedelta(seconds=discussion_seconds)
        else:
            game.phase_deadline = None
        game.save(
            update_fields=["phase", "current_wave", "phase_deadline", "updated_at"]
        )

        # Reset has_acted for voting phase later
        # pyrefly: ignore [missing-attribute]
        game.player_roles.update(has_acted=False)

    if discussion_seconds > 0:
        callback = timers.make_idempotent_callback(
            game.id, Phase.DISCUSSION, _auto_transition_to_voting
        )
        timers.schedule(f"{game.id}:discussion", discussion_seconds, callback)

    # Broadcast phase change to all players
    channel_layer = get_channel_layer()
    if channel_layer is not None:
        async_to_sync(channel_layer.group_send)(
            f"game_{game.id}",
            {
                "type": "phase.change",
                "phase": "discussion",
                "deadline": game.phase_deadline.isoformat()
                if game.phase_deadline
                else None,
            },
        )


def check_and_maybe_advance(game: Game) -> None:
    """
    Check if all actors for the current wave have submitted.

    If everyone has acted, advance the wave. This is called after
    each action submission to auto-advance when ready.

    Uses select_for_update on the Game row to prevent double-fire
    when two players submit simultaneously.
    """
    with transaction.atomic():
        game = Game.objects.select_for_update().get(id=game.id)
        if game.phase != Phase.NIGHT:
            # Already advanced by another concurrent request
            return

        wave = game.current_wave
        actor_ids = get_wave_actors(game, wave)
        if not actor_ids:
            advance_wave(game)
            return

        # Check if any actors are still pending
        pending = PlayerRole.objects.filter(
            game=game, user_id__in=actor_ids, has_acted=False
        ).count()

        if pending == 0:
            timers.cancel(f"{game.id}:wave:{wave}")
            advance_wave(game)


def get_player_acting_role_for_wave(pr: PlayerRole, wave: int) -> str | None:
    """
    Determine what role this player acts as in the given wave, or None if
    they do not act.

    Uses the role registry to check wave assignments, plus Doppelganger
    follow-up logic.

    For wave 1: if the Doppelganger has already completed the initial peek
    (wave_1_result exists) and the copied role has a wave-1 follow-up,
    returns the copied role so the follow-up action can be validated.
    """
    # Check Doppelganger wave-1 follow-up BEFORE the base role check.
    # After the initial peek resolves, the Doppelganger needs to submit
    # a follow-up action as the copied role (e.g., Seer peek_center).
    # Without this, the base check returns "Doppelganger" which only
    # allows peek_player, rejecting other action types.
    if (
        wave == 1
        and pr.original_role == "Doppelganger"
        and pr.night_action_data.get("copied_role")
        and "wave_1_result" in pr.night_action_data
    ):
        copied = pr.night_action_data["copied_role"]
        followup = get_doppelganger_followup_wave(copied)
        if followup == 1:
            return copied

    # Check if their current role acts in this wave
    role_def = get_role(pr.current_role)
    if role_def.wave == wave:
        return pr.current_role

    # Check Doppelganger follow-up for waves 2+
    if pr.original_role == "Doppelganger" and pr.night_action_data.get("copied_role"):
        copied = pr.night_action_data["copied_role"]
        followup = get_doppelganger_followup_wave(copied)
        if followup == wave:
            return copied

    return None


def validate_night_action(
    game: Game,
    pr: PlayerRole,
    action_type: str,
    targets: dict[str, Any],
) -> list[str]:
    """
    Validate a submitted night action.

    Returns a list of error messages. Empty list means valid.
    """
    errors: list[str] = []
    wave = game.current_wave

    # Determine what role the player acts as this wave
    acting_role = get_player_acting_role_for_wave(pr, wave)
    if acting_role is None:
        errors.append("You do not act in the current wave.")
        return errors

    # Validate action_type is allowed for this role
    role_def = get_role(acting_role)
    allowed_types = [at.value for at in role_def.action_types]
    if action_type not in allowed_types:
        errors.append("Invalid action type for this wave.")
        return errors

    # Get all player IDs in this game (for target validation)
    # pyrefly: ignore [missing-attribute]
    game_player_ids = set(game.player_roles.values_list("user_id", flat=True))

    # Validate targets based on action_type
    if action_type == "peek_player":
        target_id = targets.get("player_id")
        if target_id is None:
            errors.append("targets.player_id is required for peek_player.")
        else:
            target_id = int(target_id)
            # pyrefly: ignore [missing-attribute]
            if target_id == pr.user_id:
                errors.append("Cannot target yourself.")
            elif target_id not in game_player_ids:
                errors.append(f"Invalid target player: {target_id}.")

    elif action_type == "peek_center":
        indices = targets.get("center_indices")
        if not isinstance(indices, list) or len(indices) != 2:
            errors.append("targets.center_indices must be a list of exactly 2 indices.")
        else:
            for idx in indices:
                idx_int = int(idx)
                if idx_int < 0 or idx_int >= len(game.center_cards):
                    errors.append(
                        f"Invalid center card index: {idx_int}. "
                        f"Must be 0-{len(game.center_cards) - 1}."
                    )
            if len(indices) == 2 and int(indices[0]) == int(indices[1]):
                errors.append("Must peek at 2 different center cards.")

    elif action_type == "swap_with_player":
        target_id = targets.get("player_id")
        if target_id is None:
            errors.append("targets.player_id is required for swap_with_player.")
        else:
            target_id = int(target_id)
            # pyrefly: ignore [missing-attribute]
            if target_id == pr.user_id:
                errors.append("Cannot target yourself.")
            elif target_id not in game_player_ids:
                errors.append(f"Invalid target player: {target_id}.")

    elif action_type == "swap_with_center":
        center_index = targets.get("center_index")
        if center_index is None:
            errors.append("targets.center_index is required for swap_with_center.")
        else:
            idx = int(center_index)
            if idx < 0 or idx >= len(game.center_cards):
                errors.append(
                    f"Invalid center card index: {idx}. "
                    f"Must be 0-{len(game.center_cards) - 1}."
                )

    elif action_type == "swap_others":
        player_ids = targets.get("player_ids")
        if not isinstance(player_ids, list) or len(player_ids) != 2:
            errors.append("targets.player_ids must be a list of exactly 2 player IDs.")
        else:
            for pid in player_ids:
                pid_int = int(pid)
                # pyrefly: ignore [missing-attribute]
                if pid_int == pr.user_id:
                    errors.append("Cannot target yourself in swap_others.")
                elif pid_int not in game_player_ids:
                    errors.append(f"Invalid target player: {pid_int}.")
            if len(player_ids) == 2 and int(player_ids[0]) == int(player_ids[1]):
                errors.append("Must target 2 different players.")

    elif action_type == "see_team":
        # No targets required. Lone werewolf may optionally peek center.
        if targets.get("center_index") is not None:
            idx = int(targets["center_index"])
            if idx < 0 or idx >= len(game.center_cards):
                errors.append(
                    f"Invalid center card index: {idx}. "
                    f"Must be 0-{len(game.center_cards) - 1}."
                )

    return errors


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

    voting_seconds = get_timer_seconds(game, "voting_seconds", 120)

    with transaction.atomic():
        game.phase = Phase.VOTING
        if voting_seconds > 0:
            game.phase_deadline = timezone.now() + timedelta(seconds=voting_seconds)
        else:
            game.phase_deadline = None
        game.save(update_fields=["phase", "phase_deadline", "updated_at"])

        # Reset has_acted for all players (tracks vote submission)
        # pyrefly: ignore [missing-attribute]
        game.player_roles.update(has_acted=False, vote_target=None)

    if voting_seconds > 0:
        callback = timers.make_idempotent_callback(
            game.id, Phase.VOTING, _auto_reveal_votes
        )
        timers.schedule(f"{game.id}:voting", voting_seconds, callback)

    # Broadcast phase change to all players
    channel_layer = get_channel_layer()
    if channel_layer is not None:
        async_to_sync(channel_layer.group_send)(
            f"game_{game.id}",
            {
                "type": "phase.change",
                "phase": "voting",
                "deadline": game.phase_deadline.isoformat()
                if game.phase_deadline
                else None,
            },
        )


def end_discussion(game: Game) -> None:
    """End discussion early (host action). Transitions to voting."""
    timers.cancel(f"{game.id}:discussion")
    game.phase_deadline = None
    transition_to_voting(game)


def submit_vote(game: Game, voter_id: int, target_player_id: int) -> list[str]:
    """
    Submit a vote. Returns list of errors (empty = success).

    Validates:
    - Game is in VOTING phase
    - Voter is in the game
    - Voter hasn't already voted (has_acted or vote_target is set)
    - Target is not the voter (no self-votes)
    - Target is a valid player in the game

    On success:
    - Sets PlayerRole.vote_target = target user
    - Sets PlayerRole.has_acted = True
    - Broadcasts vote_submitted (WHO voted, NOT their target) to game group
    - Checks if all players have voted -> if so, trigger reveal
    """
    errors: list[str] = []

    if game.phase != Phase.VOTING:
        errors.append("Game is not in the voting phase.")
        return errors

    # Lock the voter's PlayerRole row to prevent TOCTOU race on has_acted.
    with transaction.atomic():
        try:
            voter_pr = PlayerRole.objects.select_for_update().get(
                game=game, user_id=voter_id
            )
        except PlayerRole.DoesNotExist:
            errors.append("You are not a player in this game.")
            return errors

        if voter_pr.has_acted:
            errors.append("You have already voted.")
            return errors

        # No self-votes per spec
        if voter_id == target_player_id:
            errors.append("You cannot vote for yourself.")
            return errors

        # Validate target is a valid player in the game
        # pyrefly: ignore [missing-attribute]
        game_player_ids = set(game.player_roles.values_list("user_id", flat=True))
        if target_player_id not in game_player_ids:
            errors.append("Invalid vote target.")
            return errors

        # Store vote
        # pyrefly: ignore [missing-attribute]
        voter_pr.vote_target_id = target_player_id
        voter_pr.has_acted = True
        voter_pr.save(update_fields=["vote_target", "has_acted"])

    # Broadcast and auto-reveal OUTSIDE the transaction to avoid
    # holding the row lock during channel operations.
    channel_layer = get_channel_layer()
    if channel_layer is not None:
        async_to_sync(channel_layer.group_send)(
            f"game_{game.id}",
            {"type": "vote.submitted", "player_id": voter_id},
        )

    # Check if all players have voted -> auto-reveal.
    # Lock the Game row to prevent double-fire when two players
    # submit simultaneously and both see all votes in.
    with transaction.atomic():
        game = Game.objects.select_for_update().get(id=game.id)
        if game.phase != Phase.VOTING:
            # Already revealed by another concurrent request
            return errors
        # pyrefly: ignore [missing-attribute]
        total_players = game.player_roles.count()
        # pyrefly: ignore [missing-attribute]
        voted_count = game.player_roles.filter(has_acted=True).count()

        if voted_count >= total_players:
            timers.cancel(f"{game.id}:voting")
            reveal_votes(game)

    return errors


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
    # the all-voted path (double-cancel is safe).
    timers.cancel(f"{game.id}:voting")

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

    # Broadcast vote_reveal to all players
    channel_layer = get_channel_layer()
    if channel_layer is not None:
        async_to_sync(channel_layer.group_send)(
            f"game_{game.id}",
            {"type": "vote.reveal", "votes": votes_broadcast},
        )

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

    # Transition to results phase and store results atomically
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

    # Broadcast game results
    if channel_layer is not None:
        async_to_sync(channel_layer.group_send)(
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
