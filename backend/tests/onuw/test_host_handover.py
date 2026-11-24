"""
Host handover: the host role passes on while the host's phone is away.

``Lobby.host`` stays the owner. ``Lobby.acting_host`` holds the role while the
owner is away (after ``host_handover_seconds``, default 60), and the role goes
straight back the moment the owner has a socket again. Works in a game and at
the table between games; presence comes from lobby sockets and game sockets.
"""

import asyncio
from datetime import timedelta
from typing import Any

from django.test import TransactionTestCase
from django.urls import reverse
from django.utils import timezone

import pytest
from channels.db import database_sync_to_async
from channels.testing import WebsocketCommunicator
from rest_framework import status

from apps.core import host
from apps.core import presence as core_presence
from apps.core.consumers import LobbyConsumer
from apps.core.models import Lobby, LobbyMember, LobbySocket, User
from apps.core.wire import public_name
from apps.onuw import game_presence, presence, recovery, services
from apps.onuw.consumers import GameConsumer
from apps.onuw.engine.validation import validate_timer_settings
from apps.onuw.models import Game, Phase, PlayerRole
from tests.onuw.stages import staged
from tests.onuw.test_night_windows import Night

pytestmark = pytest.mark.integration

ROLES = {  # join order = this order; "wolf" is the owner / host
    "wolf": "Werewolf",
    "seer": "Seer",
    "robber": "Robber",
    "villager": "Villager",
}


# ── helpers ──────────────────────────────────────────────────────────────────


def lobby_of(night: Night) -> Lobby:
    return Lobby.objects.get(pk=night.game.lobby_id)


def uid(night: Night, name: str) -> int:
    return night.users[name].id


def acting(night: Night) -> int | None:
    return lobby_of(night).acting_host_id


def lobby_rows(night: Night, name: str) -> int:
    """How many lobby socket rows the member has."""
    return LobbySocket.objects.filter(
        lobby_id=night.game.lobby_id, user=night.users[name]
    ).count()


def lobby_socket(night: Night, name: str) -> None:
    with night.committed():
        host.register_lobby_connection(lobby_of(night).code, uid(night, name))


def lobby_socket_closes(night: Night, name: str, seconds_ago: float = 0) -> None:
    code = lobby_of(night).code
    if not core_presence.fresh_rows(
        lobby_id=lobby_of(night).pk, user_id=uid(night, name)
    ).exists():
        lobby_socket(night, name)
    with night.committed():
        host.unregister_lobby_connection(code, uid(night, name))
    if seconds_ago:
        LobbyMember.objects.filter(lobby__code=code, user=night.users[name]).update(
            disconnected_at=timezone.now() - timedelta(seconds=seconds_ago)
        )


def game_socket(night: Night, name: str) -> None:
    with night.committed():
        if game_presence.register_connection(night.game.id, uid(night, name)):
            services.report_game_presence(night.game.id, uid(night, name), True)


def game_socket_closes(night: Night, name: str, seconds_ago: float = 0) -> None:
    if not presence.fresh_rows(
        game_id=night.game.id, user_id=uid(night, name)
    ).exists():
        game_socket(night, name)
    with night.committed():
        if game_presence.unregister_connection(night.game.id, uid(night, name)):
            services.report_game_presence(night.game.id, uid(night, name), False)
    if seconds_ago:
        PlayerRole.objects.filter(game=night.game, user=night.users[name]).update(
            disconnected_at=timezone.now() - timedelta(seconds=seconds_ago)
        )


def handover_key(night: Night) -> str:
    return host.timer_key(lobby_of(night))


def handover_timers(night: Night) -> list[tuple[float, Any]]:
    return [(d, cb) for k, d, cb in night.scheduled if k == handover_key(night)]


def fire_handover(night: Night) -> None:
    timers_ = handover_timers(night)
    assert timers_, "no handover timer is scheduled"
    with night.committed():
        timers_[-1][1]()


def fire_callback(night: Night, callback: Any) -> None:
    with night.committed():
        callback()


def host_events(night: Night) -> list[tuple[str, dict[str, Any]]]:
    return [(g, e) for g, e in night.recorder.events if e["type"] == "host.changed"]


