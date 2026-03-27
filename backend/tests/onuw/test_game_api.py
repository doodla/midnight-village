"""Integration tests for ONUW game API endpoints."""

from django.urls import reverse

import pytest
from rest_framework import status

from apps.core.models import Lobby, LobbyMember, User
from apps.onuw.models import Game, PlayerRole

pytestmark = pytest.mark.integration


def _create_lobby_with_players(host, players, role_config):
    """Helper to create a lobby with players and role config."""
    lobby = Lobby.objects.create(
        host=host,
        game_type="onuw",
        max_players=10,
        settings={"roles": role_config},
    )
    LobbyMember.objects.create(lobby=lobby, user=host, is_ready=True)
    for player in players:
        LobbyMember.objects.create(lobby=lobby, user=player, is_ready=True)
    return lobby


def _standard_5p_roles():
    """Standard 5-player role config (8 total roles)."""
    return {
        "Werewolf": 2,
        "Seer": 1,
        "Robber": 1,
        "Villager": 1,
        "Drunk": 1,
        "Insomniac": 1,
        "Troublemaker": 1,
    }


class TestGameStart:
    """Test the POST /api/onuw/lobbies/<code>/start/ endpoint."""

    def test_host_can_start_game(self, api_client, db):
        """Host can start a game when all preconditions are met."""
        host = User.objects.create_user(username="host", password="pass")
        players = [
            User.objects.create_user(username=f"p{i}", password="pass")
            for i in range(4)
        ]
        lobby = _create_lobby_with_players(host, players, _standard_5p_roles())

        api_client.force_authenticate(user=host)
        url = reverse("onuw:game-start", kwargs={"code": lobby.code})
        response = api_client.post(url)

        assert response.status_code == status.HTTP_201_CREATED
        assert "game_id" in response.data
        assert response.data["phase"] == "night"

        # Verify database state
        game = Game.objects.get(id=response.data["game_id"])
        assert game.lobby == lobby
        assert game.phase == "night"
        assert PlayerRole.objects.filter(game=game).count() == 5
        assert len(game.center_cards) == 3

        # Verify lobby status updated
        lobby.refresh_from_db()
        assert lobby.status == Lobby.Status.IN_GAME

    def test_non_host_cannot_start(self, api_client, db):
        """Non-host players cannot start the game (403)."""
        host = User.objects.create_user(username="host", password="pass")
        player = User.objects.create_user(username="player", password="pass")
        lobby = _create_lobby_with_players(
            host,
            [player],
            {
                "Werewolf": 1,
                "Seer": 1,
                "Robber": 1,
                "Villager": 2,
            },
        )

        api_client.force_authenticate(user=player)
        url = reverse("onuw:game-start", kwargs={"code": lobby.code})
        response = api_client.post(url)

        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_not_all_ready_returns_400(self, api_client, db):
        """Starting fails if not all players are ready."""
        host = User.objects.create_user(username="host", password="pass")
        player = User.objects.create_user(username="player", password="pass")

        lobby = Lobby.objects.create(
            host=host,
            game_type="onuw",
            settings={
                "roles": {
                    "Werewolf": 1,
                    "Seer": 1,
                    "Robber": 1,
                    "Villager": 2,
                }
            },
        )
        LobbyMember.objects.create(lobby=lobby, user=host, is_ready=True)
        LobbyMember.objects.create(lobby=lobby, user=player, is_ready=False)

        api_client.force_authenticate(user=host)
        url = reverse("onuw:game-start", kwargs={"code": lobby.code})
        response = api_client.post(url)

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "not all players" in response.data["detail"].lower()

    def test_invalid_role_config_returns_400(self, api_client, db):
        """Starting fails with invalid role configuration."""
        host = User.objects.create_user(username="host", password="pass")
        players = [
            User.objects.create_user(username=f"p{i}", password="pass")
            for i in range(4)
        ]
        # Wrong count: only 3 roles for 5 players (need 8)
        lobby = _create_lobby_with_players(
            host,
            players,
            {
                "Werewolf": 2,
                "Seer": 1,
            },
        )

        api_client.force_authenticate(user=host)
        url = reverse("onuw:game-start", kwargs={"code": lobby.code})
        response = api_client.post(url)

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_start_nonexistent_lobby_returns_404(self, api_client, db):
        """Starting a game with a non-existent lobby code returns 404."""
        host = User.objects.create_user(username="host", password="pass")
        api_client.force_authenticate(user=host)
        url = reverse("onuw:game-start", kwargs={"code": "XXXXXX"})
        response = api_client.post(url)

        assert response.status_code == status.HTTP_404_NOT_FOUND

    def test_cannot_start_non_waiting_lobby(self, api_client, db):
        """Cannot start a game from a lobby not in waiting state."""
        host = User.objects.create_user(username="host", password="pass")
        lobby = Lobby.objects.create(
            host=host,
            game_type="onuw",
            status=Lobby.Status.IN_GAME,
            settings={"roles": _standard_5p_roles()},
        )
        LobbyMember.objects.create(lobby=lobby, user=host, is_ready=True)

        api_client.force_authenticate(user=host)
        url = reverse("onuw:game-start", kwargs={"code": lobby.code})
        response = api_client.post(url)

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_game_start_broadcasts_event(self, api_client, db):
        """Starting a game broadcasts a game_started event."""
        from unittest.mock import MagicMock, patch

        host = User.objects.create_user(username="host", password="pass")
        players = [
            User.objects.create_user(username=f"p{i}", password="pass")
            for i in range(4)
        ]
        lobby = _create_lobby_with_players(host, players, _standard_5p_roles())

        mock_channel_layer = MagicMock()
        with (
            patch(
                "apps.onuw.views.get_channel_layer",
                return_value=mock_channel_layer,
            ),
            patch("apps.onuw.views.async_to_sync") as mock_views_a2s,
            patch(
                "apps.onuw.services.get_channel_layer",
                return_value=mock_channel_layer,
            ),
            patch("apps.onuw.services.async_to_sync") as _mock_services_a2s,
        ):
            api_client.force_authenticate(user=host)
            url = reverse("onuw:game-start", kwargs={"code": lobby.code})
            response = api_client.post(url)

            assert response.status_code == status.HTTP_201_CREATED

            # The views module calls async_to_sync for the lobby broadcast
            mock_views_a2s.assert_called_once_with(mock_channel_layer.group_send)
            call_args = mock_views_a2s.return_value.call_args
            assert call_args[0][0] == f"lobby_{lobby.code}"
            assert call_args[0][1]["type"] == "game.started"
            assert call_args[0][1]["game_id"] == str(response.data["game_id"])
            assert call_args[0][1]["phase"] == "night"


