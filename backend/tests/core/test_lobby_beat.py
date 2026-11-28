"""A lobby socket's heartbeat (``LobbyConsumer``): the beat frame as the socket
opens, carrying the table's ``rev``, and one beat's database work in two queries
(main's took three)."""

from __future__ import annotations

import uuid

from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.utils import timezone

import pytest

from apps.core.consumers import LobbyConsumer
from apps.core.models import Lobby, LobbyMember, LobbySocket, User
from tests.core.test_lobby_websocket import _make_communicator, create_lobby_with_user

pytestmark = pytest.mark.integration


def _seated(n: int) -> tuple[Lobby, list[User]]:
    users = [
        User.objects.create_user(username=f"beat_{uuid.uuid4().hex[:8]}", password="p")
        for _ in range(n)
    ]
    lobby = Lobby.objects.create(host=users[0], game_type="onuw")
    for user in users:
        LobbyMember.objects.create(lobby=lobby, user=user)
    return lobby, users


@pytest.mark.django_db
def test_a_lobby_beat_is_two_queries_and_reads_the_tables_rev() -> None:
    lobby, users = _seated(3)
    Lobby.objects.filter(pk=lobby.pk).update(rev=7)
    now = timezone.now()
    for n, user in enumerate(users):
        LobbySocket.objects.create(
            user=user, lobby=lobby, channel_name=f"lobby-{n}", connected_at=now,
            last_seen=now,
        )  # fmt: skip
    consumer = LobbyConsumer()
    consumer.lobby_code = lobby.code
    consumer.scope = {"user": users[1]}
    consumer.channel_name = "lobby-1"
    with CaptureQueriesContext(connection) as beat:
        consumer._beat_work()
    assert len(beat) == 2, [q["sql"] for q in beat.captured_queries]
    assert consumer._rev == 7


@pytest.mark.django_db(transaction=True)
async def test_a_lobby_socket_hears_a_beat_as_it_opens_with_the_tables_rev() -> None:
    code, user = await create_lobby_with_user()
    communicator = _make_communicator(f"/ws/lobby/{code}/", user)
    connected, _ = await communicator.connect()
    assert connected
    first = await communicator.receive_json_from(timeout=5)
    assert first["type"] == "beat"
    assert set(first) == {"type", "every", "rev"}
    await communicator.disconnect()
