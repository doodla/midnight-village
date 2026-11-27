"""
A late, lost vote or ready must not overwrite a newer tap (issue #16).

A phone may send ``"asked"`` (its tap time in ms, increasing per phone) with a
vote or a ready. Per lane (``vote``, ``ready``) the server keeps the newest
``asked`` it applied and the stage it was for (``PlayerRole.asked``). A request
for the SAME stage with an OLDER ``asked`` changes nothing: ``409 stale_request``.
That check comes last, after every refusal there was before (``wrong_stage``,
``vote_locked``, a bad target), so those answer as they always did. A request
without ``asked`` (an older phone) is handled as before.

All through the real API, five players, seat order unlike user-id order
(``Night``), seeded where there is a choice.
"""

from __future__ import annotations

import random
from typing import Any

import pytest
from rest_framework import status

from apps.onuw import night_flow
from apps.onuw.models import Game, Phase, PlayerRole
from apps.onuw.protocol import stage_token
from tests.onuw.stages import staged
from tests.onuw.test_night_windows import Night
from tests.onuw.test_resend import LONE, pid, send, to_talk, to_vote

pytestmark = pytest.mark.integration


def stale(newest: int) -> dict:
    """The one stale body: ``newest`` is the requester's own stored ``asked``."""
    return {
        "detail": "A newer tap from this phone already got there.",
        "code": "stale_request",
        "newest": newest,
    }


NAMES = list(LONE)


@pytest.fixture
def make_table(make_night):
    """Five players (Werewolf, Seer, Robber, Villager, Hunter), timed stages."""

    def factory(**settings: Any) -> Night:
        merged = {
            "night_wave_seconds": 60,
            "discussion_seconds": 300,
            "voting_seconds": 120,
            **settings,
        }
        return make_night(LONE, ["Villager", "Tanner", "Troublemaker"], **merged)

    return factory


def vote(night: Night, who: str, target: str, asked: Any = None, *, lock=False):
    body: dict[str, Any] = {"target_player_id": pid(night, target), "lock": lock}
    if asked is not None:
        body["asked"] = asked
    return send(night, who, "onuw:vote", staged(night, body))


def ready(night: Night, who: str, value: bool, asked: Any = None):
    body: dict[str, Any] = {"ready": value}
    if asked is not None:
        body["asked"] = asked
    return send(night, who, "onuw:ready", staged(night, body))


def row(night: Night, who: str) -> PlayerRole:
    return PlayerRole.objects.get(game=night.game, user=night.users[who])


def voted_for(night: Night, who: str) -> int | None:
    return row(night, who).vote_target_id  # type: ignore[attr-defined]


@pytest.fixture
def voting(make_table) -> Night:
    night = make_table()
    night.start()
    to_vote(night)
    return night


@pytest.fixture
def talking(make_table) -> Night:
    night = make_table()
    night.start()
    to_talk(night)
    return night


