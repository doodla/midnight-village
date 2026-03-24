"""Unit tests for ONUW role behavior functions."""

import pytest

from apps.onuw.engine.behaviors import (
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
from apps.onuw.engine.state import GameState, NightAction

pytestmark = pytest.mark.unit


def _make_state(
    player_roles: dict[int, str] | None = None,
    center_cards: list[str] | None = None,
) -> GameState:
    """Create a GameState with sensible defaults for testing."""
    roles = player_roles or {
        1: "Werewolf",
        2: "Seer",
        3: "Robber",
        4: "Villager",
        5: "Drunk",
    }
    center = center_cards or ["Villager", "Tanner", "Mason"]
    return GameState(
        player_roles=roles,
        center_cards=center,
        original_roles=dict(roles),
    )


# ── Werewolf Tests ───────────────────────────────────────────────────────────


class TestExecuteWerewolf:
    """Tests for execute_werewolf behavior."""

    def test_two_werewolves_see_each_other(self):
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Werewolf",
                3: "Seer",
                4: "Villager",
                5: "Robber",
            }
        )
        action = NightAction(
            player_id=1,
            role_acting_as="Werewolf",
            action_type="see_team",
            targets={},
        )
        new_state, result = execute_werewolf(state, action)
        assert result.revealed_info["werewolves"] == [2]
        assert new_state.player_roles == state.player_roles  # no mutation

    def test_two_werewolves_other_perspective(self):
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Werewolf",
                3: "Seer",
                4: "Villager",
                5: "Robber",
            }
        )
        action = NightAction(
            player_id=2,
            role_acting_as="Werewolf",
            action_type="see_team",
            targets={},
        )
        _, result = execute_werewolf(state, action)
        assert result.revealed_info["werewolves"] == [1]

    def test_lone_werewolf_can_peek_center_card(self):
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Seer",
                3: "Robber",
                4: "Villager",
                5: "Drunk",
            }
        )
        action = NightAction(
            player_id=1,
            role_acting_as="Werewolf",
            action_type="see_team",
            targets={"center_index": 0},
        )
        _, result = execute_werewolf(state, action)
        assert result.revealed_info["werewolves"] == []
        assert result.revealed_info["center_card"] == {"index": 0, "role": "Villager"}

    def test_lone_werewolf_with_no_target_sees_empty_list(self):
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Seer",
                3: "Robber",
                4: "Villager",
                5: "Drunk",
            }
        )
        action = NightAction(
            player_id=1,
            role_acting_as="Werewolf",
            action_type="see_team",
            targets={},
        )
        _, result = execute_werewolf(state, action)
        assert result.revealed_info["werewolves"] == []
        assert "center_card" not in result.revealed_info

    def test_lone_werewolf_invalid_center_index_raises(self):
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Seer",
                3: "Robber",
                4: "Villager",
                5: "Drunk",
            }
        )
        action = NightAction(
            player_id=1,
            role_acting_as="Werewolf",
            action_type="see_team",
            targets={"center_index": 5},
        )
        with pytest.raises(ValueError, match="Invalid center card index"):
            execute_werewolf(state, action)

    def test_werewolf_no_state_mutations(self):
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Werewolf",
                3: "Seer",
                4: "Villager",
                5: "Robber",
            }
        )
        action = NightAction(
            player_id=1,
            role_acting_as="Werewolf",
            action_type="see_team",
            targets={},
        )
        _, result = execute_werewolf(state, action)
        assert result.state_mutations == []


# ── Minion Tests ─────────────────────────────────────────────────────────────


