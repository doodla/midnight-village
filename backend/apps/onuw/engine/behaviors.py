"""
Pure-Python role behavior functions for ONUW night phase.

Each behavior is a function:
    execute_<role>(state, action) -> (new_state, result)

NO Django imports allowed in this module. This is pure game logic.
"""

from __future__ import annotations

from collections.abc import Callable

from .roles import get_role
from .state import ActionResult, GameState, NightAction

# Type alias for role behavior functions
RoleBehavior = Callable[[GameState, NightAction], tuple[GameState, ActionResult]]

# ── Wave 2: See-team roles ──────────────────────────────────────────────────


def _is_effective_werewolf(pid: int, state: GameState) -> bool:
    """Check if a player is effectively a Werewolf (including Doppelganger-as-Werewolf)."""
    role = state.player_roles.get(pid, "")
    if role == "Werewolf":
        return True
    return (
        role == "Doppelganger" and state.doppelganger_copied_role.get(pid) == "Werewolf"
    )


def _is_effective_mason(pid: int, state: GameState) -> bool:
    """Check if a player is effectively a Mason (including Doppelganger-as-Mason)."""
    role = state.player_roles.get(pid, "")
    if role == "Mason":
        return True
    return role == "Doppelganger" and state.doppelganger_copied_role.get(pid) == "Mason"


def execute_werewolf(
    state: GameState, action: NightAction
) -> tuple[GameState, ActionResult]:
    """
    Werewolf sees other werewolves (including Doppelganger-as-Werewolf).

    Lone werewolf may optionally peek at one center card.
    """
    player_id = action.player_id
    all_werewolves = [
        pid
        for pid in state.player_roles
        if pid != player_id and _is_effective_werewolf(pid, state)
    ]

    if len(all_werewolves) == 0:
        # Lone werewolf — may peek one center card
        targets = action.targets
        if targets and "center_index" in targets:
            idx = int(targets["center_index"])
            if idx < 0 or idx >= len(state.center_cards):
                raise ValueError(
                    f"Invalid center card index: {idx}. Must be 0-{len(state.center_cards) - 1}."
                )
            revealed_info: dict[str, object] = {
                "werewolves": [],
                "center_card": {
                    "index": idx,
                    "role": state.center_cards[idx],
                },
            }
        else:
            revealed_info = {"werewolves": []}
        return state, ActionResult(
            player_id=player_id,
            revealed_info=revealed_info,
            state_mutations=[],
        )

    # Multiple werewolves see each other
    return state, ActionResult(
        player_id=player_id,
        revealed_info={"werewolves": all_werewolves},
        state_mutations=[],
    )


def execute_minion(
    state: GameState, action: NightAction
) -> tuple[GameState, ActionResult]:
    """Minion sees all werewolf player_ids (including Doppelganger-as-Werewolf)."""
    player_id = action.player_id
    werewolves = [
        pid for pid in state.player_roles if _is_effective_werewolf(pid, state)
    ]

    return state, ActionResult(
        player_id=player_id,
        revealed_info={"werewolves": werewolves},
        state_mutations=[],
    )


def execute_mason(
    state: GameState, action: NightAction
) -> tuple[GameState, ActionResult]:
    """Mason sees other mason player_ids (including Doppelganger-as-Mason)."""
    player_id = action.player_id
    other_masons = [
        pid
        for pid in state.player_roles
        if pid != player_id and _is_effective_mason(pid, state)
    ]

    return state, ActionResult(
        player_id=player_id,
        revealed_info={"masons": other_masons},
        state_mutations=[],
    )


# ── Wave 3: Action roles ────────────────────────────────────────────────────


def _validate_player_target(state: GameState, player_id: int, target_id: int) -> None:
    """Validate that target_id is a valid player and not the acting player."""
    if target_id == player_id:
        raise ValueError("Cannot target yourself.")
    if target_id not in state.player_roles:
        raise ValueError(f"Invalid target player: {target_id}. Not in game.")


def execute_seer(
    state: GameState, action: NightAction
) -> tuple[GameState, ActionResult]:
    """
    Seer peeks at one player's role OR two center cards.

    action_type determines which mode:
    - "peek_player": targets = {"player_id": X}
    - "peek_center": targets = {"center_indices": [i, j]}
    """
    player_id = action.player_id

    if action.action_type == "peek_player":
        target_id = int(action.targets["player_id"])
        _validate_player_target(state, player_id, target_id)
        return state, ActionResult(
            player_id=player_id,
            revealed_info={"peeked_role": state.player_roles[target_id]},
            state_mutations=[],
        )

    if action.action_type == "peek_center":
        indices = list(action.targets["center_indices"])
        if len(indices) != 2:
            raise ValueError("Seer must peek at exactly 2 center cards.")
        if indices[0] == indices[1]:
            raise ValueError("Seer must peek at 2 different center cards.")
        for idx in indices:
            idx_int = int(idx)
            if idx_int < 0 or idx_int >= len(state.center_cards):
                raise ValueError(
                    f"Invalid center card index: {idx_int}. Must be 0-{len(state.center_cards) - 1}."
                )
        peeked = [
            {"index": int(idx), "role": state.center_cards[int(idx)]} for idx in indices
        ]
        return state, ActionResult(
            player_id=player_id,
            revealed_info={"peeked_center": peeked},
            state_mutations=[],
        )

    raise ValueError(
        f"Invalid action type for Seer: {action.action_type!r}. "
        "Must be 'peek_player' or 'peek_center'."
    )


