"""
During a rollout an older instance can be handed a group event type that only the
new code knows. Channels would raise "No handler for message type" and close the
player's socket; both consumers drop such an event (with a warning) instead and
carry on. Under ``ONUW_STRICT_SOCKET_EVENTS`` (test, development, harness) they
raise instead, so a misspelled event type in new code cannot hide.
"""

from unittest.mock import patch

import pytest
from channels.layers import get_channel_layer

from tests.core.test_lobby_websocket import _make_communicator, create_lobby_with_user
from tests.onuw.test_game_consumer import (
    _build_communicator,
    _create_game_with_players,
)
from tests.sockets import heard

pytestmark = pytest.mark.integration


@pytest.fixture(autouse=True)
def production_like_consumers(settings):
    settings.ONUW_STRICT_SOCKET_EVENTS = False


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
        assert await heard(communicator) == {"type": "player_joined"}
        await communicator.send_json_to({"anything": 1})
        assert (await heard(communicator))["type"] == "error"
        await communicator.disconnect()


class TestGameSocket:
    @pytest.mark.django_db(transaction=True)
    async def test_unknown_event_is_dropped_and_the_socket_stays_open(self):
        game, users = await _create_game_with_players()
        communicator = _build_communicator(game.id, users[0])
        assert (await communicator.connect())[0]
        # Connecting announces the player's own presence; not what this is about.
        assert (await heard(communicator))["type"] == ("player_presence")
        layer = get_channel_layer()
        assert layer is not None

        await layer.group_send(f"game_{game.id}", FROM_A_NEWER_INSTANCE)
        await layer.group_send(
            f"game_{game.id}_player_{users[0].id}", FROM_A_NEWER_INSTANCE
        )
        await layer.group_send(
            f"game_{game.id}", {"type": "night.window", "window": 2, "deadline": None}
        )

        first = await heard(communicator)
        assert first["type"] == "night_window"  # nothing of the unknown one came first
        assert first["window"] == 2
        await communicator.disconnect()


class TestStrictMode:
    @pytest.mark.django_db(transaction=True)
    async def test_a_misspelled_event_type_fails_loudly_under_the_test_settings(
        self, settings
    ):
        settings.ONUW_STRICT_SOCKET_EVENTS = True
        code, user = await create_lobby_with_user()
        communicator = _make_communicator(f"/ws/lobby/{code}/", user)
        assert (await communicator.connect())[0]
        layer = get_channel_layer()
        assert layer is not None

        await layer.group_send(f"lobby_{code}", {"type": "player.joinned"})

        # What the socket sent before it (its beat as it opened, the table's
        # own body) comes out first; then the misspelled event fails.
        with pytest.raises(ValueError, match="No handler for message type"):
            for _ in range(10):
                await communicator.receive_output(timeout=2)

    def test_the_test_and_development_settings_are_strict_and_base_is_not(self):
        from config.settings import base, development, harness, test

        assert base.ONUW_STRICT_SOCKET_EVENTS is False
        assert development.ONUW_STRICT_SOCKET_EVENTS is True
        assert harness.ONUW_STRICT_SOCKET_EVENTS is True
        assert test.ONUW_STRICT_SOCKET_EVENTS is True


class TestTheWarning:
    @pytest.mark.django_db(transaction=True)
    async def test_a_dropped_event_is_logged_as_a_warning(self):
        code, user = await create_lobby_with_user()
        communicator = _make_communicator(f"/ws/lobby/{code}/", user)
        assert (await communicator.connect())[0]
        layer = get_channel_layer()
        assert layer is not None

        with patch("apps.core.consumers.logger") as log:
            await layer.group_send(f"lobby_{code}", FROM_A_NEWER_INSTANCE)
            await layer.group_send(
                f"lobby_{code}", {"type": "player.joined", "username": "x"}
            )
            await heard(communicator)

        log.warning.assert_called_once()
        assert "ready.progress" in log.warning.call_args.args[1]
        await communicator.disconnect()
