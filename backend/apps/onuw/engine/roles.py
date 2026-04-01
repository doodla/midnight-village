"""
Pure-Python role registry for One Night Ultimate Werewolf.

NO Django imports allowed in this module. This is pure game logic.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum


class Team(StrEnum):
    VILLAGE = "village"
    WEREWOLF = "werewolf"
    NEUTRAL = "neutral"


class ActionType(StrEnum):
    PEEK_PLAYER = "peek_player"
    PEEK_CENTER = "peek_center"
    SWAP_WITH_PLAYER = "swap_with_player"
    SWAP_WITH_CENTER = "swap_with_center"
    SWAP_OTHERS = "swap_others"
    SEE_TEAM = "see_team"
    NONE = "none"


@dataclass(frozen=True)
class RoleDefinition:
    name: str
    team: Team
    wave: int | None  # None = no night action
    action_types: tuple[
        ActionType, ...
    ]  # allowed action types (some roles have choices)
    min_count: int = 0
    max_count: int = 3


# ── Role Definitions ──────────────────────────────────────────────────────────

ROLE_REGISTRY: dict[str, RoleDefinition] = {}


def _register(role: RoleDefinition) -> RoleDefinition:
    """Register a role definition and return it."""
    ROLE_REGISTRY[role.name] = role
    return role


WEREWOLF = _register(
    RoleDefinition(
        name="Werewolf",
        team=Team.WEREWOLF,
        wave=2,
        action_types=(ActionType.SEE_TEAM,),
        max_count=2,
    )
)

VILLAGER = _register(
    RoleDefinition(
        name="Villager",
        team=Team.VILLAGE,
        wave=None,
        action_types=(ActionType.NONE,),
        max_count=3,
    )
)

SEER = _register(
    RoleDefinition(
        name="Seer",
        team=Team.VILLAGE,
        wave=3,
        action_types=(ActionType.PEEK_PLAYER, ActionType.PEEK_CENTER),
        max_count=1,
    )
)

ROBBER = _register(
    RoleDefinition(
        name="Robber",
        team=Team.VILLAGE,
        wave=3,
        action_types=(ActionType.SWAP_WITH_PLAYER,),
        max_count=1,
    )
)

TROUBLEMAKER = _register(
    RoleDefinition(
        name="Troublemaker",
        team=Team.VILLAGE,
        wave=3,
        action_types=(ActionType.SWAP_OTHERS,),
        max_count=1,
    )
)

DRUNK = _register(
    RoleDefinition(
        name="Drunk",
        team=Team.VILLAGE,
        wave=3,
        action_types=(ActionType.SWAP_WITH_CENTER,),
        max_count=1,
    )
)

INSOMNIAC = _register(
    RoleDefinition(
        name="Insomniac",
        team=Team.VILLAGE,
        wave=4,
        action_types=(ActionType.NONE,),
        max_count=1,
    )
)

MINION = _register(
    RoleDefinition(
        name="Minion",
        team=Team.WEREWOLF,
        wave=2,
        action_types=(ActionType.SEE_TEAM,),
        max_count=1,
    )
)

TANNER = _register(
    RoleDefinition(
        name="Tanner",
        team=Team.NEUTRAL,
        wave=None,
        action_types=(ActionType.NONE,),
        max_count=1,
    )
)

HUNTER = _register(
    RoleDefinition(
        name="Hunter",
        team=Team.VILLAGE,
        wave=None,
        action_types=(ActionType.NONE,),
        max_count=1,
    )
)

MASON = _register(
    RoleDefinition(
        name="Mason",
        team=Team.VILLAGE,
        wave=2,
        action_types=(ActionType.SEE_TEAM,),
        max_count=2,
    )
)

DOPPELGANGER = _register(
    RoleDefinition(
        name="Doppelganger",
        team=Team.VILLAGE,
        wave=1,
        action_types=(ActionType.PEEK_PLAYER,),
        max_count=1,
    )
)


def get_role(name: str) -> RoleDefinition:
    """Get a role definition by name. Raises ValueError if not found."""
    if name not in ROLE_REGISTRY:
        raise ValueError(f"Unknown role: {name!r}")
    return ROLE_REGISTRY[name]


def get_roles_for_wave(wave: int) -> list[RoleDefinition]:
    """Get all role definitions that act during a given wave."""
    return [role for role in ROLE_REGISTRY.values() if role.wave == wave]