def execute_robber(
    state: GameState, action: NightAction
) -> tuple[GameState, ActionResult]:
    """Robber swaps with a target player and learns their new role."""
    player_id = action.player_id
    target_id = int(action.targets["player_id"])
    _validate_player_target(state, player_id, target_id)

    # The role the Robber takes from the target
    new_role = state.player_roles[target_id]

    new_state = state.with_swap(player_id, target_id)

    return new_state, ActionResult(
        player_id=player_id,
        revealed_info={"new_role": new_role},
        state_mutations=[f"Player {player_id} swapped roles with player {target_id}."],
    )


def execute_troublemaker(
    state: GameState, action: NightAction
) -> tuple[GameState, ActionResult]:
    """Troublemaker swaps two other players' roles. Learns nothing."""
    player_id = action.player_id
    target_ids = list(action.targets["player_ids"])

    if len(target_ids) != 2:
        raise ValueError("Troublemaker must target exactly 2 players.")

    target_a = int(target_ids[0])
    target_b = int(target_ids[1])

    if target_a == target_b:
        raise ValueError("Troublemaker must target 2 different players.")
    if target_a == player_id or target_b == player_id:
        raise ValueError("Troublemaker cannot target themselves.")
    if target_a not in state.player_roles:
        raise ValueError(f"Invalid target player: {target_a}. Not in game.")
    if target_b not in state.player_roles:
        raise ValueError(f"Invalid target player: {target_b}. Not in game.")

    new_state = state.with_swap(target_a, target_b)

    return new_state, ActionResult(
        player_id=player_id,
        revealed_info={},
        state_mutations=[
            f"Player {target_a} and player {target_b} had their roles swapped."
        ],
    )


def execute_drunk(
    state: GameState, action: NightAction
) -> tuple[GameState, ActionResult]:
    """Drunk swaps own role with a center card. Learns nothing."""
    player_id = action.player_id
    center_index = int(action.targets["center_index"])

    if center_index < 0 or center_index >= len(state.center_cards):
        raise ValueError(
            f"Invalid center card index: {center_index}. Must be 0-{len(state.center_cards) - 1}."
        )

    new_state = state.with_center_swap(player_id, center_index)

    return new_state, ActionResult(
        player_id=player_id,
        revealed_info={},
        state_mutations=[
            f"Player {player_id} swapped their role with center card {center_index}."
        ],
    )


# ── Wave 1 + Wave 4: Special roles ──────────────────────────────────────────


def execute_doppelganger(
    state: GameState, action: NightAction
) -> tuple[GameState, ActionResult]:
    """
    Doppelganger peeks at a player's role and copies it.

    The Doppelganger's current_role stays "Doppelganger" — the copy is
    recorded in GameState.doppelganger_copied_role for follow-up scheduling.
    """
    player_id = action.player_id
    target_id = int(action.targets["player_id"])
    _validate_player_target(state, player_id, target_id)

    copied_role = state.player_roles[target_id]
    new_state = state.with_doppelganger_copy(player_id, copied_role)

    return new_state, ActionResult(
        player_id=player_id,
        revealed_info={"copied_role": copied_role},
        state_mutations=[f"Player {player_id} copied the role of player {target_id}."],
    )


def execute_insomniac(
    state: GameState, action: NightAction
) -> tuple[GameState, ActionResult]:
    """Insomniac peeks at their own current role (may have changed due to swaps)."""
    player_id = action.player_id

    return state, ActionResult(
        player_id=player_id,
        revealed_info={"current_role": state.player_roles[player_id]},
        state_mutations=[],
    )


# ── Doppelganger follow-up helper ───────────────────────────────────────────

# Roles that have follow-up actions and which wave they belong to
_DOPPELGANGER_FOLLOWUP_WAVES: dict[str, int] = {
    "Werewolf": 2,
    "Minion": 2,
    "Mason": 2,
    "Seer": 1,
    "Robber": 1,
    "Troublemaker": 1,
    "Drunk": 1,
    "Insomniac": 4,
}


def get_doppelganger_followup_wave(copied_role: str) -> int | None:
    """
    Return the wave in which Doppelganger acts as the copied role, or None.

    Villager, Tanner, Hunter, Doppelganger -> None (no follow-up action).
    """
    return _DOPPELGANGER_FOLLOWUP_WAVES.get(copied_role)


# ── Dispatch ─────────────────────────────────────────────────────────────────

_ROLE_EXECUTORS: dict[str, RoleBehavior] = {
    "Werewolf": execute_werewolf,
    "Minion": execute_minion,
    "Mason": execute_mason,
    "Seer": execute_seer,
    "Robber": execute_robber,
    "Troublemaker": execute_troublemaker,
    "Drunk": execute_drunk,
    "Doppelganger": execute_doppelganger,
    "Insomniac": execute_insomniac,
}


def execute_action(
    state: GameState, action: NightAction
) -> tuple[GameState, ActionResult]:
    """Dispatch to the correct behavior function based on role_acting_as."""
    role_name = action.role_acting_as

    # Validate the role exists
    get_role(role_name)

    executor = _ROLE_EXECUTORS.get(role_name)
    if executor is None:
        raise ValueError(
            f"Role {role_name!r} has no night action behavior. "
            "Roles without night actions should not submit actions."
        )

    return executor(state, action)
