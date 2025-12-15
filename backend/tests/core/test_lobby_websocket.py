"""Integration tests for Lobby WebSocket consumer."""

import uuid

import pytest
from channels.db import database_sync_to_async
from channels.testing import WebsocketCommunicator

from config.asgi import application


@database_sync_to_async
def create_lobby_with_user():
    """Create a lobby and return the code and user."""
    from apps.core.models import Lobby, User

    username = f"wsuser_{uuid.uuid4().hex[:8]}"
    user = User.objects.create_user(username=username, password="pass")
    lobby = Lobby.objects.create(host=user, game_type="onuw")
    return lobby.code, user


class TestLobbyWebSocket:
    """Test Lobby WebSocket consumer."""

    @pytest.mark.django_db(transaction=True)
    async def test_connect_to_lobby(self):
        """Users can connect to a lobby WebSocket."""
        code, _user = await create_lobby_with_user()

        communicator = WebsocketCommunicator(
            application,
            f"/ws/lobby/{code}/",
        )
        communicator.scope["headers"] = [(b"origin", b"http://testserver")]
        connected, _close_code = await communicator.connect()

        assert connected

        await communicator.disconnect()

    @pytest.mark.django_db(transaction=True)
    async def test_connect_to_nonexistent_lobby_fails(self):
        """Connecting to nonexistent lobby closes connection."""
        communicator = WebsocketCommunicator(
            application,
            "/ws/lobby/XXXXXX/",
        )
        communicator.scope["headers"] = [(b"origin", b"http://testserver")]
        connected, close_code = await communicator.connect()

        assert not connected or close_code == 4004

        await communicator.disconnect()

    @pytest.mark.django_db(transaction=True)
    async def test_receive_player_joined_event(self):
        """Connected clients receive player_joined events."""
        from apps.core.models import LobbyMember, User

        code, _host = await create_lobby_with_user()

        # Connect as host
        communicator = WebsocketCommunicator(
            application,
            f"/ws/lobby/{code}/",
        )
        communicator.scope["headers"] = [(b"origin", b"http://testserver")]
        await communicator.connect()

        # Another player joins
        @database_sync_to_async
        def add_player():
            from apps.core.models import Lobby

            username = f"player_{uuid.uuid4().hex[:8]}"
            player = User.objects.create_user(username=username, password="pass")
            lobby = Lobby.objects.get(code=code)
            LobbyMember.objects.create(lobby=lobby, user=player)
            return player.username

        player_username = await add_player()

        # Send event through channel layer
        from channels.layers import get_channel_layer

        channel_layer = get_channel_layer()
        assert channel_layer is not None
        await channel_layer.group_send(
            f"lobby_{code}",
            {
                "type": "player.joined",
                "username": player_username,
            },
        )

        # Receive the message
        response = await communicator.receive_json_from()

        assert response["type"] == "player_joined"
        assert response["username"] == player_username

        await communicator.disconnect()
