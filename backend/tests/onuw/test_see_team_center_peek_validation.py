"""
Tests for see_team center_index validation in validate_night_action.

Only a lone Werewolf (or Doppelganger-as-Werewolf with no other werewolves)
may submit center_index with a see_team action. Multi-werewolves, Masons,
and Minions must be rejected at the validation layer — not allowed through
to crash during wave resolution.

Spec: night-phase.md § Wave 2 — "Lone Werewolf variant: you may view one
center card" (optional). All other see_team roles gain information only
about teammates.
"""

import pytest

from apps.core.models import Lobby, LobbyMember, User
from apps.onuw.models import Game, Phase, PlayerRole
from apps.onuw.services import validate_night_action

pytestmark = pytest.mark.integration


def _create_game(
    players_roles: dict[str, str],
    center_cards: list[str],
    current_wave: int = 2,
) -> tuple[Game, dict[str, User]]:
    """Create a game with specific role assignments for validation tests."""
    usernames = list(players_roles.keys())
    users = {}
    for uname in usernames:
        users[uname] = User.objects.create_user(username=uname, password="pass")

    host = users[usernames[0]]
    lobby = Lobby.objects.create(
        host=host,
        game_type="onuw",
        max_players=10,
        settings={"roles": {}},
    )
    for user in users.values():
        LobbyMember.objects.create(lobby=lobby, user=user, is_ready=True)
    lobby.status = Lobby.Status.IN_GAME
    lobby.save()

    game = Game.objects.create(
        lobby=lobby,
        phase=Phase.NIGHT,
        current_wave=current_wave,
        random_seed=42,
        settings=lobby.settings,
        center_cards=center_cards,
    )

    for uname, role in players_roles.items():
        PlayerRole.objects.create(
            game=game,
            user=users[uname],
            original_role=role,
            current_role=role,
        )

    return game, users


class TestSeeTeamCenterPeekValidation:
    """Validate that center_index on see_team is only allowed for lone werewolves."""

    def test_multi_werewolf_rejects_center_index(self, db):
        """Two werewolves in game — center_index must be rejected."""
        game, users = _create_game(
            {
                "alice": "Werewolf",
                "bob": "Werewolf",
                "carol": "Seer",
                "dave": "Villager",
                "eve": "Robber",
            },
            center_cards=["Troublemaker", "Drunk", "Villager"],
            current_wave=2,
        )
        pr = PlayerRole.objects.get(game=game, user=users["alice"])

        errors = validate_night_action(game, pr, "see_team", {"center_index": 0})

        assert len(errors) > 0
        assert any("lone" in e.lower() or "center" in e.lower() for e in errors)

    def test_mason_rejects_center_index(self, db):
        """Masons use see_team but must not be allowed center_index."""
        game, users = _create_game(
            {
                "alice": "Mason",
                "bob": "Mason",
                "carol": "Werewolf",
                "dave": "Villager",
                "eve": "Seer",
            },
            center_cards=["Robber", "Drunk", "Villager"],
            current_wave=2,
        )
        pr = PlayerRole.objects.get(game=game, user=users["alice"])

        errors = validate_night_action(game, pr, "see_team", {"center_index": 1})

        assert len(errors) > 0
        assert any(
            "lone" in e.lower() or "center" in e.lower() or "werewolf" in e.lower()
            for e in errors
        )

    def test_minion_rejects_center_index(self, db):
        """Minion uses see_team but must not be allowed center_index."""
        game, users = _create_game(
            {
                "alice": "Minion",
                "bob": "Werewolf",
                "carol": "Seer",
                "dave": "Villager",
                "eve": "Robber",
            },
            center_cards=["Troublemaker", "Drunk", "Villager"],
            current_wave=2,
        )
        pr = PlayerRole.objects.get(game=game, user=users["alice"])

        errors = validate_night_action(game, pr, "see_team", {"center_index": 0})

        assert len(errors) > 0
        assert any(
            "lone" in e.lower() or "center" in e.lower() or "werewolf" in e.lower()
            for e in errors
        )

    def test_lone_werewolf_allows_center_index(self, db):
        """A lone werewolf (no other werewolves among players) may peek center."""
        game, users = _create_game(
            {
                "alice": "Werewolf",
                "bob": "Seer",
                "carol": "Robber",
                "dave": "Villager",
                "eve": "Mason",
            },
            center_cards=["Werewolf", "Drunk", "Mason"],
            current_wave=2,
        )
        pr = PlayerRole.objects.get(game=game, user=users["alice"])

        errors = validate_night_action(game, pr, "see_team", {"center_index": 0})

        assert errors == []

    def test_lone_werewolf_rejects_out_of_range_center_index(self, db):
        """Lone werewolf center_index must still be in range."""
        game, users = _create_game(
            {
                "alice": "Werewolf",
                "bob": "Seer",
                "carol": "Robber",
                "dave": "Villager",
                "eve": "Mason",
            },
            center_cards=["Werewolf", "Drunk", "Mason"],
            current_wave=2,
        )
        pr = PlayerRole.objects.get(game=game, user=users["alice"])

        errors = validate_night_action(game, pr, "see_team", {"center_index": 5})

        assert len(errors) > 0

    def test_lone_werewolf_allows_empty_targets(self, db):
        """A lone werewolf may skip the center peek (optional action)."""
        game, users = _create_game(
            {
                "alice": "Werewolf",
                "bob": "Seer",
                "carol": "Robber",
                "dave": "Villager",
                "eve": "Mason",
            },
            center_cards=["Werewolf", "Drunk", "Mason"],
            current_wave=2,
        )
        pr = PlayerRole.objects.get(game=game, user=users["alice"])

        errors = validate_night_action(game, pr, "see_team", {})

        assert errors == []

    def test_doppelganger_as_lone_werewolf_allows_center_index(self, db):
        """Doppelganger-as-Werewolf with no other werewolves is a lone werewolf."""
        game, users = _create_game(
            {
                "alice": "Doppelganger",
                "bob": "Seer",
                "carol": "Robber",
                "dave": "Villager",
                "eve": "Mason",
            },
            center_cards=["Werewolf", "Drunk", "Mason"],
            current_wave=2,
        )
        # Set up Doppelganger as having copied Werewolf
        pr = PlayerRole.objects.get(game=game, user=users["alice"])
        pr.night_action_data = {"copied_role": "Werewolf"}
        pr.save(update_fields=["night_action_data"])

        errors = validate_night_action(game, pr, "see_team", {"center_index": 0})

        assert errors == []

    def test_doppelganger_as_werewolf_with_real_werewolf_rejects_center_index(self, db):
        """Doppelganger-as-Werewolf with a real werewolf present — not lone."""
        game, users = _create_game(
            {
                "alice": "Doppelganger",
                "bob": "Werewolf",
                "carol": "Seer",
                "dave": "Villager",
                "eve": "Robber",
            },
            center_cards=["Troublemaker", "Drunk", "Villager"],
            current_wave=2,
        )
        pr = PlayerRole.objects.get(game=game, user=users["alice"])
        pr.night_action_data = {"copied_role": "Werewolf"}
        pr.save(update_fields=["night_action_data"])

        errors = validate_night_action(game, pr, "see_team", {"center_index": 0})

        assert len(errors) > 0
        assert any("lone" in e.lower() or "center" in e.lower() for e in errors)
