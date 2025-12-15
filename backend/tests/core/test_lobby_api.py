"""Integration tests for Lobby API endpoints."""

from django.urls import reverse

import pytest
from rest_framework import status


@pytest.mark.integration
class TestCreateLobby:
    """Test lobby creation endpoint."""

    def test_authenticated_user_can_create_lobby(self, authenticated_client):
        """Authenticated users can create a new lobby."""
        url = reverse("core:lobby-list")
        response = authenticated_client.post(
            url,
            {"game_type": "onuw", "max_players": 8},
            format="json",
        )

        assert response.status_code == status.HTTP_201_CREATED
        assert "code" in response.data
        assert len(response.data["code"]) == 6
        assert response.data["game_type"] == "onuw"
        assert response.data["status"] == "waiting"

    def test_unauthenticated_user_cannot_create_lobby(self, api_client):
        """Unauthenticated users cannot create lobbies."""
        url = reverse("core:lobby-list")
        response = api_client.post(
            url,
            {"game_type": "onuw"},
            format="json",
        )

        assert response.status_code == status.HTTP_401_UNAUTHORIZED


@pytest.mark.integration
class TestGetLobby:
    """Test lobby retrieval endpoints."""

    def test_get_lobby_by_code(self, authenticated_client, user):
        """Users can retrieve a lobby by its code."""
        from apps.core.models import Lobby, LobbyMember

        lobby = Lobby.objects.create(host=user, game_type="onuw")
        LobbyMember.objects.create(lobby=lobby, user=user)

        url = reverse("core:lobby-detail", kwargs={"code": lobby.code})
        response = authenticated_client.get(url)

        assert response.status_code == status.HTTP_200_OK
        assert response.data["code"] == lobby.code
        assert response.data["game_type"] == "onuw"
        assert "players" in response.data
        assert len(response.data["players"]) == 1  # Host auto-joined

    def test_get_nonexistent_lobby_returns_404(self, authenticated_client):
        """Requesting a nonexistent lobby returns 404."""
        url = reverse("core:lobby-detail", kwargs={"code": "XXXXXX"})
        response = authenticated_client.get(url)

        assert response.status_code == status.HTTP_404_NOT_FOUND
