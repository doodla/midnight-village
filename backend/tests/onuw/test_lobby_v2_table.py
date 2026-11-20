"""
A night protocol 2 table before its deal (the rebuilt lobby screens).

- The deal has no ready check at a protocol-2 table: a guest who joins and closes
  the app at once cannot block it (the original night still needs everyone ready).
- The lobby body (and ``lobby_update``) has ``connected`` per member, from presence:
  a phone that drops still shows as connected for the table's grace period
  (``disconnect_grace_seconds``), then the table is told; coming back is told at once.
- ``deck_preview``: the automatic deck the deal would build now (null for a custom
  deck); ``deal``: ``{ok, need, have}``, ``ok`` exactly what the deal view answers.
- A member of another table that is still going is refused a seat with 409
  ``already_at_table`` and that table's code; finished tables trap nobody.

All through the real API, several players, seeded deals; a table whose settings do
not say ``night_protocol: 2`` is answered exactly as before.
"""

from __future__ import annotations

import itertools
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
from apps.onuw.engine.decks import DECK_CHIPS, auto_deck
from apps.onuw.models import Game, Phase

pytestmark = pytest.mark.integration

V2 = {"night_protocol": 2, "card_look_seconds": 30, "deck": "auto"}
CUSTOM_5 = {"Werewolf": 2, "Seer": 1, "Robber": 1, "Troublemaker": 1, "Villager": 3}
_names = itertools.count()


class FakeLayer:
    """The channel layer: remembers every group message."""

    def __init__(self) -> None:
        self.sent: list[tuple[str, dict[str, Any]]] = []

    async def group_send(self, group: str, message: dict[str, Any]) -> None:
        self.sent.append((group, message))

    def lobby_updates(self, code: str) -> list[dict[str, Any]]:
        return [
            m["data"]
            for g, m in self.sent
            if g == f"lobby_{code}" and m["type"] == "lobby.update"
        ]


@pytest.fixture
def layer():
    fake = FakeLayer()
    with (
        patch("apps.core.effects.get_channel_layer", return_value=fake),
        patch("apps.core.views.get_channel_layer", return_value=fake),
        patch("apps.onuw.views.get_channel_layer", return_value=fake),
    ):
        yield fake


class Table:
    def __init__(self, capture: Any, settings: dict[str, Any] | None) -> None:
        self.capture = capture
        self.users: dict[str, User] = {}
        self.host = self.user("host")
        body: dict[str, Any] = {"game_type": "onuw"}
        if settings is not None:
            body["settings"] = settings
        reply = self.post("host", reverse("core:lobby-list"), body)
        assert reply.status_code == status.HTTP_201_CREATED, reply.data
        self.code = reply.data["code"]

    def user(self, name: str) -> User:
        user = User.objects.create_user(
            username=f"lv2_{name}_{next(_names)}", password="pass"
        )
        self.users[name] = user
        return user

    def client(self, name: str) -> APIClient:
        client = APIClient()
        client.force_authenticate(user=self.users[name])
        return client

    def post(self, name: str, url: str, body: Any = None) -> Any:
        with self.capture(execute=True):
            return self.client(name).post(url, body or {}, format="json")

    def join(self, name: str) -> Any:
        if name not in self.users:
            self.user(name)
        return self.post(name, reverse("core:lobby-join", kwargs={"code": self.code}))

    def body(self, name: str = "host") -> dict[str, Any]:
        reply = self.client(name).get(
            reverse("core:lobby-detail", kwargs={"code": self.code})
        )
        assert reply.status_code == status.HTTP_200_OK
        return reply.data

    def patch(self, settings: dict[str, Any]) -> Any:
        with self.capture(execute=True):
            return self.client("host").patch(
                reverse("core:lobby-detail", kwargs={"code": self.code}),
                {"settings": settings},
                format="json",
            )

    def deal(self, seed: int = 7) -> Any:
        with self.settings_debug():
            return self.post(
                "host",
                reverse("onuw:game-start", kwargs={"code": self.code}),
                {"debug": {"seed": seed}},
            )

    def settings_debug(self) -> Any:
        from django.test import override_settings

        return override_settings(DEBUG=True)

    def lobby(self) -> Lobby:
        return Lobby.objects.get(code=self.code)

    def socket(self, name: str) -> None:
        with self.capture(execute=True):
            host.register_lobby_connection(self.code, self.users[name].id)

    def socket_closes(self, name: str) -> None:
        with self.capture(execute=True):
            host.unregister_lobby_connection(self.code, self.users[name].id)


