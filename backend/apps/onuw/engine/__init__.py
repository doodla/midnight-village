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
from .night import build_prompt, get_required_actions, resolve_night, resolve_wave
from .phases import VALID_TRANSITIONS, validate_phase_transition
from .roles import ActionType, RoleDefinition, Team, get_role, get_roles_for_wave
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
    "apply_hunter",
    "build_prompt",
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
    "get_role",
    "get_roles_for_wave",
    "resolve_night",
    "resolve_wave",
    "validate_phase_transition",
]
