"""
Pure-Python night resolution engine for ONUW.

The night runs in two windows (see roles.NIGHT_WINDOW_ORDER_GROUPS):

* Window 1 - the Doppelganger alone: the look, then the immediate follow-up
  if the copied role is Seer, Robber, Troublemaker, Drunk or Minion.
* Window 2 - everyone else at once.  When the window closes the order groups
  are resolved in order, each step seeing the table after the previous one:
  team views (group 2), Seer -> Robber -> Troublemaker -> Drunk (group 3),
  then Insomniac (group 4).

"Wave" in this module means the *order group* (``RoleDefinition.wave``), the
position in the official wake order.  Action-log entries are tagged with it so
the night log stays in wake order.

Who acts is always decided from the DEALT cards (``state.original_roles``)
plus Doppelganger follow-ups, never from the cards held mid-night.

NO Django imports allowed in this module. This is pure game logic.
"""

from __future__ import annotations

from typing import Any

from .behaviors import (
    execute_action,
    get_doppelganger_followup_wave,
    is_effective_mason,
    is_effective_werewolf,
)
from .roles import (
    ActionType,
    get_role,
    get_roles_for_wave,
    order_groups_for_window,
    window_for_order_group,
)
from .state import ActionLogEntry, ActionResult, GameState, NightAction

# Canonical ordering for wave 3 roles.
# Doppelganger-as-X acts BEFORE the real X (per official rules).
_WAVE_3_CANONICAL_ORDER: list[str] = [
    "Seer",
    "Robber",
    "Troublemaker",
    "Drunk",
]


def _compute_see_team_targets(
    state: GameState, player_id: int, role_acting_as: str
) -> list[int]:
    """Compute teammate IDs visible to a see_team actor.

    - Werewolf sees other effective Werewolves (excludes self)
    - Mason sees other effective Masons (excludes self)
    - Minion sees all effective Werewolves (does not exclude self — Minion is never a Werewolf)
    """
    if role_acting_as == "Werewolf":
        return [
            pid
            for pid in state.player_roles
            if pid != player_id and is_effective_werewolf(pid, state)
        ]
    if role_acting_as == "Mason":
        return [
            pid
            for pid in state.player_roles
            if pid != player_id and is_effective_mason(pid, state)
        ]
    if role_acting_as == "Minion":
        return [pid for pid in state.player_roles if is_effective_werewolf(pid, state)]
    return []


def get_required_actions(
    state: GameState,
    wave: int,
    doppelganger_info: dict[int, str] | None = None,
) -> list[dict[str, Any]]:
    """
    Return list of action prompts for players who need to act in this order group.

    Each dict: {"player_id": int, "role_acting_as": str,
                "action_types": [...], "valid_targets": {...}}

    doppelganger_info maps doppelganger player_id -> copied_role for
    scheduling follow-up actions.

    Who acts is decided from the DEALT cards (state.original_roles) in every
    group: in the physical game the narrator calls "Seer, wake up" and the
    player who was dealt the Seer card opens their eyes, whatever has been
    swapped since.  Using the cards held now would prompt whoever happens to
    hold the Seer card instead, and leak swap information.
    """
    prompts: list[dict[str, Any]] = []
    wave_roles = get_roles_for_wave(wave)
    wave_role_names = {r.name for r in wave_roles}

    for player_id, role_name in state.original_roles.items():
        if role_name in wave_role_names:
            prompts.append(build_role_prompt(state, player_id, role_name))

    # Check for Doppelganger follow-up actions
    if doppelganger_info:
        for doppel_id, copied_role in doppelganger_info.items():
            followup_wave = get_doppelganger_followup_wave(copied_role)
            if followup_wave == wave:
                prompts.append(build_role_prompt(state, doppel_id, copied_role))

    return prompts


def get_required_actions_for_window(
    state: GameState,
    window: int,
    doppelganger_info: dict[int, str] | None = None,
) -> list[dict[str, Any]]:
    """
    Prompts for everyone who acts in a night window, in wake order.

    Window 1 is the Doppelganger's look.  Window 2 prompts every remaining
    actor at once: dealt Werewolves, Minion, Masons, Seer, Robber,
    Troublemaker, Drunk, Insomniac, and a Doppelganger who copied Werewolf,
    Mason or Insomniac (supplied through doppelganger_info).
    """
    prompts: list[dict[str, Any]] = []
    for group in order_groups_for_window(window):
        prompts.extend(get_required_actions(state, group, doppelganger_info))
    return prompts


def build_prompt(
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
            valid_targets["see_team"] = _compute_see_team_targets(
                state, player_id, role_acting_as
            )
        elif at in (ActionType.NONE, ActionType.SKIP):
            pass  # no targets needed

    return {
        "player_id": player_id,
        "role_acting_as": role_acting_as,
        "action_types": [at.value for at in action_types],
        "valid_targets": valid_targets,
    }


def build_role_prompt(
    state: GameState, player_id: int, role_acting_as: str
) -> dict[str, Any]:
    """Build the prompt for a player acting as ``role_acting_as``.

    Uses the role's prompt action types, which include the explicit ``skip``
    choice for roles whose action is optional (Seer, Robber, Troublemaker).
    """
    role_def = get_role(role_acting_as)
    return build_prompt(state, player_id, role_acting_as, role_def.prompt_action_types)


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
                role_acting_as=action.role_acting_as,
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
            role_acting_as=action.role_acting_as,
        )
        current_state = new_state.with_log_entry(log_entry)
        results.append(result)
        timestamp_order += 1

    return current_state, results


