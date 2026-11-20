"""
Lock-in voting: a vote is *picked* (changeable, private) and then *locked* (final).

``POST /api/onuw/games/<id>/vote/`` takes ``lock`` (default true, so a client that
never heard of it behaves exactly as before). A pick sends no socket event at all;
a lock sends the legacy ``vote_submitted`` and a count-only ``progress``. At any
reveal (everyone locked, the deadline, the host) every stored pick counts, locked or
not, so a pick never needs to be sent twice and a dropped player's pick still counts.

All through the real API with seat order different from user-id order (``Night``).
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

from apps.onuw.models import Game, Phase, PlayerRole
from tests.onuw.test_night_windows import Night
from tests.onuw.test_presence import drop, fire_grace, to_voting

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
def vote_night(make_night) -> Night:
    """Five players at the vote, a deadline far away."""
    night = make_night(ROLES, CENTER, voting_seconds=120)
    night.start()
    to_voting(night)
    night.recorder.events.clear()
    return night


def post_vote(night: Night, voter: str, body: Any) -> Any:
    night.client.force_authenticate(user=night.users[voter])
    with night.committed():
        return night.client.post(
            reverse("onuw:vote", kwargs={"game_id": str(night.game.id)}),
            body,
            format="json",
        )


def vote(night: Night, voter: str, target: str, **extra: Any) -> Any:
    return post_vote(
        night, voter, {"target_player_id": night.users[target].id, **extra}
    )


def pick(night: Night, voter: str, target: str) -> Any:
    return vote(night, voter, target, lock=False)


def lock(night: Night, voter: str, target: str) -> Any:
    return vote(night, voter, target, lock=True)


def me(night: Night, name: str) -> dict[str, Any]:
    night.client.force_authenticate(user=night.users[name])
    response = night.client.get(
        reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})
    )
    assert response.status_code == status.HTTP_200_OK
    return response.data


def stored(night: Night, name: str) -> tuple[int | None, bool]:
    pr = night.role_of(name)
    return pr.vote_target_id, pr.has_acted


def fire_voting_deadline(night: Night) -> None:
    key = f"{night.game.id}:voting"
    callbacks = [cb for k, _, cb in night.scheduled if k == key]
    assert callbacks, "no voting timer was scheduled"
    with night.committed():
        callbacks[-1]()
    night.refresh()


def host_reveal(night: Night) -> Any:
    night.client.force_authenticate(user=night.host)
    with night.committed():
        return night.client.post(
            reverse("onuw:reveal-votes", kwargs={"game_id": str(night.game.id)})
        )


def revealed(night: Night) -> dict[str, int | None]:
    (event,) = night.broadcasts("vote.reveal")
    return event["votes"]


# ── pick and lock ────────────────────────────────────────────────────────────


class TestPickAndLock:
    def test_pick_can_change_until_locked(self, vote_night) -> None:
        night = vote_night
        seer, wolf = night.users["seer"].id, night.users["wolf"].id

        first = pick(night, "robber", "seer")
        second = pick(night, "robber", "wolf")

        assert first.status_code == second.status_code == status.HTTP_200_OK
        assert first.data == {"status": "picked", "target_player_id": seer}
        assert second.data == {"status": "picked", "target_player_id": wolf}
        assert stored(night, "robber") == (wolf, False)

        locked = lock(night, "robber", "villager")
        assert locked.status_code == status.HTTP_200_OK
        assert locked.data == {"status": "submitted"}
        assert stored(night, "robber") == (night.users["villager"].id, True)

    def test_lock_is_final_repick_returns_409(self, vote_night) -> None:
        night = vote_night
        assert lock(night, "robber", "seer").status_code == status.HTTP_200_OK

        for attempt in (pick(night, "robber", "wolf"), lock(night, "robber", "wolf")):
            assert attempt.status_code == status.HTTP_409_CONFLICT
            assert attempt.data["code"] == "vote_locked"
            assert attempt.data["detail"] == "You have already locked in your vote."

        assert stored(night, "robber") == (night.users["seer"].id, True)

    def test_vote_without_lock_field_locks_like_before(self, vote_night) -> None:
        night = vote_night

        response = vote(night, "robber", "seer")

        assert response.status_code == status.HTTP_200_OK
        assert response.data == {"status": "submitted"}
        assert stored(night, "robber") == (night.users["seer"].id, True)
        assert night.broadcasts("vote.submitted") == [
            {"type": "vote.submitted", "player_id": night.users["robber"].id}
        ]
        assert me(night, "robber")["has_voted"] is True
        assert vote(night, "robber", "wolf").status_code == status.HTTP_409_CONFLICT

    def test_an_unlocked_pick_is_not_a_vote_cast_for_has_voted(
        self, vote_night
    ) -> None:
        night = vote_night
        pick(night, "robber", "seer")

        body = me(night, "robber")
        assert body["has_voted"] is False
        other = me(night, "wolf")
        assert all(p["has_voted"] is False for p in other["players"])

    def test_a_pick_repeated_for_the_same_target_is_harmless(self, vote_night) -> None:
        night = vote_night
        for _ in range(3):
            assert pick(night, "robber", "seer").status_code == status.HTTP_200_OK
        assert stored(night, "robber") == (night.users["seer"].id, False)

    @pytest.mark.parametrize("bad", ["seer", "robber"])
    def test_cannot_pick_yourself_or_a_stranger(self, vote_night, bad) -> None:
        night = vote_night
        target = night.users["robber"].id if bad == "robber" else 999_999

        response = post_vote(
            night, "robber", {"target_player_id": target, "lock": False}
        )

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["code"] == "invalid_target"
        assert stored(night, "robber") == (None, False)

    def test_a_non_player_is_refused(self, vote_night, django_user_model) -> None:
        night = vote_night
        stranger = django_user_model.objects.create_user(
            username="nobody", password="x"
        )
        night.client.force_authenticate(user=stranger)

        response = night.client.post(
            reverse("onuw:vote", kwargs={"game_id": str(night.game.id)}),
            {"target_player_id": night.users["seer"].id, "lock": False},
            format="json",
        )

        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_picking_outside_the_voting_phase_is_wrong_phase(self, make_night) -> None:
        night = make_night(ROLES, CENTER)
        night.start()
        assert night.game.phase == Phase.NIGHT

        response = pick(night, "robber", "seer")

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["code"] == "wrong_phase"
        assert night.role_of("robber").vote_target_id is None

    @pytest.mark.parametrize(
        "target", ["5", 5.0, True, False, None, [], {}, "", [1]], ids=repr
    )
    def test_target_must_be_a_json_integer(self, vote_night, target) -> None:
        night = vote_night

        response = post_vote(
            night, "robber", {"target_player_id": target, "lock": False}
        )

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["code"] == "bad_request"
        assert stored(night, "robber") == (None, False)

    def test_a_missing_target_is_a_bad_request(self, vote_night) -> None:
        response = post_vote(vote_night, "robber", {"lock": False})

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["code"] == "bad_request"

    @pytest.mark.parametrize(
        "bad", ["true", "false", 1, 0, None, [], {}, "yes"], ids=repr
    )
    def test_lock_must_be_a_json_boolean(self, vote_night, bad) -> None:
        night = vote_night

        response = vote(night, "robber", "seer", lock=bad)

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["code"] == "bad_request"
        assert response.data["detail"] == "lock must be true or false"
        assert stored(night, "robber") == (None, False)

    @pytest.mark.parametrize("body", [[], "seer", 5, None])
    def test_the_body_must_be_an_object(self, vote_night, body) -> None:
        response = post_vote(vote_night, "robber", body)

        assert response.status_code == status.HTTP_400_BAD_REQUEST


# ── what the table hears ─────────────────────────────────────────────────────


class TestSocketEvents:
    def test_pick_sends_no_socket_event(self, vote_night) -> None:
        night = vote_night

        pick(night, "robber", "seer")
        pick(night, "robber", "wolf")

        # Not to the group and not to any player's channel.
        assert night.recorder.events == []

    def test_a_lock_sends_the_legacy_event_and_a_count(self, vote_night) -> None:
        night = vote_night

        lock(night, "robber", "seer")

        assert night.broadcasts("vote.submitted") == [
            {"type": "vote.submitted", "player_id": night.users["robber"].id}
        ]
        assert night.broadcasts("progress") == [
            {"type": "progress", "stage": "vote", "done": 1, "needed": 5}
        ]
        # Nothing at all goes to a single player.
        assert all(
            group == f"game_{night.game.id}" for group, _ in night.recorder.events
        )

    def test_progress_event_carries_only_counts(self, vote_night) -> None:
        night = vote_night
        pick(night, "wolf", "seer")  # picked but not locked: never counted
        lock(night, "robber", "seer")
        lock(night, "villager", "wolf")

        events = night.broadcasts("progress")

        assert [(e["done"], e["needed"]) for e in events] == [(1, 5), (2, 5)]
        for event in events:
            assert set(event) == {"type", "stage", "done", "needed"}
            assert event["stage"] == "vote"
        # Everything broadcast is a lock (who) or a count: no target anywhere.
        assert sorted(e["type"] for _, e in night.recorder.events) == [
            "progress",
            "progress",
            "vote.submitted",
            "vote.submitted",
        ]
        for event in night.broadcasts("vote.submitted"):
            assert set(event) == {"type", "player_id"}

    def test_opening_the_vote_announces_done_zero(self, make_night) -> None:
        night = make_night(ROLES, CENTER, voting_seconds=120)
        night.start()

        to_voting(night)

        assert night.broadcasts("progress")[-1] == {
            "type": "progress",
            "stage": "vote",
            "done": 0,
            "needed": 5,
        }

    def test_a_grace_period_ending_changes_needed(self, vote_night) -> None:
        night = vote_night
        drop(night, "robber", seconds_ago=5)
        lock(night, "wolf", "seer")
        night.recorder.events.clear()
        PlayerRole.objects.filter(game=night.game, user=night.users["robber"]).update(
            disconnected_at=timezone.now() - timedelta(seconds=30)
        )

        fire_grace(night, "robber")

        assert night.broadcasts("progress") == [
            {"type": "progress", "stage": "vote", "done": 1, "needed": 4}
        ]

    def test_progress_has_a_socket_handler(self) -> None:
        from apps.onuw.consumers import GameConsumer

        assert hasattr(GameConsumer, "progress")


# ── when the vote is revealed ────────────────────────────────────────────────


class TestReveal:
    def test_votes_revealed_when_all_present_players_locked_even_if_deadline_far(
        self, vote_night
    ) -> None:
        night = vote_night
        # The robber picked but never locked, and has gone for good.
        pick(night, "robber", "wolf")
        drop(night, "robber", seconds_ago=60)

        for voter, target in (
            ("wolf", "seer"),
            ("seer", "wolf"),
            ("hunter", "wolf"),
        ):
            lock(night, voter, target)
            assert night.refresh().phase == Phase.VOTING
        lock(night, "villager", "wolf")

        assert night.refresh().phase == Phase.RESULTS
        assert night.game.phase_deadline is None

    def test_a_present_player_who_has_only_picked_holds_the_reveal(
        self, vote_night
    ) -> None:
        night = vote_night
        for voter, target in (
            ("wolf", "seer"),
            ("seer", "wolf"),
            ("hunter", "wolf"),
            ("villager", "wolf"),
        ):
            lock(night, voter, target)
        pick(night, "robber", "wolf")

        assert night.refresh().phase == Phase.VOTING

    def test_unlocked_pick_counts_at_voting_deadline(self, vote_night) -> None:
        night = vote_night
        pick(night, "robber", "wolf")
        pick(night, "seer", "wolf")
        lock(night, "wolf", "seer")

        fire_voting_deadline(night)

        assert night.game.phase == Phase.RESULTS
        votes = revealed(night)
        assert votes[str(night.users["robber"].id)] == night.users["wolf"].id
        assert votes[str(night.users["seer"].id)] == night.users["wolf"].id
        assert votes[str(night.users["wolf"].id)] == night.users["seer"].id

    def test_unlocked_pick_counts_at_host_reveal(self, vote_night) -> None:
        night = vote_night
        pick(night, "robber", "wolf")
        pick(night, "robber", "seer")  # changed her mind: the last pick counts

        response = host_reveal(night)

        assert response.status_code == status.HTTP_200_OK
        assert revealed(night)[str(night.users["robber"].id)] == night.users["seer"].id

    def test_player_with_no_pick_is_non_voter_at_deadline(self, vote_night) -> None:
        night = vote_night
        lock(night, "wolf", "seer")

        fire_voting_deadline(night)

        votes = revealed(night)
        assert votes[str(night.users["robber"].id)] is None
        assert votes[str(night.users["wolf"].id)] == night.users["seer"].id

    def test_gone_player_pick_counts_when_others_lock_early(self, vote_night) -> None:
        night = vote_night
        pick(night, "robber", "seer")
        drop(night, "robber", seconds_ago=60)

        for voter, target in (
            ("wolf", "seer"),
            ("seer", "wolf"),
            ("hunter", "seer"),
            ("villager", "seer"),
        ):
            lock(night, voter, target)

        assert night.refresh().phase == Phase.RESULTS
        assert revealed(night)[str(night.users["robber"].id)] == night.users["seer"].id
        # Three votes for the Seer, who is not the wolf: the village loses.
        assert night.game.results["eliminated_players"] == [night.users["seer"].id]

    def test_unlocked_hunter_pick_triggers_the_hunter_chain(self, vote_night) -> None:
        night = vote_night
        for voter in ("wolf", "seer", "robber", "villager"):
            lock(night, voter, "hunter")
        # The Hunter picked the wolf but never locked in.
        pick(night, "hunter", "wolf")
        assert night.refresh().phase == Phase.VOTING

        fire_voting_deadline(night)

        results = night.game.results
        assert set(results["eliminated_players"]) == {
            night.users["hunter"].id,
            night.users["wolf"].id,
        }
        assert results["elimination_reasons"][str(night.users["wolf"].id)] == (
            "hunter_chain"
        )

    def test_vote_after_reveal_is_rejected_and_does_not_change_results(
        self, vote_night
    ) -> None:
        night = vote_night
        lock(night, "wolf", "seer")
        fire_voting_deadline(night)
        before = dict(night.game.results)
        assert night.game.phase == Phase.RESULTS

        late = (pick(night, "robber", "wolf"), lock(night, "robber", "wolf"))

        for response in late:
            assert response.status_code == status.HTTP_400_BAD_REQUEST
            assert response.data["code"] == "wrong_phase"
        assert night.role_of("robber").vote_target_id is None
        assert Game.objects.get(id=night.game.id).results == before
        assert len(night.broadcasts("vote.reveal")) == 1

    def test_a_stale_game_object_cannot_vote_after_the_reveal(self, vote_night) -> None:
        """The phase is re-read under the Game lock: a caller holding an old row
        (taken while the vote was open) is still refused once it has closed."""
        from apps.onuw import services

        night = vote_night
        stale = Game.objects.get(id=night.game.id)
        fire_voting_deadline(night)

        errors = services.submit_vote(
            stale, night.users["robber"].id, night.users["wolf"].id, lock=False
        )

        assert errors == ["Game is not in the voting phase."]
        assert night.role_of("robber").vote_target_id is None

    @pytest.mark.django_db(transaction=True)
    def test_concurrent_last_two_locks_reveal_once(self, vote_night) -> None:
        night = vote_night
        for voter, target in (("wolf", "seer"), ("seer", "wolf"), ("hunter", "wolf")):
            lock(night, voter, target)
        url = reverse("onuw:vote", kwargs={"game_id": str(night.game.id)})
        barrier = threading.Barrier(2)
        codes: list[int] = []

        def last_lock(voter: str, target: str) -> None:
            try:
                client = APIClient()
                client.force_authenticate(user=night.users[voter])
                barrier.wait(timeout=10)
                reply = client.post(
                    url,
                    {"target_player_id": night.users[target].id, "lock": True},
                    format="json",
                )
                codes.append(reply.status_code)
            finally:
                connections.close_all()

        threads = [
            threading.Thread(target=last_lock, args=("robber", "wolf")),
            threading.Thread(target=last_lock, args=("villager", "wolf")),
        ]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=30)

        assert codes == [status.HTTP_200_OK, status.HTTP_200_OK]
        assert night.refresh().phase == Phase.RESULTS
        assert len(night.broadcasts("vote.reveal")) == 1
        assert len(night.broadcasts("game.results")) == 1


# ── /me/ ─────────────────────────────────────────────────────────────────────


class TestMe:
    def test_me_my_vote_is_own_only(self, vote_night) -> None:
        night = vote_night
        pick(night, "robber", "wolf")
        lock(night, "seer", "wolf")

        assert me(night, "robber")["my_vote"] == {
            "target_player_id": night.users["wolf"].id,
            "locked": False,
        }
        assert me(night, "seer")["my_vote"] == {
            "target_player_id": night.users["wolf"].id,
            "locked": True,
        }
        # Nobody else's page says who picked or locked whom.
        body = me(night, "villager")
        assert body["my_vote"] is None
        for entry in body["players"]:
            assert set(entry) <= {
                "player_id",
                "display_name",
                "token",
                "seat",
                "has_voted",
            }

    def test_my_vote_follows_a_repick(self, vote_night) -> None:
        night = vote_night
        pick(night, "robber", "wolf")
        pick(night, "robber", "seer")

        assert me(night, "robber")["my_vote"] == {
            "target_player_id": night.users["seer"].id,
            "locked": False,
        }

    def test_progress_counts_locks_not_picks(self, vote_night) -> None:
        night = vote_night
        pick(night, "robber", "wolf")
        lock(night, "seer", "wolf")
        lock(night, "wolf", "seer")

        for name in ROLES:
            assert me(night, name)["progress"] == {
                "stage": "vote",
                "done": 2,
                "needed": 5,
            }

    def test_progress_needed_leaves_out_a_player_gone_past_the_grace_period(
        self, vote_night
    ) -> None:
        night = vote_night
        drop(night, "villager", seconds_ago=60)
        lock(night, "seer", "wolf")

        assert me(night, "seer")["progress"] == {
            "stage": "vote",
            "done": 1,
            "needed": 4,
        }

    def test_my_vote_and_progress_are_null_outside_the_vote(self, make_night) -> None:
        night = make_night(ROLES, CENTER)
        night.start()

        body = me(night, "seer")

        assert body["my_vote"] is None
        assert body["progress"] is None

    def test_my_vote_is_null_in_the_results(self, vote_night) -> None:
        night = vote_night
        lock(night, "wolf", "seer")
        fire_voting_deadline(night)

        body = me(night, "wolf")

        assert body["my_vote"] is None
        assert body["progress"] is None
