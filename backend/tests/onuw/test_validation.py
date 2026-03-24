"""Unit tests for ONUW settings validation."""

import pytest

from apps.onuw.engine.validation import validate_onuw_settings

pytestmark = pytest.mark.unit


class TestValidateOnuwSettings:
    """Tests for validate_onuw_settings."""

    def _valid_config_5_players(self) -> dict:
        """Return a valid role config for 5 players (8 total roles)."""
        return {
            "roles": {
                "Werewolf": 2,
                "Seer": 1,
                "Robber": 1,
                "Villager": 1,
                "Drunk": 1,
                "Insomniac": 1,
                "Troublemaker": 1,
            }
        }

    def test_valid_config_passes(self):
        """A correctly configured game produces no errors."""
        errors = validate_onuw_settings(self._valid_config_5_players(), 5)
        assert errors == []

    def test_wrong_total_count_fails(self):
        """Total roles must equal player_count + 3."""
        config = {
            "roles": {
                "Werewolf": 2,
                "Seer": 1,
            }
        }
        errors = validate_onuw_settings(config, 5)
        assert any("Total role count" in e for e in errors)

    def test_unknown_role_fails(self):
        """Unknown role names produce an error."""
        config = {
            "roles": {
                "Wizard": 1,
                "Werewolf": 2,
                "Seer": 1,
                "Robber": 1,
                "Villager": 1,
                "Drunk": 1,
                "Insomniac": 1,
            }
        }
        errors = validate_onuw_settings(config, 5)
        assert any("Unknown role" in e for e in errors)

    def test_role_count_exceeding_max_fails(self):
        """A role count above its max produces an error."""
        config = {
            "roles": {
                "Werewolf": 3,  # max is 2
                "Seer": 1,
                "Robber": 1,
                "Villager": 1,
                "Drunk": 1,
                "Insomniac": 1,
            }
        }
        errors = validate_onuw_settings(config, 5)
        assert any("at most" in e for e in errors)

    def test_player_count_below_minimum_fails(self):
        """player_count < 3 produces an error."""
        config = {
            "roles": {
                "Werewolf": 2,
                "Seer": 1,
                "Robber": 1,
                "Villager": 1,
            }
        }
        errors = validate_onuw_settings(config, 2)
        assert any("At least 3 players" in e for e in errors)

    def test_missing_roles_key_fails(self):
        """Settings without a 'roles' key produce an error."""
        errors = validate_onuw_settings({}, 5)
        assert any("'roles'" in e for e in errors)

    def test_roles_not_a_dict_fails(self):
        """Non-dict 'roles' value produces an error."""
        errors = validate_onuw_settings({"roles": ["Werewolf"]}, 5)
        assert any("mapping" in e for e in errors)

    def test_negative_count_fails(self):
        """Negative role counts produce an error."""
        config = {
            "roles": {
                "Werewolf": -1,
                "Seer": 1,
                "Robber": 1,
                "Villager": 3,
                "Drunk": 1,
                "Insomniac": 1,
                "Troublemaker": 1,
            }
        }
        errors = validate_onuw_settings(config, 5)
        assert any("non-negative integer" in e for e in errors)

    def test_valid_config_3_players(self):
        """Minimum viable game with 3 players (6 total roles)."""
        config = {
            "roles": {
                "Werewolf": 2,
                "Seer": 1,
                "Robber": 1,
                "Villager": 2,
            }
        }
        errors = validate_onuw_settings(config, 3)
        assert errors == []
