"""The night results a phone reads in ``GET /me/`` (``night_results``).

The service layer transforms the engine's raw revealed_info into the
client-friendly format the app reads. These tests verify that each role's
result is transformed with display names, canonical role names, consistent key
names and the right action_type.
"""

import pytest

from apps.onuw.engine.state import ActionResult, NightAction
from apps.onuw.services import _client_action_type, _transform_revealed_info

pytestmark = pytest.mark.unit

# Player name lookup used across all tests.
PLAYER_NAMES: dict[int, str] = {
    1: "Alice",
    2: "Bob",
    3: "Charlie",
    4: "Diana",
    5: "Eve",
}


# ── _client_action_type ─────────────────────────────────────────────────────


class TestClientActionType:
    """The frontend uses action_type to route to the correct result view."""

    def test_insomniac_overrides_to_insomniac(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Insomniac",
            action_type="none",
            targets={},
        )
        assert _client_action_type(action) == "insomniac"

    def test_doppelganger_as_insomniac_overrides(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Insomniac",
            action_type="none",
            targets={},
        )
        assert _client_action_type(action) == "insomniac"

    def test_seer_peek_player_passes_through(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Seer",
            action_type="peek_player",
            targets={"player_id": 2},
        )
        assert _client_action_type(action) == "peek_player"

    def test_see_team_passes_through(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Werewolf",
            action_type="see_team",
            targets={},
        )
        assert _client_action_type(action) == "see_team"

    def test_skip_passes_through(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Seer",
            action_type="skip",
            targets={},
        )
        assert _client_action_type(action) == "skip"


# ── Seer: peek_player ───────────────────────────────────────────────────────


class TestTransformSeerPeekPlayer:
    """Seer peeks at a player's card."""

    def test_includes_target_name_and_canonical_role(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Seer",
            action_type="peek_player",
            targets={"player_id": 2},
        )
        result = ActionResult(
            player_id=1,
            revealed_info={"peeked_role": "Werewolf"},
            state_mutations=[],
        )
        out = _transform_revealed_info(action, result, PLAYER_NAMES)
        assert out == {"target_name": "Bob", "role": "Werewolf"}

    def test_unknown_target_uses_fallback_name(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Seer",
            action_type="peek_player",
            targets={"player_id": 99},
        )
        result = ActionResult(
            player_id=1,
            revealed_info={"peeked_role": "Villager"},
            state_mutations=[],
        )
        out = _transform_revealed_info(action, result, PLAYER_NAMES)
        assert out["target_name"] == "Unknown"


# ── Seer: peek_center ───────────────────────────────────────────────────────


class TestTransformSeerPeekCenter:
    """Seer peeks at two center cards."""

    def test_extracts_roles_and_indices_from_peeked_center(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Seer",
            action_type="peek_center",
            targets={"center_indices": [0, 2]},
        )
        result = ActionResult(
            player_id=1,
            revealed_info={
                "peeked_center": [
                    {"index": 0, "role": "Werewolf"},
                    {"index": 2, "role": "Tanner"},
                ]
            },
            state_mutations=[],
        )
        out = _transform_revealed_info(action, result, PLAYER_NAMES)
        assert out == {"roles": ["Werewolf", "Tanner"], "center_indices": [0, 2]}


# ── Robber: swap_with_player ─────────────────────────────────────────────────


class TestTransformRobber:
    """Robber swaps with a target and learns the target's role."""

    def test_includes_target_name_and_canonical_new_role(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Robber",
            action_type="swap_with_player",
            targets={"player_id": 3},
        )
        result = ActionResult(
            player_id=1,
            revealed_info={"new_role": "Seer"},
            state_mutations=["Player 1 swapped roles with player 3."],
        )
        out = _transform_revealed_info(action, result, PLAYER_NAMES)
        assert out == {"target_name": "Charlie", "new_role": "Seer"}


# ── Troublemaker: swap_others ────────────────────────────────────────────────


class TestTransformTroublemaker:
    """Troublemaker swaps two other players. Learns nothing from engine."""

    def test_resolves_player_names_from_targets(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Troublemaker",
            action_type="swap_others",
            targets={"player_ids": [2, 4]},
        )
        result = ActionResult(
            player_id=1,
            revealed_info={},
            state_mutations=["Player 2 and player 4 had their roles swapped."],
        )
        out = _transform_revealed_info(action, result, PLAYER_NAMES)
        assert out == {"player1_name": "Bob", "player2_name": "Diana"}


# ── Drunk: swap_with_center ──────────────────────────────────────────────────


class TestTransformDrunk:
    """Drunk swaps with a center card. Learns nothing from engine."""

    def test_includes_card_index_from_targets(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Drunk",
            action_type="swap_with_center",
            targets={"center_index": 1},
        )
        result = ActionResult(
            player_id=1,
            revealed_info={},
            state_mutations=["Player 1 swapped their role with center card 1."],
        )
        out = _transform_revealed_info(action, result, PLAYER_NAMES)
        assert out == {"card_index": 1}


# ── Werewolf: see_team ───────────────────────────────────────────────────────