class TestVote:
    def test_a_late_older_pick_does_not_replace_the_newer_pick(self, voting) -> None:
        """The hole: the Seer picks the Robber, then the Werewolf; the Werewolf
        pick arrives first and the Robber pick late. The Werewolf pick stays."""
        night = voting
        assert vote(night, "seer", "wolf", 2000).status_code == 200
        events = len(night.recorder.events)

        late = vote(night, "seer", "robber", 1000)

        assert late.status_code == status.HTTP_409_CONFLICT
        assert late.data == stale(2000)
        assert voted_for(night, "seer") == pid(night, "wolf")
        assert len(night.recorder.events) == events
        assert row(night, "seer").asked == {"vote": [stage_token(night.game), 2000]}

    def test_a_late_older_lock_does_not_lock_over_a_newer_pick(self, voting) -> None:
        night = voting
        vote(night, "seer", "wolf", 2000)

        late = vote(night, "seer", "robber", 1000, lock=True)

        assert late.data == stale(2000)
        assert row(night, "seer").has_acted is False
        assert voted_for(night, "seer") == pid(night, "wolf")

    def test_a_stale_answer_names_only_the_players_own_number(self, voting) -> None:
        """Each player's entry is on their own row: the Seer's stale answer
        carries the Seer's number, never the Werewolf's larger one."""
        night = voting
        vote(night, "wolf", "seer", 10**12)
        vote(night, "seer", "wolf", 2000)

        late = vote(night, "seer", "robber", 1000)

        assert late.data == stale(2000)

    def test_a_phone_behind_gets_through_with_an_asked_above_newest(
        self, voting
    ) -> None:
        """The way out the answer gives: the player's second phone (its clock
        behind the first's) resends its newest tap above ``newest``."""
        night = voting
        vote(night, "seer", "wolf", 5_000_000)  # the first phone
        behind = vote(night, "seer", "robber", 1000)  # the second, clock behind

        again = vote(night, "seer", "robber", behind.data["newest"] + 1)

        assert again.status_code == status.HTTP_200_OK
        assert voted_for(night, "seer") == pid(night, "robber")

    def test_an_equal_asked_is_the_same_tap_sent_again(self, voting) -> None:
        night = voting
        first = vote(night, "seer", "wolf", 1500)
        again = vote(night, "seer", "wolf", 1500)

        assert first.status_code == again.status_code == status.HTTP_200_OK
        assert first.content == again.content

    def test_only_the_same_stage_is_compared(self, voting) -> None:
        """An entry left by another stage (here written as if from the talk) is
        never compared: the vote starts afresh."""
        night = voting
        talk_token = stage_token(night.game).replace("vote.", "talk.")
        PlayerRole.objects.filter(pk=row(night, "seer").pk).update(
            asked={"vote": [talk_token, 10**12]}
        )

        reply = vote(night, "seer", "robber", 5)

        assert reply.status_code == status.HTTP_200_OK
        assert voted_for(night, "seer") == pid(night, "robber")

    def test_after_the_lock_the_old_rule_still_answers(self, voting) -> None:
        """Locked is final whatever ``asked`` says: another pick, older or newer,
        is ``vote_locked``; the same lock again is the same 200."""
        night = voting
        assert vote(night, "seer", "wolf", 2000, lock=True).status_code == 200

        for asked in (1000, 3000):
            reply = vote(night, "seer", "robber", asked)
            assert reply.status_code == status.HTTP_409_CONFLICT
            assert reply.data["code"] == "vote_locked"
        for asked in (1000, 2000):
            again = vote(night, "seer", "wolf", asked, lock=True)
            assert again.json()["status"] == "submitted"
            assert again.json()["target_player_id"] == pid(night, "wolf")
        assert voted_for(night, "seer") == pid(night, "wolf")

    def test_a_stage_that_is_over_is_still_wrong_stage(self, voting) -> None:
        night = voting
        vote(night, "seer", "wolf", 2000)
        body = {
            "target_player_id": pid(night, "robber"),
            "lock": False,
            "stage": stage_token(night.game).replace("vote.", "talk."),
            "asked": 1000,
        }

        reply = send(night, "seer", "onuw:vote", body)

        assert reply.status_code == status.HTTP_409_CONFLICT
        assert reply.data["code"] == "wrong_stage"

    def test_without_asked_it_is_as_before_even_after_an_asked_pick(
        self, voting
    ) -> None:
        night = voting
        vote(night, "seer", "wolf", 9000)

        old_phone = vote(night, "seer", "robber")

        assert old_phone.status_code == status.HTTP_200_OK
        assert voted_for(night, "seer") == pid(night, "robber")
        assert row(night, "seer").asked["vote"][1] == 9000  # left as it was

    def test_a_vote_without_asked_stores_no_entry(self, voting) -> None:
        night = voting
        vote(night, "seer", "wolf")
        vote(night, "wolf", "seer", lock=True)
        assert row(night, "seer").asked == row(night, "wolf").asked == {}

    @pytest.mark.parametrize("bad", [None, True, -1, 1.5, "7", [7], {}])
    def test_an_asked_that_is_not_a_whole_number_is_bad_request(
        self, voting, bad
    ) -> None:
        night = voting
        body = staged(
            night,
            {"target_player_id": pid(night, "wolf"), "lock": False, "asked": bad},
        )

        reply = send(night, "seer", "onuw:vote", body)

        assert reply.status_code == status.HTTP_400_BAD_REQUEST
        assert reply.data["code"] == "bad_request"
        assert isinstance(reply.data["detail"], str)
        assert voted_for(night, "seer") is None

    @pytest.mark.parametrize("seed", range(8))
    def test_picks_delivered_in_any_order_leave_each_phones_newest(
        self, voting, seed
    ) -> None:
        """Seeded: every phone taps three picks, then all fifteen requests reach
        the server in a shuffled order. Each phone ends on its last tap."""
        night = voting
        rng = random.Random(seed)  # noqa: S311 (seeded test data, not secret)
        taps = []
        newest = {}
        for who in NAMES:
            for asked in (100, 200, 300):
                target = rng.choice([n for n in NAMES if n != who])
                taps.append((who, target, asked))
                newest[who] = target
        rng.shuffle(taps)

        for who, target, asked in taps:
            assert vote(night, who, target, asked).status_code in (200, 409)

        assert {n: voted_for(night, n) for n in NAMES} == {
            n: pid(night, t) for n, t in newest.items()
        }
        assert night.refresh().phase == Phase.VOTING


