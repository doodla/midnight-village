"""
"Ready to vote" in the talk: ``POST /api/onuw/games/<id>/ready/ {"ready": bool}``.

Each player taps ready (and may un-tap). When every player who is not gone past the
grace period is ready the server calls ``end_discussion``, the very function the
host's button calls, under the same Game lock and phase check. The talk never waits
for anyone: readiness can only end it early. There are no grace timers in the talk,
so ``needed`` is recomputed when a player taps and when a phone comes back.

All through the real API; seat order differs from user-id order (``Night``).
"""

import threading
from datetime import timedelta
from typing import Any

from django.db import connections
from django.urls import reverse
from django.utils import timezone

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.onuw import services
from apps.onuw.models import Game, Phase, PlayerRole
from tests.onuw.test_night_windows import Night
from tests.onuw.test_presence import connect, drop, grace_callbacks

pytestmark = pytest.mark.integration

ROLES = {
    "wolf": "Werewolf",
    "seer": "Seer",
    "hunter": "Hunter",
    "robber": "Robber",
    "villager": "Villager",
}
CENTER = ["Villager", "Tanner", "Villager"]


@pytest.fixture
def talk_night(make_night) -> Night:
    """Five players in the talk, a deadline far away."""
    night = make_night(ROLES, CENTER, discussion_seconds=300, voting_seconds=120)
    night.start()
    with night.committed():
        services.transition_to_discussion(night.game)
    night.refresh()
    assert night.game.phase == Phase.DISCUSSION
    night.recorder.events.clear()
    return night


def post_ready(night: Night, who: str, body: Any) -> Any:
    night.client.force_authenticate(user=night.users[who])
    with night.committed():
        return night.client.post(
            reverse("onuw:ready", kwargs={"game_id": str(night.game.id)}),
            body,
            format="json",
        )


def ready(night: Night, who: str, value: bool = True) -> Any:
    return post_ready(night, who, {"ready": value})


def me(night: Night, name: str) -> dict[str, Any]:
    night.client.force_authenticate(user=night.users[name])
    response = night.client.get(
        reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})
    )
    assert response.status_code == status.HTTP_200_OK
    return response.data


def flag(night: Night, name: str) -> bool:
    return night.role_of(name).phase_ready


def progress_events(night: Night) -> list[tuple[int, int]]:
    return [(e["done"], e["needed"]) for e in night.broadcasts("progress")]


# ── the tap ──────────────────────────────────────────────────────────────────


class TestTheTap:
    def test_a_tap_marks_the_caller_ready_and_answers_ok(self, talk_night) -> None:
        night = talk_night

        response = ready(night, "seer")

        assert response.status_code == status.HTTP_200_OK
        assert response.data == {"status": "ok", "ready": True}
        assert flag(night, "seer") is True
        assert all(flag(night, n) is False for n in ROLES if n != "seer")

    def test_unready_toggle_counts_down(self, talk_night) -> None:
        night = talk_night

        ready(night, "seer")
        ready(night, "wolf")
        undone = ready(night, "seer", False)

        assert undone.data == {"status": "ok", "ready": False}
        assert progress_events(night) == [(1, 5), (2, 5), (1, 5)]
        assert me(night, "wolf")["progress"] == {
            "stage": "talk",
            "done": 1,
            "needed": 5,
        }

    def test_tapping_twice_is_harmless(self, talk_night) -> None:
        night = talk_night
        for _ in range(3):
            assert ready(night, "seer").status_code == status.HTTP_200_OK
        assert flag(night, "seer") is True
        assert night.refresh().phase == Phase.DISCUSSION

    def test_the_talk_announces_done_zero_when_it_opens(self, make_night) -> None:
        night = make_night(ROLES, CENTER, discussion_seconds=300)
        night.start()
        night.recorder.events.clear()

        with night.committed():
            services.transition_to_discussion(night.game)

        assert night.broadcasts("progress") == [
            {"type": "progress", "stage": "talk", "done": 0, "needed": 5}
        ]

    def test_the_flags_start_clear_when_the_talk_opens(self, make_night) -> None:
        night = make_night(ROLES, CENTER, discussion_seconds=300)
        night.start()
        PlayerRole.objects.filter(game=night.game).update(phase_ready=True)

        with night.committed():
            services.transition_to_discussion(night.game)

        assert not PlayerRole.objects.filter(game=night.game, phase_ready=True).exists()

    def test_progress_event_carries_only_counts_and_nothing_goes_to_one_player(
        self, talk_night
    ) -> None:
        night = talk_night
        ready(night, "seer")

        assert night.recorder.events == [
            (
                f"game_{night.game.id}",
                {"type": "progress", "stage": "talk", "done": 1, "needed": 5},
            )
        ]

    def test_me_has_the_callers_own_flag_and_the_count(self, talk_night) -> None:
        night = talk_night
        ready(night, "seer")

        assert me(night, "seer")["ready"] is True
        assert me(night, "wolf")["ready"] is False
        for name in ROLES:
            assert me(night, name)["progress"] == {
                "stage": "talk",
                "done": 1,
                "needed": 5,
            }

    def test_other_players_pages_do_not_say_who_is_ready(self, talk_night) -> None:
        night = talk_night
        ready(night, "seer")

        body = me(night, "wolf")

        for entry in body["players"]:
            assert set(entry) <= {"player_id", "display_name", "token", "seat"}


