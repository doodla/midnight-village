"""
Pure-Python wave resolution engine for ONUW night phase.

Processes night actions wave by wave, handling canonical ordering within
waves and Doppelganger follow-up actions.

NO Django imports allowed in this module. This is pure game logic.
"""

from __future__ import annotations

from typing import Any

from .behaviors import execute_action, get_doppelganger_followup_wave
from .roles import ActionType, get_role, get_roles_for_wave
from .state import ActionLogEntry, ActionResult, GameState, NightAction

# Canonical ordering for wave 3 roles.
# Doppelganger-as-X acts BEFORE the real X (per official rules).
_WAVE_3_CANONICAL_ORDER: list[str] = [
    "Seer",
    "Robber",
    "Troublemaker",
    "Drunk",
]


def get_required_actions(
    state: GameState,
    wave: int,
    doppelganger_info: dict[int, str] | None = None,
) -> list[dict[str, Any]]:
    """
    Return list of action prompts for players who need to act in this wave.

    Each dict: {"player_id": int, "role_acting_as": str,
                "action_types": [...], "valid_targets": {...}}

    doppelganger_info maps doppelganger player_id -> copied_role for
    scheduling follow-up actions.
    """
    prompts: list[dict[str, Any]] = []
    wave_roles = get_roles_for_wave(wave)
    wave_role_names = {r.name for r in wave_roles}

    # Find players whose current role acts in this wave
    for player_id, role_name in state.player_roles.items():
        if role_name in wave_role_names:
            role_def = get_role(role_name)
            prompts.append(
                _build_prompt(state, player_id, role_name, role_def.action_types)
            )

    # Check for Doppelganger follow-up actions
    if doppelganger_info:
        for doppel_id, copied_role in doppelganger_info.items():
            followup_wave = get_doppelganger_followup_wave(copied_role)
            if followup_wave == wave:
                copied_def = get_role(copied_role)
                prompts.append(
                    _build_prompt(
                        state, doppel_id, copied_role, copied_def.action_types
                    )
                )

    return prompts


def _build_prompt(
    state: GameState,
    player_id: int,
    role_acting_as: str,
    action_types: tuple[ActionType, ...],
) -> dict[str, Any]:
    """Build an action prompt for a player."""
    valid_targets: dict[str, Any] = {}
    other_players = [pid for pid in state.player_roles if pid != player_id]

    for at in action_types:
        if at == ActionType.PEEK_PLAYER:
            valid_targets["player_ids"] = other_players
        elif at == ActionType.PEEK_CENTER:
            valid_targets["center_indices"] = list(range(len(state.center_cards)))
        elif at == ActionType.SWAP_WITH_PLAYER:
            valid_targets["player_ids"] = other_players
        elif at == ActionType.SWAP_WITH_CENTER:
            valid_targets["center_indices"] = list(range(len(state.center_cards)))
        elif at == ActionType.SWAP_OTHERS:
            valid_targets["player_ids"] = other_players
        elif at == ActionType.SEE_TEAM:
            pass  # no targets needed
        elif at == ActionType.NONE:
            pass  # no targets needed

    return {
        "player_id": player_id,
        "role_acting_as": role_acting_as,
        "action_types": [at.value for at in action_types],
        "valid_targets": valid_targets,
    }


def _sort_wave_3_actions_with_state(
    actions: list[NightAction], state: GameState
) -> list[NightAction]:
    """
    Sort wave 3 actions in canonical order with Doppelganger awareness.

    Canonical order: Seer -> Robber -> Troublemaker -> Drunk.
    Within the same role_acting_as, Doppelganger (player whose original
    role is Doppelganger) acts BEFORE the real role holder.
    """

    def sort_key(action: NightAction) -> tuple[int, int]:
        role = action.role_acting_as
        if role in _WAVE_3_CANONICAL_ORDER:
            role_order = _WAVE_3_CANONICAL_ORDER.index(role)
        else:
            role_order = len(_WAVE_3_CANONICAL_ORDER)

        # Doppelganger acts before the real role holder
        is_doppelganger = state.original_roles.get(action.player_id) == "Doppelganger"
        doppel_order = 0 if is_doppelganger else 1

        return (role_order, doppel_order)

    return sorted(actions, key=sort_key)


