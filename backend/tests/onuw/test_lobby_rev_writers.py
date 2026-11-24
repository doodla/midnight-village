"""
The lobby's number (``Lobby.rev``) at the writers the evening in
``test_lobby_rev.py`` does not reach: practice players cleared from a person's
OTHER tables (from a new table and from switching them on there), an acting host
leaving, the handover and the owner's return arriving through the GAME socket, and
a read racing a write (real threads, real transactions).

Each checks the numbers told AND their content against a GET after, so a missing
bump (content changed, number not) fails here.
"""

from __future__ import annotations

import copy
import threading
from contextlib import contextmanager
from datetime import timedelta
from typing import Any
from unittest.mock import patch

from django.db import connection
from django.urls import reverse
from django.utils import timezone

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.core import host
from apps.core.models import Lobby, LobbyMember, User
from apps.core.serializers import LobbySerializer
from apps.onuw import game_presence, services

pytestmark = pytest.mark.integration

SEED = 20261124
DECK = {"Werewolf": 2, "Seer": 1, "Robber": 1, "Villager": 3}  # four people + 3
TIMERS_OFF = {
    "night_wave_seconds": 0,
    "night_min_window_seconds": 0,
    "night_doppelganger_window_seconds": 0,
    "discussion_seconds": 0,
    "voting_seconds": 0,
}


def content(body: dict[str, Any]) -> dict[str, Any]:
    """A lobby body without ``rev`` and without anyone's ``connected``."""
    body = copy.deepcopy(dict(body))
    body.pop("rev", None)
    for player in body.get("players") or []:
        player.pop("connected", None)
    return body


class Tables:
    """People driving tables through the API; every group send recorded."""

    def __init__(self, capture: Any, names: list[str]) -> None:
        self._capture = capture
        self.users = {
            name: User.objects.create_user(
                username=f"rw-{name}", password=None, display_name=name.title()
            )
            for name in names
        }
        self.client = APIClient()
        self.sent: list[tuple[str, dict[str, Any]]] = []

    @contextmanager
    def committed(self):
        layer = type(
            "Layer", (), {"group_send": lambda _, g, e: self.sent.append((g, e))}
        )()
        with (
            patch("apps.core.effects.get_channel_layer", return_value=layer),
            patch("apps.core.effects.async_to_sync", side_effect=lambda f: f),
            patch("apps.core.views.get_channel_layer", return_value=layer),
            patch("apps.core.views.async_to_sync", side_effect=lambda f: f),
            patch("apps.onuw.views.get_channel_layer", return_value=None),
            self._capture(execute=True),
        ):
            yield

    def call(self, name: str, method: str, url: str, body: Any = None) -> Any:
        self.client.force_authenticate(user=self.users[name])
        with self.committed():
            return getattr(self.client, method)(url, body, format="json")

    def create(self, name: str, **body: Any) -> str:
        reply = self.call(
            name, "post", reverse("core:lobby-list"), {"game_type": "onuw", **body}
        )
        assert reply.status_code == status.HTTP_201_CREATED, reply.data
        return reply.data["code"]

    def url(self, code: str, kind: str = "lobby-detail") -> str:
        return reverse(f"core:{kind}", kwargs={"code": code})

    def get(self, code: str) -> dict[str, Any]:
        reply = self.call(next(iter(self.users)), "get", self.url(code))
        return dict(reply.data)

    def told(self, code: str, since: int) -> list[dict[str, Any]]:
        return [
            e
            for g, e in self.sent[since:]
            if g == f"lobby_{code}" and e["type"] in ("lobby.update", "host.changed")
        ]


@pytest.fixture
def tables(db, django_capture_on_commit_callbacks):
    return lambda names: Tables(django_capture_on_commit_callbacks, names)


class TestPracticeClearedFromTheOtherTables:
    def test_a_new_table_tells_the_old_one_its_practice_players_went(
        self, tables
    ) -> None:
        t = tables(["host", "ada"])
        first = t.create("host")
        t.call("ada", "post", t.url(first, "lobby-join"))
        reply = t.call("host", "post", t.url(first, "lobby-practice"), {"count": 2})
        assert reply.status_code == status.HTTP_200_OK
        before = t.get(first)
        assert before["rev"] == reply.data["rev"] and len(before["players"]) == 4

        since = len(t.sent)
        t.create("host")  # practice.clear_elsewhere on the first table

        (update,) = t.told(first, since)
        after = t.get(first)
        assert update["data"]["rev"] == before["rev"] + 1 == after["rev"]
        assert content(update["data"]) == content(after)
        assert len(after["players"]) == 2 and "practice" not in after

    def test_switching_them_on_here_tells_the_table_they_left(self, tables) -> None:
        t = tables(["host", "ada"])
        first = t.create("host")
        second = t.create("host")
        t.call("ada", "post", t.url(second, "lobby-join"))
        on_first = t.call("host", "post", t.url(first, "lobby-practice"), {"count": 3})
        assert on_first.status_code == status.HTTP_200_OK
        before = t.get(first)

        since = len(t.sent)
        here = t.call("host", "post", t.url(second, "lobby-practice"), {"on": True})
        assert here.status_code == status.HTTP_200_OK

        (update,) = t.told(first, since)
        after = t.get(first)
        assert update["data"]["rev"] == before["rev"] + 1 == after["rev"]
        assert content(update["data"]) == content(after)
        assert [p["user"]["display_name"] for p in after["players"]] == ["Host"]
        # The table switched on is told once, with its own next number.
        (told_here,) = t.told(second, since)
        assert told_here["data"] == here.data