# ── refusals ─────────────────────────────────────────────────────────────────


class TestRefusals:
    @pytest.mark.parametrize(
        "bad", ["true", "false", 1, 0, None, [], {}, "yes"], ids=repr
    )
    def test_ready_must_be_a_json_boolean(self, talk_night, bad) -> None:
        response = post_ready(talk_night, "seer", {"ready": bad})

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["code"] == "bad_request"
        assert flag(talk_night, "seer") is False

    @pytest.mark.parametrize("body", [{}, [], "ready", None])
    def test_ready_is_required(self, talk_night, body) -> None:
        response = post_ready(talk_night, "seer", body)

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["code"] == "bad_request"

    def test_a_stranger_is_refused(self, talk_night, django_user_model) -> None:
        night = talk_night
        stranger = django_user_model.objects.create_user(
            username="nobody", password="x"
        )
        night.client.force_authenticate(user=stranger)

        response = night.client.post(
            reverse("onuw:ready", kwargs={"game_id": str(night.game.id)}),
            {"ready": True},
            format="json",
        )

        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_an_unknown_game_is_404(self, talk_night) -> None:
        night = talk_night
        night.client.force_authenticate(user=night.users["seer"])

        response = night.client.post(
            reverse(
                "onuw:ready", kwargs={"game_id": "00000000-0000-0000-0000-000000000000"}
            ),
            {"ready": True},
            format="json",
        )

        assert response.status_code == status.HTTP_404_NOT_FOUND

    @pytest.mark.parametrize("phase", [Phase.VOTING, Phase.RESULTS])
    def test_ready_outside_the_talk_is_wrong_phase(self, talk_night, phase) -> None:
        night = talk_night
        Game.objects.filter(id=night.game.id).update(phase=phase)

        response = ready(night, "seer")

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["code"] == "wrong_phase"
        assert flag(night, "seer") is False

    def test_ready_during_the_night_is_wrong_phase_for_now(self, make_night) -> None:
        # Window 0 (the card look) answers ``true`` once the look stage exists; an
        # open window never takes ready.
        night = make_night(ROLES, CENTER)
        night.start()
        assert night.game.current_wave in (1, 2)

        response = ready(night, "seer")

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["code"] == "wrong_phase"


# ── ending the talk ──────────────────────────────────────────────────────────


class TestEndingTheTalk:
    def test_all_ready_ends_discussion_once(self, talk_night) -> None:
        night = talk_night
        for name in ("wolf", "seer", "hunter", "robber"):
            assert ready(night, name).status_code == status.HTTP_200_OK
            assert night.refresh().phase == Phase.DISCUSSION

        last = ready(night, "villager")

        assert last.status_code == status.HTTP_200_OK
        assert night.refresh().phase == Phase.VOTING
        changes = night.broadcasts("phase.change")
        assert [c["phase"] for c in changes] == ["voting"]
        # The vote opens with its own count, from zero.
        assert night.broadcasts("progress")[-1] == {
            "type": "progress",
            "stage": "vote",
            "done": 0,
            "needed": 5,
        }
        # Tapping again once the vote is on is refused and changes nothing.
        again = ready(night, "villager", False)
        assert again.status_code == status.HTTP_400_BAD_REQUEST
        assert len(night.broadcasts("phase.change")) == 1

    def test_ending_by_ready_stops_the_talk_timer_and_starts_the_vote_timer(
        self, talk_night
    ) -> None:
        night = talk_night
        for name in ROLES:
            ready(night, name)

        assert night.game.phase_deadline is not None  # the vote's deadline now
        assert night.timer_delays_for("voting") == [120]

    def test_the_vote_that_follows_starts_clean(self, talk_night) -> None:
        night = talk_night
        for name in ROLES:
            ready(night, name)

        body = me(night, "seer")

        assert body["phase"] == "voting"
        assert body["ready"] is None
        assert body["my_vote"] is None
        assert all(p["has_voted"] is False for p in body["players"])

    def test_one_player_not_ready_keeps_the_talk_going(self, talk_night) -> None:
        night = talk_night
        for name in ("wolf", "seer", "hunter", "robber"):
            ready(night, name)

        assert night.refresh().phase == Phase.DISCUSSION

    def test_unreadying_before_the_last_tap_keeps_the_talk_going(
        self, talk_night
    ) -> None:
        night = talk_night
        for name in ("wolf", "seer", "hunter", "robber"):
            ready(night, name)
        ready(night, "wolf", False)

        ready(night, "villager")

        assert night.refresh().phase == Phase.DISCUSSION
        ready(night, "wolf")
        assert night.refresh().phase == Phase.VOTING

    def test_the_host_can_still_end_the_talk_at_any_time(self, talk_night) -> None:
        night = talk_night
        ready(night, "seer")
        night.client.force_authenticate(user=night.host)

        with night.committed():
            response = night.client.post(
                reverse("onuw:end-discussion", kwargs={"game_id": str(night.game.id)})
            )

        assert response.status_code == status.HTTP_200_OK
        assert night.refresh().phase == Phase.VOTING

    def test_the_talk_deadline_still_ends_the_talk_with_nobody_ready(
        self, talk_night
    ) -> None:
        night = talk_night
        key = f"{night.game.id}:discussion"
        (callback,) = [cb for k, _, cb in night.scheduled if k == key][-1:]

        with night.committed():
            callback()

        assert night.refresh().phase == Phase.VOTING

    @pytest.mark.django_db(transaction=True)
    def test_host_end_discussion_and_last_ready_race_one_transition(
        self, talk_night
    ) -> None:
        night = talk_night
        for name in ("wolf", "seer", "hunter", "robber"):
            ready(night, name)
        ready_url = reverse("onuw:ready", kwargs={"game_id": str(night.game.id)})
        end_url = reverse("onuw:end-discussion", kwargs={"game_id": str(night.game.id)})
        barrier = threading.Barrier(2)
        codes: list[int] = []

        def call(user: Any, url: str, body: dict[str, Any] | None) -> None:
            try:
                client = APIClient()
                client.force_authenticate(user=user)
                barrier.wait(timeout=10)
                codes.append(client.post(url, body, format="json").status_code)
            finally:
                connections.close_all()

        threads = [
            threading.Thread(
                target=call, args=(night.users["villager"], ready_url, {"ready": True})
            ),
            threading.Thread(target=call, args=(night.host, end_url, None)),
        ]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=30)

        # Whichever came second got the ordinary "not in the talk" refusal.
        assert sorted(codes) == [status.HTTP_200_OK, status.HTTP_400_BAD_REQUEST]
        assert night.refresh().phase == Phase.VOTING
        assert [c["phase"] for c in night.broadcasts("phase.change")] == ["voting"]
        assert len(night.timer_delays_for("voting")) == 1


