"""
Integration tests for the ONUW GameConsumer WebSocket.

Tests connection authorization, message routing, and player isolation.
"""

from django.test import TransactionTestCase

import pytest
from channels.db import database_sync_to_async
from channels.testing import WebsocketCommunicator

from apps.core.models import Lobby, LobbyMember, User
from apps.onuw.consumers import GameConsumer
from apps.onuw.models import Game, Phase, PlayerRole

pytestmark = pytest.mark.integration


def _build_communicator(game_id, user):
    """Build a WebsocketCommunicator for GameConsumer with a given user."""
    communicator = WebsocketCommunicator(
        GameConsumer.as_asgi(),
        f"/ws/game/{game_id}/",
    )
    communicator.scope["user"] = user
    communicator.scope["url_route"] = {"kwargs": {"game_id": str(game_id)}}
    return communicator


@database_sync_to_async
def _create_game_with_players(player_count=3):
    """Create a game with the specified number of players. Returns (game, users)."""
    roles_config = {
        "Werewolf": 1,
        "Seer": 1,
        "Villager": player_count - 2,
        "Robber": 1,
        "Drunk": 1,
        "Troublemaker": 1,
    }

    host = User.objects.create_user(username="host_ws", password="pass")
    players = [
        User.objects.create_user(username=f"ws_p{i}", password="pass")
        for i in range(player_count - 1)
    ]
    all_users = [host, *players]

    lobby = Lobby.objects.create(
        host=host,
        game_type="onuw",
        max_players=10,
        settings={"roles": roles_config},
    )
    LobbyMember.objects.create(lobby=lobby, user=host)
    for p in players:
        LobbyMember.objects.create(lobby=lobby, user=p)

    game = Game.objects.create(
        lobby=lobby,
        phase=Phase.NIGHT,
        random_seed=42,
        settings=lobby.settings,
        center_cards=["Drunk", "Troublemaker", "Robber"],
    )

    role_names = ["Werewolf", "Seer", "Villager"]
    for user, role in zip(all_users, role_names, strict=False):
        PlayerRole.objects.create(
            game=game,
            user=user,
            original_role=role,
            current_role=role,
        )

    return game, all_users


class TestGameConsumerConnect(TransactionTestCase):
    """Tests for GameConsumer connection."""

    @pytest.mark.asyncio
    async def test_player_can_connect_to_game_ws(self):
        """A player in the game can connect successfully."""
        game, users = await _create_game_with_players()
        player = users[0]

        communicator = _build_communicator(game.id, player)
        connected, _ = await communicator.connect()

        assert connected is True
        await communicator.disconnect()

    @pytest.mark.asyncio
    async def test_non_player_rejected_with_4003(self):
        """A user not in the game is rejected with close code 4003."""
        game, _users = await _create_game_with_players()
        outsider = await database_sync_to_async(User.objects.create_user)(
            username="outsider_ws", password="pass"
        )

        communicator = _build_communicator(game.id, outsider)
        connected, code = await communicator.connect()

        # WebsocketCommunicator returns (False, code) when connection is rejected
        assert connected is False
        assert code == 4003

    @pytest.mark.asyncio
    async def test_player_receives_messages_on_player_channel(self):
        """A player receives messages sent to their player-specific group."""
        from channels.layers import get_channel_layer

        game, users = await _create_game_with_players()
        player = users[0]

        communicator = _build_communicator(game.id, player)
        connected, _ = await communicator.connect()
        assert connected is True

        channel_layer = get_channel_layer()
        assert channel_layer is not None

        # Send a message to the player's private group
        await channel_layer.group_send(
            f"game_{game.id}_player_{player.id}",
            {"type": "progress", "stage": "vote", "done": 1, "needed": 3},
        )

        response = await _next_of(communicator, "progress")
        assert response == {"type": "progress", "stage": "vote", "done": 1, "needed": 3}

        await communicator.disconnect()

    @pytest.mark.asyncio
    async def test_player_does_not_receive_other_player_messages(self):
        """Player A does not receive messages sent to Player B's private group."""
        from channels.layers import get_channel_layer

        game, users = await _create_game_with_players()
        player_a = users[0]
        player_b = users[1]

        comm_a = _build_communicator(game.id, player_a)
        connected_a, _ = await comm_a.connect()
        assert connected_a is True
        # Connecting announces the player's own presence to the table; that
        # broadcast is not what this test is about.
        presence = await comm_a.receive_json_from(timeout=2)
        assert presence["type"] == "player_presence"

        channel_layer = get_channel_layer()
        assert channel_layer is not None

        # Send a message to player B's private group
        await channel_layer.group_send(
            f"game_{game.id}_player_{player_b.id}",
            {"type": "progress", "stage": "vote", "done": 1, "needed": 3},
        )

        # Player A should NOT receive this message
        assert await communicator_is_empty(comm_a)

        await comm_a.disconnect()

    @pytest.mark.asyncio
    async def test_player_receives_broadcast_messages(self):
        """A player receives messages broadcast to the game group."""
        from channels.layers import get_channel_layer

        game, users = await _create_game_with_players()
        player = users[0]

        communicator = _build_communicator(game.id, player)
        connected, _ = await communicator.connect()
        assert connected is True

        channel_layer = get_channel_layer()
        assert channel_layer is not None

        # Send a broadcast message to all players
        await channel_layer.group_send(
            f"game_{game.id}",
            {"type": "night.window", "window": 2, "deadline": None},
        )

        response = await _next_of(communicator, "night_window")
        assert response == {"type": "night_window", "window": 2, "deadline": None}

        await communicator.disconnect()


async def _next_of(communicator, kind: str) -> dict:
    """The next event of ``kind`` (connecting also announces the player's own
    presence, which these tests are not about)."""
    while True:
        event = await communicator.receive_json_from(timeout=2)
        if event["type"] == kind:
            return event


async def communicator_is_empty(communicator):
    """Check that a communicator has no pending messages."""
    import asyncio

    try:
        await asyncio.wait_for(communicator.receive_json_from(), timeout=0.5)
        return False
    except TimeoutError:
        return True
