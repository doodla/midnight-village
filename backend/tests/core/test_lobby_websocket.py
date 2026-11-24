"""Integration tests for Lobby WebSocket consumer."""

import uuid

import pytest
from channels.db import database_sync_to_async
from channels.testing import WebsocketCommunicator

from config.asgi import application

pytestmark = pytest.mark.integration


@database_sync_to_async
def create_lobby_with_user():
    """Create a lobby with host as a member and return the code and user."""
    from apps.core.models import Lobby, LobbyMember, User

    username = f"wsuser_{uuid.uuid4().hex[:8]}"
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


class TestLobbyWebSocket:
    """Test Lobby WebSocket consumer."""

    @pytest.mark.django_db(transaction=True)
    async def test_connect_to_lobby(self):
        """Authenticated lobby members can connect to a lobby WebSocket."""
        code, user = await create_lobby_with_user()

        communicator = _make_communicator(f"/ws/lobby/{code}/", user)
        connected, _close_code = await communicator.connect()

        assert connected

        await communicator.disconnect()

    @pytest.mark.django_db(transaction=True)
    async def test_connect_unauthenticated_fails(self):
        """Unauthenticated users cannot connect to a lobby WebSocket."""
        from django.contrib.auth.models import AnonymousUser

        code, _user = await create_lobby_with_user()

        communicator = _make_communicator(f"/ws/lobby/{code}/", AnonymousUser())
        connected, close_code = await communicator.connect()

        assert not connected or close_code == 4001

        await communicator.disconnect()

    @pytest.mark.django_db(transaction=True)
    async def test_connect_to_nonexistent_lobby_fails(self):
        """Connecting to nonexistent lobby closes connection."""
        _code, user = await create_lobby_with_user()

        communicator = _make_communicator("/ws/lobby/XXXXXX/", user)
        connected, close_code = await communicator.connect()

        assert not connected or close_code == 4004

        await communicator.disconnect()

    @pytest.mark.django_db(transaction=True)
    async def test_non_member_cannot_connect(self):
        """Non-members cannot connect to a lobby WebSocket."""
        from apps.core.models import User

        code, _host = await create_lobby_with_user()

        @database_sync_to_async
        def create_non_member():
            return User.objects.create_user(
                username=f"outsider_{uuid.uuid4().hex[:8]}", password="pass"
            )

        outsider = await create_non_member()
        communicator = _make_communicator(f"/ws/lobby/{code}/", outsider)
        connected, close_code = await communicator.connect()

        assert not connected or close_code == 4004

        await communicator.disconnect()

    @pytest.mark.django_db(transaction=True)
    async def test_receive_player_joined_event(self):
        """Connected clients receive player_joined events."""
        from apps.core.models import LobbyMember, User

        code, host = await create_lobby_with_user()

        # Connect as host
        communicator = _make_communicator(f"/ws/lobby/{code}/", host)
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
        response = await _next_event(communicator)

        # Who joined is read from the lobby body; the account's username is
        # nobody else's to know, so the event names nobody.
        assert response == {"type": "player_joined"}

        await communicator.disconnect()