@pytest.fixture
def table(db, django_capture_on_commit_callbacks, layer):
    def factory(settings: dict[str, Any] | None = V2, players: int = 5) -> Table:
        t = Table(django_capture_on_commit_callbacks, settings)
        for i in range(1, players):
            assert t.join(f"p{i}").status_code == status.HTTP_200_OK
        return t

    return factory


def connected(body: dict[str, Any]) -> dict[int, bool]:
    return {p["user"]["id"]: p["connected"] for p in body["players"]}


# ── A. the deal does not wait for "ready" ───────────────────────────────────


class TestNoReadyCheck:
    def test_a_v2_table_deals_although_nobody_tapped_ready(self, table) -> None:
        t = table(players=5)
        assert not any(
            m.is_ready for m in LobbyMember.objects.filter(lobby__code=t.code)
        )

        reply = t.deal()

        assert reply.status_code == status.HTTP_201_CREATED, reply.data
        game = Game.objects.get(id=reply.data["game_id"])
        assert game.player_roles.count() == 5  # everyone at the table is dealt in

    def test_a_guest_who_joined_and_closed_the_app_does_not_block_it(
        self, table
    ) -> None:
        t = table(players=4)
        for name in ["host", "p1", "p2", "p3"]:
            t.socket(name)
        t.join("guest")  # joins over HTTP, never opens a socket, never taps ready

        assert t.body()["deal"]["ok"] is True
        assert t.deal().status_code == status.HTTP_201_CREATED

    def test_the_original_night_still_needs_everyone_ready(self, table) -> None:
        t = table(settings={"roles": CUSTOM_5}, players=5)

        reply = t.deal()

        assert reply.status_code == status.HTTP_400_BAD_REQUEST
        assert reply.data == {"detail": "Not all players are ready."}


# ── B. who is connected ─────────────────────────────────────────────────────


