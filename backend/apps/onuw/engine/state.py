"""
Pure-Python game state data structures for ONUW night phase.

NO Django imports allowed in this module. This is pure game logic.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class ActionLogEntry:
    """Immutable record of a single action taken during the night phase."""

    wave: int
    player_id: int
    action_type: str
    targets: dict[str, Any]
    result: dict[str, Any]
    timestamp_order: int  # ordering within wave
    # The role the player acted AS for this entry (Doppelganger-aware). Captured
    # at action time — current_role may differ later once the player's own card
    # is swapped, so this must not be recomputed from current state afterward.
    # "" only for legacy/synthetic entries that predate this field.
    role_acting_as: str = ""
    # True when the server made this move for a player who ran out of time (the
    # Drunk must swap); recorded so a replay can tell it from a chosen move.
    made_by_server: bool = False

    def to_dict(self) -> dict[str, Any]:
        """The JSON stored in ``Game.night_actions_log`` (and read by the timeline)."""
        return {
            "wave": self.wave,
            "player_id": self.player_id,
            "action_type": self.action_type,
            "targets": self.targets,
            "result": self.result,
            "timestamp_order": self.timestamp_order,
            "role_acting_as": self.role_acting_as,
            # Only present when the server moved for a player who timed out.
            **({"made_by_server": True} if self.made_by_server else {}),
        }


@dataclass(frozen=True)
class NightAction:
    """A player's submitted action for a wave."""

    player_id: int
    role_acting_as: str  # the role this player is acting as (matters for Doppelganger)
    action_type: str
    targets: dict[str, Any]  # e.g. {"player_id": 3} or {"center_indices": [0, 1]}
    made_by_server: bool = False  # chosen by the server on timeout, not the player


@dataclass(frozen=True)
class ActionResult:
    """The outcome of executing a night action, scoped to the acting player."""

    player_id: int
    revealed_info: dict[str, Any]  # player-scoped data to send back
    state_mutations: list[str]  # human-readable descriptions of what changed


@dataclass(frozen=True)
class GameState:
    """
    Immutable snapshot of the game state during the night phase.

    All mutation methods return a new GameState instance.
    original_roles is never modified after initial construction.
    """

    player_roles: dict[int, str]  # player_id -> current role
    center_cards: list[str]  # 3 center cards
    original_roles: dict[int, str]  # immutable snapshot from start
    action_log: tuple[ActionLogEntry, ...] = ()
    doppelganger_copied_role: dict[int, str] = field(
        default_factory=dict
    )  # player_id -> copied role

    def with_swap(self, id_a: int, id_b: int) -> GameState:
        """Return new GameState with two players' roles swapped."""
        new_roles = dict(self.player_roles)
        new_roles[id_a], new_roles[id_b] = new_roles[id_b], new_roles[id_a]
        return GameState(
            player_roles=new_roles,
            center_cards=list(self.center_cards),
            original_roles=self.original_roles,
            action_log=self.action_log,
            doppelganger_copied_role=self.doppelganger_copied_role,
        )

    def with_center_swap(self, player_id: int, center_index: int) -> GameState:
        """Return new GameState with player's role swapped with a center card."""
        new_roles = dict(self.player_roles)
        new_center = list(self.center_cards)
        new_roles[player_id], new_center[center_index] = (
            new_center[center_index],
            new_roles[player_id],
        )
        return GameState(
            player_roles=new_roles,
            center_cards=new_center,
            original_roles=self.original_roles,
            action_log=self.action_log,
            doppelganger_copied_role=self.doppelganger_copied_role,
        )

    def with_log_entry(self, entry: ActionLogEntry) -> GameState:
        """Return new GameState with an appended log entry."""
        return GameState(
            player_roles=self.player_roles,
            center_cards=list(self.center_cards),
            original_roles=self.original_roles,
            action_log=(*self.action_log, entry),
            doppelganger_copied_role=self.doppelganger_copied_role,
        )

    def with_doppelganger_copy(self, player_id: int, copied_role: str) -> GameState:
        """Record which role the Doppelganger copied."""
        new_copied = dict(self.doppelganger_copied_role)
        new_copied[player_id] = copied_role
        return GameState(
            player_roles=self.player_roles,
            center_cards=list(self.center_cards),
            original_roles=self.original_roles,
            action_log=self.action_log,
            doppelganger_copied_role=new_copied,
        )
