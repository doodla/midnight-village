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


@pytest.mark.integration
class TestJoinLobby:
    """Test lobby join endpoint."""

    def test_user_can_join_lobby_by_code(self, api_client, db):
        """Users can join an existing lobby."""
        from apps.core.models import Lobby, LobbyMember, User

        host = User.objects.create_user(username="host", password="pass")
        player = User.objects.create_user(username="player", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")
        LobbyMember.objects.create(lobby=lobby, user=host)

        api_client.force_authenticate(user=player)
        url = reverse("core:lobby-join", kwargs={"code": lobby.code})
        response = api_client.post(url)

        assert response.status_code == status.HTTP_200_OK
        assert len(response.data["players"]) == 2

    def test_user_cannot_join_full_lobby(self, api_client, db):
        """Users cannot join a lobby that is full."""
        from apps.core.models import Lobby, LobbyMember, User

        host = User.objects.create_user(username="host", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw", max_players=2)
        LobbyMember.objects.create(lobby=lobby, user=host)

        # Add another player to fill the lobby
        player1 = User.objects.create_user(username="player1", password="pass")
        LobbyMember.objects.create(lobby=lobby, user=player1)

        # Try to join as third player
        player2 = User.objects.create_user(username="player2", password="pass")
        api_client.force_authenticate(user=player2)
        url = reverse("core:lobby-join", kwargs={"code": lobby.code})
        response = api_client.post(url)

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_user_cannot_join_lobby_twice(self, authenticated_client, user):
        """Users cannot join a lobby they're already in."""
        from apps.core.models import Lobby, LobbyMember

        lobby = Lobby.objects.create(host=user, game_type="onuw")
        LobbyMember.objects.create(lobby=lobby, user=user)

        url = reverse("core:lobby-join", kwargs={"code": lobby.code})
        response = authenticated_client.post(url)

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_user_cannot_join_non_waiting_lobby(self, api_client, db):
        """Users cannot join a lobby that is not in waiting state."""
        from apps.core.models import Lobby, LobbyMember, User

        host = User.objects.create_user(username="host", password="pass")
        player = User.objects.create_user(username="player", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw", status="in_game")
        LobbyMember.objects.create(lobby=lobby, user=host)

        api_client.force_authenticate(user=player)
        url = reverse("core:lobby-join", kwargs={"code": lobby.code})
        response = api_client.post(url)

        assert response.status_code == status.HTTP_400_BAD_REQUEST


@pytest.mark.integration
class TestLeaveLobby:
    """Test lobby leave endpoint."""

    def test_player_can_leave_lobby(self, api_client, db):
        """Players can leave a lobby."""
        from apps.core.models import Lobby, LobbyMember, User

        host = User.objects.create_user(username="host", password="pass")
        player = User.objects.create_user(username="player", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")
        LobbyMember.objects.create(lobby=lobby, user=host)
        LobbyMember.objects.create(lobby=lobby, user=player)

        api_client.force_authenticate(user=player)
        url = reverse("core:lobby-leave", kwargs={"code": lobby.code})
        response = api_client.post(url)

        assert response.status_code == status.HTTP_200_OK
        assert not LobbyMember.objects.filter(lobby=lobby, user=player).exists()

    def test_host_leaving_deletes_lobby(self, authenticated_client, user):
        """When the host leaves, the lobby is deleted."""
        from apps.core.models import Lobby, LobbyMember

        lobby = Lobby.objects.create(host=user, game_type="onuw")
        LobbyMember.objects.create(lobby=lobby, user=user)
        lobby_code = lobby.code

        url = reverse("core:lobby-leave", kwargs={"code": lobby.code})
        response = authenticated_client.post(url)

        assert response.status_code == status.HTTP_200_OK
        assert not Lobby.objects.filter(code=lobby_code).exists()

    def test_non_member_cannot_leave_lobby(self, api_client, db):
        """Users not in the lobby cannot leave it."""
        from apps.core.models import Lobby, LobbyMember, User

        host = User.objects.create_user(username="host", password="pass")
        outsider = User.objects.create_user(username="outsider", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")
        LobbyMember.objects.create(lobby=lobby, user=host)

        api_client.force_authenticate(user=outsider)
        url = reverse("core:lobby-leave", kwargs={"code": lobby.code})
        response = api_client.post(url)

        assert response.status_code == status.HTTP_400_BAD_REQUEST


@pytest.mark.integration
class TestLobbyReady:
    """Test lobby ready state endpoint."""

    def test_player_can_toggle_ready(self, api_client, db):
        """Players can toggle their ready state."""
        from apps.core.models import Lobby, LobbyMember, User

        host = User.objects.create_user(username="host", password="pass")
        player = User.objects.create_user(username="player", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")
        LobbyMember.objects.create(lobby=lobby, user=player)

        api_client.force_authenticate(user=player)
        url = reverse("core:lobby-ready", kwargs={"code": lobby.code})

        # Toggle to ready
        response = api_client.post(url, {"is_ready": True}, format="json")
        assert response.status_code == status.HTTP_200_OK

        player_in_lobby = LobbyMember.objects.get(lobby=lobby, user=player)
        assert player_in_lobby.is_ready is True

        # Toggle to not ready
        response = api_client.post(url, {"is_ready": False}, format="json")
        assert response.status_code == status.HTTP_200_OK

        player_in_lobby.refresh_from_db()
        assert player_in_lobby.is_ready is False

    def test_non_member_cannot_ready(self, api_client, db):
        """Users not in lobby cannot set ready state."""
        from apps.core.models import Lobby, User

        host = User.objects.create_user(username="host", password="pass")
        outsider = User.objects.create_user(username="outsider", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")

        api_client.force_authenticate(user=outsider)
        url = reverse("core:lobby-ready", kwargs={"code": lobby.code})
        response = api_client.post(url, {"is_ready": True}, format="json")

        assert response.status_code == status.HTTP_400_BAD_REQUEST