class TestConnected:
    def test_each_member_says_whether_their_phone_is_here(self, table) -> None:
        t = table(players=4)
        for name in ["host", "p1", "p2"]:
            t.socket(name)

        shown = connected(t.body("p3"))

        assert shown == {
            t.users["host"].id: True,
            t.users["p1"].id: True,
            t.users["p2"].id: True,
            t.users["p3"].id: False,  # never opened the table
        }
        # The same on every phone: it is the table's, not the viewer's.
        assert {tuple(sorted(connected(t.body(n)).items())) for n in t.users} == {
            tuple(sorted(shown.items()))
        }

    def test_a_drop_is_told_after_the_grace_period_and_a_return_at_once(
        self, table, layer
    ) -> None:
        t = table({**V2, "disconnect_grace_seconds": 20}, players=4)
        for name in t.users:
            t.socket(name)
        layer.sent.clear()
        p2 = t.users["p2"].id

        t.socket_closes("p2")
        # Inside the grace period: still shown, nothing told.
        assert connected(t.body())[p2] is True
        assert layer.lobby_updates(t.code) == []
        # The check fires early: nothing yet.
        with t.capture(execute=True):
            host.check_lobby_presence(t.lobby().pk, p2)
        assert layer.lobby_updates(t.code) == []

        LobbyMember.objects.filter(lobby__code=t.code, user_id=p2).update(
            disconnected_at=timezone.now() - timedelta(seconds=21)
        )
        with t.capture(execute=True):
            host.check_lobby_presence(t.lobby().pk, p2)
        (dropped,) = layer.lobby_updates(t.code)
        assert connected(dropped)[p2] is False
        assert all(v for k, v in connected(dropped).items() if k != p2)
        assert connected(t.body("p1"))[p2] is False

        t.socket("p2")
        assert connected(layer.lobby_updates(t.code)[-1])[p2] is True

    def test_a_drop_is_never_told_for_someone_who_came_back(self, table, layer) -> None:
        t = table({**V2, "disconnect_grace_seconds": 20}, players=3)
        for name in t.users:
            t.socket(name)
        p1 = t.users["p1"].id
        t.socket_closes("p1")
        t.socket("p1")
        layer.sent.clear()

        with t.capture(execute=True):
            host.check_lobby_presence(t.lobby().pk, p1)

        assert layer.lobby_updates(t.code) == []

    def test_join_and_leave_send_the_whole_body(self, table, layer) -> None:
        t = table(players=3)
        layer.sent.clear()

        t.join("late")
        t.post("late", reverse("core:lobby-leave", kwargs={"code": t.code}))

        joined, left = layer.lobby_updates(t.code)
        assert len(joined["players"]) == 4 and joined["deal"]["need"] == 7
        assert len(left["players"]) == 3 and left["deal"]["need"] == 6

    def test_the_original_table_is_answered_as_before(self, table, layer) -> None:
        t = table(settings={"roles": CUSTOM_5}, players=4)
        t.socket("p1")
        t.socket_closes("p1")

        body = t.body()

        assert not {"deck_preview", "deal"} & set(body)
        assert all("connected" not in p for p in body["players"])
        assert layer.lobby_updates(t.code) == []


# ── C. the automatic deck the deal would build ──────────────────────────────


class TestDeckPreview:
    @pytest.mark.parametrize("chip", DECK_CHIPS)
    def test_the_preview_is_what_the_deal_deals(self, table, chip) -> None:
        for players, seed in ((3, 11), (6, 12), (10, 13)):
            t = table({**V2, "deck_chip": chip}, players=players)
            preview = t.body()["deck_preview"]
            assert preview == auto_deck(players, chip)

            reply = t.deal(seed)

            assert reply.status_code == status.HTTP_201_CREATED
            game = Game.objects.get(id=reply.data["game_id"])
            assert game.settings["roles"] == preview

    def test_it_follows_the_chip_and_the_player_count(self, table, layer) -> None:
        t = table(players=4)
        layer.sent.clear()

        t.patch({"deck_chip": "chaos"})
        t.join("p4")

        chip_change, joined = layer.lobby_updates(t.code)
        assert chip_change["deck_preview"] == auto_deck(4, "chaos")
        assert joined["deck_preview"] == auto_deck(5, "chaos")

    def test_a_custom_deck_has_no_preview(self, table) -> None:
        t = table({**V2, "deck": "custom", "roles": CUSTOM_5}, players=5)
        assert t.body()["deck_preview"] is None


# ── D. ``deal`` says exactly what the deal view would answer ────────────────

SWEEP = [
    # (settings, players at the table)
    (V2, 1),
    (V2, 2),
    (V2, 3),
    (V2, 7),
    (V2, 10),
    ({**V2, "deck_chip": "classic"}, 5),
    ({**V2, "deck_chip": "chaos"}, 9),
    ({**V2, "deck": "custom", "roles": CUSTOM_5}, 5),
    ({**V2, "deck": "custom", "roles": CUSTOM_5}, 4),  # one card too many
    ({**V2, "deck": "custom", "roles": CUSTOM_5}, 6),  # one card short
    ({**V2, "deck": "custom", "roles": {**CUSTOM_5, "Mason": 1, "Villager": 2}}, 5),
    ({**V2, "deck": "custom"}, 5),  # no roles at all
]


