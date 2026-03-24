"""
Integration tests for the ONUW Results API endpoint.

Tests GET /api/onuw/games/<game_id>/results/.
"""

from unittest.mock import patch

from django.urls import reverse

import pytest
from rest_framework import status

from apps.core.models import Lobby, LobbyMember, User
from apps.onuw.models import Game, Phase, PlayerRole

pytestmark = pytest.mark.integration


def _create_game_in_results(
    players_roles: dict[str, str],
    center_cards: list[str],
    votes: dict[str, str] | None = None,
    host_username: str | None = None,
):
    """
    Create a game already in RESULTS phase with win conditions computed.

    players_roles: username -> role
    votes: voter_username -> target_username (optional)
    Returns (game, users_dict, host_user).
    """
    usernames = list(players_roles.keys())
    users = {}
    for uname in usernames:
        users[uname] = User.objects.create_user(
            username=uname, password="pass", display_name=uname
        )

    host_key = host_username or usernames[0]
    host = users[host_key]
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
        phase=Phase.VOTING,
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

    # Submit votes and trigger reveal (which computes win conditions)
    if votes:
        for voter_name, target_name in votes.items():
            pr = PlayerRole.objects.get(game=game, user=users[voter_name])
            pr.vote_target = users[target_name]
            pr.has_acted = True
            pr.save(update_fields=["vote_target", "has_acted"])

    # Trigger reveal_votes to compute win conditions
    with patch("apps.onuw.services.get_channel_layer", return_value=None):
        from apps.onuw.services import reveal_votes

        reveal_votes(game)

    game.refresh_from_db()
    return game, users, host


def _results_url(game_id):
    return reverse("onuw:results", kwargs={"game_id": str(game_id)})


def _patch_channels():
    return patch("apps.onuw.services.get_channel_layer", return_value=None)


class TestResultsEndpoint:
    """Tests for GET /api/onuw/games/<game_id>/results/."""

    def test_results_endpoint_returns_full_reveal(self, api_client, db):
        """Results endpoint returns complete game state reveal."""
        game, users, _host = _create_game_in_results(
            {
                "host_res": "Werewolf",
                "p1_res": "Seer",
                "p2_res": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            votes={
                "host_res": "p1_res",
                "p1_res": "host_res",
                "p2_res": "host_res",
            },
        )

        api_client.force_authenticate(user=users["p1_res"])
        response = api_client.get(_results_url(game.id))

        assert response.status_code == status.HTTP_200_OK
        data = response.data

        # Check required fields exist
        assert "winning_team" in data
        assert "reason" in data
        assert "eliminated_players" in data
        assert "players" in data
        assert "center_cards" in data
        assert "night_actions_log" in data

        # Check players data structure
        assert len(data["players"]) == 3
        for player in data["players"]:
            assert "player_id" in player
            assert "display_name" in player
            assert "original_role" in player
            assert "final_role" in player
            assert "outcome" in player
            assert "vote_target_id" in player

    def test_results_returns_403_before_results_phase(self, api_client, db):
        """Cannot access results before game is in RESULTS phase."""
        users = {}
        for uname in ["host_403", "p1_403"]:
            users[uname] = User.objects.create_user(username=uname, password="pass")

        host = users["host_403"]
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
            phase=Phase.VOTING,
            current_wave=0,
            random_seed=42,
            settings=lobby.settings,
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
        )
        PlayerRole.objects.create(
            game=game, user=host, original_role="Werewolf", current_role="Werewolf"
        )
        PlayerRole.objects.create(
            game=game,
            user=users["p1_403"],
            original_role="Seer",
            current_role="Seer",
        )

        api_client.force_authenticate(user=host)
        response = api_client.get(_results_url(game.id))

        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_results_returns_all_votes(self, api_client, db):
        """Results include vote targets for all players."""
        game, users, _host = _create_game_in_results(
            {
                "host_rv": "Werewolf",
                "p1_rv": "Seer",
                "p2_rv": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            votes={
                "host_rv": "p1_rv",
                "p1_rv": "host_rv",
                "p2_rv": "host_rv",
            },
        )

        api_client.force_authenticate(user=users["p1_rv"])
        response = api_client.get(_results_url(game.id))

        assert response.status_code == status.HTTP_200_OK

        # Build vote map from response
        vote_map = {}
        for player in response.data["players"]:
            vote_map[player["player_id"]] = player["vote_target_id"]

        assert vote_map[users["host_rv"].id] == users["p1_rv"].id
        assert vote_map[users["p1_rv"].id] == users["host_rv"].id
        assert vote_map[users["p2_rv"].id] == users["host_rv"].id

    def test_results_returns_winning_team(self, api_client, db):
        """Results include the correct winning team."""
        game, users, _host = _create_game_in_results(
            {
                "host_wt": "Werewolf",
                "p1_wt": "Seer",
                "p2_wt": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            votes={
                "host_wt": "p1_wt",
                "p1_wt": "host_wt",
                "p2_wt": "host_wt",
            },
        )

        api_client.force_authenticate(user=users["p1_wt"])
        response = api_client.get(_results_url(game.id))

        assert response.status_code == status.HTTP_200_OK
        assert response.data["winning_team"] == "village"

    def test_non_player_gets_403(self, api_client, db):
        """A user not in the game gets 403."""
        game, _users, _host = _create_game_in_results(
            {
                "host_np": "Werewolf",
                "p1_np": "Seer",
                "p2_np": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            votes={
                "host_np": "p1_np",
                "p1_np": "host_np",
                "p2_np": "host_np",
            },
        )

        outsider = User.objects.create_user(
            username="outsider_results", password="pass"
        )
        api_client.force_authenticate(user=outsider)
        response = api_client.get(_results_url(game.id))

        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_results_nonexistent_game_returns_404(self, api_client, db):
        """Requesting results for non-existent game returns 404."""
        user = User.objects.create_user(username="someone_r404", password="pass")
        api_client.force_authenticate(user=user)
        url = reverse(
            "onuw:results",
            kwargs={"game_id": "00000000-0000-0000-0000-000000000000"},
        )
        response = api_client.get(url)

        assert response.status_code == status.HTTP_404_NOT_FOUND

    def test_results_shows_eliminated_player_details(self, api_client, db):
        """Eliminated players section includes display_name and role."""
        game, users, _host = _create_game_in_results(
            {
                "host_ep": "Werewolf",
                "p1_ep": "Seer",
                "p2_ep": "Villager",
            },
            center_cards=["Drunk", "Insomniac", "Troublemaker"],
            votes={
                "host_ep": "p1_ep",
                "p1_ep": "host_ep",
                "p2_ep": "host_ep",
            },
        )

        api_client.force_authenticate(user=users["p1_ep"])
        response = api_client.get(_results_url(game.id))

        assert response.status_code == status.HTTP_200_OK
        eliminated = response.data["eliminated_players"]
        assert len(eliminated) >= 1

        # Find the eliminated werewolf
        elim_ids = [e["player_id"] for e in eliminated]
        assert users["host_ep"].id in elim_ids

        ww_entry = next(e for e in eliminated if e["player_id"] == users["host_ep"].id)
        assert ww_entry["role"] == "Werewolf"
        assert ww_entry["display_name"] == "host_ep"
