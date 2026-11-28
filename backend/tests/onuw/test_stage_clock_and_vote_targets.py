"""
``GET /me/``: ``stage_started_at`` and ``vote_targets``.

``stage_started_at`` is when the timed stage that is open now (the look, a night
window, the talk, the vote) opened, in ``deadline``'s format, so a phone that
restarts can draw how much of the stage has passed. It is the same on every phone
and null when the stage has no deadline.

``vote_targets`` is, while voting, the player ids the caller may vote for in seat
order: everyone but the caller (no self-votes). The phone lists exactly those and
holds no rule; the vote service accepts every one of them and refuses the caller.

All through the real API, seeded deals, seat order the reverse of user-id order
(``Night``), every role at the table checked alike.
"""

import random
from datetime import UTC, datetime, timedelta
from typing import Any
from unittest.mock import patch

from django.urls import reverse

import pytest
from rest_framework import status

from apps.core.wire import wire_time
from apps.onuw import night_flow, recovery
from apps.onuw.engine.validation import length_ranges
from apps.onuw.models import Phase
from tests.onuw.stages import staged
from tests.onuw.test_choose_night import choose
from tests.onuw.test_night_windows import Night
from tests.onuw.test_presence import drop, to_voting

pytestmark = pytest.mark.integration

# A Doppelganger in the deck, so the night has both windows.
ROLES = {
    "dop": "Doppelganger",
    "wolf": "Werewolf",
    "seer": "Seer",
    "robber": "Robber",
    "villager": "Villager",
    "hunter": "Hunter",
}
CENTER = ["Villager", "Tanner", "Troublemaker"]
T0 = datetime(2026, 1, 2, 18, 0, tzinfo=UTC)

VOTE = 120
# The setting of each timed stage, in the order the game opens them.
STAGE_KEYS = (
    "card_look_seconds",
    "night_doppelganger_window_seconds",
    "night_wave_seconds",
    "discussion_seconds",
    "voting_seconds",
)


def _lengths(case: str) -> dict[str, int]:
    """Every timed stage's length: the least the live rules let a table set (above 0,
    which is no clock), the most, or a seeded draw between. A stage that lasts other
    than its setting (a floor, a cap, an assumed default) differs at one of them."""
    ranges = length_ranges({"disconnect_grace_seconds": 25}, allow_untimed=False)
    rng = random.Random(f"stage-lengths:{case}")  # noqa: S311 (a seeded test draw)
    out = {}
    for key in STAGE_KEYS:
        least, most = max(1, ranges[key][0]), ranges[key][1]
        out[key] = {"least": least, "most": most}.get(case) or rng.randint(least, most)
    return out


class Clock:
    def __init__(self) -> None:
        self.now = T0

    def __call__(self) -> datetime:
        return self.now

    def advance(self, seconds: float) -> None:
        self.now += timedelta(seconds=seconds)


@pytest.fixture
def clock() -> Any:
    tick = Clock()
    with patch("django.utils.timezone.now", new=tick):
        yield tick


def me(night: Night, name: str) -> dict[str, Any]:
    night.client.force_authenticate(user=night.users[name])
    response = night.client.get(
        reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})
    )
    assert response.status_code == status.HTTP_200_OK
    return response.data


def post(night: Night, who: str, name: str, body: dict[str, Any]) -> Any:
    night.client.force_authenticate(user=night.users[who])
    with night.committed():
        return night.client.post(
            reverse(f"onuw:{name}", kwargs={"game_id": str(night.game.id)}),
            staged(night, body),
            format="json",
        )


def everyone(night: Night, name: str, body: dict[str, Any]) -> None:
    for who in night.users:
        assert post(night, who, name, body).status_code == status.HTTP_200_OK


def lasts(night: Night, timer: str, seconds: int) -> None:
    """The stage's timer is scheduled to end it after exactly the table's setting."""
    delays = night.timer_delays_for(timer)
    assert delays, f"no {timer} timer was scheduled"
    assert delays[-1] == seconds, (
        f"the {timer} stage ends {delays[-1]} s after it opens; the table set"
        f" {seconds} s. A stage ends when the table's setting says (no floor, cap or"
        " assumed length)."
    )