# ── dropped phones ───────────────────────────────────────────────────────────


class TestDroppedPhones:
    def test_dropped_player_inside_grace_still_needed_for_ready(
        self, talk_night
    ) -> None:
        night = talk_night
        drop(night, "robber", seconds_ago=5)

        for name in ("wolf", "seer", "hunter", "villager"):
            ready(night, name)

        assert night.refresh().phase == Phase.DISCUSSION
        assert night.broadcasts("progress")[-1]["needed"] == 5
        # The phone comes back and taps: now everyone is ready.
        connect(night, "robber")
        ready(night, "robber")
        assert night.refresh().phase == Phase.VOTING

    def test_a_player_gone_past_the_grace_period_is_not_needed(
        self, talk_night
    ) -> None:
        night = talk_night
        drop(night, "robber", seconds_ago=60)

        for name in ("wolf", "seer", "hunter"):
            ready(night, name)
            assert night.refresh().phase == Phase.DISCUSSION
        assert night.broadcasts("progress")[-1] == {
            "type": "progress",
            "stage": "talk",
            "done": 3,
            "needed": 4,
        }

        ready(night, "villager")

        assert night.refresh().phase == Phase.VOTING

    def test_a_gone_talker_is_only_recounted_on_the_next_tap(self, talk_night) -> None:
        night = talk_night
        drop(night, "robber", seconds_ago=5)
        for name in ("wolf", "seer", "hunter", "villager"):
            ready(night, name)
        assert night.refresh().phase == Phase.DISCUSSION
        # No grace timer exists in the talk, so nothing fires when it runs out...
        assert grace_callbacks(night, "robber") == []
        PlayerRole.objects.filter(game=night.game, user=night.users["robber"]).update(
            disconnected_at=timezone.now() - timedelta(seconds=60)
        )
        assert night.refresh().phase == Phase.DISCUSSION

        # ...the next tap (even a repeat) counts them out.
        ready(night, "villager")

        assert night.refresh().phase == Phase.VOTING

    def test_a_phone_coming_back_in_the_talk_tells_the_table_the_new_count(
        self, talk_night
    ) -> None:
        night = talk_night
        drop(night, "robber", seconds_ago=60)
        ready(night, "wolf")
        night.recorder.events.clear()

        connect(night, "robber")

        assert night.broadcasts("progress") == [
            {"type": "progress", "stage": "talk", "done": 1, "needed": 5}
        ]

    def test_every_phone_gone_means_nobody_ends_the_talk(self, talk_night) -> None:
        night = talk_night
        for name in ROLES:
            drop(night, name, seconds_ago=60)
        PlayerRole.objects.filter(game=night.game, user=night.users["wolf"]).update(
            phase_ready=True
        )

        night.client.force_authenticate(user=night.users["wolf"])
        with night.committed():
            night.client.post(
                reverse("onuw:ready", kwargs={"game_id": str(night.game.id)}),
                {"ready": True},
                format="json",
            )

        assert night.refresh().phase == Phase.DISCUSSION