class TestExecuteMinion:
    """Tests for execute_minion behavior."""

    def test_minion_sees_all_werewolf_ids(self):
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Werewolf",
                3: "Minion",
                4: "Villager",
                5: "Seer",
            }
        )
        action = NightAction(
            player_id=3,
            role_acting_as="Minion",
            action_type="see_team",
            targets={},
        )
        _, result = execute_minion(state, action)
        assert sorted(result.revealed_info["werewolves"]) == [1, 2]

    def test_minion_with_no_werewolves_sees_empty_list(self):
        state = _make_state(
            player_roles={
                1: "Villager",
                2: "Seer",
                3: "Minion",
                4: "Robber",
                5: "Drunk",
            }
        )
        action = NightAction(
            player_id=3,
            role_acting_as="Minion",
            action_type="see_team",
            targets={},
        )
        _, result = execute_minion(state, action)
        assert result.revealed_info["werewolves"] == []

    def test_minion_no_state_mutations(self):
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Seer",
                3: "Minion",
                4: "Villager",
                5: "Robber",
            }
        )
        action = NightAction(
            player_id=3,
            role_acting_as="Minion",
            action_type="see_team",
            targets={},
        )
        _, result = execute_minion(state, action)
        assert result.state_mutations == []


# ── Mason Tests ──────────────────────────────────────────────────────────────


class TestExecuteMason:
    """Tests for execute_mason behavior."""

    def test_two_masons_see_each_other(self):
        state = _make_state(
            player_roles={
                1: "Mason",
                2: "Mason",
                3: "Seer",
                4: "Villager",
                5: "Werewolf",
            }
        )
        action = NightAction(
            player_id=1,
            role_acting_as="Mason",
            action_type="see_team",
            targets={},
        )
        _, result = execute_mason(state, action)
        assert result.revealed_info["masons"] == [2]

    def test_lone_mason_sees_empty_list(self):
        state = _make_state(
            player_roles={
                1: "Mason",
                2: "Seer",
                3: "Robber",
                4: "Villager",
                5: "Werewolf",
            }
        )
        action = NightAction(
            player_id=1,
            role_acting_as="Mason",
            action_type="see_team",
            targets={},
        )
        _, result = execute_mason(state, action)
        assert result.revealed_info["masons"] == []

    def test_mason_no_state_mutations(self):
        state = _make_state(
            player_roles={
                1: "Mason",
                2: "Mason",
                3: "Seer",
                4: "Villager",
                5: "Werewolf",
            }
        )
        action = NightAction(
            player_id=1,
            role_acting_as="Mason",
            action_type="see_team",
            targets={},
        )
        _, result = execute_mason(state, action)
        assert result.state_mutations == []


# ── Seer Tests ───────────────────────────────────────────────────────────────


class TestExecuteSeer:
    """Tests for execute_seer behavior."""

    def test_seer_peeks_a_player_sees_current_role(self):
        state = _make_state()
        action = NightAction(
            player_id=2,
            role_acting_as="Seer",
            action_type="peek_player",
            targets={"player_id": 1},
        )
        _, result = execute_seer(state, action)
        assert result.revealed_info["peeked_role"] == "Werewolf"

    def test_seer_peeks_two_center_cards(self):
        state = _make_state()
        action = NightAction(
            player_id=2,
            role_acting_as="Seer",
            action_type="peek_center",
            targets={"center_indices": [0, 2]},
        )
        _, result = execute_seer(state, action)
        peeked = result.revealed_info["peeked_center"]
        assert len(peeked) == 2
        assert peeked[0] == {"index": 0, "role": "Villager"}
        assert peeked[1] == {"index": 2, "role": "Mason"}

    def test_seer_cannot_peek_self(self):
        state = _make_state()
        action = NightAction(
            player_id=2,
            role_acting_as="Seer",
            action_type="peek_player",
            targets={"player_id": 2},
        )
        with pytest.raises(ValueError, match="Cannot target yourself"):
            execute_seer(state, action)

    def test_seer_cannot_peek_invalid_player(self):
        state = _make_state()
        action = NightAction(
            player_id=2,
            role_acting_as="Seer",
            action_type="peek_player",
            targets={"player_id": 99},
        )
        with pytest.raises(ValueError, match="Invalid target player"):
            execute_seer(state, action)

    def test_seer_peek_center_requires_exactly_two(self):
        state = _make_state()
        action = NightAction(
            player_id=2,
            role_acting_as="Seer",
            action_type="peek_center",
            targets={"center_indices": [0]},
        )
        with pytest.raises(ValueError, match="exactly 2 center cards"):
            execute_seer(state, action)

    def test_seer_peek_center_must_be_different(self):
        state = _make_state()
        action = NightAction(
            player_id=2,
            role_acting_as="Seer",
            action_type="peek_center",
            targets={"center_indices": [1, 1]},
        )
        with pytest.raises(ValueError, match="2 different center cards"):
            execute_seer(state, action)

    def test_seer_invalid_action_type_raises(self):
        state = _make_state()
        action = NightAction(
            player_id=2,
            role_acting_as="Seer",
            action_type="swap_with_player",
            targets={"player_id": 1},
        )
        with pytest.raises(ValueError, match="Invalid action type for Seer"):
            execute_seer(state, action)

    def test_seer_no_state_mutations(self):
        state = _make_state()
        action = NightAction(
            player_id=2,
            role_acting_as="Seer",
            action_type="peek_player",
            targets={"player_id": 1},
        )
        new_state, result = execute_seer(state, action)
        assert new_state.player_roles == state.player_roles
        assert result.state_mutations == []