def clock_of_every_seat(night: Night) -> tuple[str | None, str | None]:
    """``(stage_started_at, deadline)``, asserted the same on every seat."""
    seen = {(b["stage_started_at"], b["deadline"]) for b in map_me(night)}
    assert len(seen) == 1, seen
    return seen.pop()


def map_me(night: Night) -> list[dict[str, Any]]:
    return [me(night, name) for name in night.users]


def iso(moment: datetime) -> str:
    return wire_time(moment)


def deal(night: Night) -> None:
    with night.committed():
        night_flow.begin_night(night.game)
    night.refresh()


class TestStageStartedAt:
    @pytest.mark.parametrize("case", ["least", "most", "seeded"])
    def test_every_timed_stage_lasts_what_the_table_set_the_same_on_every_seat(
        self, make_night, clock, case
    ) -> None:
        lengths = _lengths(case)
        night = make_night(ROLES, CENTER, night_min_window_seconds=0, **lengths)
        # A timer the game scheduled is armed, as on a server: no read finds one
        # missing and rebuilds it (the rebuild's reconnect allowance is recovery's).
        armed = patch(
            "apps.core.timers.is_scheduled",
            new=lambda key: any(k == key for k, *_ in night.scheduled),
        )
        with armed:
            self._play(night, clock, lengths)

    def _play(self, night: Night, clock: Clock, lengths: dict[str, int]) -> None:
        look, window_1, wave, talk_for, vote_for = (lengths[k] for k in STAGE_KEYS)
        deal(night)
        # The look stage.
        assert clock_of_every_seat(night) == (
            iso(T0),
            iso(T0 + timedelta(seconds=look)),
        )
        lasts(night, "look", look)

        # The last look opens window 1 (the Doppelganger's), before the look's end.
        clock.advance(look / 4)
        everyone(night, "ready", {"ready": True})
        w1 = T0 + timedelta(seconds=look / 4)
        assert night.refresh().current_wave == 1
        assert clock_of_every_seat(night) == (
            iso(w1),
            iso(w1 + timedelta(seconds=window_1)),
        )
        lasts(night, "wave:1", window_1)

        # Window 1 ends on its fixed timer; window 2 opens then.
        clock.advance(window_1)
        night.fire_timer(1)
        w2 = w1 + timedelta(seconds=window_1)
        assert night.refresh().current_wave == 2
        assert clock_of_every_seat(night) == (
            iso(w2),
            iso(w2 + timedelta(seconds=wave)),
        )
        lasts(night, "wave:2", wave)

        # Every phone with a choice chooses before the window ends: the talk opens.
        clock.advance(wave / 4)
        for name in night.users:
            if night.turn_open(name):
                assert choose(night, name, []).status_code == status.HTTP_200_OK
        talk = w2 + timedelta(seconds=wave / 4)
        assert night.refresh().phase == Phase.DISCUSSION
        assert clock_of_every_seat(night) == (
            iso(talk),
            iso(talk + timedelta(seconds=talk_for)),
        )
        lasts(night, "discussion", talk_for)

        # Everyone is ready before the talk ends: the vote opens.
        clock.advance(talk_for / 4)
        everyone(night, "ready", {"ready": True})
        vote = talk + timedelta(seconds=talk_for / 4)
        assert night.refresh().phase == Phase.VOTING
        assert clock_of_every_seat(night) == (
            iso(vote),
            iso(vote + timedelta(seconds=vote_for)),
        )
        lasts(night, "voting", vote_for)

        # The results have no stage clock.
        clock.advance(vote_for / 4)
        for name in night.users:
            target = "wolf" if name != "wolf" else "seer"
            body = {"target_player_id": night.users[target].id, "lock": True}
            post(night, name, "vote", body)
        assert night.refresh().phase == Phase.RESULTS
        assert clock_of_every_seat(night) == (None, None)

    def test_untimed_stages_have_no_start_either(self, make_night, clock) -> None:
        night = make_night(
            ROLES,
            CENTER,
            night_doppelganger_window_seconds=0,
            night_wave_seconds=0,
            night_min_window_seconds=0,
            discussion_seconds=0,
            voting_seconds=0,
        )
        night.start()
        assert night.game.current_wave == 1
        assert clock_of_every_seat(night) == (None, None)

        while night.refresh().phase == Phase.NIGHT:
            for name in night.users:
                choose(night, name, [])
        assert night.game.phase == Phase.DISCUSSION
        assert clock_of_every_seat(night) == (None, None)

        everyone(night, "ready", {"ready": True})
        assert night.refresh().phase == Phase.VOTING
        assert clock_of_every_seat(night) == (None, None)

    def test_a_late_deadline_keeps_the_stage_start(self, make_night, clock) -> None:
        """A restart's reconnect allowance moves the deadline, never the start: the
        phone draws the stage as it really ran."""
        night = make_night(ROLES, CENTER, voting_seconds=VOTE)
        night.start()
        to_voting(night)
        started, _ = clock_of_every_seat(night)

        clock.advance(VOTE + 30)  # the server was down past the deadline
        with night.committed():
            recovery._grant_reconnect_allowance(night.refresh())

        later_start, later_deadline = clock_of_every_seat(night)
        assert later_start == started == iso(T0)
        assert later_deadline is not None
        assert datetime.fromisoformat(later_deadline) > clock.now


