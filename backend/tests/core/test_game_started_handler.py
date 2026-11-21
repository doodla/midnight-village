"""
Integration tests for game_started WebSocket handler in LobbyConsumer (FR-031).

Tests that game.started channel layer events are forwarded to connected
WebSocket clients as game_started messages.
"""

import uuid

import pytest
from channels.db import database_sync_to_async
from channels.testing import WebsocketCommunicator

from config.asgi import application

pytestmark = pytest.mark.integration


@database_sync_to_async
def create_lobby_with_user():
    """Create a lobby with host as a member and return (code, user)."""
    from apps.core.models import Lobby, LobbyMember, User

    username = f"gs_user_{uuid.uuid4().hex[:8]}"
    user = User.objects.create_user(username=username, password="pass")
    lobby = Lobby.objects.create(host=user, game_type="onuw")
    LobbyMember.objects.create(lobby=lobby, user=user)
    return lobby.code, user


def _make_communicator(path, user):
    """Create a WebSocket communicator with auth scope."""
    communicator = WebsocketCommunicator(application, path)
    communicator.scope["headers"] = [(b"origin", b"http://testserver")]
    communicator.scope["user"] = user
    return communicator


async def _next_event(communicator):
    """The next event that is not the table's own ``lobby_update`` (an ONUW table
    sends its body to the lobby socket when phones come and go)."""
    while True:
        event = await communicator.receive_json_from()
        if event["type"] != "lobby_update":
            return event


class TestGameStartedHandler:
    """Tests for LobbyConsumer.game_started event handler."""

    @pytest.mark.django_db(transaction=True)
    async def test_game_started_event_forwarded_to_clients(self):
        """Connected clients receive game_started event when game.started is sent."""
        code, user = await create_lobby_with_user()
        game_id = str(uuid.uuid4())

        communicator = _make_communicator(f"/ws/lobby/{code}/", user)
        connected, _ = await communicator.connect()
        assert connected

        from channels.layers import get_channel_layer

        channel_layer = get_channel_layer()
        assert channel_layer is not None

        await channel_layer.group_send(
            f"lobby_{code}",
            {
                "type": "game.started",
                "game_id": game_id,
            },
        )

        response = await communicator.receive_json_from()

        assert response["type"] == "game_started"
        assert response["game_id"] == game_id

        await communicator.disconnect()

    @pytest.mark.django_db(transaction=True)
    async def test_game_started_event_contains_game_id(self):
        """game_started event forwarded to clients includes the game_id field."""
        code, user = await create_lobby_with_user()
        expected_game_id = "aaaabbbb-cccc-dddd-eeee-ffffaaaabbbb"

        communicator = _make_communicator(f"/ws/lobby/{code}/", user)
        await communicator.connect()

        from channels.layers import get_channel_layer

        channel_layer = get_channel_layer()
        assert channel_layer is not None

        await channel_layer.group_send(
            f"lobby_{code}",
            {
                "type": "game.started",
                "game_id": expected_game_id,
            },
        )

        response = await communicator.receive_json_from()

        assert response["game_id"] == expected_game_id

        await communicator.disconnect()

    @pytest.mark.django_db(transaction=True)
    async def test_multiple_clients_receive_game_started(self):
        """All connected clients in a lobby receive the game_started event."""
        from apps.core.models import LobbyMember, User

        code, host = await create_lobby_with_user()

        # Create a second player and add to the lobby
        @database_sync_to_async
        def add_second_player():
            from apps.core.models import Lobby

            username = f"p2_{uuid.uuid4().hex[:8]}"
            player = User.objects.create_user(username=username, password="pass")
            lobby = Lobby.objects.get(code=code)
            LobbyMember.objects.create(lobby=lobby, user=player)
            return player

        player2 = await add_second_player()
        game_id = str(uuid.uuid4())

        comm1 = _make_communicator(f"/ws/lobby/{code}/", host)
        comm2 = _make_communicator(f"/ws/lobby/{code}/", player2)

        await comm1.connect()
        await comm2.connect()

        from channels.layers import get_channel_layer

        channel_layer = get_channel_layer()
        assert channel_layer is not None

        await channel_layer.group_send(
            f"lobby_{code}",
            {
                "type": "game.started",
                "game_id": game_id,
            },
        )

        msg1 = await _next_event(comm1)
        msg2 = await _next_event(comm2)

        assert msg1["type"] == "game_started"
        assert msg1["game_id"] == game_id
        assert msg2["type"] == "game_started"
        assert msg2["game_id"] == game_id

        await comm1.disconnect()
        await comm2.disconnect()