def at_the_table(night: Night) -> None:
    """Between games: the lobby is waiting and the newest game is over."""
    Game.objects.filter(id=night.game.id).update(phase=Phase.RESULTS, current_wave=0)
    Lobby.objects.filter(pk=night.game.lobby_id).update(status=Lobby.Status.WAITING)
    night.refresh()


def post_as(night: Night, name: str, url: str, **kw: Any) -> Any:
    """POST as ``name``; a game's host endpoint names the current stage."""
    night.client.force_authenticate(user=night.users[name])
    if "data" not in kw and "/games/" in url:
        kw["data"] = staged(night, {})
    with night.committed():
        return night.client.post(url, format="json", **kw)


# ── handing over ─────────────────────────────────────────────────────────────


class TestHandoverInAGame:
    def test_after_the_period_the_next_connected_member_in_join_order_takes_over(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        game_socket(night, "wolf")
        game_socket(night, "robber")  # the seer (next in order) is not connected
        game_socket(night, "villager")
        game_socket_closes(night, "wolf", seconds_ago=61)
        assert len(handover_timers(night)) == 1
        assert 59 < handover_timers(night)[0][0] <= 60

        fire_handover(night)

        lobby = lobby_of(night)
        assert lobby.host_id == uid(night, "wolf")  # the owner never changes
        assert lobby.acting_host_id == uid(night, "robber")
        assert lobby.effective_host_id == uid(night, "robber")

    def test_the_change_is_announced_once_to_the_lobby_and_the_game(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        game_socket(night, "wolf")
        game_socket(night, "seer")
        game_socket_closes(night, "wolf", seconds_ago=61)

        fire_handover(night)

        code = lobby_of(night).code
        expected = {
            "type": "host.changed",
            "host_id": uid(night, "seer"),
            "host_name": public_name(night.users["seer"]),
            "original_host_id": uid(night, "wolf"),
            "reason": "handover",
            "rev": lobby_of(night).rev,  # telling is the bump
        }
        assert sorted(host_events(night), key=lambda ge: ge[0]) == sorted(
            [(f"lobby_{code}", expected), (f"game_{night.game.id}", expected)],
            key=lambda ge: ge[0],
        )

    def test_nothing_happens_before_the_period_is_over(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        game_socket(night, "wolf")
        game_socket(night, "seer")
        game_socket_closes(night, "wolf", seconds_ago=30)
        due = handover_timers(night)[-1][1]
        night.scheduled.clear()

        fire_callback(night, due)

        assert acting(night) is None
        assert host_events(night) == []
        assert 29 < handover_timers(night)[0][0] <= 30  # waits out the rest

    def test_a_host_who_comes_back_in_time_keeps_the_role_and_the_timer_stops(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        game_socket(night, "wolf")
        game_socket(night, "seer")
        game_socket_closes(night, "wolf", seconds_ago=20)
        stale = handover_timers(night)[-1][1]

        game_socket(night, "wolf")
        with night.committed():
            stale()  # the timer was already running

        assert acting(night) is None
        assert host_events(night) == []

    def test_the_owner_gets_the_role_back_at_once_when_a_game_socket_opens(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        game_socket(night, "wolf")
        game_socket(night, "seer")
        game_socket_closes(night, "wolf", seconds_ago=61)
        fire_handover(night)
        assert acting(night) == uid(night, "seer")
        night.recorder.events.clear()

        game_socket(night, "wolf")

        assert acting(night) is None
        events = host_events(night)
        assert {e["reason"] for _, e in events} == {"returned"}
        assert {e["host_id"] for _, e in events} == {uid(night, "wolf")}
        assert len(events) == 2  # lobby group and game group

    def test_the_role_passes_on_again_when_the_acting_host_also_drops(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        for name in ROLES:
            game_socket(night, name)
        game_socket_closes(night, "wolf", seconds_ago=120)
        fire_handover(night)
        assert acting(night) == uid(night, "seer")

        game_socket_closes(night, "seer", seconds_ago=61)
        fire_handover(night)

        # Next connected in join order; never the absent owner.
        assert acting(night) == uid(night, "robber")
        assert lobby_of(night).host_id == uid(night, "wolf")

    def test_a_third_handover_skips_everyone_absent_and_never_picks_the_owner(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        for name in ROLES:
            game_socket(night, name)
        game_socket_closes(night, "wolf", seconds_ago=300)
        fire_handover(night)
        game_socket_closes(night, "seer", seconds_ago=200)
        fire_handover(night)
        assert acting(night) == uid(night, "robber")
        game_socket_closes(night, "robber", seconds_ago=100)

        fire_handover(night)

        assert acting(night) == uid(night, "villager")

    def test_nobody_connected_means_no_handover_until_someone_connects(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        game_socket(night, "wolf")
        game_socket_closes(night, "wolf", seconds_ago=500)

        fire_handover(night)  # the period is long over, but nobody is here
        assert acting(night) is None
        assert host_events(night) == []

        game_socket(night, "villager")  # someone arrives

        assert acting(night) == uid(night, "villager")
        assert [e["reason"] for _, e in host_events(night)] == ["handover"] * 2

    def test_the_acting_host_dropping_before_the_period_keeps_the_role(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        for name in ROLES:
            game_socket(night, name)
        game_socket_closes(night, "wolf", seconds_ago=120)
        fire_handover(night)
        game_socket_closes(night, "seer", seconds_ago=10)
        due = handover_timers(night)[-1][1]
        night.scheduled.clear()

        fire_callback(night, due)

        assert acting(night) == uid(night, "seer")  # not yet

    def test_the_setting_zero_turns_it_off(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        Lobby.objects.filter(pk=night.game.lobby_id).update(
            settings={"roles": {}, "host_handover_seconds": 0}
        )
        night.start()
        game_socket(night, "wolf")
        game_socket(night, "seer")
        game_socket_closes(night, "wolf", seconds_ago=900)

        assert handover_timers(night) == []
        game_socket(night, "robber")
        assert acting(night) is None

    def test_a_custom_period_is_honoured(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        Lobby.objects.filter(pk=night.game.lobby_id).update(
            settings={"roles": {}, "host_handover_seconds": 200}
        )
        night.start()
        game_socket(night, "wolf")
        game_socket(night, "seer")
        game_socket_closes(night, "wolf", seconds_ago=100)
        due = handover_timers(night)[-1][1]
        night.scheduled.clear()

        fire_callback(night, due)

        assert acting(night) is None
        assert 99 < handover_timers(night)[0][0] <= 100


class TestHandoverAtTheTable:
    def test_it_works_between_games_with_lobby_sockets_only(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        at_the_table(night)
        for name in ROLES:
            lobby_socket(night, name)
        lobby_socket_closes(night, "wolf", seconds_ago=61)
        assert len(handover_timers(night)) == 1

        fire_handover(night)

        assert acting(night) == uid(night, "seer")

    def test_it_is_not_early_at_the_table_either(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        at_the_table(night)
        lobby_socket(night, "seer")
        lobby_socket_closes(night, "wolf", seconds_ago=40)
        due = handover_timers(night)[-1][1]
        night.scheduled.clear()

        fire_callback(night, due)

        assert acting(night) is None

    def test_a_lobby_socket_gives_the_role_back_at_once(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        at_the_table(night)
        lobby_socket(night, "villager")
        lobby_socket_closes(night, "wolf", seconds_ago=61)
        fire_handover(night)
        assert acting(night) == uid(night, "villager")

        lobby_socket(night, "wolf")

        assert acting(night) is None

    def test_a_game_socket_counts_as_connected_for_the_newest_game_only(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        at_the_table(night)
        # The seer is on the old game's results screen: that is still "here".
        game_socket(night, "seer")
        lobby_socket_closes(night, "wolf", seconds_ago=61)
        fire_handover(night)
        assert acting(night) == uid(night, "seer")

    def test_the_owner_with_a_game_socket_open_is_not_away_even_with_no_lobby_socket(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        game_socket(night, "wolf")
        lobby_socket(night, "wolf")
        lobby_socket(night, "seer")

        lobby_socket_closes(night, "wolf", seconds_ago=500)  # the game socket remains

        assert handover_timers(night) == []
        assert acting(night) is None


# ── counting sockets ─────────────────────────────────────────────────────────


class TestLobbySocketCounting:
    def test_two_sockets_for_one_member_stay_connected_until_the_last_closes(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        lobby_socket(night, "wolf")
        lobby_socket(night, "wolf")
        member = LobbyMember.objects.get(
            lobby_id=night.game.lobby_id, user=night.users["wolf"]
        )
        assert lobby_rows(night, "wolf") == 2

        with night.committed():
            host.unregister_lobby_connection(lobby_of(night).code, uid(night, "wolf"))
        member.refresh_from_db()
        assert lobby_rows(night, "wolf") == 1
        assert member.disconnected_at is None
        assert handover_timers(night) == []

        with night.committed():
            host.unregister_lobby_connection(lobby_of(night).code, uid(night, "wolf"))
        member.refresh_from_db()
        assert lobby_rows(night, "wolf") == 0
        assert member.disconnected_at is not None
        assert len(handover_timers(night)) == 1

    def test_the_count_never_goes_below_zero(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        with night.committed():
            host.unregister_lobby_connection(lobby_of(night).code, uid(night, "seer"))
            host.unregister_lobby_connection(lobby_of(night).code, uid(night, "seer"))
        member = LobbyMember.objects.get(
            lobby_id=night.game.lobby_id, user=night.users["seer"]
        )
        assert lobby_rows(night, "seer") == 0
        assert member.disconnected_at is None

    def test_a_non_member_is_not_counted(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        stranger = User.objects.create_user(username="hh_stranger", password="x")
        with night.committed():
            assert (
                host.register_lobby_connection(lobby_of(night).code, stranger.id)
                is False
            )

    def test_lobby_presence_is_never_broadcast_as_a_presence_event(
        self, make_night
    ) -> None:
        """A lobby socket's comings and goings reach the table only as the table's
        own body (``lobby_update`` with ``connected``), never as presence events."""
        night = make_night(ROLES, night_wave_seconds=0)
        lobby_socket(night, "wolf")
        lobby_socket(night, "seer")
        lobby_socket_closes(night, "wolf")
        assert {e["type"] for _, e in night.recorder.events} <= {"lobby.update"}


# ── what the host may do ─────────────────────────────────────────────────────


class TestHostPowers:
    def _hand_over(self, night: Night) -> None:
        for name in ROLES:
            game_socket(night, name)
        game_socket_closes(night, "wolf", seconds_ago=120)
        fire_handover(night)
        assert acting(night) == uid(night, "seer")

    def test_the_acting_host_can_close_the_night_end_the_talk_and_reveal(
        self, make_night
    ) -> None:
        night = make_night(
            ROLES, night_wave_seconds=0, discussion_seconds=0, voting_seconds=0
        )
        night.start()
        self._hand_over(night)
        kw = {"game_id": str(night.game.id)}

        assert (
            post_as(night, "seer", reverse("onuw:wave-advance", kwargs=kw)).status_code
            == 200
        )
        assert night.refresh().phase == Phase.DISCUSSION
        assert (
            post_as(
                night, "seer", reverse("onuw:end-discussion", kwargs=kw)
            ).status_code
            == 200
        )
        assert night.refresh().phase == Phase.VOTING
        assert (
            post_as(night, "seer", reverse("onuw:reveal-votes", kwargs=kw)).status_code
            == 200
        )
        assert night.refresh().phase == Phase.RESULTS

    def test_while_someone_else_acts_the_absent_owner_and_others_are_refused(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        self._hand_over(night)
        url = reverse("onuw:wave-advance", kwargs={"game_id": str(night.game.id)})

        for name in ("wolf", "robber", "villager"):
            assert post_as(night, name, url).status_code == status.HTTP_403_FORBIDDEN
        assert night.refresh().phase == Phase.NIGHT

    def test_the_owner_has_every_power_back_after_returning(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        self._hand_over(night)
        game_socket(night, "wolf")

        url = reverse("onuw:wave-advance", kwargs={"game_id": str(night.game.id)})
        assert post_as(night, "seer", url).status_code == status.HTTP_403_FORBIDDEN
        assert post_as(night, "wolf", url).status_code == status.HTTP_200_OK

    def test_the_acting_host_can_change_the_lobby_settings_and_deal_again(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        at_the_table(night)
        for name in ROLES:
            lobby_socket(night, name)
        lobby_socket_closes(night, "wolf", seconds_ago=120)
        fire_handover(night)
        code = lobby_of(night).code
        roles = {"Werewolf": 2, "Seer": 1, "Villager": 3, "Robber": 1}

        night.client.force_authenticate(user=night.users["seer"])
        patched = night.client.patch(
            reverse("core:lobby-detail", kwargs={"code": code}),
            {"settings": {"roles": roles}},
            format="json",
        )
        night.client.force_authenticate(user=night.users["villager"])
        refused = night.client.patch(
            reverse("core:lobby-detail", kwargs={"code": code}),
            {"settings": {"roles": roles}},
            format="json",
        )

        assert patched.status_code == status.HTTP_200_OK
        assert refused.status_code == status.HTTP_403_FORBIDDEN
        assert lobby_of(night).settings["roles"] == roles
        started = post_as(
            night, "seer", reverse("onuw:game-start", kwargs={"code": code})
        )
        assert started.status_code == status.HTTP_201_CREATED
        assert Game.objects.filter(lobby_id=night.game.lobby_id).count() == 2

    def test_play_again_by_the_acting_host_works_and_the_owner_stays_the_owner(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        Game.objects.filter(id=night.game.id).update(
            phase=Phase.RESULTS, current_wave=0
        )
        Lobby.objects.filter(pk=night.game.lobby_id).update(
            status=Lobby.Status.FINISHED
        )
        for name in ROLES:
            lobby_socket(night, name)
        lobby_socket_closes(night, "wolf", seconds_ago=120)
        fire_handover(night)
        code = lobby_of(night).code
        url = reverse("core:lobby-play-again", kwargs={"code": code})

        refused = post_as(night, "robber", url)
        response = post_as(night, "seer", url)

        assert refused.status_code == status.HTTP_403_FORBIDDEN
        assert response.status_code == status.HTTP_200_OK
        lobby = lobby_of(night)
        assert lobby.status == Lobby.Status.WAITING
        assert lobby.host_id == uid(night, "wolf")
        assert lobby.acting_host_id == uid(night, "seer")
        assert response.data["original_host_id"] == uid(night, "wolf")

    def test_the_owner_cannot_play_again_while_someone_else_holds_the_role(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        Game.objects.filter(id=night.game.id).update(
            phase=Phase.RESULTS, current_wave=0
        )
        Lobby.objects.filter(pk=night.game.lobby_id).update(
            status=Lobby.Status.FINISHED
        )
        for name in ROLES:
            lobby_socket(night, name)
        lobby_socket_closes(night, "wolf", seconds_ago=120)
        fire_handover(night)
        url = reverse("core:lobby-play-again", kwargs={"code": lobby_of(night).code})

        assert post_as(night, "wolf", url).status_code == status.HTTP_403_FORBIDDEN


# ── what clients read ────────────────────────────────────────────────────────


class TestWhatClientsRead:
    def _hand_over(self, night: Night) -> None:
        for name in ROLES:
            game_socket(night, name)
        game_socket_closes(night, "wolf", seconds_ago=120)
        fire_handover(night)

    def test_lobby_detail_host_is_the_effective_host_with_the_owner_alongside(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        code = lobby_of(night).code
        night.client.force_authenticate(user=night.users["villager"])
        url = reverse("core:lobby-detail", kwargs={"code": code})

        before = night.client.get(url).data
        assert before["host"]["id"] == uid(night, "wolf")
        assert before["original_host_id"] == uid(night, "wolf")
        assert before["is_acting_host"] is False

        self._hand_over(night)
        after = night.client.get(url).data

        assert set(after["host"]) == {"id", "display_name"}
        assert after["host"]["id"] == uid(night, "seer")
        assert after["original_host_id"] == uid(night, "wolf")
        assert after["is_acting_host"] is True

    def test_me_has_host_id_and_is_host_for_the_effective_host(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        url = reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})
        night.client.force_authenticate(user=night.users["wolf"])
        data = night.client.get(url).data
        assert data["host_id"] == uid(night, "wolf")
        assert data["is_host"] is True

        self._hand_over(night)

        for name, expected in (("wolf", False), ("seer", True), ("robber", False)):
            night.client.force_authenticate(user=night.users[name])
            data = night.client.get(url).data
            assert data["host_id"] == uid(night, "seer")
            assert data["is_host"] is expected

    def test_the_debug_oracle_marks_the_effective_host(
        self, make_night, settings
    ) -> None:
        settings.DEBUG = True
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        self._hand_over(night)
        night.client.force_authenticate(user=night.users["robber"])

        state = night.client.get(
            reverse("onuw:debug-state", kwargs={"game_id": str(night.game.id)})
        ).data

        hosts = [p["user_id"] for p in state["players"] if p["is_host"]]
        assert hosts == [uid(night, "seer")]

    def test_the_timer_key_can_never_be_a_game_timer_key(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        assert handover_key(night).startswith("lobby:")
        assert not handover_key(night).startswith(f"{night.game.id}:")


# ── leaving ──────────────────────────────────────────────────────────────────


class TestLeaving:
    def _hand_over(self, night: Night) -> None:
        for name in ROLES:
            game_socket(night, name)
        game_socket_closes(night, "wolf", seconds_ago=120)
        fire_handover(night)

    def _leave(self, night: Night, name: str) -> Any:
        night.client.force_authenticate(user=night.users[name])
        with night.committed():
            return night.client.post(
                reverse("core:lobby-leave", kwargs={"code": lobby_of(night).code})
            )

    def test_an_acting_host_who_leaves_hands_the_role_to_the_next_connected_member(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        at_the_table(night)
        self._hand_over(night)
        night.recorder.events.clear()

        response = self._leave(night, "seer")

        assert response.status_code == status.HTTP_200_OK
        assert acting(night) == uid(night, "robber")
        assert [e["reason"] for _, e in host_events(night)] == ["handover"] * 2
        assert not LobbyMember.objects.filter(
            lobby_id=night.game.lobby_id, user=night.users["seer"]
        ).exists()

    def test_with_nobody_else_connected_the_role_goes_back_to_the_owner(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        at_the_table(night)
        self._hand_over(night)
        for name in ("robber", "villager"):
            game_socket_closes(night, name)
        night.recorder.events.clear()

        self._leave(night, "seer")

        lobby = lobby_of(night)
        assert lobby.acting_host_id is None
        assert lobby.effective_host_id == uid(night, "wolf")
        assert {e["reason"] for _, e in host_events(night)} == {"returned"}
        assert {e["host_id"] for _, e in host_events(night)} == {uid(night, "wolf")}

    def test_a_non_host_leaving_changes_nothing(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        at_the_table(night)
        self._hand_over(night)
        night.recorder.events.clear()

        self._leave(night, "villager")

        assert acting(night) == uid(night, "seer")
        assert host_events(night) == []

    def test_the_last_member_leaving_still_deletes_the_lobby(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        at_the_table(night)
        code = lobby_of(night).code
        LobbyMember.objects.filter(lobby_id=night.game.lobby_id).exclude(
            user=night.users["wolf"]
        ).delete()

        assert self._leave(night, "wolf").status_code == status.HTTP_200_OK

        assert not Lobby.objects.filter(code=code).exists()


# ── the setting ──────────────────────────────────────────────────────────────


class TestHandoverSetting:
    @pytest.mark.parametrize("value", [0, 1, 60, 600])
    def test_accepts_zero_to_six_hundred(self, value: int) -> None:
        assert validate_timer_settings({"host_handover_seconds": value}) == []

    @pytest.mark.parametrize("value", [-1, 601, "60", 60.5, True, None])
    def test_rejects_anything_else(self, value: object) -> None:
        errors = validate_timer_settings({"host_handover_seconds": value})
        assert len(errors) == 1
        assert "0 to 600" in errors[0]

    def test_default_is_sixty_and_a_bad_stored_value_falls_back(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        lobby = lobby_of(night)
        assert host.handover_seconds(lobby) == 60
        lobby.settings = {"host_handover_seconds": 9999}
        assert host.handover_seconds(lobby) == 60
        lobby.settings = {"host_handover_seconds": 120}
        assert host.handover_seconds(lobby) == 120

    def test_the_host_can_set_it_through_the_lobby_settings(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=0)
        night.start()
        at_the_table(night)
        url = reverse("core:lobby-detail", kwargs={"code": lobby_of(night).code})
        roles = {"Werewolf": 2, "Seer": 1, "Villager": 3, "Robber": 1}
        night.client.force_authenticate(user=night.users["wolf"])

        good = night.client.patch(
            url,
            {"settings": {"roles": roles, "host_handover_seconds": 90}},
            format="json",
        )
        bad = night.client.patch(
            url,
            {"settings": {"roles": roles, "host_handover_seconds": 601}},
            format="json",
        )

        assert good.status_code == status.HTTP_200_OK
        assert bad.status_code == status.HTTP_400_BAD_REQUEST


# ── restart ──────────────────────────────────────────────────────────────────


class TestRestart:
    """Presence is never reset at start-up: rows left by the dead process go
    stale and their durable presence checks notice them."""

    def _restart(self, night: Night) -> None:
        night.scheduled.clear()
        with night.committed():
            recovery.recover_timers()

    def _die_silently(self, night: Night, name: str) -> None:
        """The player's socket died with its instance: stale row, no disconnect."""
        LobbySocket.objects.filter(
            lobby_id=night.game.lobby_id, user=night.users[name]
        ).update(last_seen=timezone.now() - timedelta(seconds=300))

    def test_a_restart_resets_nothing_and_hands_nothing_over(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        for name in ROLES:
            lobby_socket(night, name)

        self._restart(night)

        assert all(lobby_rows(night, name) == 1 for name in ROLES)
        assert not LobbyMember.objects.filter(
            lobby_id=night.game.lobby_id, disconnected_at__isnull=False
        ).exists()
        assert acting(night) is None

    def test_a_host_whose_socket_died_with_the_old_process_starts_the_clock_when_noticed(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        for name in ROLES:
            lobby_socket(night, name)
        self._die_silently(night, "wolf")
        self._restart(night)

        with night.committed():
            host.check_lobby_presence(
                lobby_of(night).pk, uid(night, "wolf")
            )  # the check fires

        member = LobbyMember.objects.get(
            lobby_id=night.game.lobby_id, user=night.users["wolf"]
        )
        assert member.disconnected_at is not None  # the minute starts now
        assert lobby_rows(night, "wolf") == 0
        ((delay, _),) = handover_timers(night)
        assert 59 < delay <= 60
        assert acting(night) is None

    def test_a_host_who_reconnects_after_the_restart_is_never_marked_away(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        lobby_socket(night, "wolf")
        lobby_socket(night, "seer")
        self._die_silently(night, "wolf")
        self._restart(night)

        lobby_socket(night, "wolf")  # the phone reconnects within seconds
        with night.committed():
            host.check_lobby_presence(lobby_of(night).pk, uid(night, "wolf"))

        member = LobbyMember.objects.get(
            lobby_id=night.game.lobby_id, user=night.users["wolf"]
        )
        assert member.disconnected_at is None
        assert acting(night) is None
        assert host_events(night) == []

    def test_the_timer_firing_early_after_a_noticed_death_does_not_steal_the_role(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        lobby_socket(night, "wolf")
        lobby_socket(night, "seer")
        self._die_silently(night, "wolf")
        with night.committed():
            host.check_lobby_presence(lobby_of(night).pk, uid(night, "wolf"))
        due = handover_timers(night)[-1][1]
        night.scheduled.clear()

        fire_callback(night, due)  # a connected member, but the owner has had ~0 s

        assert acting(night) is None
        assert 58 < handover_timers(night)[0][0] <= 60

    def test_after_a_restart_nobody_is_handed_the_role_until_someone_connects(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        lobby_socket(night, "wolf")
        self._restart(night)
        LobbySocket.objects.filter(lobby_id=night.game.lobby_id).delete()
        LobbyMember.objects.filter(lobby_id=night.game.lobby_id).update(
            disconnected_at=timezone.now() - timedelta(seconds=90)
        )
        PlayerRole.objects.filter(game=night.game).update(
            disconnected_at=timezone.now() - timedelta(seconds=90)
        )
        with night.committed():
            host.ensure_timers_after_restart()

        fire_handover(night)  # due, but nobody is connected
        assert acting(night) is None

        lobby_socket(night, "robber")  # now someone is

        assert acting(night) == uid(night, "robber")


# ── the real consumers ───────────────────────────────────────────────────────


@database_sync_to_async
def _table():
    host_user = User.objects.create_user(username="hc_host", password="x")
    guest = User.objects.create_user(username="hc_guest", password="x")
    lobby = Lobby.objects.create(
        host=host_user, game_type="onuw", settings={"roles": {}}
    )
    game = Game.objects.create(
        lobby=lobby,
        phase=Phase.RESULTS,
        random_seed=1,
        settings={},
        center_cards=[],
    )
    for user in (host_user, guest):
        LobbyMember.objects.create(lobby=lobby, user=user)
        PlayerRole.objects.create(
            game=game, user=user, original_role="Villager", current_role="Villager"
        )
    return lobby, game, host_user, guest


@database_sync_to_async
def _lobby_counts(lobby_id):
    return {
        m.user.username: LobbySocket.objects.filter(
            lobby_id=lobby_id, user_id=m.user_id
        ).count()
        for m in LobbyMember.objects.filter(lobby_id=lobby_id).select_related("user")
    }


def _lobby_ws(lobby, user):
    ws = WebsocketCommunicator(LobbyConsumer.as_asgi(), f"/ws/lobby/{lobby.code}/")
    ws.scope["user"] = user
    ws.scope["url_route"] = {"kwargs": {"code": lobby.code}}
    return ws


def _game_ws(game, user):
    ws = WebsocketCommunicator(GameConsumer.as_asgi(), f"/ws/game/{game.id}/")
    ws.scope["user"] = user
    ws.scope["url_route"] = {"kwargs": {"game_id": str(game.id)}}
    return ws


async def _next_of(ws: Any, kind: str) -> dict[str, Any]:
    """The next event of ``kind`` on ``ws`` (a lobby socket also hears the table's
    ``lobby_update`` bodies), within 2 s."""
    while True:
        event = await asyncio.wait_for(ws.receive_json_from(), 2)
        if event["type"] == kind:
            return event


class TestConsumersDriveHandover(TransactionTestCase):
    @pytest.mark.asyncio
    async def test_lobby_sockets_are_counted_and_a_rejected_one_is_not(self):
        lobby, _game, host_user, _guest = await _table()
        stranger = await database_sync_to_async(User.objects.create_user)(
            username="hc_stranger", password="x"
        )
        first = _lobby_ws(lobby, host_user)
        second = _lobby_ws(lobby, host_user)
        rejected = _lobby_ws(lobby, stranger)
        assert (await first.connect())[0]
        assert (await second.connect())[0]
        assert (await rejected.connect())[0] is False
        await rejected.disconnect()

        assert (await _lobby_counts(lobby.id))["hc_host"] == 2
        await first.disconnect()
        assert (await _lobby_counts(lobby.id))["hc_host"] == 1
        await second.disconnect()
        assert (await _lobby_counts(lobby.id))["hc_host"] == 0
        assert (await _lobby_counts(lobby.id))["hc_guest"] == 0

    @pytest.mark.asyncio
    async def test_the_owner_coming_back_is_announced_to_lobby_and_game_sockets(self):
        lobby, game, host_user, guest = await _table()
        await database_sync_to_async(Lobby.objects.filter(pk=lobby.pk).update)(
            acting_host=guest
        )
        lobby_ws = _lobby_ws(lobby, guest)
        game_ws = _game_ws(game, guest)
        assert (await lobby_ws.connect())[0]
        assert (await game_ws.connect())[0]
        await game_ws.receive_json_from(timeout=2)  # its own presence

        owner = _lobby_ws(lobby, host_user)
        assert (await owner.connect())[0]

        expected = {
            "type": "host_changed",
            "host_id": host_user.id,
            "host_name": public_name(host_user),
            "original_host_id": host_user.id,
            "reason": "returned",
        }
        heard = await _next_of(lobby_ws, "host_changed")
        # The table's number after the change (telling is the bump).
        expected["rev"] = heard["rev"]
        assert heard["rev"] >= 1
        assert heard == expected
        assert await _next_of(game_ws, "host_changed") == expected
        for ws in (owner, lobby_ws, game_ws):
            await ws.disconnect()