class TestVoteTargets:
    @pytest.fixture
    def voting(self, make_night) -> Night:
        night = make_night(ROLES, CENTER, voting_seconds=VOTE)
        night.start()
        to_voting(night)
        return night

    def test_each_seat_may_vote_for_every_other_player_in_seat_order(
        self, voting
    ) -> None:
        night = voting
        seat_order = [night.users[name].id for name in ROLES]
        # Seats are the reverse of user-id order: a list in id order would differ.
        assert seat_order != sorted(seat_order)

        for name in ROLES:
            own = night.users[name].id
            assert me(night, name)["vote_targets"] == [
                pid for pid in seat_order if pid != own
            ]

    def test_the_list_is_exactly_what_the_vote_accepts(self, voting) -> None:
        night = voting
        for name in ROLES:
            own = night.users[name].id
            for target in me(night, name)["vote_targets"]:
                body = {"target_player_id": target, "lock": False}
                assert post(night, name, "vote", body).status_code == 200
            body = {"target_player_id": own, "lock": False}
            assert post(night, name, "vote", body).status_code == 400

    def test_picks_locks_and_a_dropped_player_change_nobodys_list(self, voting) -> None:
        night = voting
        before = {name: me(night, name)["vote_targets"] for name in ROLES}
        post(night, "seer", "vote", {"target_player_id": night.users["wolf"].id})
        post(
            night,
            "robber",
            "vote",
            {"target_player_id": night.users["dop"].id, "lock": False},
        )
        drop(night, "villager", seconds_ago=600)

        assert {name: me(night, name)["vote_targets"] for name in ROLES} == before
        # Same length on every seat, whatever it was dealt.
        assert {len(targets) for targets in before.values()} == {len(ROLES) - 1}

    def test_null_outside_the_vote(self, make_night) -> None:
        night = make_night(
            ROLES,
            CENTER,
            night_doppelganger_window_seconds=0,
            night_wave_seconds=0,
            night_min_window_seconds=0,
            voting_seconds=0,
        )
        night.start()
        assert {b["vote_targets"] for b in map_me(night)} == {None}
        while night.refresh().phase == Phase.NIGHT:
            for name in night.users:
                choose(night, name, [])
        assert {b["vote_targets"] for b in map_me(night)} == {None}
        everyone(night, "ready", {"ready": True})
        for name in night.users:
            target = "wolf" if name != "wolf" else "seer"
            body = {"target_player_id": night.users[target].id, "lock": True}
            post(night, name, "vote", body)
        assert night.refresh().phase == Phase.RESULTS
        assert {b["vote_targets"] for b in map_me(night)} == {None}
