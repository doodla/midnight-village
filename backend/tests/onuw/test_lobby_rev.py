"""
The lobby's number (``Lobby.rev``) over a real evening at one table.

A phone cannot tell an older lobby body from a newer one by its content and the
order it arrives in; ``rev`` tells it. Five people (and practice players) at one
ONUW table go through everything that writes or tells the table: settings, a
stale tap, a refusal, practice on and count, joins (one to a FULL table, where
``practice.make_room`` frees a seat), a member's phone coming, the host going
away (the handover fires, ``host_changed``) and coming back, the deal, a whole
game to the results, play again (twice), a member leaving and the owner leaving.

Every body told (each lobby answer, every ``lobby_update`` and ``host_changed``
from the channel layer, in commit order) is recorded, and a GET after every step.
The rule the phone follows (api-contract-v2.md, section 2) holds:

(a) the numbers told rise strictly, in commit order;
(b) a GET whose content (without ``connected`` and ``rev``) changed has a higher ``rev``;
(c) two bodies with one ``rev`` are equal without ``connected``;
(d) an answer and the ``lobby_update`` of one request carry one ``rev``;
(e) a request that changed nothing leaves ``rev`` as it was.
"""

from __future__ import annotations

import copy
from contextlib import contextmanager
from datetime import timedelta
from typing import Any
from unittest.mock import patch

from django.urls import reverse
from django.utils import timezone

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.core import host
from apps.core.models import Lobby, LobbyMember, User
from apps.onuw.models import Game, Phase

pytestmark = pytest.mark.integration

SEED = 20261124
# Five people + three centre cards; timers off so nothing waits on a clock.
DECK = {
    "Werewolf": 2,
    "Seer": 1,
    "Robber": 1,
    "Villager": 2,
    "Drunk": 1,
    "Insomniac": 1,
}
TIMERS_OFF = {
    "night_wave_seconds": 0,
    "night_min_window_seconds": 0,
    "night_doppelganger_window_seconds": 0,
    "discussion_seconds": 0,
    "voting_seconds": 0,
}
PEOPLE = ["host", "ada", "bo", "cy", "di", "eve"]


def content(body: dict[str, Any]) -> dict[str, Any]:
    """A lobby body without ``rev`` and without anyone's ``connected``."""
    body = copy.deepcopy(dict(body))
    body.pop("rev", None)
    for player in body.get("players") or []:
        player.pop("connected", None)
    return body


def rev_of(event: dict[str, Any]) -> int:
    """The number a told event carries (``host_changed`` has it at the top)."""
    return event["rev"] if event["type"] == "host.changed" else event["data"]["rev"]


class Evening:
    """One table driven through the API; every told body and every GET recorded."""

    def __init__(self, capture: Any) -> None:
        self._capture = capture
        self.users = {
            name: User.objects.create_user(
                username=f"rev-{name}", password=None, display_name=name.title()
            )
            for name in PEOPLE
        }
        self.observer = User.objects.create_user(username="rev-observer", password=None)
        self.client = APIClient()
        self.sent: list[tuple[str, dict[str, Any]]] = []
        # One entry per step: (label, answer body or None, told events, the GET after).
        self.steps: list[dict[str, Any]] = []
        self.code = ""
        self.game_id = ""

    # -- requests -----------------------------------------------------------

    @contextmanager
    def committed(self):
        """Run as a request whose transaction commits; record every group send."""
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
        user = self.observer if name == "observer" else self.users[name]
        self.client.force_authenticate(user=user)
        with self.committed():
            return getattr(self.client, method)(url, body, format="json")

    def lobby_url(self, kind: str = "lobby-detail") -> str:
        return reverse(f"core:{kind}", kwargs={"code": self.code})

    def get(self) -> dict[str, Any]:
        reply = self.call("observer", "get", self.lobby_url())
        assert reply.status_code == status.HTTP_200_OK, reply.data
        return dict(reply.data)

    def step(self, label: str, run: Any, expect: int | None = None) -> Any:
        """Run one step; record its told bodies and the GET after it."""
        start = len(self.sent)
        reply = run()
        if expect is not None:
            assert reply.status_code == expect, (label, reply.data)
        data = getattr(reply, "data", None)
        answer = (
            dict(data)
            if isinstance(data, dict) and "rev" in data and "players" in data
            else None
        )
        told = [
            (e["type"], e)
            for g, e in self.sent[start:]
            if g == f"lobby_{self.code}"
            and e["type"] in ("lobby.update", "host.changed")
        ]
        self.steps.append(
            {
                "label": label,
                "answer": answer,
                "told": told,
                "get": self.get(),
                "game_told": [e for g, e in self.sent[start:] if g.startswith("game_")],
            }
        )
        return reply

    def at(self, label: str) -> dict[str, Any]:
        return next(s for s in self.steps if s["label"] == label)

    # -- the game -----------------------------------------------------------

    def stage(self, name: str) -> str:
        url = reverse("onuw:game-me", kwargs={"game_id": self.game_id})
        return self.call(name, "get", url).data["stage"]

    def staged(self, name: str, url_name: str, body: dict | None = None) -> Any:
        url = reverse(url_name, kwargs={"game_id": self.game_id})
        return self.call(name, "post", url, {**(body or {}), "stage": self.stage(name)})