class TestDealOk:
    @pytest.mark.parametrize(("settings", "players"), SWEEP)
    def test_ok_and_the_deal_view_never_disagree(
        self, table, settings, players
    ) -> None:
        t = table(settings, players=players)
        deal = t.body()["deal"]
        deck = (
            auto_deck(players, settings.get("deck_chip"))
            if settings.get("deck") == "auto"
            else settings.get("roles")
        )
        expected_have = sum((deck or {}).values())

        reply = t.deal()

        assert deal == {"ok": deal["ok"], "need": players + 3, "have": expected_have}
        assert deal["ok"] is (reply.status_code == status.HTTP_201_CREATED), reply.data

    def test_a_table_in_a_game_or_finished_is_not_ok(self, table) -> None:
        t = table(players=5)
        assert t.deal().status_code == status.HTTP_201_CREATED
        assert t.body()["deal"]["ok"] is False
        assert t.deal().status_code == status.HTTP_400_BAD_REQUEST

        Lobby.objects.filter(code=t.code).update(status=Lobby.Status.FINISHED)
        assert t.body()["deal"]["ok"] is False
        assert t.deal().status_code == status.HTTP_400_BAD_REQUEST


# ── E. one table at a time ──────────────────────────────────────────────────


class TestOneTableAtATime:
    def test_a_member_of_a_table_still_going_is_pointed_at_it(self, table) -> None:
        first = table(players=3)
        second = table(players=3)
        second.users["p1"] = first.users["p1"]

        reply = second.join("p1")

        assert reply.status_code == status.HTTP_409_CONFLICT
        assert reply.data == {
            "detail": "You are already at another table.",
            "code": "already_at_table",
            "lobby_code": first.code,
        }
        assert not LobbyMember.objects.filter(
            lobby__code=second.code, user=first.users["p1"]
        ).exists()

    def test_a_table_in_a_game_counts_too(self, table) -> None:
        first = table(players=3)
        assert first.deal().status_code == status.HTTP_201_CREATED
        second = table(players=3)
        second.users["p2"] = first.users["p2"]

        reply = second.join("p2")

        assert reply.status_code == status.HTTP_409_CONFLICT
        assert reply.data["lobby_code"] == first.code

    def test_a_finished_table_traps_nobody(self, table) -> None:
        first = table(players=3)
        assert first.deal().status_code == status.HTTP_201_CREATED
        game = Game.objects.get(lobby__code=first.code)
        Game.objects.filter(id=game.id).update(phase=Phase.RESULTS)
        Lobby.objects.filter(code=first.code).update(status=Lobby.Status.FINISHED)
        second = table(players=3)
        second.users["p1"] = first.users["p1"]

        assert second.join("p1").status_code == status.HTTP_200_OK

    def test_after_play_again_a_player_may_leave_and_sit_elsewhere(self, table) -> None:
        first = table(players=3)
        assert first.deal().status_code == status.HTTP_201_CREATED
        Game.objects.filter(lobby__code=first.code).update(phase=Phase.RESULTS)
        Lobby.objects.filter(code=first.code).update(status=Lobby.Status.FINISHED)
        again = first.post(
            "host", reverse("core:lobby-play-again", kwargs={"code": first.code})
        )
        assert again.status_code == status.HTTP_200_OK
        second = table(players=3)
        second.users["p1"] = first.users["p1"]

        # The table is waiting again: it is where p1 sits...
        assert second.join("p1").status_code == status.HTTP_409_CONFLICT
        # ...until p1 gets up.
        first.post("p1", reverse("core:lobby-leave", kwargs={"code": first.code}))
        assert second.join("p1").status_code == status.HTTP_200_OK

    def test_a_table_nobody_touched_for_hours_traps_nobody(
        self, table, settings
    ) -> None:
        first = table(players=3)
        Lobby.objects.filter(code=first.code).update(
            updated_at=timezone.now()
            - timedelta(hours=settings.CORE_TABLE_RESUME_HOURS + 1)
        )
        second = table(players=3)
        second.users["p1"] = first.users["p1"]

        assert second.join("p1").status_code == status.HTTP_200_OK
