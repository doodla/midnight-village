"""
The lobby's number (``Lobby.rev``): where it starts, who raises it, who carries it.

``lobbies.told_body`` is the one way to build a body told because of a change: it
raises ``rev`` with an UPDATE on the lobby row (so numbers follow commit order even
where a caller did not lock first) and builds the body after it. A read carries the
number of the row it loaded. The whole evening at one table is
``tests/onuw/test_lobby_rev.py``; here: the start, the function, the consumers, an
older phone, and two requests racing on one table (real threads, real transactions).
"""

from __future__ import annotations

import threading
from typing import Any
from unittest.mock import AsyncMock, patch

from django.db import connection, transaction
from django.urls import reverse

import pytest
from asgiref.sync import async_to_sync
from rest_framework import status
from rest_framework.test import APIClient

from apps.core import lobbies
from apps.core.consumers import LobbyConsumer
from apps.core.models import Lobby, LobbyMember, User
from apps.onuw.consumers import GameConsumer

pytestmark = pytest.mark.integration

# Every key an ONUW lobby body had before ``rev``: none is changed or removed.
BODY_KEYS_BEFORE_REV = {
    "code",
    "host",
    "original_host_id",
    "is_acting_host",
    "game_type",
    "status",
    "max_players",
    "settings",
    "players",
    "created_at",
    "deck_preview",
    "deck_cards",
    "deal",
    "seats_range",
    "lengths",
    "length_ranges",
}


def _client(user: User) -> APIClient:
    client = APIClient()
    client.force_authenticate(user=user)
    return client


def _people(count: int, prefix: str = "rev") -> list[User]:
    return [
        User.objects.create_user(username=f"{prefix}-{i}", password=None)
        for i in range(count)
    ]


@pytest.mark.django_db
class TestWhereTheNumberStarts:
    def test_a_new_table_starts_at_0_and_the_create_answer_carries_it(self) -> None:
        host, *guests = _people(4)
        created = _client(host).post(
            reverse("core:lobby-list"), {"game_type": "onuw"}, format="json"
        )
        assert created.status_code == status.HTTP_201_CREATED
        assert created.data["rev"] == 0
        code = created.data["code"]
        assert Lobby.objects.get(code=code).rev == 0

        for number, guest in enumerate(guests, start=1):
            joined = _client(guest).post(
                reverse("core:lobby-join", kwargs={"code": code})
            )
            assert joined.data["rev"] == number

    def test_a_read_carries_the_number_of_its_row_and_raises_nothing(self) -> None:
        host, guest, other = _people(3)
        code = (
            _client(host)
            .post(reverse("core:lobby-list"), {"game_type": "onuw"}, format="json")
            .data["code"]
        )
        _client(guest).post(reverse("core:lobby-join", kwargs={"code": code}))
        url = reverse("core:lobby-detail", kwargs={"code": code})
        reads = [
            _client(who).get(url).data["rev"] for who in (host, guest, other, host)
        ]
        assert reads == [1, 1, 1, 1]
        assert Lobby.objects.get(code=code).rev == 1

    def test_an_older_phone_finds_every_key_it_knew_and_only_rev_added(self) -> None:
        host, guest = _people(2)
        body = (
            _client(host)
            .post(reverse("core:lobby-list"), {"game_type": "onuw"}, format="json")
            .data
        )
        assert set(body) == BODY_KEYS_BEFORE_REV | {"rev"}
        joined = _client(guest).post(
            reverse("core:lobby-join", kwargs={"code": body["code"]})
        )
        assert set(joined.data) == BODY_KEYS_BEFORE_REV | {"rev"}
        # What a join does not move is answered exactly as before.
        for key in (
            "code",
            "host",
            "original_host_id",
            "is_acting_host",
            "game_type",
            "status",
            "max_players",
            "settings",
            "created_at",
        ):
            assert joined.data[key] == body[key], key