class TestReady:
    def test_a_late_older_true_does_not_undo_a_newer_false(self, talking) -> None:
        night = talking
        assert ready(night, "seer", False, 2000).status_code == 200
        events = len(night.recorder.events)

        late = ready(night, "seer", True, 1000)

        assert late.status_code == status.HTTP_409_CONFLICT
        assert late.data == stale(2000)
        assert row(night, "seer").phase_ready is False
        assert len(night.recorder.events) == events  # no progress sent

    def test_a_late_ready_does_not_end_the_talk(self, talking) -> None:
        """Four are ready; the fifth taps ready, then takes it back; the first tap
        arriving last would have ended the talk for everyone."""
        night = talking
        for name in ("wolf", "seer", "robber", "hunter"):
            ready(night, name, True, 10)
        ready(night, "villager", False, 2000)

        late = ready(night, "villager", True, 1000)

        assert late.data == stale(2000)
        assert night.refresh().phase == Phase.DISCUSSION

    def test_the_same_value_still_moves_the_newest_asked(self, talking) -> None:
        """A newer tap that changes nothing (false over false) is still the newest:
        an older true arriving after it is stale."""
        night = talking
        ready(night, "seer", False, 1000)
        ready(night, "seer", False, 3000)

        assert ready(night, "seer", True, 2000).data == stale(3000)
        assert row(night, "seer").phase_ready is False

    def test_an_equal_asked_answers_alike(self, talking) -> None:
        night = talking
        first = ready(night, "seer", True, 50)
        again = ready(night, "seer", True, 50)

        assert first.content == again.content
        assert first.json() == {
            "status": "ok",
            "ready": True,
            "progress": {"stage": "talk", "done": 1, "needed": 5},
        }

    def test_a_new_stage_starts_afresh(self, make_table) -> None:
        """The look's ready is not compared with the talk's: a phone whose clock
        went back between them is not refused."""
        night = make_table(card_look_seconds=30)
        with night.committed():
            night_flow.begin_night(night.game)
        for name in NAMES:
            assert ready(night, name, True, 50_000).status_code == 200
        assert night.refresh().current_wave == 2  # everyone looked: the night
        to_talk(night)

        reply = ready(night, "seer", True, 7)

        assert reply.status_code == status.HTTP_200_OK
        assert row(night, "seer").asked["ready"][1] == 7

    def test_without_asked_it_is_as_before_even_after_an_asked_tap(
        self, talking
    ) -> None:
        night = talking
        ready(night, "seer", True, 9000)

        old_phone = ready(night, "seer", False)

        assert old_phone.status_code == status.HTTP_200_OK
        assert row(night, "seer").phase_ready is False
        assert row(night, "seer").asked["ready"][1] == 9000

    def test_a_stage_that_is_over_is_still_wrong_stage(self, voting) -> None:
        night = voting
        body = {
            "ready": True,
            "stage": stage_token(night.game).replace("vote.", "talk."),
            "asked": 1,
        }
        reply = send(night, "seer", "onuw:ready", body)
        assert reply.data["code"] == "wrong_stage"

    @pytest.mark.parametrize("bad", [None, False, -5, 3.0, "3"])
    def test_an_asked_that_is_not_a_whole_number_is_bad_request(
        self, talking, bad
    ) -> None:
        night = talking
        reply = send(
            night, "seer", "onuw:ready", staged(night, {"ready": True, "asked": bad})
        )
        assert reply.status_code == status.HTTP_400_BAD_REQUEST
        assert reply.data["code"] == "bad_request"
        assert row(night, "seer").phase_ready is False

    @pytest.mark.parametrize("seed", range(8))
    def test_toggles_delivered_in_any_order_leave_each_phones_newest(
        self, talking, seed
    ) -> None:
        """Seeded: four phones toggle ready three times each (never all ready at
        the end, so the talk stays), delivered shuffled. Each ends on its last."""
        night = talking
        rng = random.Random(seed)  # noqa: S311 (seeded test data, not secret)
        taps = []
        newest = {}
        for who in NAMES[:4]:
            for asked in (100, 200, 300):
                value = rng.random() < 0.5
                taps.append((who, value, asked))
                newest[who] = value
        rng.shuffle(taps)

        for who, value, asked in taps:
            assert ready(night, who, value, asked).status_code in (200, 409)

        assert night.refresh().phase == Phase.DISCUSSION
        assert {n: row(night, n).phase_ready for n in newest} == newest


def test_choose_and_the_results_ack_ignore_asked(make_table) -> None:
    """Only the vote and ready lanes read ``asked``: a choose or a night-results
    ack carrying one is answered as without, and stores no entry."""
    night = make_table()
    night.start()
    game = Game.objects.get(id=night.game.id)
    body = staged(
        night,
        {"action_type": "choose", "picks": [], "chosen": 0, "asked": "ignored"},
    )
    assert send(night, "seer", "onuw:night-action", body).status_code == 200
    assert game.player_roles.filter(asked={}).count() == len(NAMES)
