"""
ONUW game engine — pure Python, zero Django imports.

This package contains all game logic for One Night Ultimate Werewolf.
"""

from .behaviors import (
    execute_action,
    execute_doppelganger,
    execute_drunk,
    execute_insomniac,
    execute_mason,
    execute_minion,
    execute_robber,
    execute_seer,
    execute_troublemaker,
    execute_werewolf,
    get_doppelganger_followup_wave,
)
from .night import (
    action_order_group,
    build_prompt,
    build_role_prompt,
    get_required_actions,
    get_required_actions_for_window,
    resolve_night,
    resolve_wave,
    resolve_window,
)
from .phases import VALID_TRANSITIONS, validate_phase_transition
from .roles import (
    ActionType,
    RoleDefinition,
    Team,
    get_role,
    get_roles_for_wave,
    order_groups_for_window,
    window_for_order_group,
)
from .state import ActionLogEntry, ActionResult, GameState, NightAction
from .voting import apply_hunter, count_votes, determine_elimination
from .win_conditions import GameResult, evaluate_winner, get_effective_team

__all__ = [
    "VALID_TRANSITIONS",
    "ActionLogEntry",
    "ActionResult",
    "ActionType",
    "GameResult",
    "GameState",
    "NightAction",
    "RoleDefinition",
    "Team",
    "action_order_group",
    "apply_hunter",
    "build_prompt",
    "build_role_prompt",
    "count_votes",
    "determine_elimination",
    "evaluate_winner",
    "execute_action",
    "execute_doppelganger",
    "execute_drunk",
    "execute_insomniac",
    "execute_mason",
    "execute_minion",
    "execute_robber",
    "execute_seer",
    "execute_troublemaker",
    "execute_werewolf",
    "get_doppelganger_followup_wave",
    "get_effective_team",
    "get_required_actions",
    "get_required_actions_for_window",
    "get_role",
    "get_roles_for_wave",
    "order_groups_for_window",
    "resolve_night",
    "resolve_wave",
    "resolve_window",
    "validate_phase_transition",
    "window_for_order_group",
]