class TestGameMe:
    """Test the GET /api/onuw/games/<game_id>/me/ endpoint."""

    def _create_started_game(self):
        """Helper to create a game with 5 players already started."""
        host = User.objects.create_user(username="host_me", password="pass")
        players = [
            User.objects.create_user(username=f"me_p{i}", password="pass")
            for i in range(4)
        ]
        all_players = [host, *players]
        lobby = _create_lobby_with_players(host, players, _standard_5p_roles())

        game = Game.objects.create(
            lobby=lobby,
            phase="night",
            random_seed=42,
            settings=lobby.settings,
            center_cards=["Werewolf", "Drunk", "Insomniac"],
        )

        roles = ["Seer", "Robber", "Villager", "Werewolf", "Troublemaker"]
        for player, role in zip(all_players, roles, strict=True):
            PlayerRole.objects.create(
                game=game,
                user=player,
                original_role=role,
                current_role=role,
            )

        return game, all_players

    def test_player_sees_own_role(self, api_client, db):
        """A player can see their own role through /me/ endpoint."""
        game, players = self._create_started_game()
        player = players[0]  # Seer

        api_client.force_authenticate(user=player)
        url = reverse("onuw:game-me", kwargs={"game_id": str(game.id)})
        response = api_client.get(url)

        assert response.status_code == status.HTTP_200_OK
        assert response.data["game_id"] == str(game.id)
        assert response.data["phase"] == "night"
        assert response.data["your_role"]["original_role"] == "Seer"
        assert "current_role" not in response.data["your_role"]  # Hidden before results
        assert response.data["your_role"]["has_acted"] is False

    def test_player_cannot_see_other_player_role(self, api_client, db):
        """Player A's /me/ response does not contain Player B's role."""
        game, players = self._create_started_game()
        player_a = players[0]  # Seer

        api_client.force_authenticate(user=player_a)
        url = reverse("onuw:game-me", kwargs={"game_id": str(game.id)})
        response = api_client.get(url)

        response_str = str(response.data)
        # Player B is Robber, Player D is Werewolf - should not appear
        assert response.data["your_role"]["original_role"] == "Seer"
        # Ensure other player roles are not present in the response
        # Only Seer should appear (player A's role)
        assert "Robber" not in response_str
        assert "Werewolf" not in response_str
        assert "Troublemaker" not in response_str

    def test_center_cards_not_visible(self, api_client, db):
        """Center cards are never exposed through the /me/ endpoint."""
        game, players = self._create_started_game()

        api_client.force_authenticate(user=players[0])
        url = reverse("onuw:game-me", kwargs={"game_id": str(game.id)})
        response = api_client.get(url)

        assert "center_cards" not in response.data

    def test_non_player_gets_403(self, api_client, db):
        """A user not in the game gets 403."""
        game, _ = self._create_started_game()
        outsider = User.objects.create_user(username="outsider", password="pass")

        api_client.force_authenticate(user=outsider)
        url = reverse("onuw:game-me", kwargs={"game_id": str(game.id)})
        response = api_client.get(url)

        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_nonexistent_game_returns_404(self, api_client, db):
        """Requesting a non-existent game returns 404."""
        user = User.objects.create_user(username="someone", password="pass")
        api_client.force_authenticate(user=user)
        url = reverse(
            "onuw:game-me",
            kwargs={"game_id": "00000000-0000-0000-0000-000000000000"},
        )
        response = api_client.get(url)

        assert response.status_code == status.HTTP_404_NOT_FOUND

    def test_invalid_uuid_returns_404(self, api_client, db):
        """An invalid UUID in the URL returns 404."""
        user = User.objects.create_user(username="someone2", password="pass")
        api_client.force_authenticate(user=user)
        url = reverse("onuw:game-me", kwargs={"game_id": "not-a-uuid"})
        response = api_client.get(url)

        assert response.status_code == status.HTTP_404_NOT_FOUND
