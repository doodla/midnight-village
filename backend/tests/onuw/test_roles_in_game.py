"""
Integration tests for roles_in_game field in GameMeSerializer (FR-032).

Tests GET /api/onuw/games/<id>/me/ returns roles_in_game field.
"""

from unittest.mock import patch

from django.urls import reverse

import pytest
from rest_framework import status

from apps.core.models import Lobby, LobbyMember, User
from apps.onuw.models import Game, Phase, PlayerRole

pytestmark = pytest.mark.integration


def _game_me_url(game_id):
    return reverse("onuw:game-me", kwargs={"game_id": str(game_id)})


def _create_game_with_settings(roles: dict, phase: str = Phase.DISCUSSION):
    """
    Create a minimal game with specified roles in settings.

    Returns (game, host_user).
    """
    host = User.objects.create_user(username="roles_host", password="pass")
    player2 = User.objects.create_user(username="roles_p2", password="pass")
    player3 = User.objects.create_user(username="roles_p3", password="pass")

    lobby = Lobby.objects.create(
        host=host,
        game_type="onuw",
        max_players=10,
        settings={"roles": roles},
    )
    for u in [host, player2, player3]:
        LobbyMember.objects.create(lobby=lobby, user=u)
    lobby.status = Lobby.Status.IN_GAME
    lobby.save()

    game = Game.objects.create(
        lobby=lobby,
        phase=phase,
        current_wave=0,
        random_seed=42,
        settings=lobby.settings,
        center_cards=["Villager", "Drunk", "Insomniac"],
    )

    for u, role in [(host, "Werewolf"), (player2, "Seer"), (player3, "Villager")]:
        PlayerRole.objects.create(
            game=game, user=u, original_role=role, current_role=role
        )

    return game, host


class TestRolesInGame:
    """Tests for the roles_in_game field on GameMeSerializer."""

    def test_roles_in_game_field_present_in_response(self, api_client, db):
        """GET /onuw/games/<id>/me/ includes roles_in_game field."""
        roles = {"Werewolf": 2, "Seer": 1, "Villager": 2, "Drunk": 1}
        game, host = _create_game_with_settings(roles)

        api_client.force_authenticate(user=host)
        with patch("apps.core.effects.get_channel_layer", return_value=None):
            response = api_client.get(_game_me_url(game.id))

        assert response.status_code == status.HTTP_200_OK
        assert "roles_in_game" in response.data

    def test_roles_in_game_correct_format(self, api_client, db):
        """roles_in_game is a list of {role, count} dicts."""
        roles = {"Werewolf": 2, "Seer": 1, "Villager": 2, "Drunk": 1}
        game, host = _create_game_with_settings(roles)

        api_client.force_authenticate(user=host)
        with patch("apps.core.effects.get_channel_layer", return_value=None):
            response = api_client.get(_game_me_url(game.id))

        assert response.status_code == status.HTTP_200_OK
        roles_in_game = response.data["roles_in_game"]

        assert isinstance(roles_in_game, list)
        for entry in roles_in_game:
            assert "role" in entry
            assert "count" in entry
            assert isinstance(entry["count"], int)

    def test_roles_in_game_matches_game_settings(self, api_client, db):
        """roles_in_game entries match the roles stored in game settings."""
        roles = {"Werewolf": 2, "Seer": 1, "Villager": 2, "Drunk": 1}
        game, host = _create_game_with_settings(roles)

        api_client.force_authenticate(user=host)
        with patch("apps.core.effects.get_channel_layer", return_value=None):
            response = api_client.get(_game_me_url(game.id))

        roles_in_game = response.data["roles_in_game"]
        result_dict = {entry["role"]: entry["count"] for entry in roles_in_game}

        assert result_dict == roles

    def test_roles_in_game_present_during_discussion_phase(self, api_client, db):
        """roles_in_game is present during discussion phase."""
        roles = {"Werewolf": 2, "Seer": 1, "Villager": 2, "Drunk": 1}
        game, host = _create_game_with_settings(roles, phase=Phase.DISCUSSION)

        api_client.force_authenticate(user=host)
        with patch("apps.core.effects.get_channel_layer", return_value=None):
            response = api_client.get(_game_me_url(game.id))

        assert response.status_code == status.HTTP_200_OK
        assert "roles_in_game" in response.data

    def test_roles_in_game_present_during_voting_phase(self, api_client, db):
        """roles_in_game is present during voting phase."""
        roles = {"Werewolf": 2, "Seer": 1, "Villager": 2, "Drunk": 1}
        game, host = _create_game_with_settings(roles, phase=Phase.VOTING)

        api_client.force_authenticate(user=host)
        with patch("apps.core.effects.get_channel_layer", return_value=None):
            response = api_client.get(_game_me_url(game.id))

        assert response.status_code == status.HTTP_200_OK
        assert "roles_in_game" in response.data