def lobby_sockets(evening: Evening, name: str, opened: bool) -> Any:
    """A member's lobby socket opens or closes (what the consumer calls)."""
    with evening.committed():
        user_id = evening.users[name].id
        if opened:
            host.register_lobby_connection(evening.code, user_id, f"rev.{name}")
        else:
            host.unregister_lobby_connection(evening.code, user_id, f"rev.{name}")


def run_the_evening(evening: Evening) -> Evening:
    e = evening
    reply = e.call(
        "host",
        "post",
        reverse("core:lobby-list"),
        {
            "game_type": "onuw",
            "max_players": 5,
            "settings": {"roles": DECK, **TIMERS_OFF},
        },
    )
    assert reply.status_code == status.HTTP_201_CREATED, reply.data
    e.code = reply.data["code"]
    e.steps.append(
        {
            "label": "create",
            "answer": dict(reply.data),
            "told": [],
            "get": e.get(),
            "game_told": [],
        }
    )
    join = lambda who: lambda: e.call(who, "post", e.lobby_url("lobby-join"))  # noqa: E731
    patch_ = lambda who, body: lambda: e.call(who, "patch", e.lobby_url(), body)  # noqa: E731
    practice = lambda body: lambda: e.call(  # noqa: E731
        "host", "post", e.lobby_url("lobby-practice"), body
    )
    ok = status.HTTP_200_OK

    e.step("ada joins", join("ada"), ok)
    e.step("bo joins", join("bo"), ok)
    e.step(
        "settings", patch_("host", {"settings": {"pace": "quick"}, "asked": 200}), ok
    )
    e.step(
        "stale settings",
        patch_("host", {"settings": {"pace": "long"}, "asked": 100}),
        status.HTTP_409_CONFLICT,
    )
    e.step(
        "not the host",
        patch_("ada", {"settings": {"pace": "long"}}),
        status.HTTP_403_FORBIDDEN,
    )
    e.step("practice on", practice({"on": True}), ok)
    e.step("practice count", practice({"count": 2}), ok)  # 3 people + 2 = full
    e.step("join a full table", join("cy"), ok)  # make_room: a practice seat goes
    e.step("practice off", practice({"on": False}), ok)
    e.step("di joins", join("di"), ok)
    e.step("eve finds it full", join("eve"), status.HTTP_400_BAD_REQUEST)

    # The host's phone goes; ada's is here. The handover fires, then the host is back.
    e.step("ada's phone", lambda: lobby_sockets(e, "ada", True))
    e.step("host's phone", lambda: lobby_sockets(e, "host", True))
    e.step("host's phone goes", lambda: lobby_sockets(e, "host", False))
    lobby_id = Lobby.objects.get(code=e.code).pk
    LobbyMember.objects.filter(lobby_id=lobby_id, user=e.users["host"]).update(
        disconnected_at=timezone.now() - timedelta(seconds=120)
    )

    def handover() -> None:
        with e.committed():
            host._handover_due(lobby_id)

    def shown_gone() -> None:
        with e.committed():
            host._announce_if_dropped(lobby_id, e.users["host"].id)

    e.step("handover fires", handover)
    e.step("host shown gone", shown_gone)
    e.step("host comes back", lambda: lobby_sockets(e, "host", True))

    # The deal and a whole game.
    reply = e.step(
        "deal",
        lambda: e.call(
            "host",
            "post",
            reverse("onuw:game-start", kwargs={"code": e.code}),
            {"debug": {"seed": SEED}},
        ),
        status.HTTP_201_CREATED,
    )
    e.game_id = reply.data["game_id"]
    while Game.objects.get(id=e.game_id).phase == Phase.NIGHT:
        e.step("night closes", lambda: e.staged("host", "onuw:wave-advance"), ok)
    e.step("talk ends", lambda: e.staged("host", "onuw:end-discussion"), ok)
    voters = ["host", "ada", "bo", "cy", "di"]
    for i, name in enumerate(voters):
        target = e.users[voters[(i + 1) % len(voters)]].id
        e.step(
            f"{name} votes",
            lambda n=name, t=target: e.staged(
                n, "onuw:vote", {"target_player_id": t, "lock": True}
            ),
            ok,
        )
    assert Game.objects.get(id=e.game_id).phase == Phase.RESULTS

    e.step(
        "play again",
        lambda: e.call("host", "post", e.lobby_url("lobby-play-again")),
        ok,
    )
    e.step(
        "play again twice",
        lambda: e.call("host", "post", e.lobby_url("lobby-play-again")),
        ok,
    )
    e.step("bo leaves", lambda: e.call("bo", "post", e.lobby_url("lobby-leave")), ok)
    e.step(
        "owner leaves", lambda: e.call("host", "post", e.lobby_url("lobby-leave")), ok
    )
    return e


