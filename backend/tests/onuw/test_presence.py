"""
Dropped phones: presence, the grace period, and carrying on without a player.

Product rules under test: wait ``disconnect_grace_seconds`` (default 25) before
treating a player as gone; never pause the talk; at night and in the vote wait
for a missing player only up to the grace period; the host can carry on.

"Gone" is simulated the way it happens: a real socket is registered and closed
through the service functions the consumer uses, then ``disconnected_at`` is
moved back in time.
"""

import asyncio
from datetime import timedelta
from typing import Any
from unittest.mock import patch

from django.test import TransactionTestCase
from django.urls import reverse
from django.utils import timezone

import pytest
from asgiref.sync import sync_to_async
from channels.db import database_sync_to_async
from channels.testing import WebsocketCommunicator
from rest_framework import status

from apps.core.models import Lobby, LobbyMember, User
from apps.onuw import presence, services
from apps.onuw.consumers import GameConsumer
from apps.onuw.engine.validation import validate_timer_settings
from apps.onuw.models import Game, Phase, PlayerRole, ScheduledTimer, SocketPresence
from tests.onuw.test_night_windows import Night

pytestmark = pytest.mark.integration

ROLES = {
    "wolf": "Werewolf",
    "seer": "Seer",
    "robber": "Robber",
    "villager": "Villager",
}


# ── helpers ──────────────────────────────────────────────────────────────────


def connect(night: Night, name: str) -> None:
    with night.committed():
        services.register_connection(night.game.id, night.users[name].id)


def socket_rows(night: Night, name: str) -> int:
    """How many socket rows the player has in the game."""
    return SocketPresence.objects.filter(
        game=night.game, user=night.users[name]
    ).count()


def drop(night: Night, name: str, seconds_ago: float = 0) -> None:
    """The player's last socket closes ``seconds_ago`` seconds ago."""
    if not presence.fresh_rows(
        game_id=night.game.id, user_id=night.users[name].id
    ).exists():
        connect(night, name)
    with night.committed():
        services.unregister_connection(night.game.id, night.users[name].id)
    if seconds_ago:
        PlayerRole.objects.filter(game=night.game, user=night.users[name]).update(
            disconnected_at=timezone.now() - timedelta(seconds=seconds_ago)
        )


def grace_callbacks(night: Night, name: str) -> list[Any]:
    key = f"{night.game.id}:grace:{night.users[name].id}"
    return [cb for k, _, cb in night.scheduled if k == key]


def fire_grace(night: Night, name: str) -> None:
    """Run the player's most recently scheduled grace timer (its expiry)."""
    callbacks = grace_callbacks(night, name)
    assert callbacks, f"no grace timer scheduled for {name}"
    with night.committed():
        callbacks[-1]()
    night.refresh()


def presence_events(night: Night) -> list[dict[str, Any]]:
    return night.broadcasts("player.presence")


def to_voting(night: Night) -> None:
    """Skip the night and the talk: the table is at the vote."""
    Game.objects.filter(id=night.game.id).update(
        phase=Phase.DISCUSSION, current_wave=0, phase_deadline=None
    )
    night.refresh()
    with night.committed():
        services.transition_to_voting(night.game)
    night.refresh()
    assert night.game.phase == Phase.VOTING


def vote(night: Night, voter: str, target: str) -> Any:
    night.client.force_authenticate(user=night.users[voter])
    with night.committed():
        return night.client.post(
            reverse("onuw:vote", kwargs={"game_id": str(night.game.id)}),
            {"target_player_id": night.users[target].id},
            format="json",
        )


def me(night: Night, name: str) -> dict[str, Any]:
    night.client.force_authenticate(user=night.users[name])
    return night.client.get(
        reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})
    ).data


# ── counting connections ─────────────────────────────────────────────────────