def resolve_wave(
    state: GameState, actions: list[NightAction], wave: int
) -> tuple[GameState, list[ActionResult]]:
    """
    Process all actions for a wave.

    Wave 3 actions resolve in canonical order: Seer -> Robber ->
    Troublemaker -> Drunk. Each action in the sequence sees the state
    AFTER previous actions in the wave.

    For other waves, order doesn't matter (wave 2 is all see_team,
    wave 1 is just Doppelganger, wave 4 is just Insomniac).

    Players who don't submit are skipped (logged as skip, no error).
    """
    results: list[ActionResult] = []
    current_state = state
    timestamp_order = 0

    # Sort wave 3 actions in canonical order
    if wave == 3:
        sorted_actions = _sort_wave_3_actions_with_state(actions, state)
    else:
        sorted_actions = list(actions)

    for action in sorted_actions:
        if action.action_type == "skip":
            # Log skipped action
            log_entry = ActionLogEntry(
                wave=wave,
                player_id=action.player_id,
                action_type="skip",
                targets={},
                result={},
                timestamp_order=timestamp_order,
            )
            current_state = current_state.with_log_entry(log_entry)
            results.append(
                ActionResult(
                    player_id=action.player_id,
                    revealed_info={},
                    state_mutations=["Action skipped."],
                )
            )
            timestamp_order += 1
            continue

        new_state, result = execute_action(current_state, action)

        # Log the action
        log_entry = ActionLogEntry(
            wave=wave,
            player_id=action.player_id,
            action_type=action.action_type,
            targets=dict(action.targets),
            result=dict(result.revealed_info),
            timestamp_order=timestamp_order,
        )
        current_state = new_state.with_log_entry(log_entry)
        results.append(result)
        timestamp_order += 1

    return current_state, results


def resolve_night(
    state: GameState,
    all_actions: dict[int, list[NightAction]],
) -> tuple[GameState, dict[int, list[ActionResult]]]:
    """
    Process the entire night phase (waves 1-4).

    all_actions: maps wave number to list of actions for that wave.

    Returns (final_state, results_by_wave).

    Handles Doppelganger follow-ups: after wave 1, if Doppelganger
    copied a role with a later wave action, adds the Doppelganger's
    follow-up action to the appropriate wave's action list.
    """
    current_state = state
    results_by_wave: dict[int, list[ActionResult]] = {}

    # Track Doppelganger follow-ups discovered during wave 1
    doppelganger_followups: dict[int, dict[str, Any]] = {}
    # Maps wave_number -> list of follow-up NightActions to inject

    for wave in (1, 2, 3, 4):
        wave_actions = list(all_actions.get(wave, []))

        if wave == 1:
            # For wave 1, only process Doppelganger peek actions initially.
            # Follow-up actions (role_acting_as != "Doppelganger") are
            # deferred to the second pass after we discover the copied role.
            doppelganger_peek_actions = [
                a for a in wave_actions if a.role_acting_as == "Doppelganger"
            ]
            current_state, wave_results = resolve_wave(
                current_state, doppelganger_peek_actions, wave
            )
            if wave_results:
                results_by_wave[wave] = wave_results

            # Discover follow-ups from the Doppelganger copy results
            for (
                doppel_id,
                copied_role,
            ) in current_state.doppelganger_copied_role.items():
                followup_wave = get_doppelganger_followup_wave(copied_role)
                if followup_wave is not None:
                    doppelganger_followups[doppel_id] = {
                        "copied_role": copied_role,
                        "followup_wave": followup_wave,
                    }

            # Process any wave 1 follow-ups IMMEDIATELY.
            # These are discovered after the initial Doppelganger peek,
            # so we need a second pass through wave 1 to resolve them.
            wave_1_followups: list[NightAction] = []
            for doppel_id, info in doppelganger_followups.items():
                if info["followup_wave"] == 1:
                    # Find the submitted follow-up action in all_actions[1]
                    followup_action = None
                    for a in wave_actions:
                        if (
                            a.player_id == doppel_id
                            and a.role_acting_as == info["copied_role"]
                        ):
                            followup_action = a
                            break
                    if followup_action is None:
                        # No follow-up submitted — skip it
                        followup_action = NightAction(
                            player_id=doppel_id,
                            role_acting_as=str(info["copied_role"]),
                            action_type="skip",
                            targets={},
                        )
                    wave_1_followups.append(followup_action)

            if wave_1_followups:
                current_state, followup_results = resolve_wave(
                    current_state, wave_1_followups, 1
                )
                if 1 in results_by_wave:
                    results_by_wave[1].extend(followup_results)
                else:
                    results_by_wave[1] = followup_results
        else:
            # Inject Doppelganger follow-up actions for waves 2+
            if doppelganger_followups:
                for doppel_id, info in doppelganger_followups.items():
                    followup_wave = info["followup_wave"]
                    if followup_wave == wave:
                        # Look for a submitted follow-up action from this
                        # Doppelganger in the all_actions for this wave
                        has_followup = any(
                            a.player_id == doppel_id
                            and a.role_acting_as == info["copied_role"]
                            for a in wave_actions
                        )
                        if not has_followup:
                            # No follow-up submitted — skip it
                            skip_action = NightAction(
                                player_id=doppel_id,
                                role_acting_as=str(info["copied_role"]),
                                action_type="skip",
                                targets={},
                            )
                            wave_actions.append(skip_action)

            current_state, wave_results = resolve_wave(
                current_state, wave_actions, wave
            )
            if wave_results:
                results_by_wave[wave] = wave_results

    return current_state, results_by_wave