@pytest.fixture
def evening(db, settings, django_capture_on_commit_callbacks) -> Evening:
    settings.DEBUG = True  # the deal takes a fixed seed
    return run_the_evening(Evening(django_capture_on_commit_callbacks))


UNCHANGED = ["stale settings", "not the host", "eve finds it full", "play again twice"]


class TestTheNumberOverAnEvening:
    def test_the_numbers_told_rise_strictly_in_commit_order(self, evening) -> None:
        told: list[int] = []
        for step in evening.steps:
            revs = [rev_of(event) for _, event in step["told"]]
            if step["answer"] is not None and revs:
                # An answer that tells is one of the step's numbers (no extra bump).
                assert step["answer"]["rev"] in revs, step["label"]
            told.extend(revs)
        assert told == sorted(set(told)), told
        assert told[0] == 1 and len(told) > 15

    def test_a_read_whose_content_changed_has_a_higher_number(self, evening) -> None:
        changed = 0
        for before, after in zip(evening.steps, evening.steps[1:], strict=False):
            old, new = before["get"], after["get"]
            assert new["rev"] >= old["rev"], after["label"]
            if content(new) != content(old):
                changed += 1
                assert new["rev"] > old["rev"], after["label"]
        assert changed > 10

    def test_two_bodies_with_one_number_are_equal_without_connected(
        self, evening
    ) -> None:
        bodies: dict[int, dict[str, Any]] = {}
        for step in evening.steps:
            found = [step["get"]] + ([step["answer"]] if step["answer"] else [])
            found += [
                event["data"] for kind, event in step["told"] if kind == "lobby.update"
            ]
            for body in found:
                first = bodies.setdefault(body["rev"], body)
                assert content(body) == content(first), (step["label"], body["rev"])

    def test_an_answer_and_its_lobby_update_carry_one_number(self, evening) -> None:
        for label in [
            "ada joins",
            "practice on",
            "practice count",
            "join a full table",
            "settings",
            "play again",
        ]:
            step = evening.at(label)
            updates = [e for kind, e in step["told"] if kind == "lobby.update"]
            assert len(updates) == 1, label
            assert (
                updates[0]["data"]["rev"] == step["answer"]["rev"] == step["get"]["rev"]
            )
            assert updates[0]["data"] == step["answer"], label

    def test_a_request_that_changed_nothing_leaves_the_number(self, evening) -> None:
        for label in UNCHANGED:
            index = evening.steps.index(evening.at(label))
            step, before = evening.steps[index], evening.steps[index - 1]
            assert step["told"] == [], label
            assert step["get"]["rev"] == before["get"]["rev"], label
        # The repeated play again answers with the body as read, not a new number.
        assert (
            evening.at("play again twice")["answer"]["rev"]
            == evening.at("play again")["answer"]["rev"]
        )


class TestTheForeignWriters:
    def test_the_full_table_join_that_frees_a_practice_seat_is_one_number(
        self, evening
    ) -> None:
        before, step = evening.at("practice count"), evening.at("join a full table")
        assert step["answer"]["rev"] == before["answer"]["rev"] + 1
        names = [p["user"]["display_name"] for p in step["answer"]["players"]]
        assert (
            "Cy" in names
            and sum(bool(p.get("practice")) for p in step["answer"]["players"]) == 1
        )

    def test_the_handover_tells_host_changed_with_the_new_number(self, evening) -> None:
        before, step = evening.at("host's phone goes"), evening.at("handover fires")
        ((kind, event),) = step["told"]
        assert kind == "host.changed" and event["reason"] == "handover"
        assert event["host_id"] == evening.users["ada"].id
        assert event["rev"] == before["get"]["rev"] + 1 == step["get"]["rev"]
        assert step["get"]["host"]["id"] == evening.users["ada"].id

    def test_the_host_back_is_host_changed_then_the_body_with_the_next_number(
        self, evening
    ) -> None:
        step = evening.at("host comes back")
        kinds = [kind for kind, _ in step["told"]]
        assert kinds == ["host.changed", "lobby.update"]
        changed, update = (event for _, event in step["told"])
        assert changed["reason"] == "returned"
        assert rev_of(update) == changed["rev"] + 1 == step["get"]["rev"]

    def test_the_owner_leaving_tells_both_groups_one_number(self, evening) -> None:
        step = evening.at("owner leaves")
        changed = [e for kind, e in step["told"] if kind == "host.changed"]
        in_game = [e for e in step["game_told"] if e["type"] == "host.changed"]
        assert len(changed) == len(in_game) == 1
        assert changed[0]["reason"] == "transferred"
        assert in_game[0]["rev"] == changed[0]["rev"] == step["get"]["rev"] - 1

    def test_the_deal_and_the_results_raise_the_number_without_a_body(
        self, evening
    ) -> None:
        deal = evening.at("deal")
        assert deal["told"] == [] and deal["get"]["status"] == "in_game"
        last_vote = evening.at("di votes")
        assert last_vote["get"]["status"] == "finished"
        index = evening.steps.index(last_vote)
        assert last_vote["get"]["rev"] == evening.steps[index - 1]["get"]["rev"] + 1
