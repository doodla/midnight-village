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

    def test_max_player_count_exceeded(self):
        """player_count > 10 produces an error."""
        config = {
            "roles": {
                "Werewolf": 2,
                "Villager": 3,
                "Seer": 1,
                "Robber": 1,
                "Troublemaker": 1,
                "Drunk": 1,
                "Insomniac": 1,
                "Minion": 1,
                "Tanner": 1,
                "Hunter": 1,
            }
        }
        errors = validate_onuw_settings(config, 11)
        assert any("at most" in e.lower() or "10" in e for e in errors)

    def test_single_mason_fails(self):
        """1 Mason produces an error (must be 0 or 2)."""
        config = {
            "roles": {
                "Werewolf": 2,
                "Seer": 1,
                "Robber": 1,
                "Mason": 1,
                "Villager": 1,
                "Troublemaker": 1,
                "Drunk": 1,
            }
        }
        errors = validate_onuw_settings(config, 5)
        assert any("mason" in e.lower() or "pair" in e.lower() for e in errors)


class TestTimerSettingsValidation:
    """Timer settings are host-facing: integers from 0 to 3600, clear errors."""

    TIMER_KEYS = (
        "night_wave_seconds",
        "night_min_window_seconds",
        "night_doppelganger_window_seconds",
        "discussion_seconds",
        "voting_seconds",
    )

    def _config(self, **timers) -> dict:
        return {
            "roles": {
                "Werewolf": 2,
                "Seer": 1,
                "Robber": 1,
                "Villager": 1,
                "Drunk": 1,
                "Insomniac": 1,
                "Troublemaker": 1,
            },
            **timers,
        }

    @pytest.mark.parametrize("key", TIMER_KEYS)
    @pytest.mark.parametrize("value", [0, 1, 30, 3600])
    def test_valid_values_pass(self, key, value):
        # The minimum window is at most the window (the default, 30 s).
        if key == "night_min_window_seconds" and value > 30:
            value = 30
        assert validate_onuw_settings(self._config(**{key: value}), 5) == []

    @pytest.mark.parametrize("key", TIMER_KEYS)
    @pytest.mark.parametrize(
        "value", [-1, 3601, 10**9, "30", "abc", None, True, 1.5, [30], {"a": 1}]
    )
    def test_bad_values_are_rejected_with_a_clear_error(self, key, value):
        if key == "night_min_window_seconds" and value == 3601:
            value = 31  # past the window (the default, 30 s)
        errors = validate_onuw_settings(self._config(**{key: value}), 5)
        assert len(errors) == 1
        assert key in errors[0]
        most = 30 if key == "night_min_window_seconds" else 3600
        assert f"0 to {most}" in errors[0]

    def test_absent_timer_keys_are_fine(self):
        assert validate_onuw_settings(self._config(), 5) == []

    def test_minimum_window_longer_than_maximum_is_rejected(self):
        errors = validate_onuw_settings(
            self._config(night_wave_seconds=10, night_min_window_seconds=11), 5
        )
        assert errors == [
            "'night_min_window_seconds' must be a whole number of seconds from 0 to 10."
        ]

    def test_minimum_may_equal_the_maximum(self):
        config = self._config(night_wave_seconds=10, night_min_window_seconds=10)
        assert validate_onuw_settings(config, 5) == []

    def test_minimum_is_unconstrained_when_the_maximum_is_zero(self):
        # night_wave_seconds == 0 means "no maximum timer".
        config = self._config(night_wave_seconds=0, night_min_window_seconds=60)
        assert validate_onuw_settings(config, 5) == []

    def test_timer_errors_are_reported_alongside_role_errors(self):
        errors = validate_onuw_settings(
            {"roles": {"Werewolf": 1}, "voting_seconds": -5}, 5
        )
        assert any("voting_seconds" in e for e in errors)
        assert any("Total role count" in e for e in errors)

    def test_settings_that_are_not_an_object_are_rejected(self):
        assert validate_onuw_settings([], 5) == ["Settings must be an object."]  # type: ignore[arg-type]
