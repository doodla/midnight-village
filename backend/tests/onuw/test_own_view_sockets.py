"""Real sockets hear their own view (``own_view``), and only their own.

Three players open real game sockets (``GameConsumer`` through Channels' test
communicator, the in-memory layer); the talk ends and the vote opens with a real
commit. Each socket hears exactly one ``me``, the view of its own player, before
the table's ``phase_change``: the group a view is addressed to is the one its
socket joined (``groups.player_group``), so a renamed group fails here rather than
sending every view to nobody.
"""

from __future__ import annotations

from unittest.mock import patch

from django.db import transaction
from django.test import TransactionTestCase, override_settings

import pytest
from channels.db import database_sync_to_async

from apps.onuw import voting
from apps.onuw.models import Game, Phase
from tests.onuw.test_game_consumer import (
    _build_communicator,
    _create_game_with_players,
)

pytestmark = pytest.mark.integration


async def _until(communicator, kind: str) -> list[dict]:
    """Every frame up to and including the first of ``kind``."""
    heard = []
    while True:
        frame = await communicator.receive_json_from(timeout=5)
        heard.append(frame)
        if frame["type"] == kind:
            return heard


@database_sync_to_async
def _open_the_vote(game_id) -> None:
    with transaction.atomic():
        game = Game.objects.select_for_update().get(id=game_id)
        Game.objects.filter(id=game_id).update(phase=Phase.DISCUSSION)
        game.refresh_from_db()
        voting.transition_to_voting(game)


class TestEachSocketHearsItsOwnView(TransactionTestCase):
    @pytest.mark.asyncio
    async def test_three_sockets_each_hear_one_view_their_own_before_the_table(
        self,
    ):
        game, users = await _create_game_with_players(3)
        sockets = []
        for user in users:
            communicator = _build_communicator(game.id, user)
            connected, _ = await communicator.connect()
            assert connected
            sockets.append(communicator)

        await _open_the_vote(game.id)

        for user, communicator in zip(users, sockets, strict=True):
            heard = await _until(communicator, "phase_change")
            views = [f for f in heard if f["type"] == "me"]
            assert len(views) == 1, [f["type"] for f in heard]
            assert views[0]["me"]["player_id"] == user.id
            assert views[0]["me"]["phase"] == "voting"
            assert heard.index(views[0]) < len(heard) - 1  # before phase_change
        for communicator in sockets:
            await communicator.disconnect()


class TestTheBeat(TransactionTestCase):
    @pytest.mark.asyncio
    async def test_each_socket_hears_the_beat_and_its_beat_asks_for_the_repair(
        self,
    ):
        """Three real sockets, a short beat: each hears a beat as it opens and
        then on time, the same bytes for all (the table's token, nothing of
        anyone's), and the game's repair is asked for. A repair that fails stops
        nothing: the beats go on (frames are the clock here: no sleep)."""
        game, users = await _create_game_with_players(3)
        asked: list[str] = []

        def failing(game_id) -> None:
            asked.append(str(game_id))
            raise RuntimeError("the repair is down")

        with (
            override_settings(ONUW_PRESENCE_HEARTBEAT_SECONDS=0.05),
            patch("apps.onuw.repair.repair_on_beat", failing),
        ):
            sockets = []
            for user in users:
                communicator = _build_communicator(game.id, user)
                connected, _ = await communicator.connect()
                assert connected
                first = await communicator.receive_json_from(timeout=5)
                assert first["type"] == "beat", "the first frame, at once"
                sockets.append(communicator)
            heard = {}
            for n, communicator in enumerate(sockets):
                beats = []
                while len(beats) < 4 or not asked:
                    frame = await communicator.receive_json_from(timeout=5)
                    if frame["type"] == "beat":
                        beats.append(frame)
                    assert len(beats) < 200, "the repair was never asked for"
                heard[n] = beats[-1]
            assert set(heard[0]) == {"type", "every", "phase", "window", "moved_on"}
            assert heard[0] == heard[1] == heard[2]
            assert set(asked) == {str(game.id)}
            for communicator in sockets:
                await communicator.disconnect()