class TestTransformWerewolfSeeTeam:
    """Werewolf sees other werewolves."""

    def test_resolves_teammate_ids_to_names(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Werewolf",
            action_type="see_team",
            targets={},
        )
        result = ActionResult(
            player_id=1,
            revealed_info={"werewolves": [3, 5]},
            state_mutations=[],
        )
        out = _transform_revealed_info(action, result, PLAYER_NAMES)
        assert out == {
            "teammate_names": ["Charlie", "Eve"],
            "role_acting_as": "Werewolf",
        }

    def test_lone_werewolf_empty_teammates(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Werewolf",
            action_type="see_team",
            targets={},
        )
        result = ActionResult(
            player_id=1,
            revealed_info={"werewolves": []},
            state_mutations=[],
        )
        out = _transform_revealed_info(action, result, PLAYER_NAMES)
        assert out["teammate_names"] == []
        assert out["role_acting_as"] == "Werewolf"

    def test_lone_werewolf_center_peek(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Werewolf",
            action_type="see_team",
            targets={"center_index": 0},
        )
        result = ActionResult(
            player_id=1,
            revealed_info={
                "werewolves": [],
                "center_card": {"index": 0, "role": "Tanner"},
            },
            state_mutations=[],
        )
        out = _transform_revealed_info(action, result, PLAYER_NAMES)
        assert out["teammate_names"] == []
        assert out["center_card"] == {"index": 0, "role": "Tanner"}


# ── Mason: see_team ──────────────────────────────────────────────────────────


class TestTransformMasonSeeTeam:
    """Mason sees other masons."""

    def test_resolves_mason_ids_to_names(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Mason",
            action_type="see_team",
            targets={},
        )
        result = ActionResult(
            player_id=1,
            revealed_info={"masons": [4]},
            state_mutations=[],
        )
        out = _transform_revealed_info(action, result, PLAYER_NAMES)
        assert out == {
            "teammate_names": ["Diana"],
            "role_acting_as": "Mason",
        }

    def test_lone_mason_empty_teammates(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Mason",
            action_type="see_team",
            targets={},
        )
        result = ActionResult(
            player_id=1,
            revealed_info={"masons": []},
            state_mutations=[],
        )
        out = _transform_revealed_info(action, result, PLAYER_NAMES)
        assert out["teammate_names"] == []


# ── Minion: see_team ─────────────────────────────────────────────────────────


class TestTransformMinionSeeTeam:
    """Minion sees werewolves (uses 'werewolves' key like Werewolf)."""

    def test_resolves_werewolf_ids_to_names_with_minion_label(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Minion",
            action_type="see_team",
            targets={},
        )
        result = ActionResult(
            player_id=1,
            revealed_info={"werewolves": [2, 3]},
            state_mutations=[],
        )
        out = _transform_revealed_info(action, result, PLAYER_NAMES)
        assert out["teammate_names"] == ["Bob", "Charlie"]
        assert out["role_acting_as"] == "Minion"


# ── Insomniac ────────────────────────────────────────────────────────────────


class TestTransformInsomniac:
    """Insomniac peeks at their own card (may have changed via swap)."""

    def test_shows_the_current_role(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Insomniac",
            action_type="none",
            targets={},
        )
        result = ActionResult(
            player_id=1,
            revealed_info={"current_role": "Robber"},
            state_mutations=[],
        )
        out = _transform_revealed_info(action, result, PLAYER_NAMES)
        assert out == {"current_role": "Robber"}

    def test_unchanged_role(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Insomniac",
            action_type="none",
            targets={},
        )
        result = ActionResult(
            player_id=1,
            revealed_info={"current_role": "Insomniac"},
            state_mutations=[],
        )
        out = _transform_revealed_info(action, result, PLAYER_NAMES)
        assert out == {"current_role": "Insomniac"}


# ── Doppelganger ─────────────────────────────────────────────────────────────


class TestTransformDoppelganger:
    """Doppelganger peeks at a player and copies their role."""

    def test_includes_target_name_role_and_copied_role(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Doppelganger",
            action_type="peek_player",
            targets={"player_id": 3},
        )
        result = ActionResult(
            player_id=1,
            revealed_info={"copied_role": "Seer"},
            state_mutations=["Player 1 copied the role of player 3."],
        )
        out = _transform_revealed_info(action, result, PLAYER_NAMES)
        assert out["target_name"] == "Charlie"
        assert out["role"] == "Seer"
        # copied_role preserved at original case for engine follow-up.
        assert out["copied_role"] == "Seer"


# ── Skip ─────────────────────────────────────────────────────────────────────


class TestTransformSkip:
    """Skipped actions return empty revealed_info."""

    def test_skip_says_nothing_was_chosen(self):
        action = NightAction(
            player_id=1,
            role_acting_as="Seer",
            action_type="skip",
            targets={},
        )
        result = ActionResult(
            player_id=1,
            revealed_info={},
            state_mutations=["Action skipped."],
        )
        out = _transform_revealed_info(action, result, PLAYER_NAMES)
        assert out == {"nothing_chosen": True}