# ── Robber Tests ─────────────────────────────────────────────────────────────


class TestExecuteRobber:
    """Tests for execute_robber behavior."""

    def test_robber_swaps_and_learns_new_role(self):
        state = _make_state()
        action = NightAction(
            player_id=3,
            role_acting_as="Robber",
            action_type="swap_with_player",
            targets={"player_id": 1},
        )
        new_state, result = execute_robber(state, action)
        assert result.revealed_info["new_role"] == "Werewolf"
        assert new_state.player_roles[3] == "Werewolf"
        assert new_state.player_roles[1] == "Robber"

    def test_robber_cannot_target_self(self):
        state = _make_state()
        action = NightAction(
            player_id=3,
            role_acting_as="Robber",
            action_type="swap_with_player",
            targets={"player_id": 3},
        )
        with pytest.raises(ValueError, match="Cannot target yourself"):
            execute_robber(state, action)

    def test_robber_cannot_target_invalid_player(self):
        state = _make_state()
        action = NightAction(
            player_id=3,
            role_acting_as="Robber",
            action_type="swap_with_player",
            targets={"player_id": 99},
        )
        with pytest.raises(ValueError, match="Invalid target player"):
            execute_robber(state, action)

    def test_robber_state_mutation_description(self):
        state = _make_state()
        action = NightAction(
            player_id=3,
            role_acting_as="Robber",
            action_type="swap_with_player",
            targets={"player_id": 1},
        )
        _, result = execute_robber(state, action)
        assert len(result.state_mutations) == 1
        assert "swapped" in result.state_mutations[0]


# ── Troublemaker Tests ───────────────────────────────────────────────────────


class TestExecuteTroublemaker:
    """Tests for execute_troublemaker behavior."""

    def test_troublemaker_swaps_two_others_learns_nothing(self):
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Seer",
                3: "Robber",
                4: "Troublemaker",
                5: "Drunk",
            }
        )
        action = NightAction(
            player_id=4,
            role_acting_as="Troublemaker",
            action_type="swap_others",
            targets={"player_ids": [1, 2]},
        )
        new_state, result = execute_troublemaker(state, action)
        assert new_state.player_roles[1] == "Seer"
        assert new_state.player_roles[2] == "Werewolf"
        assert new_state.player_roles[4] == "Troublemaker"  # unchanged
        assert result.revealed_info == {}

    def test_troublemaker_cannot_include_self(self):
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Seer",
                3: "Robber",
                4: "Troublemaker",
                5: "Drunk",
            }
        )
        action = NightAction(
            player_id=4,
            role_acting_as="Troublemaker",
            action_type="swap_others",
            targets={"player_ids": [4, 2]},
        )
        with pytest.raises(ValueError, match="cannot target themselves"):
            execute_troublemaker(state, action)

    def test_troublemaker_must_target_two_different_players(self):
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Seer",
                3: "Robber",
                4: "Troublemaker",
                5: "Drunk",
            }
        )
        action = NightAction(
            player_id=4,
            role_acting_as="Troublemaker",
            action_type="swap_others",
            targets={"player_ids": [1, 1]},
        )
        with pytest.raises(ValueError, match="2 different players"):
            execute_troublemaker(state, action)

    def test_troublemaker_requires_exactly_two_targets(self):
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Seer",
                3: "Robber",
                4: "Troublemaker",
                5: "Drunk",
            }
        )
        action = NightAction(
            player_id=4,
            role_acting_as="Troublemaker",
            action_type="swap_others",
            targets={"player_ids": [1]},
        )
        with pytest.raises(ValueError, match="exactly 2 players"):
            execute_troublemaker(state, action)


