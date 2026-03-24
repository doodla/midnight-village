"""Unit tests for LobbyMember model."""

import pytest

pytestmark = pytest.mark.unit


class TestLobbyMemberModel:
    """Test LobbyMember model behavior."""

    def test_player_can_join_lobby(self, db):
        """A user can join a lobby as a player."""
        from apps.core.models import Lobby, LobbyMember, User

        host = User.objects.create_user(username="host", password="pass")
        player = User.objects.create_user(username="player", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")

        membership = LobbyMember.objects.create(lobby=lobby, user=player)

        assert membership.lobby == lobby
        assert membership.user == player
        assert membership.is_ready is False

    def test_player_cannot_join_same_lobby_twice(self, db):
        """A user cannot join the same lobby twice."""
        from django.db import IntegrityError

        from apps.core.models import Lobby, LobbyMember, User

        host = User.objects.create_user(username="host", password="pass")
        player = User.objects.create_user(username="player", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")

        LobbyMember.objects.create(lobby=lobby, user=player)

        with pytest.raises(IntegrityError):
            LobbyMember.objects.create(lobby=lobby, user=player)

    def test_players_ordered_by_join_time(self, db):
        """Players are ordered by when they joined."""
        from apps.core.models import Lobby, LobbyMember, User

        host = User.objects.create_user(username="host", password="pass")
        player1 = User.objects.create_user(username="player1", password="pass")
        player2 = User.objects.create_user(username="player2", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw")

        lp1 = LobbyMember.objects.create(lobby=lobby, user=player1)
        lp2 = LobbyMember.objects.create(lobby=lobby, user=player2)

        players = list(LobbyMember.objects.filter(lobby=lobby))
        assert players[0] == lp1
        assert players[1] == lp2
