"""Unit tests for ONUW role assignment."""

import pytest

from apps.onuw.engine.assignment import assign_roles

pytestmark = pytest.mark.unit


class TestAssignRoles:
    """Tests for the deterministic role assignment function."""

    def _standard_config(self) -> dict[str, int]:
        """Return a standard role config for 5 players (8 roles)."""
        return {
            "Werewolf": 2,
            "Seer": 1,
            "Robber": 1,
            "Villager": 1,
            "Drunk": 1,
            "Insomniac": 1,
            "Troublemaker": 1,
        }

    def test_deterministic_same_seed(self):
        """Same seed and inputs produce identical assignments."""
        config = self._standard_config()
        player_ids = [1, 2, 3, 4, 5]

        result_a = assign_roles(config, player_ids, seed=42)
        result_b = assign_roles(config, player_ids, seed=42)

        assert result_a == result_b

    def test_distributes_correct_counts(self):
        """Players get exactly player_count roles, center gets exactly 3."""
        config = self._standard_config()
        player_ids = [10, 20, 30, 40, 50]

        player_roles, center_cards = assign_roles(config, player_ids, seed=123)

        assert len(player_roles) == 5
        assert len(center_cards) == 3

        # Verify all player IDs are assigned
        assert set(player_roles.keys()) == set(player_ids)

    def test_all_roles_accounted_for(self):
        """Every role from the config appears in either player or center assignments."""
        config = self._standard_config()
        player_ids = [1, 2, 3, 4, 5]

        player_roles, center_cards = assign_roles(config, player_ids, seed=99)

        # Collect all assigned roles
        all_assigned = list(player_roles.values()) + center_cards

        # Count occurrences
        from collections import Counter

        counts = Counter(all_assigned)
        expected_counts = Counter()
        for role_name, count in config.items():
            expected_counts[role_name] = count

        assert counts == expected_counts

    def test_different_seeds_produce_different_assignments(self):
        """Different seeds should (with high probability) produce different results."""
        config = self._standard_config()
        player_ids = [1, 2, 3, 4, 5]

        result_a = assign_roles(config, player_ids, seed=1)
        result_b = assign_roles(config, player_ids, seed=2)

        # At least one of (player_roles, center_cards) should differ
        assert result_a != result_b

    def test_minimum_game_3_players(self):
        """Assignment works with the minimum 3 players (6 roles)."""
        config = {"Werewolf": 2, "Seer": 1, "Robber": 1, "Villager": 2}
        player_ids = [1, 2, 3]

        player_roles, center_cards = assign_roles(config, player_ids, seed=42)

        assert len(player_roles) == 3
        assert len(center_cards) == 3

    def test_player_ids_are_sorted_before_assignment(self):
        """Assignment is stable regardless of player_ids input order."""
        config = self._standard_config()

        result_a = assign_roles(config, [5, 3, 1, 4, 2], seed=42)
        result_b = assign_roles(config, [1, 2, 3, 4, 5], seed=42)

        assert result_a == result_b