# ── Drunk Tests ──────────────────────────────────────────────────────────────


class TestExecuteDrunk:
    """Tests for execute_drunk behavior."""

    def test_drunk_swaps_with_center_learns_nothing(self):
        state = _make_state()
        action = NightAction(
            player_id=5,
            role_acting_as="Drunk",
            action_type="swap_with_center",
            targets={"center_index": 1},
        )
        new_state, result = execute_drunk(state, action)
        assert new_state.player_roles[5] == "Tanner"
        assert new_state.center_cards[1] == "Drunk"
        assert result.revealed_info == {}

    def test_drunk_invalid_center_index_raises(self):
        state = _make_state()
        action = NightAction(
            player_id=5,
            role_acting_as="Drunk",
            action_type="swap_with_center",
            targets={"center_index": 5},
        )
        with pytest.raises(ValueError, match="Invalid center card index"):
            execute_drunk(state, action)

    def test_drunk_state_mutation_description(self):
        state = _make_state()
        action = NightAction(
            player_id=5,
            role_acting_as="Drunk",
            action_type="swap_with_center",
            targets={"center_index": 0},
        )
        _, result = execute_drunk(state, action)
        assert len(result.state_mutations) == 1
        assert "swapped" in result.state_mutations[0]


# ── Doppelganger Tests ───────────────────────────────────────────────────────


class TestExecuteDoppelganger:
    """Tests for execute_doppelganger behavior."""

    def test_doppelganger_copies_target_role(self):
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Seer",
                3: "Robber",
                4: "Villager",
                5: "Werewolf",
            }
        )
        action = NightAction(
            player_id=1,
            role_acting_as="Doppelganger",
            action_type="peek_player",
            targets={"player_id": 2},
        )
        new_state, result = execute_doppelganger(state, action)
        assert result.revealed_info["copied_role"] == "Seer"
        assert new_state.doppelganger_copied_role[1] == "Seer"
        # Doppelganger's current role stays "Doppelganger"
        assert new_state.player_roles[1] == "Doppelganger"

    def test_doppelganger_cannot_target_self(self):
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Seer",
                3: "Robber",
                4: "Villager",
                5: "Werewolf",
            }
        )
        action = NightAction(
            player_id=1,
            role_acting_as="Doppelganger",
            action_type="peek_player",
            targets={"player_id": 1},
        )
        with pytest.raises(ValueError, match="Cannot target yourself"):
            execute_doppelganger(state, action)

    def test_doppelganger_copies_seer_gets_followup_in_wave_1(self):
        assert get_doppelganger_followup_wave("Seer") == 1

    def test_doppelganger_copies_werewolf_gets_followup_in_wave_2(self):
        assert get_doppelganger_followup_wave("Werewolf") == 2

    def test_doppelganger_copies_villager_no_followup(self):
        assert get_doppelganger_followup_wave("Villager") is None

    def test_doppelganger_copies_insomniac_followup_in_wave_4(self):
        assert get_doppelganger_followup_wave("Insomniac") == 4

    def test_doppelganger_copies_tanner_no_followup(self):
        assert get_doppelganger_followup_wave("Tanner") is None

    def test_doppelganger_copies_hunter_no_followup(self):
        assert get_doppelganger_followup_wave("Hunter") is None

    def test_doppelganger_copies_doppelganger_no_followup(self):
        assert get_doppelganger_followup_wave("Doppelganger") is None

    def test_doppelganger_copies_minion_followup_in_wave_2(self):
        assert get_doppelganger_followup_wave("Minion") == 2

    def test_doppelganger_copies_mason_followup_in_wave_2(self):
        assert get_doppelganger_followup_wave("Mason") == 2

    def test_doppelganger_copies_robber_followup_in_wave_1(self):
        assert get_doppelganger_followup_wave("Robber") == 1

    def test_doppelganger_copies_troublemaker_followup_in_wave_1(self):
        assert get_doppelganger_followup_wave("Troublemaker") == 1

    def test_doppelganger_copies_drunk_followup_in_wave_1(self):
        assert get_doppelganger_followup_wave("Drunk") == 1


