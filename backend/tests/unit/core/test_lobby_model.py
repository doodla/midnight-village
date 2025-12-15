"""Unit tests for Lobby model."""

import pytest


@pytest.mark.unit
class TestLobbyModel:
    """Test Lobby model behavior."""

    def test_lobby_generates_unique_code_on_create(self, db):
        """Lobby generates a 6-character code when created."""
        from apps.core.models import Lobby, User

        host = User.objects.create_user(username="host", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")

        assert lobby.code is not None
        assert len(lobby.code) == 6
        assert lobby.code.isalnum()

    def test_lobby_code_is_unique(self, db):
        """Each lobby gets a unique code."""
        from apps.core.models import Lobby, User

        host = User.objects.create_user(username="host", password="pass")
        lobby1 = Lobby.objects.create(host=host, game_type="onuw")
        lobby2 = Lobby.objects.create(host=host, game_type="onuw")

        assert lobby1.code != lobby2.code

    def test_lobby_default_status_is_waiting(self, db):
        """New lobbies have 'waiting' status."""
        from apps.core.models import Lobby, User

        host = User.objects.create_user(username="host", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")

        assert lobby.status == "waiting"

    def test_lobby_str_representation(self, db):
        """Lobby string representation includes code and game type."""
        from apps.core.models import Lobby, User

        host = User.objects.create_user(username="host", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")

        assert lobby.code in str(lobby)
        assert "onuw" in str(lobby)
