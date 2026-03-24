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
from .night import get_required_actions, resolve_night, resolve_wave
from .roles import ActionType, RoleDefinition, Team, get_role, get_roles_for_wave
from .state import ActionLogEntry, ActionResult, GameState, NightAction

__all__ = [
    "ActionLogEntry",
    "ActionResult",
    "ActionType",
    "GameState",
    "NightAction",
    "RoleDefinition",
    "Team",
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
    "get_required_actions",
    "get_role",
    "get_roles_for_wave",
    "resolve_night",
    "resolve_wave",
]