# ── Insomniac Tests ──────────────────────────────────────────────────────────


class TestExecuteInsomniac:
    """Tests for execute_insomniac behavior."""

    def test_insomniac_sees_own_current_role_unchanged(self):
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Seer",
                3: "Robber",
                4: "Insomniac",
                5: "Drunk",
            }
        )
        action = NightAction(
            player_id=4,
            role_acting_as="Insomniac",
            action_type="peek_player",
            targets={},
        )
        _, result = execute_insomniac(state, action)
        assert result.revealed_info["current_role"] == "Insomniac"

    def test_insomniac_sees_changed_role_after_swap(self):
        """If Robber or Troublemaker swapped the Insomniac, they see their new role."""
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Seer",
                3: "Robber",
                4: "Insomniac",
                5: "Drunk",
            }
        )
        # Simulate Robber having already swapped with Insomniac
        swapped_state = state.with_swap(3, 4)
        assert swapped_state.player_roles[4] == "Robber"  # Insomniac now has Robber

        action = NightAction(
            player_id=4,
            role_acting_as="Insomniac",
            action_type="peek_player",
            targets={},
        )
        _, result = execute_insomniac(swapped_state, action)
        assert result.revealed_info["current_role"] == "Robber"

    def test_insomniac_no_state_mutations(self):
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Seer",
                3: "Robber",
                4: "Insomniac",
                5: "Drunk",
            }
        )
        action = NightAction(
            player_id=4,
            role_acting_as="Insomniac",
            action_type="peek_player",
            targets={},
        )
        new_state, result = execute_insomniac(state, action)
        assert new_state.player_roles == state.player_roles
        assert result.state_mutations == []


# ── Dispatch Tests ───────────────────────────────────────────────────────────


class TestExecuteAction:
    """Tests for the execute_action dispatch function."""

    def test_dispatches_to_werewolf(self):
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Seer",
                3: "Robber",
                4: "Villager",
                5: "Drunk",
            }
        )
        action = NightAction(
            player_id=1,
            role_acting_as="Werewolf",
            action_type="see_team",
            targets={},
        )
        _, result = execute_action(state, action)
        assert "werewolves" in result.revealed_info

    def test_dispatches_to_seer(self):
        state = _make_state()
        action = NightAction(
            player_id=2,
            role_acting_as="Seer",
            action_type="peek_player",
            targets={"player_id": 1},
        )
        _, result = execute_action(state, action)
        assert "peeked_role" in result.revealed_info

    def test_raises_for_role_without_night_action(self):
        state = _make_state()
        action = NightAction(
            player_id=4,
            role_acting_as="Villager",
            action_type="none",
            targets={},
        )
        with pytest.raises(ValueError, match="no night action behavior"):
            execute_action(state, action)

    def test_raises_for_unknown_role(self):
        state = _make_state()
        action = NightAction(
            player_id=1,
            role_acting_as="Wizard",
            action_type="none",
            targets={},
        )
        with pytest.raises(ValueError, match="Unknown role"):
            execute_action(state, action)