def action_order_group(action: NightAction) -> int:
    """Order group (wake-order position) of the role an action is performed as.

    A Doppelganger follow-up belongs to the group of the copied role (e.g. a
    Doppelganger-as-Werewolf sees her team with the Werewolves in group 2).
    """
    group = get_role(action.role_acting_as).wave
    if group is None:
        raise ValueError(f"Role {action.role_acting_as!r} has no night action.")
    return group


def _skip_for(player_id: int, role_acting_as: str) -> NightAction:
    return NightAction(
        player_id=player_id,
        role_acting_as=role_acting_as,
        action_type="skip",
        targets={},
    )


def _resolve_window_by_group(
    state: GameState, actions: list[NightAction], window: int
) -> tuple[GameState, dict[int, list[ActionResult]]]:
    """Resolve a window, returning results keyed by order group."""
    if window == 1:
        return _resolve_doppelganger_window(state, actions)

    groups = order_groups_for_window(window)
    for action in actions:
        if action_order_group(action) not in groups:
            raise ValueError(f"Action does not belong to night window {window}.")

    current_state = state
    results_by_group: dict[int, list[ActionResult]] = {}
    for group in groups:
        group_actions = [a for a in actions if action_order_group(a) == group]
        # A Doppelganger who copied a role in this group and submitted nothing
        # is skipped (no error), exactly like any other missing action.
        for doppel_id, copied in state.doppelganger_copied_role.items():
            if get_doppelganger_followup_wave(copied) == group and not any(
                a.player_id == doppel_id and a.role_acting_as == copied
                for a in group_actions
            ):
                group_actions.append(_skip_for(doppel_id, copied))
        current_state, group_results = resolve_wave(current_state, group_actions, group)
        if group_results:
            results_by_group[group] = group_results
    return current_state, results_by_group


def _resolve_doppelganger_window(
    state: GameState, actions: list[NightAction]
) -> tuple[GameState, dict[int, list[ActionResult]]]:
    """Window 1: the look, then the immediate follow-up if there is one.

    ``actions`` may hold the look (role_acting_as == "Doppelganger"), the
    follow-up (role_acting_as == the copied role), or both.  The look always
    resolves first.  A follow-up the copied role calls for (Seer, Robber,
    Troublemaker, Drunk, Minion) that was not submitted is skipped.  The copy
    may already be recorded in ``state`` when the look was resolved earlier.
    """
    results: list[ActionResult] = []
    looks = [a for a in actions if a.role_acting_as == "Doppelganger"]
    followups = [a for a in actions if a.role_acting_as != "Doppelganger"]

    current_state, look_results = resolve_wave(state, looks, 1)
    results.extend(look_results)

    pending: list[NightAction] = []
    for doppel_id, copied in current_state.doppelganger_copied_role.items():
        if get_doppelganger_followup_wave(copied) != 1:
            continue
        submitted = next(
            (
                a
                for a in followups
                if a.player_id == doppel_id and a.role_acting_as == copied
            ),
            None,
        )
        pending.append(submitted or _skip_for(doppel_id, copied))

    if pending:
        current_state, followup_results = resolve_wave(current_state, pending, 1)
        results.extend(followup_results)

    return current_state, ({1: results} if results else {})


def resolve_window(
    state: GameState, actions: list[NightAction], window: int
) -> tuple[GameState, list[ActionResult]]:
    """
    Close a night window: resolve every action in it and return the new table.

    Window 1: the Doppelganger's look, then her immediate follow-up.
    Window 2: team views (group 2), then Seer -> Robber -> Troublemaker ->
    Drunk (group 3, Doppelganger before the real role), then Insomniac
    (group 4).  Each step sees the table after the previous one, so the
    Insomniac sees every swap made in the same window and the Seer sees the
    table before the Robber moves.

    Results are returned in resolution order.  Log entries are tagged with
    their order group.  Callers deliver results to players only after this
    returns, i.e. when the window has closed.
    """
    new_state, by_group = _resolve_window_by_group(state, actions, window)
    flat: list[ActionResult] = []
    for group in sorted(by_group):
        flat.extend(by_group[group])
    return new_state, flat


def resolve_night(
    state: GameState,
    all_actions: dict[int, list[NightAction]],
) -> tuple[GameState, dict[int, list[ActionResult]]]:
    """
    Process the entire night (window 1, then window 2).

    all_actions: maps order group (1-4) to the actions for that group.
    Window 1 takes group 1 (the look and any immediate follow-up); window 2
    takes groups 2-4.

    Returns (final_state, results_by_order_group).
    """
    window_actions: dict[int, list[NightAction]] = {1: [], 2: []}
    for group, group_actions in all_actions.items():
        window_actions[window_for_order_group(group)].extend(group_actions)

    current_state = state
    results_by_group: dict[int, list[ActionResult]] = {}
    for window in (1, 2):
        current_state, by_group = _resolve_window_by_group(
            current_state, window_actions[window], window
        )
        for group, group_results in by_group.items():
            results_by_group.setdefault(group, []).extend(group_results)

    return current_state, results_by_group