class TestAnActingHostLeaving:
    def test_host_changed_then_the_body_with_the_next_number(self, tables) -> None:
        t = tables(["host", "ada", "bo", "cy"])
        code = t.create("host")
        for name in ("ada", "bo", "cy"):
            t.call(name, "post", t.url(code, "lobby-join"))
        with t.committed():
            host.register_lobby_connection(code, t.users["bo"].id, "rw.bo")
        Lobby.objects.filter(code=code).update(acting_host=t.users["ada"])
        before = t.get(code)
        assert before["host"]["id"] == t.users["ada"].id

        since = len(t.sent)
        left = t.call("ada", "post", t.url(code, "lobby-leave"))
        assert left.status_code == status.HTTP_200_OK

        changed, update = t.told(code, since)
        after = t.get(code)
        assert changed["type"] == "host.changed" and changed["reason"] == "handover"
        assert changed["host_id"] == t.users["bo"].id == after["host"]["id"]
        assert changed["rev"] == before["rev"] + 1
        assert update["data"]["rev"] == before["rev"] + 2 == after["rev"]
        assert content(update["data"]) == content(after)
        assert t.users["ada"].id not in [p["user"]["id"] for p in after["players"]]


class TestThroughTheGameSocket:
    """The game app reports a game socket opening (``member_presence_changed``)."""

    def deal(self, t: Tables, settings: Any) -> tuple[str, str]:
        settings.DEBUG = True
        code = t.create("host", settings={"roles": DECK, **TIMERS_OFF})
        for name in ("ada", "bo", "cy"):
            t.call(name, "post", t.url(code, "lobby-join"))
        reply = t.call(
            "host",
            "post",
            reverse("onuw:game-start", kwargs={"code": code}),
            {"debug": {"seed": SEED}},
        )
        assert reply.status_code == status.HTTP_201_CREATED, reply.data
        return code, reply.data["game_id"]

    def game_socket(self, t: Tables, game_id: str, name: str) -> None:
        with t.committed():
            user_id = t.users[name].id
            if game_presence.register_connection(game_id, user_id):
                services.report_game_presence(game_id, user_id, True)

    def test_the_handover_and_the_owner_back_each_tell_the_next_number(
        self, tables, settings
    ) -> None:
        t = tables(["host", "ada", "bo", "cy"])
        code, game_id = self.deal(t, settings)
        LobbyMember.objects.filter(lobby__code=code, user=t.users["host"]).update(
            disconnected_at=timezone.now() - timedelta(seconds=120)
        )
        before = t.get(code)

        since = len(t.sent)
        self.game_socket(t, game_id, "ada")  # the owner is long gone: ada takes it
        (handover,) = t.told(code, since)
        mid = t.get(code)
        assert handover["reason"] == "handover"
        assert handover["host_id"] == t.users["ada"].id == mid["host"]["id"]
        assert handover["rev"] == before["rev"] + 1 == mid["rev"]
        assert mid["is_acting_host"] is True
        assert content({**mid, "host": before["host"], "is_acting_host": False}) == (
            content(before)
        )

        since = len(t.sent)
        self.game_socket(t, game_id, "host")  # the owner is back
        (returned,) = t.told(code, since)
        after = t.get(code)
        assert returned["reason"] == "returned"
        assert returned["host_id"] == t.users["host"].id == after["host"]["id"]
        assert returned["rev"] == mid["rev"] + 1 == after["rev"]
        assert content(after) == content(before)
        # The game's socket heard the same events with the same numbers.
        in_game = [e for g, e in t.sent if g == f"game_{game_id}" and "rev" in e]
        assert [e["rev"] for e in in_game] == [handover["rev"], returned["rev"]]


@pytest.mark.django_db(transaction=True)
class TestAReadRacingAWrite:
    def test_a_read_is_never_numbered_ahead_of_its_content(self) -> None:
        """The GET has loaded the row when the PATCH commits; it finishes after.
        Its body may be older or newer than the PATCH, never a number ahead of
        what it shows."""
        users = [
            User.objects.create_user(username=f"race-{i}", password=None)
            for i in range(4)
        ]
        lobby = Lobby.objects.create(
            host=users[0], game_type="onuw", settings={"pace": "normal"}
        )
        for user in users:
            LobbyMember.objects.create(lobby=lobby, user=user)
        url = reverse("core:lobby-detail", kwargs={"code": lobby.code})

        def client(user: User) -> APIClient:
            c = APIClient()
            c.force_authenticate(user=user)
            return c

        before = dict(client(users[1]).get(url).data)
        loaded, committed = threading.Event(), threading.Event()
        real = LobbySerializer.to_representation
        results: dict[str, Any] = {}
        errors: list[BaseException] = []

        def held(self, instance):
            if threading.current_thread().name == "reader":
                loaded.set()  # the row is read; let the write commit now
                assert committed.wait(10)
            return real(self, instance)

        def reader() -> None:
            try:
                results["read"] = dict(client(users[1]).get(url).data)
            except BaseException as error:
                errors.append(error)
            finally:
                connection.close()

        def writer() -> None:
            try:
                assert loaded.wait(10)
                reply = client(users[0]).patch(
                    url, {"settings": {"pace": "quick"}}, format="json"
                )
                results["write"] = dict(reply.data)
            except BaseException as error:
                errors.append(error)
            finally:
                committed.set()
                connection.close()

        with patch.object(LobbySerializer, "to_representation", held):
            threads = [
                threading.Thread(target=reader, name="reader"),
                threading.Thread(target=writer, name="writer"),
            ]
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join(timeout=20)
        assert errors == []

        read, write = results["read"], results["write"]
        assert write["rev"] == before["rev"] + 1
        # The read loaded the row before the write: the older number, and content
        # that is that number's or newer, never older than its number says.
        assert read["rev"] == before["rev"]
        assert content(read) in (content(before), content(write))
        assert read["settings"] == {"pace": "normal"}