class TestConnectionCounting:
    def test_first_socket_marks_connected_and_tells_the_table(self, make_night) -> None:
        night = make_night(ROLES)
        night.start()

        connect(night, "seer")

        pr = night.role_of("seer")
        assert socket_rows(night, "seer") == 1
        assert pr.disconnected_at is None
        assert presence_events(night) == [
            {
                "type": "player.presence",
                "player_id": night.users["seer"].id,
                "connected": True,
            }
        ]

    def test_two_sockets_for_one_player_stay_connected_until_the_last_closes(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        connect(night, "seer")
        connect(night, "seer")  # a second tab / device
        assert socket_rows(night, "seer") == 2
        assert len(presence_events(night)) == 1  # only 0 -> 1 is news

        with night.committed():
            services.unregister_connection(night.game.id, night.users["seer"].id)

        pr = night.role_of("seer")
        assert socket_rows(night, "seer") == 1
        assert pr.disconnected_at is None
        assert len(presence_events(night)) == 1
        assert grace_callbacks(night, "seer") == []  # still here: nothing to time

        with night.committed():
            services.unregister_connection(night.game.id, night.users["seer"].id)

        pr = night.role_of("seer")
        assert socket_rows(night, "seer") == 0
        assert pr.disconnected_at is not None
        assert [e["connected"] for e in presence_events(night)] == [True, False]
        assert len(grace_callbacks(night, "seer")) == 1

    def test_closing_a_socket_that_was_never_counted_does_not_go_below_zero(
        self, make_night
    ) -> None:
        night = make_night(ROLES)
        night.start()

        with night.committed():
            services.unregister_connection(night.game.id, night.users["seer"].id)
            services.unregister_connection(night.game.id, night.users["seer"].id)

        assert socket_rows(night, "seer") == 0
        assert presence_events(night) == []

    def test_presence_payload_carries_nothing_but_who_and_whether(
        self, make_night
    ) -> None:
        night = make_night(ROLES)
        night.start()
        connect(night, "wolf")
        drop(night, "wolf")

        for event in presence_events(night):
            assert set(event) == {"type", "player_id", "connected"}

    def test_player_list_reports_connected_for_everyone(self, make_night) -> None:
        night = make_night(ROLES)
        night.start()
        connect(night, "seer")
        connect(night, "wolf")
        drop(night, "wolf")

        night.client.force_authenticate(user=night.users["villager"])
        response = night.client.get(
            reverse("onuw:player-list", kwargs={"game_id": str(night.game.id)})
        )

        assert response.status_code == status.HTTP_200_OK
        connected = {p["player_id"]: p["connected"] for p in response.data["players"]}
        assert connected == {
            night.users["seer"].id: True,
            night.users["wolf"].id: False,
            night.users["robber"].id: False,
            night.users["villager"].id: False,
        }
        for p in response.data["players"]:
            assert set(p) == {"player_id", "display_name", "connected"}

    def test_a_drop_in_the_talk_starts_no_grace_timer(self, make_night) -> None:
        night = make_night(ROLES)
        night.start()
        Game.objects.filter(id=night.game.id).update(phase=Phase.DISCUSSION)
        night.refresh()

        drop(night, "seer")

        assert grace_callbacks(night, "seer") == []
        assert night.role_of("seer").disconnected_at is not None


# ── night ────────────────────────────────────────────────────────────────────


class TestNightWithADroppedPlayer:
    def test_window_waits_for_a_dropped_actor_inside_the_grace_period(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        drop(night, "seer", seconds_ago=5)
        night.post("wolf", "see_team")
        night.post("robber", "skip")

        assert night.refresh().phase == Phase.NIGHT
        assert night.game.current_wave == 2
        # The grace timer is set for the grace period from the drop.
        key = f"{night.game.id}:grace:{night.users['seer'].id}"
        delays = [d for k, d, _ in night.scheduled if k == key]
        assert delays == [pytest.approx(25, abs=1)]

        # Its early firing (clock skew) just reschedules itself.
        fire_grace(night, "seer")
        assert night.game.phase == Phase.NIGHT

    def test_window_goes_on_without_an_actor_gone_past_the_grace_period(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        drop(night, "seer")
        night.post("wolf", "see_team")
        night.post("robber", "skip")
        assert night.refresh().phase == Phase.NIGHT

        PlayerRole.objects.filter(game=night.game, user=night.users["seer"]).update(
            disconnected_at=timezone.now() - timedelta(seconds=26)
        )
        fire_grace(night, "seer")

        assert night.game.phase == Phase.DISCUSSION
        # Treated exactly as a timeout: the Seer's action was skipped.
        log = [
            e
            for e in night.game.night_actions_log
            if e["player_id"] == night.users["seer"].id
        ]
        assert [e["action_type"] for e in log] == ["skip"]
        assert night.events_to("seer", "action.result")[0]["action_type"] == "skip"

    def test_a_player_who_returns_inside_the_grace_period_is_still_waited_for(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        drop(night, "seer", seconds_ago=10)
        night.post("wolf", "see_team")
        night.post("robber", "skip")
        stale = grace_callbacks(night, "seer")[-1]

        with patch("apps.onuw.timers.cancel") as cancel:
            connect(night, "seer")
        cancel.assert_any_call(f"{night.game.id}:grace:{night.users['seer'].id}")

        # The old timer firing anyway (it was already running) does nothing.
        PlayerRole.objects.filter(game=night.game, user=night.users["seer"]).update(
            disconnected_at=None
        )
        with night.committed():
            stale()
        assert night.refresh().phase == Phase.NIGHT

        # They act, and the window closes with their real action.
        response = night.post(
            "seer", "peek_player", {"player_id": night.users["wolf"].id}
        )
        assert response.status_code == status.HTTP_200_OK
        assert night.refresh().phase == Phase.DISCUSSION
        assert (
            night.events_to("seer", "action.result")[0]["revealed_info"]["role"]
            == "werewolf"
        )

    def test_a_player_who_returns_after_the_grace_period_can_still_act(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        drop(night, "seer", seconds_ago=40)
        night.post("wolf", "see_team")  # the robber has not acted yet
        fire_grace(night, "seer")
        assert night.game.phase == Phase.NIGHT  # still waiting for the robber

        connect(night, "seer")
        response = night.post(
            "seer", "peek_player", {"player_id": night.users["villager"].id}
        )
        night.post("robber", "skip")

        assert response.status_code == status.HTTP_200_OK
        assert night.refresh().phase == Phase.DISCUSSION
        assert (
            night.events_to("seer", "action.result")[0]["revealed_info"]["role"]
            == "villager"
        )

    def test_coming_back_lifts_the_hold_so_the_window_can_close(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        drop(night, "seer", seconds_ago=3)
        night.post("seer", "skip")
        night.post("wolf", "see_team")
        night.post("robber", "skip")
        assert night.refresh().phase == Phase.NIGHT  # held: the Seer's phone is out

        connect(night, "seer")

        assert night.refresh().phase == Phase.DISCUSSION

    def test_a_dropped_player_with_nothing_to_do_holds_the_window_just_the_same(
        self, make_night
    ) -> None:
        """Whether the window waits must not tell the table the dropped player's role."""
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        drop(night, "villager", seconds_ago=5)  # has no action
        night.post("seer", "skip")
        night.post("wolf", "see_team")
        night.post("robber", "skip")
        assert night.refresh().phase == Phase.NIGHT  # held, exactly as for an actor

        PlayerRole.objects.filter(game=night.game, user=night.users["villager"]).update(
            disconnected_at=timezone.now() - timedelta(seconds=26)
        )
        fire_grace(night, "villager")

        assert night.game.phase == Phase.DISCUSSION

    def test_the_minimum_window_length_still_applies_when_the_close_is_early(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60, night_min_window_seconds=40)
        night.start()
        drop(night, "seer")
        night.post("wolf", "see_team")
        night.post("robber", "skip")
        night.pretend_window_opened(30)
        PlayerRole.objects.filter(game=night.game, user=night.users["seer"]).update(
            disconnected_at=timezone.now() - timedelta(seconds=26)
        )

        fire_grace(night, "seer")

        # Not closed yet: the close is scheduled for when the minimum is reached.
        assert night.game.phase == Phase.NIGHT
        delays = night.timer_delays(2)
        assert 8 < delays[-1] <= 10
        night.fire_timer(2)
        assert night.game.phase == Phase.DISCUSSION

    def test_a_gone_player_who_returns_before_the_deferred_close_fires_is_not_left_behind(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60, night_min_window_seconds=40)
        night.start()
        drop(night, "seer", seconds_ago=30)  # already gone
        night.post("wolf", "see_team")
        night.post("robber", "skip")
        night.pretend_window_opened(30)
        fire_grace(night, "seer")  # ready: the close is deferred to the minimum
        assert night.game.phase == Phase.NIGHT
        deferred = [cb for k, _, cb in night.scheduled if k.endswith(":wave:2")][-1]

        connect(night, "seer")  # back before it fires
        night.scheduled.clear()
        with night.committed():
            deferred()

        assert night.refresh().phase == Phase.NIGHT  # not closed without her
        delays = night.timer_delays(2)
        assert len(delays) == 1  # the window's own deadline is back
        assert 55 < delays[0] <= 60
        night.post("seer", "skip")
        # Everyone is done: the close waits for the minimum length, then closes.
        assert night.refresh().phase == Phase.NIGHT
        night.fire_timer(2)
        assert night.game.phase == Phase.DISCUSSION

    def test_the_deferred_close_still_closes_at_the_same_moment_when_nothing_changed(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60, night_min_window_seconds=40)
        night.start()
        night.post("wolf", "see_team")
        night.post("seer", "skip")
        night.post("robber", "skip")
        assert night.refresh().phase == Phase.NIGHT
        assert 0 < night.timer_delays(2)[-1] <= 40

        night.fire_timer(2)

        assert night.game.phase == Phase.DISCUSSION

    def test_a_deferred_close_at_the_deadline_always_closes(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=60, night_min_window_seconds=40)
        night.start()
        drop(night, "seer", seconds_ago=30)
        night.post("wolf", "see_team")
        night.post("robber", "skip")
        fire_grace(night, "seer")
        deferred = [cb for k, _, cb in night.scheduled if k.endswith(":wave:2")][-1]
        connect(night, "seer")
        Game.objects.filter(id=night.game.id).update(
            phase_deadline=timezone.now() - timedelta(seconds=1)
        )

        with night.committed():
            deferred()

        assert night.refresh().phase == Phase.DISCUSSION  # the deadline wins

    def test_the_doppelganger_window_keeps_its_exact_length_whatever_happens_to_a_phone(
        self, make_night
    ) -> None:
        night = make_night(
            {"d": "Doppelganger", "s": "Seer", "w": "Werewolf", "v": "Villager"},
            night_doppelganger_window_seconds=10,
            night_wave_seconds=60,
        )
        night.start()
        assert night.game.current_wave == 1
        window_one_timers = night.timer_delays(1)
        assert window_one_timers == [10]

        drop(night, "d")  # the Doppelganger herself, then everyone else too
        for name in ("s", "w", "v"):
            drop(night, name)
        for name in ("d", "s", "w", "v"):
            PlayerRole.objects.filter(game=night.game, user=night.users[name]).update(
                disconnected_at=timezone.now() - timedelta(seconds=30)
            )
            fire_grace(night, name)

        assert night.game.current_wave == 1  # not closed early
        assert night.timer_delays(1) == window_one_timers  # nothing rescheduled
        night.fire_timer(1)  # only its own timer closes it
        assert night.game.current_wave == 2

    def test_with_every_phone_gone_only_the_deadline_closes_the_window(
        self, make_night
    ) -> None:
        """Nobody is there to be told, so the grace period alone does not close it."""
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        drop(night, "seer")
        SocketPresence.objects.filter(game=night.game).delete()
        PlayerRole.objects.filter(game=night.game).update(
            disconnected_at=timezone.now() - timedelta(seconds=30)
        )

        fire_grace(night, "seer")

        assert night.game.phase == Phase.NIGHT
        night.fire_timer(2)  # the window's own deadline
        assert night.game.phase == Phase.DISCUSSION

    def test_a_grace_of_zero_turns_the_feature_off(self, make_night) -> None:
        night = make_night(ROLES, night_wave_seconds=60, disconnect_grace_seconds=0)
        night.start()
        drop(night, "seer", seconds_ago=500)
        night.post("wolf", "see_team")
        night.post("robber", "skip")

        assert night.refresh().phase == Phase.NIGHT  # waits for the Seer as ever
        assert grace_callbacks(night, "seer") == []


# ── the vote ─────────────────────────────────────────────────────────────────


class TestVoteWithADroppedPlayer:
    def test_vote_waits_for_a_dropped_player_inside_the_grace_period(
        self, make_night
    ) -> None:
        night = make_night(ROLES, voting_seconds=120)
        night.start()
        to_voting(night)
        drop(night, "robber", seconds_ago=5)

        for voter, target in (("wolf", "seer"), ("seer", "wolf"), ("villager", "wolf")):
            assert vote(night, voter, target).status_code == status.HTTP_200_OK

        assert night.refresh().phase == Phase.VOTING
        fire_grace(night, "robber")  # fires a hair early: still waiting
        assert night.game.phase == Phase.VOTING

    def test_vote_is_revealed_once_everyone_else_has_voted_and_the_grace_ends(
        self, make_night
    ) -> None:
        night = make_night(ROLES, voting_seconds=120)
        night.start()
        to_voting(night)
        drop(night, "robber")
        for voter, target in (("wolf", "seer"), ("seer", "wolf"), ("villager", "wolf")):
            vote(night, voter, target)
        assert night.refresh().phase == Phase.VOTING

        PlayerRole.objects.filter(game=night.game, user=night.users["robber"]).update(
            disconnected_at=timezone.now() - timedelta(seconds=26)
        )
        fire_grace(night, "robber")

        assert night.game.phase == Phase.RESULTS
        reveal = night.broadcasts("vote.reveal")[0]["votes"]
        # The missing player counts exactly as a non-voter at the deadline.
        assert reveal[str(night.users["robber"].id)] is None
        assert reveal[str(night.users["wolf"].id)] == night.users["seer"].id

    def test_a_player_gone_past_the_grace_period_does_not_hold_up_the_last_vote(
        self, make_night
    ) -> None:
        night = make_night(ROLES, voting_seconds=120)
        night.start()
        to_voting(night)
        drop(night, "robber", seconds_ago=30)
        vote(night, "wolf", "seer")
        vote(night, "seer", "wolf")
        assert night.refresh().phase == Phase.VOTING

        vote(night, "villager", "wolf")  # the last one to vote reveals at once

        assert night.refresh().phase == Phase.RESULTS

    def test_a_player_who_returns_inside_the_grace_period_can_still_vote(
        self, make_night
    ) -> None:
        night = make_night(ROLES, voting_seconds=120)
        night.start()
        to_voting(night)
        drop(night, "robber", seconds_ago=10)
        for voter, target in (("wolf", "seer"), ("seer", "wolf"), ("villager", "wolf")):
            vote(night, voter, target)
        connect(night, "robber")
        stale = grace_callbacks(night, "robber")[-1]
        with night.committed():
            stale()
        assert night.refresh().phase == Phase.VOTING

        vote(night, "robber", "wolf")

        assert night.refresh().phase == Phase.RESULTS
        assert night.broadcasts("vote.reveal")[0]["votes"][
            str(night.users["robber"].id)
        ] == (night.users["wolf"].id)

    def test_a_phone_that_dropped_during_the_talk_is_on_the_clock_when_voting_opens(
        self, make_night
    ) -> None:
        night = make_night(ROLES, voting_seconds=120)
        night.start()
        Game.objects.filter(id=night.game.id).update(
            phase=Phase.DISCUSSION, current_wave=0
        )
        night.refresh()
        drop(night, "robber", seconds_ago=10)  # in the talk: no timer yet
        assert grace_callbacks(night, "robber") == []

        to_voting(night)

        key = f"{night.game.id}:grace:{night.users['robber'].id}"
        delays = [d for k, d, _ in night.scheduled if k == key]
        assert delays == [pytest.approx(15, abs=1)]

    def test_a_phone_gone_since_the_talk_is_not_waited_for_when_voting_opens(
        self, make_night
    ) -> None:
        night = make_night(ROLES, voting_seconds=120)
        night.start()
        Game.objects.filter(id=night.game.id).update(
            phase=Phase.DISCUSSION, current_wave=0
        )
        night.refresh()
        drop(night, "robber", seconds_ago=90)
        to_voting(night)

        for voter, target in (("wolf", "seer"), ("seer", "wolf"), ("villager", "wolf")):
            vote(night, voter, target)

        assert night.refresh().phase == Phase.RESULTS

    def test_every_phone_gone_means_no_early_reveal(self, make_night) -> None:
        night = make_night(ROLES, voting_seconds=120)
        night.start()
        to_voting(night)
        for name in ROLES:
            drop(night, name, seconds_ago=30)
        # One player had voted before dropping.
        PlayerRole.objects.filter(game=night.game, user=night.users["wolf"]).update(
            has_acted=True, vote_target=night.users["seer"]
        )

        fire_grace(night, "seer")

        assert night.game.phase == Phase.VOTING


# ── the talk and the host ────────────────────────────────────────────────────


class TestTalkAndHost:
    def test_the_talk_never_waits_for_anyone(self, make_night) -> None:
        night = make_night(ROLES, discussion_seconds=300)
        night.start()
        assert night.game.phase == Phase.NIGHT
        night.post("wolf", "see_team")
        night.post("seer", "skip")
        night.post("robber", "skip")
        assert night.refresh().phase == Phase.DISCUSSION
        deadline = night.game.phase_deadline

        for name in ROLES:
            drop(night, name, seconds_ago=60)

        assert night.refresh().phase == Phase.DISCUSSION
        assert night.game.phase_deadline == deadline
        # ...and nothing was scheduled that could move it.
        assert [k for k, _, _ in night.scheduled if ":grace:" in k] == []

    def test_a_grace_timer_that_fires_in_the_talk_changes_nothing(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60, discussion_seconds=300)
        night.start()
        drop(night, "seer")  # at night: timer set
        Game.objects.filter(id=night.game.id).update(
            phase=Phase.DISCUSSION, current_wave=0
        )
        PlayerRole.objects.filter(game=night.game, user=night.users["seer"]).update(
            disconnected_at=timezone.now() - timedelta(seconds=40)
        )

        fire_grace(night, "seer")

        assert night.game.phase == Phase.DISCUSSION

    def test_host_can_close_the_window_while_a_player_is_dropped(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        drop(night, "seer", seconds_ago=5)

        response = night.host_close_window()

        assert response.status_code == status.HTTP_200_OK
        assert night.refresh().phase == Phase.DISCUSSION

    def test_host_can_end_the_talk_and_force_the_reveal_with_a_player_dropped(
        self, make_night
    ) -> None:
        night = make_night(ROLES, discussion_seconds=300, voting_seconds=120)
        night.start()
        Game.objects.filter(id=night.game.id).update(
            phase=Phase.DISCUSSION, current_wave=0
        )
        drop(night, "villager", seconds_ago=5)
        night.client.force_authenticate(user=night.host)

        with night.committed():
            ended = night.client.post(
                reverse("onuw:end-discussion", kwargs={"game_id": str(night.game.id)})
            )
        assert ended.status_code == status.HTTP_200_OK
        assert night.refresh().phase == Phase.VOTING

        vote(night, "seer", "wolf")
        night.client.force_authenticate(user=night.host)
        with night.committed():
            revealed = night.client.post(
                reverse("onuw:reveal-votes", kwargs={"game_id": str(night.game.id)})
            )

        assert revealed.status_code == status.HTTP_200_OK
        assert night.refresh().phase == Phase.RESULTS

    def test_a_host_who_is_gone_cannot_use_the_host_endpoints_but_the_clock_still_runs(
        self, make_night
    ) -> None:
        """No host transfer: only the host may force things along.

        The game still moves on its own: night and vote timers do not need the
        host, and the dropped host is treated like any other missing player.
        """
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        drop(night, "wolf", seconds_ago=40)  # "wolf" is the host (first player)
        assert night.host == night.users["wolf"]
        night.post("seer", "skip")
        night.post("robber", "skip")
        fire_grace(night, "wolf")

        assert night.game.phase == Phase.DISCUSSION  # went on without the host
        night.client.force_authenticate(user=night.users["seer"])
        refused = night.client.post(
            reverse("onuw:end-discussion", kwargs={"game_id": str(night.game.id)})
        )
        assert refused.status_code == status.HTTP_403_FORBIDDEN  # nobody else may


# ── validation of the setting ────────────────────────────────────────────────


class TestGraceSetting:
    @pytest.mark.parametrize("value", [0, 1, 25, 60])
    def test_accepts_zero_to_sixty_seconds(self, value: int) -> None:
        assert validate_timer_settings({"disconnect_grace_seconds": value}) == []

    @pytest.mark.parametrize("value", [-1, 61, 3600, "25", 25.5, True, None, [25]])
    def test_rejects_anything_else(self, value: object) -> None:
        errors = validate_timer_settings({"disconnect_grace_seconds": value})
        assert len(errors) == 1
        assert "disconnect_grace_seconds" in errors[0]
        assert "0 to 60" in errors[0]

    def test_other_timers_keep_their_larger_limit(self) -> None:
        assert validate_timer_settings({"voting_seconds": 3600}) == []
        assert validate_timer_settings({"voting_seconds": 3601}) != []

    def test_default_is_twenty_five_seconds_and_a_bad_stored_value_falls_back(
        self, make_night
    ) -> None:
        night = make_night(ROLES)
        assert services._grace_seconds(night.game) == 25
        night.game.settings = {"disconnect_grace_seconds": 999}
        assert services._grace_seconds(night.game) == 25
        night.game.settings = {"disconnect_grace_seconds": 40}
        assert services._grace_seconds(night.game) == 40

    def test_host_can_set_it_through_the_lobby_settings(self, db, api_client) -> None:
        host = User.objects.create_user(username="grace_host", password="pass")
        lobby = Lobby.objects.create(host=host, game_type="onuw", settings={})
        for i in range(2):
            LobbyMember.objects.create(
                lobby=lobby,
                user=User.objects.create_user(username=f"g{i}", password="x"),
            )
        LobbyMember.objects.create(lobby=lobby, user=host)
        api_client.force_authenticate(user=host)
        roles = {"Werewolf": 2, "Seer": 1, "Villager": 3}

        good = api_client.patch(
            reverse("core:lobby-detail", kwargs={"code": lobby.code}),
            {"settings": {"roles": roles, "disconnect_grace_seconds": 40}},
            format="json",
        )
        bad = api_client.patch(
            reverse("core:lobby-detail", kwargs={"code": lobby.code}),
            {"settings": {"roles": roles, "disconnect_grace_seconds": 61}},
            format="json",
        )

        assert good.status_code == status.HTTP_200_OK
        assert bad.status_code == status.HTTP_400_BAD_REQUEST


# ── the real consumer ────────────────────────────────────────────────────────


@database_sync_to_async
def _make_table():
    host = User.objects.create_user(username="ws_host", password="pass")
    other = User.objects.create_user(username="ws_other", password="pass")
    third = User.objects.create_user(username="ws_third", password="pass")
    lobby = Lobby.objects.create(host=host, game_type="onuw", settings={"roles": {}})
    game = Game.objects.create(
        lobby=lobby,
        phase=Phase.DISCUSSION,  # no timers involved
        random_seed=1,
        settings={"roles": {}},
        center_cards=["Villager", "Villager", "Villager"],
    )
    for user in (host, other, third):
        LobbyMember.objects.create(lobby=lobby, user=user, is_ready=True)
        PlayerRole.objects.create(
            game=game, user=user, original_role="Villager", current_role="Villager"
        )
    return game, host, other, third


def _communicator(game_id, user):
    communicator = WebsocketCommunicator(GameConsumer.as_asgi(), f"/ws/game/{game_id}/")
    communicator.scope["user"] = user
    communicator.scope["url_route"] = {"kwargs": {"game_id": str(game_id)}}
    return communicator


async def _drain(communicator, timeout: float = 0.3) -> list[dict]:
    seen = []
    while True:
        try:
            seen.append(
                await asyncio.wait_for(communicator.receive_json_from(), timeout)
            )
        except TimeoutError:
            return seen


@database_sync_to_async
def _connections(game_id, user_id) -> tuple[int, Any]:
    pr = PlayerRole.objects.get(game_id=game_id, user_id=user_id)
    rows = SocketPresence.objects.filter(game_id=game_id, user_id=user_id).count()
    return rows, pr.disconnected_at


class TestConsumerPresence(TransactionTestCase):
    @pytest.mark.asyncio
    async def test_sockets_open_and_close_the_count_and_the_table_hears_it(self):
        game, host, other, _third = await _make_table()
        watcher = _communicator(game.id, host)
        assert (await watcher.connect())[0]
        await _drain(watcher)  # its own "connected"

        first = _communicator(game.id, other)
        second = _communicator(game.id, other)
        assert (await first.connect())[0]
        assert (await second.connect())[0]
        heard = await _drain(watcher)
        # One announcement for two sockets, with exactly the public fields.
        assert heard == [
            {"type": "player_presence", "player_id": other.id, "connected": True}
        ]
        assert (await _connections(game.id, other.id))[0] == 2

        await first.disconnect()
        assert await _drain(watcher) == []
        assert (await _connections(game.id, other.id))[0] == 1

        await second.disconnect()
        heard = await _drain(watcher)
        assert heard == [
            {"type": "player_presence", "player_id": other.id, "connected": False}
        ]
        count, since = await _connections(game.id, other.id)
        assert count == 0
        assert since is not None
        await watcher.disconnect()

    @pytest.mark.asyncio
    async def test_a_rejected_connection_is_never_counted(self):
        game, _host, _other, _third = await _make_table()
        stranger = await database_sync_to_async(User.objects.create_user)(
            username="ws_stranger", password="pass"
        )
        communicator = _communicator(game.id, stranger)

        connected, _ = await communicator.connect()
        await communicator.disconnect()

        assert connected is False
        assert (
            await sync_to_async(
                lambda: SocketPresence.objects.filter(game_id=game.id).count()
            )()
            == 0
        )


class TestDebugHookIgnoresGraceTimers:
    @pytest.mark.uses_timers
    def test_current_resolves_to_the_phase_timer_even_when_a_player_has_dropped(
        self, db, django_capture_on_commit_callbacks
    ) -> None:
        from apps.onuw import debug, timers
        from tests.onuw.test_night_windows import _Recorder

        night = Night(
            ROLES,
            ["Villager", "Tanner", "Hunter"],
            {"roles": {}},
            _Recorder(),
            [],
            django_capture_on_commit_callbacks,
        )
        gid = night.game.id
        fired: list[str] = []
        timers.JOBS["debug_test_job"] = lambda who: fired.append(who)
        for key, who in ((f"{gid}:wave:2", "wave"), (f"{gid}:grace:99", "grace")):
            ScheduledTimer.objects.create(
                key=key,
                token="t",
                job="debug_test_job",
                params={"who": who},
                due_at=timezone.now() + timedelta(hours=1),
            )

        ok, key = debug.fire_timer(night.game, "current")

        assert ok
        assert key == f"{gid}:wave:2"
        assert fired == ["wave"]


# ── socket rows, heartbeats and silent deaths ────────────────────────────────


def age_rows(night: Night, name: str, seconds: float) -> None:
    """The player's socket rows were last seen ``seconds`` ago."""
    SocketPresence.objects.filter(game=night.game, user=night.users[name]).update(
        last_seen=timezone.now() - timedelta(seconds=seconds)
    )


def presence_checks(night: Night, name: str) -> list[tuple[float, Any]]:
    key = presence.check_key("game", night.game.id, night.users[name].id)
    return [(d, cb) for k, d, cb in night.scheduled if k == key]


class TestSocketRowsAndHeartbeats:
    def test_a_fresh_row_is_connected_and_a_stale_one_is_not(self, make_night) -> None:
        night = make_night(ROLES)
        night.start()
        connect(night, "seer")
        connect(night, "wolf")
        age_rows(night, "wolf", 100)

        assert presence.connected_user_ids(game_id=night.game.id) == {
            night.users["seer"].id
        }

    def test_connecting_arms_one_presence_check_due_at_the_staleness_timeout(
        self, make_night
    ) -> None:
        night = make_night(ROLES)
        night.start()

        connect(night, "seer")

        ((delay, _),) = presence_checks(night, "seer")
        assert delay == presence.stale_seconds() == 40

    def test_a_heartbeat_keeps_a_player_connected_past_the_staleness_timeout(
        self, make_night
    ) -> None:
        night = make_night(ROLES)
        night.start()
        connect(night, "seer")
        channel = SocketPresence.objects.get(
            game=night.game, user=night.users["seer"]
        ).channel_name
        age_rows(night, "seer", 45)  # would be stale...
        assert not presence.fresh_rows(
            game_id=night.game.id, user_id=night.users["seer"].id
        ).exists()

        # ...the beat arrives (it re-registers: a real "coming back")
        services.refresh_connection(night.game.id, night.users["seer"].id, channel)
        age_rows(night, "seer", 20)  # the next beat is 20 s later: still fresh

        assert presence.connected_user_ids(game_id=night.game.id) == {
            night.users["seer"].id
        }

    def test_a_beat_refreshes_last_seen_without_any_presence_event(
        self, make_night
    ) -> None:
        night = make_night(ROLES)
        night.start()
        connect(night, "seer")
        row = SocketPresence.objects.get(game=night.game, user=night.users["seer"])
        age_rows(night, "seer", 30)
        events_before = len(night.recorder.events)

        came_back = services.refresh_connection(
            night.game.id, night.users["seer"].id, row.channel_name
        )

        assert came_back is False
        row.refresh_from_db()
        assert (timezone.now() - row.last_seen).total_seconds() < 5
        assert len(night.recorder.events) == events_before

    def test_a_beat_for_a_row_that_was_cleaned_up_re_registers_the_socket(
        self, make_night
    ) -> None:
        night = make_night(ROLES)
        night.start()
        connect(night, "seer")
        row = SocketPresence.objects.get(game=night.game, user=night.users["seer"])
        channel = row.channel_name
        row.delete()  # e.g. the check cleaned it up during a long pause

        with night.committed():
            came_back = services.refresh_connection(
                night.game.id, night.users["seer"].id, channel
            )

        assert came_back is True
        assert SocketPresence.objects.filter(channel_name=channel).exists()
        assert presence_events(night)[-1]["connected"] is True

    def test_the_check_re_arms_itself_when_heartbeats_kept_the_player_fresh(
        self, make_night
    ) -> None:
        night = make_night(ROLES)
        night.start()
        connect(night, "seer")
        (_, check) = presence_checks(night, "seer")[0]
        age_rows(night, "seer", 10)
        night.scheduled.clear()
        events_before = len(night.recorder.events)

        with night.committed():
            check()

        ((delay, _),) = presence_checks(night, "seer")
        assert 29 < delay <= 30  # stale timeout minus the 10 s since the last beat
        assert len(night.recorder.events) == events_before  # nothing happened
        assert night.role_of("seer").disconnected_at is None

    def test_a_silent_death_runs_the_same_path_as_a_clean_disconnect(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        connect(night, "seer")
        (_, check) = presence_checks(night, "seer")[0]
        age_rows(night, "seer", 100)  # the instance died: no heartbeat, no disconnect
        night.recorder.events.clear()

        with night.committed():
            check()

        assert socket_rows(night, "seer") == 0  # stale rows deleted
        assert night.role_of("seer").disconnected_at is not None
        assert [e["connected"] for e in presence_events(night)] == [False]
        assert len(grace_callbacks(night, "seer")) == 1  # the grace period is running

    def test_a_player_whose_phone_died_silently_stops_holding_up_the_night(
        self, make_night
    ) -> None:
        night = make_night(ROLES, night_wave_seconds=60)
        night.start()
        connect(night, "seer")
        (_, check) = presence_checks(night, "seer")[0]
        night.post("wolf", "see_team")
        night.post("robber", "skip")
        assert night.refresh().phase == Phase.NIGHT  # waiting for the Seer
        age_rows(night, "seer", 100)
        with night.committed():
            check()
        PlayerRole.objects.filter(game=night.game, user=night.users["seer"]).update(
            disconnected_at=timezone.now() - timedelta(seconds=30)
        )

        fire_grace(night, "seer")

        assert night.game.phase == Phase.DISCUSSION

    def test_a_check_for_a_player_who_already_left_cleanly_does_nothing(
        self, make_night
    ) -> None:
        night = make_night(ROLES)
        night.start()
        connect(night, "seer")
        (_, check) = presence_checks(night, "seer")[0]
        drop(night, "seer")
        night.recorder.events.clear()

        with night.committed():
            check()

        assert presence_events(night) == []

    def test_a_clean_disconnect_cancels_the_pending_check(self, make_night) -> None:
        from unittest.mock import patch

        night = make_night(ROLES)
        night.start()
        connect(night, "seer")

        with patch("apps.onuw.timers.cancel") as cancel:
            with night.committed():
                services.unregister_connection(night.game.id, night.users["seer"].id)

        cancel.assert_any_call(
            presence.check_key("game", night.game.id, night.users["seer"].id)
        )

    def test_nothing_in_the_presence_event_changes_for_a_silent_death(
        self, make_night
    ) -> None:
        night = make_night(ROLES)
        night.start()
        connect(night, "seer")
        (_, check) = presence_checks(night, "seer")[0]
        age_rows(night, "seer", 100)
        with night.committed():
            check()

        for event in presence_events(night):
            assert set(event) == {"type", "player_id", "connected"}

    def test_release_connections_closes_idle_connections_but_not_a_transaction(
        self, make_night
    ) -> None:
        from django.db import connection

        from apps.onuw import timers

        night = make_night(ROLES)
        # Inside the test's transaction nothing may be closed.
        timers.release_connections()
        assert connection.connection is not None
        assert night.game.id  # the database still answers
        Game.objects.count()


class TestConsumerHeartbeat(TransactionTestCase):
    @pytest.mark.asyncio
    async def test_the_consumer_beats_while_connected_and_stops_when_it_closes(self):
        game, _host, other, _third = await _make_table()
        with self.settings(ONUW_PRESENCE_HEARTBEAT_SECONDS=0.1):
            ws = _communicator(game.id, other)
            assert (await ws.connect())[0]

            @database_sync_to_async
            def row():
                return SocketPresence.objects.get(game_id=game.id, user_id=other.id)

            first = await row()
            await asyncio.sleep(0.45)
            later = await row()
            assert later.connected_at == first.connected_at  # the same socket row
            assert later.last_seen > first.last_seen  # kept fresh by the beat

            await ws.disconnect()
            assert not await database_sync_to_async(
                SocketPresence.objects.filter(game_id=game.id, user_id=other.id).exists
            )()
            await asyncio.sleep(0.3)  # no beat is left running to bring it back
            assert not await database_sync_to_async(
                SocketPresence.objects.filter(game_id=game.id, user_id=other.id).exists
            )()

    @pytest.mark.asyncio
    async def test_the_row_carries_the_socket_and_the_user_and_nothing_else_is_stored(
        self,
    ):
        game, _host, other, _third = await _make_table()
        ws = _communicator(game.id, other)
        assert (await ws.connect())[0]

        @database_sync_to_async
        def fields():
            r = SocketPresence.objects.get(game_id=game.id, user_id=other.id)
            return r.user_id, r.game_id, r.lobby_id, bool(r.channel_name)

        assert await fields() == (other.id, game.id, None, True)
        await ws.disconnect()
