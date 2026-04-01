"""Unit tests for the ONUW role registry."""

import pytest

from apps.onuw.engine.roles import (
    ROLE_REGISTRY,
    ActionType,
    Team,
    get_role,
    get_roles_for_wave,
)

pytestmark = pytest.mark.unit


class TestRoleRegistry:
    """Tests for individual role definitions in the registry."""

    def test_all_twelve_roles_registered(self):
        """The registry contains exactly the 12 v1 roles."""
        expected = {
            "Werewolf",
            "Villager",
            "Seer",
            "Robber",
            "Troublemaker",
            "Drunk",
            "Insomniac",
            "Minion",
            "Tanner",
            "Hunter",
            "Mason",
            "Doppelganger",
        }
        assert set(ROLE_REGISTRY.keys()) == expected

    def test_werewolf_definition(self):
        role = get_role("Werewolf")
        assert role.team == Team.WEREWOLF
        assert role.wave == 2
        assert role.action_types == (ActionType.SEE_TEAM,)
        assert role.max_count == 2

    def test_villager_definition(self):
        role = get_role("Villager")
        assert role.team == Team.VILLAGE
        assert role.wave is None
        assert role.action_types == (ActionType.NONE,)
        assert role.max_count == 3

    def test_seer_definition(self):
        role = get_role("Seer")
        assert role.team == Team.VILLAGE
        assert role.wave == 3
        assert role.action_types == (ActionType.PEEK_PLAYER, ActionType.PEEK_CENTER)
        assert role.max_count == 1

    def test_robber_definition(self):
        role = get_role("Robber")
        assert role.team == Team.VILLAGE
        assert role.wave == 3
        assert role.action_types == (ActionType.SWAP_WITH_PLAYER,)
        assert role.max_count == 1

    def test_troublemaker_definition(self):
        role = get_role("Troublemaker")
        assert role.team == Team.VILLAGE
        assert role.wave == 3
        assert role.action_types == (ActionType.SWAP_OTHERS,)
        assert role.max_count == 1

    def test_drunk_definition(self):
        role = get_role("Drunk")
        assert role.team == Team.VILLAGE
        assert role.wave == 3
        assert role.action_types == (ActionType.SWAP_WITH_CENTER,)
        assert role.max_count == 1

    def test_insomniac_definition(self):
        role = get_role("Insomniac")
        assert role.team == Team.VILLAGE
        assert role.wave == 4
        assert role.action_types == (ActionType.NONE,)
        assert role.max_count == 1

    def test_minion_definition(self):
        role = get_role("Minion")
        assert role.team == Team.WEREWOLF
        assert role.wave == 2
        assert role.action_types == (ActionType.SEE_TEAM,)
        assert role.max_count == 1

    def test_tanner_definition(self):
        role = get_role("Tanner")
        assert role.team == Team.NEUTRAL
        assert role.wave is None
        assert role.action_types == (ActionType.NONE,)
        assert role.max_count == 1

    def test_hunter_definition(self):
        role = get_role("Hunter")
        assert role.team == Team.VILLAGE
        assert role.wave is None
        assert role.action_types == (ActionType.NONE,)
        assert role.max_count == 1

    def test_mason_definition(self):
        role = get_role("Mason")
        assert role.team == Team.VILLAGE
        assert role.wave == 2
        assert role.action_types == (ActionType.SEE_TEAM,)
        assert role.max_count == 2

    def test_doppelganger_definition(self):
        role = get_role("Doppelganger")
        assert role.team == Team.VILLAGE
        assert role.wave == 1
        assert role.action_types == (ActionType.PEEK_PLAYER,)
        assert role.max_count == 1


class TestGetRole:
    """Tests for the get_role lookup function."""

    def test_get_role_returns_correct_role(self):
        role = get_role("Seer")
        assert role.name == "Seer"

    def test_get_role_raises_for_unknown_role(self):
        with pytest.raises(ValueError, match="Unknown role"):
            get_role("Wizard")

    def test_get_role_is_case_sensitive(self):
        with pytest.raises(ValueError, match="Unknown role"):
            get_role("werewolf")


class TestGetRolesForWave:
    """Tests for the get_roles_for_wave function."""

    def test_wave_1_has_doppelganger(self):
        roles = get_roles_for_wave(1)
        names = {r.name for r in roles}
        assert names == {"Doppelganger"}

    def test_wave_2_has_werewolf_minion_mason(self):
        roles = get_roles_for_wave(2)
        names = {r.name for r in roles}
        assert names == {"Werewolf", "Minion", "Mason"}

    def test_wave_3_has_seer_robber_troublemaker_drunk(self):
        roles = get_roles_for_wave(3)
        names = {r.name for r in roles}
        assert names == {"Seer", "Robber", "Troublemaker", "Drunk"}

    def test_wave_4_has_insomniac(self):
        roles = get_roles_for_wave(4)
        names = {r.name for r in roles}
        assert names == {"Insomniac"}

    def test_wave_0_returns_empty(self):
        """Wave 0 is not a real wave, should return nothing."""
        roles = get_roles_for_wave(0)
        assert roles == []

    def test_wave_99_returns_empty(self):
        """Non-existent wave returns empty list."""
        roles = get_roles_for_wave(99)
        assert roles == []
