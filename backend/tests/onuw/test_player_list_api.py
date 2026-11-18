"""
Integration tests for the ONUW Player List API endpoint.

Tests the GET /api/onuw/games/<game_id>/players/ endpoint.
"""

from unittest.mock import patch

from django.urls import reverse

import pytest
from rest_framework import status

from apps.core.models import Lobby, LobbyMember, User
from apps.onuw.models import Game, Phase, PlayerRole

pytestmark = pytest.mark.integration


def _create_game(
    players_roles: dict[str, str],
    center_cards: list[str],
    phase: str = Phase.NIGHT,
):
    """
    Create a game with specific role assignments.

    Returns (game, users_dict, host_user) where users_dict maps username -> User.
    The first key in players_roles is the host.
    """
    usernames = list(players_roles.keys())
    users = {}
    for uname in usernames:
        users[uname] = User.objects.create_user(
            username=uname,
            password="pass",
            display_name=uname.replace("_", " ").title(),
        )

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
        phase=phase,
        current_wave=0,
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

    return game, users, host


def _players_url(game_id):
    return reverse("onuw:player-list", kwargs={"game_id": str(game_id)})


def _patch_channels():
    """Context manager to mock out channel layer so WebSocket sends are no-ops."""
    return patch("apps.onuw.services.get_channel_layer", return_value=None)


class TestPlayerList:
    """Tests for GET /api/onuw/games/<game_id>/players/."""

    def test_player_list_returns_all_players(self, api_client, db):
        """The player list contains all players in the game."""
        game, users, host = _create_game(
            {
                "pl_host": "Werewolf",
                "pl_p1": "Seer",
                "pl_p2": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
        )

        api_client.force_authenticate(user=host)
        response = api_client.get(_players_url(game.id))

        assert response.status_code == status.HTTP_200_OK
        assert "players" in response.data
        assert len(response.data["players"]) == 3

        # Check all player IDs are present
        returned_ids = {p["player_id"] for p in response.data["players"]}
        expected_ids = {u.id for u in users.values()}
        assert returned_ids == expected_ids

        # Check display names are present
        for p in response.data["players"]:
            assert "display_name" in p
            assert isinstance(p["display_name"], str)
            assert len(p["display_name"]) > 0

    def test_player_list_hides_roles(self, api_client, db):
        """The player list response never contains role information."""
        game, _users, host = _create_game(
            {
                "plr_host": "Werewolf",
                "plr_p1": "Seer",
                "plr_p2": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
        )

        api_client.force_authenticate(user=host)
        response = api_client.get(_players_url(game.id))

        assert response.status_code == status.HTTP_200_OK

        # Convert entire response to string and check for role leaks
        response_str = str(response.data)
        assert "Werewolf" not in response_str
        assert "Seer" not in response_str
        assert "Villager" not in response_str
        assert "original_role" not in response_str
        assert "current_role" not in response_str
        assert "night_action_data" not in response_str
        assert "vote_target" not in response_str

        # Verify individual player entries only contain expected keys
        for p in response.data["players"]:
            assert set(p.keys()) == {"player_id", "display_name", "connected"}

    def test_player_list_shows_vote_status_during_voting(self, api_client, db):
        """During voting phase, each player entry includes has_voted status."""
        game, users, host = _create_game(
            {
                "plv_host": "Werewolf",
                "plv_p1": "Seer",
                "plv_p2": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.VOTING,
        )

        # Mark plv_p1 as having voted
        pr_p1 = PlayerRole.objects.get(game=game, user=users["plv_p1"])
        pr_p1.has_acted = True
        pr_p1.save(update_fields=["has_acted"])

        api_client.force_authenticate(user=host)
        response = api_client.get(_players_url(game.id))

        assert response.status_code == status.HTTP_200_OK

        # Build a map for easy assertions
        vote_map = {p["player_id"]: p["has_voted"] for p in response.data["players"]}

        assert vote_map[users["plv_p1"].id] is True
        assert vote_map[users["plv_host"].id] is False
        assert vote_map[users["plv_p2"].id] is False

        # Verify has_voted is present but vote_target is not
        for p in response.data["players"]:
            assert "has_voted" in p
            assert "vote_target" not in p
            assert set(p.keys()) == {
                "player_id",
                "display_name",
                "connected",
                "has_voted",
            }

    def test_non_player_gets_403(self, api_client, db):
        """A user not in the game gets 403 when requesting player list."""
        game, _users, _host = _create_game(
            {
                "pln_host": "Werewolf",
                "pln_p1": "Seer",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
        )

        outsider = User.objects.create_user(username="pl_outsider", password="pass")
        api_client.force_authenticate(user=outsider)

        response = api_client.get(_players_url(game.id))

        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_nonexistent_game_returns_404(self, api_client, db):
        """Requesting players for a non-existent game returns 404."""
        user = User.objects.create_user(username="pl_nobody", password="pass")
        api_client.force_authenticate(user=user)

        url = reverse(
            "onuw:player-list",
            kwargs={"game_id": "00000000-0000-0000-0000-000000000000"},
        )
        response = api_client.get(url)

        assert response.status_code == status.HTTP_404_NOT_FOUND

    def test_player_list_no_vote_status_outside_voting_phase(self, api_client, db):
        """Outside voting phase, has_voted is not included in player entries."""
        game, _users, host = _create_game(
            {
                "plnv_host": "Werewolf",
                "plnv_p1": "Seer",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            phase=Phase.DISCUSSION,
        )

        api_client.force_authenticate(user=host)
        response = api_client.get(_players_url(game.id))

        assert response.status_code == status.HTTP_200_OK

        for p in response.data["players"]:
            assert "has_voted" not in p
