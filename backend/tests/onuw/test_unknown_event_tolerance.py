"""
During a rollout an older instance can be handed a group event type that only the
new code knows. Channels would raise "No handler for message type" and close the
player's socket; both consumers drop such an event instead and carry on.
"""

import pytest
from channels.layers import get_channel_layer

from tests.core.test_lobby_websocket import _make_communicator, create_lobby_with_user
from tests.onuw.test_game_consumer import (
    _build_communicator,
    _create_game_with_players,
)

pytestmark = pytest.mark.integration

FROM_A_NEWER_INSTANCE = {"type": "ready.progress", "stage": "vote", "done": 3}


class TestLobbySocket:
    @pytest.mark.django_db(transaction=True)
    async def test_unknown_event_is_dropped_and_the_socket_stays_open(self):
        code, user = await create_lobby_with_user()
        communicator = _make_communicator(f"/ws/lobby/{code}/", user)
        assert (await communicator.connect())[0]
        layer = get_channel_layer()
        assert layer is not None

        await layer.group_send(f"lobby_{code}", FROM_A_NEWER_INSTANCE)
        await layer.group_send(
            f"lobby_{code}", {"type": "player.joined", "username": "x"}
        )

        # The first thing the client gets is the known event: the unknown one was
        # neither forwarded nor allowed to close the socket.
        assert await communicator.receive_json_from(timeout=2) == {
            "type": "player_joined",
            "username": "x",
        }
        await communicator.send_json_to({"anything": 1})
        assert (await communicator.receive_json_from(timeout=2))["type"] == "error"
        await communicator.disconnect()


class TestGameSocket:
    @pytest.mark.django_db(transaction=True)
    async def test_unknown_event_is_dropped_and_the_socket_stays_open(self):
        game, users = await _create_game_with_players()
        communicator = _build_communicator(game.id, users[0])
        assert (await communicator.connect())[0]
        # Connecting announces the player's own presence; not what this is about.
        assert (await communicator.receive_json_from(timeout=2))["type"] == (
            "player_presence"
        )
        layer = get_channel_layer()
        assert layer is not None

        await layer.group_send(f"game_{game.id}", FROM_A_NEWER_INSTANCE)
        await layer.group_send(
            f"game_{game.id}_player_{users[0].id}", FROM_A_NEWER_INSTANCE
        )
        await layer.group_send(f"game_{game.id}", {"type": "wave.start", "wave": 2})

        first = await communicator.receive_json_from(timeout=2)
        assert first["type"] == "wave_start"  # nothing of the unknown event came first
        assert first["wave"] == 2
        await communicator.disconnect()