@pytest.mark.django_db
class TestTheOneFunction:
    def _table(self, players: int = 4) -> Lobby:
        users = _people(players, prefix="fn")
        lobby = Lobby.objects.create(host=users[0], game_type="onuw")
        for user in users:
            LobbyMember.objects.create(lobby=lobby, user=user)
        return lobby

    def test_told_twice_in_one_transaction_is_two_numbers_built_after_the_bump(
        self,
    ) -> None:
        lobby = self._table()
        with transaction.atomic():
            first = lobbies.told_body(lobby)
            second = lobbies.told_body(lobby)
        assert (first["rev"], second["rev"]) == (1, 2)
        assert lobby.rev == 2 == Lobby.objects.get(pk=lobby.pk).rev
        assert {**first, "rev": 0} == {**second, "rev": 0}

    def test_a_stale_instance_still_gets_the_next_number_of_the_row(self) -> None:
        """Two loads of one table: each bump reads the row's number back, so the
        older instance never hands out a number already given."""
        lobby = self._table()
        older = Lobby.objects.get(pk=lobby.pk)
        assert lobbies.told_body(lobby)["rev"] == 1
        assert lobbies.told_body(older)["rev"] == 2
        assert lobbies.bump_rev(lobby) == 3

    def test_announce_lobby_bumps_once_and_returns_what_it_sends(
        self, django_capture_on_commit_callbacks
    ) -> None:
        lobby = self._table()
        sent: list[tuple[str, dict[str, Any]]] = []
        layer = type("Layer", (), {"group_send": lambda _, g, e: sent.append((g, e))})()
        with (
            patch("apps.core.effects.get_channel_layer", return_value=layer),
            patch("apps.core.effects.async_to_sync", side_effect=lambda f: f),
            django_capture_on_commit_callbacks(execute=True),
        ):
            body = lobbies.announce_lobby(lobby)
        assert sent == [(f"lobby_{lobby.code}", {"type": "lobby.update", "data": body})]
        assert body["rev"] == 1 == Lobby.objects.get(pk=lobby.pk).rev


class TestHostChangedCarriesTheNumber:
    EVENT = {
        "type": "host.changed",
        "host_id": 7,
        "host_name": "Ada",
        "original_host_id": 3,
        "reason": "handover",
    }

    @pytest.mark.parametrize("consumer_class", [LobbyConsumer, GameConsumer])
    def test_both_sockets_forward_rev(self, consumer_class) -> None:
        consumer = consumer_class()
        consumer.send_json = AsyncMock()  # type: ignore[method-assign]
        async_to_sync(consumer.host_changed)({**self.EVENT, "rev": 12})
        consumer.send_json.assert_awaited_once_with(
            {
                "type": "host_changed",
                "host_id": 7,
                "host_name": "Ada",
                "original_host_id": 3,
                "reason": "handover",
                "rev": 12,
            }
        )

    @pytest.mark.parametrize("consumer_class", [LobbyConsumer, GameConsumer])
    def test_an_older_instances_event_without_rev_is_forwarded_as_before(
        self, consumer_class
    ) -> None:
        consumer = consumer_class()
        consumer.send_json = AsyncMock()  # type: ignore[method-assign]
        async_to_sync(consumer.host_changed)(dict(self.EVENT))
        sent = consumer.send_json.await_args.args[0]
        assert "rev" not in sent and sent["reason"] == "handover"


@pytest.mark.django_db(transaction=True)
class TestTwoAtOnce:
    """Real threads, each in its own transaction on its own connection."""

    def _race(self, work: Any) -> list[Any]:
        together = threading.Barrier(2, timeout=10)
        results: list[Any] = []
        errors: list[BaseException] = []

        def run(arg: int) -> None:
            try:
                together.wait()
                results.append(work(arg))
            except BaseException as error:
                errors.append(error)
            finally:
                connection.close()

        threads = [threading.Thread(target=run, args=(n,)) for n in (1, 2)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join(timeout=20)
        assert errors == []
        return results

    def test_two_tellers_that_did_not_lock_first_get_different_numbers(self) -> None:
        users = _people(3, prefix="race")
        lobby = Lobby.objects.create(host=users[0], game_type="onuw")
        for user in users:
            LobbyMember.objects.create(lobby=lobby, user=user)

        def tell(_: int) -> int:
            with transaction.atomic():
                loaded = Lobby.objects.get(pk=lobby.pk)  # no select_for_update
                return lobbies.told_body(loaded)["rev"]

        assert sorted(self._race(tell)) == [1, 2]
        assert Lobby.objects.get(pk=lobby.pk).rev == 2

    def test_two_settings_taps_racing_get_different_numbers(self) -> None:
        users = _people(3, prefix="tap")
        lobby = Lobby.objects.create(host=users[0], game_type="onuw")
        for user in users:
            LobbyMember.objects.create(lobby=lobby, user=user)
        url = reverse("core:lobby-detail", kwargs={"code": lobby.code})
        paces = {1: "quick", 2: "long"}

        def tap(n: int) -> tuple[int, str]:
            reply = _client(users[0]).patch(
                url, {"settings": {"pace": paces[n]}}, format="json"
            )
            assert reply.status_code == status.HTTP_200_OK, reply.data
            return reply.data["rev"], reply.data["settings"]["pace"]

        answers = sorted(self._race(tap))
        assert [rev for rev, _ in answers] == [1, 2]
        # The higher number is the state that stayed.
        assert Lobby.objects.get(pk=lobby.pk).settings["pace"] == answers[-1][1]
