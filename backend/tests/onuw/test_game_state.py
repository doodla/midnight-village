"""Unit tests for ONUW GameState data structures."""

import pytest

from apps.onuw.engine.state import ActionLogEntry, GameState

pytestmark = pytest.mark.unit


def _make_state(
    player_roles: dict[int, str] | None = None,
    center_cards: list[str] | None = None,
) -> GameState:
    """Create a GameState with sensible defaults for testing."""
    roles = player_roles or {1: "Werewolf", 2: "Seer", 3: "Robber"}
    center = center_cards or ["Villager", "Drunk", "Tanner"]
    return GameState(
        player_roles=roles,
        center_cards=center,
        original_roles=dict(roles),
    )


class TestWithSwap:
    """Tests for GameState.with_swap."""

    def test_swaps_two_player_roles(self):
        state = _make_state()
        new_state = state.with_swap(1, 2)
        assert new_state.player_roles[1] == "Seer"
        assert new_state.player_roles[2] == "Werewolf"
        assert new_state.player_roles[3] == "Robber"

    def test_original_state_is_not_mutated(self):
        state = _make_state()
        state.with_swap(1, 2)
        assert state.player_roles[1] == "Werewolf"
        assert state.player_roles[2] == "Seer"

    def test_swap_is_symmetric(self):
        state = _make_state()
        swap_1_2 = state.with_swap(1, 2)
        swap_2_1 = state.with_swap(2, 1)
        assert swap_1_2.player_roles == swap_2_1.player_roles

    def test_swap_preserves_center_cards(self):
        state = _make_state()
        new_state = state.with_swap(1, 2)
        assert new_state.center_cards == state.center_cards

    def test_swap_preserves_action_log(self):
        entry = ActionLogEntry(
            wave=1,
            player_id=1,
            action_type="peek_player",
            targets={},
            result={},
            timestamp_order=0,
        )
        state = _make_state()
        state_with_log = state.with_log_entry(entry)
        new_state = state_with_log.with_swap(1, 2)
        assert len(new_state.action_log) == 1


class TestWithCenterSwap:
    """Tests for GameState.with_center_swap."""

    def test_swaps_player_with_center_card(self):
        state = _make_state()
        new_state = state.with_center_swap(1, 0)
        assert new_state.player_roles[1] == "Villager"
        assert new_state.center_cards[0] == "Werewolf"

    def test_original_state_is_not_mutated(self):
        state = _make_state()
        state.with_center_swap(1, 0)
        assert state.player_roles[1] == "Werewolf"
        assert state.center_cards[0] == "Villager"

    def test_other_players_unaffected(self):
        state = _make_state()
        new_state = state.with_center_swap(1, 0)
        assert new_state.player_roles[2] == "Seer"
        assert new_state.player_roles[3] == "Robber"

    def test_other_center_cards_unaffected(self):
        state = _make_state()
        new_state = state.with_center_swap(1, 0)
        assert new_state.center_cards[1] == "Drunk"
        assert new_state.center_cards[2] == "Tanner"


class TestOriginalRolesImmutability:
    """Tests that original_roles is never mutated by any operation."""

    def test_swap_does_not_mutate_original_roles(self):
        state = _make_state()
        new_state = state.with_swap(1, 2)
        assert new_state.original_roles[1] == "Werewolf"
        assert new_state.original_roles[2] == "Seer"

    def test_center_swap_does_not_mutate_original_roles(self):
        state = _make_state()
        new_state = state.with_center_swap(1, 0)
        assert new_state.original_roles[1] == "Werewolf"

    def test_chained_swaps_do_not_mutate_original_roles(self):
        state = _make_state()
        s1 = state.with_swap(1, 2)
        s2 = s1.with_swap(2, 3)
        s3 = s2.with_center_swap(3, 1)
        assert s3.original_roles == {1: "Werewolf", 2: "Seer", 3: "Robber"}


class TestWithLogEntry:
    """Tests for GameState.with_log_entry."""

    def test_appends_log_entry(self):
        state = _make_state()
        entry = ActionLogEntry(
            wave=2,
            player_id=1,
            action_type="see_team",
            targets={},
            result={"werewolves": []},
            timestamp_order=0,
        )
        new_state = state.with_log_entry(entry)
        assert len(new_state.action_log) == 1
        assert new_state.action_log[0] == entry

    def test_does_not_mutate_original(self):
        state = _make_state()
        entry = ActionLogEntry(
            wave=2,
            player_id=1,
            action_type="see_team",
            targets={},
            result={},
            timestamp_order=0,
        )
        state.with_log_entry(entry)
        assert len(state.action_log) == 0

    def test_multiple_entries_preserve_order(self):
        state = _make_state()
        entry1 = ActionLogEntry(
            wave=2,
            player_id=1,
            action_type="see_team",
            targets={},
            result={},
            timestamp_order=0,
        )
        entry2 = ActionLogEntry(
            wave=3,
            player_id=2,
            action_type="peek_player",
            targets={"player_id": 3},
            result={"peeked_role": "Robber"},
            timestamp_order=1,
        )
        s1 = state.with_log_entry(entry1)
        s2 = s1.with_log_entry(entry2)
        assert len(s2.action_log) == 2
        assert s2.action_log[0] == entry1
        assert s2.action_log[1] == entry2


class TestWithDoppelgangerCopy:
    """Tests for GameState.with_doppelganger_copy."""

    def test_records_copied_role(self):
        state = _make_state(player_roles={1: "Doppelganger", 2: "Seer", 3: "Robber"})
        new_state = state.with_doppelganger_copy(1, "Seer")
        assert new_state.doppelganger_copied_role[1] == "Seer"

    def test_does_not_mutate_original(self):
        state = _make_state(player_roles={1: "Doppelganger", 2: "Seer", 3: "Robber"})
        state.with_doppelganger_copy(1, "Seer")
        assert 1 not in state.doppelganger_copied_role

    def test_preserves_player_roles(self):
        state = _make_state(player_roles={1: "Doppelganger", 2: "Seer", 3: "Robber"})
        new_state = state.with_doppelganger_copy(1, "Seer")
        assert new_state.player_roles == state.player_roles
