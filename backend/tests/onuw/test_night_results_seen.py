"""
The night-results acknowledgement: ``POST /api/onuw/games/<id>/night-results/seen/``.

A phone that restarts must not show the night results it already showed. The
client acks how many of its own ``night_results`` it has shown; ``GET /me/``
returns that count as ``night_results_seen``. The count is the caller's own, only
ever goes up, and never covers a result the caller cannot see yet.
"""

import threading
from typing import Any

from django.db import connections
from django.urls import reverse

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.onuw.models import Game, Phase, PlayerRole
from tests.onuw.test_night_windows import Night

pytestmark = pytest.mark.integration

ROLES = {
    "wolf": "Werewolf",
    "seer": "Seer",
    "robber": "Robber",
    "insomniac": "Insomniac",
    "villager": "Villager",
}
CENTER = ["Villager", "Tanner", "Hunter"]


def ack(night: Night, name: str, body: Any) -> Any:
    night.client.force_authenticate(user=night.users[name])
    return night.client.post(
        reverse("onuw:night-results-seen", kwargs={"game_id": str(night.game.id)}),
        body,
        format="json",
    )


def me(night: Night, name: str) -> dict[str, Any]:
    night.client.force_authenticate(user=night.users[name])
    response = night.client.get(
        reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})
    )
    assert response.status_code == status.HTTP_200_OK
    return response.data


def stored(night: Night, name: str) -> int:
    return night.role_of(name).night_results_seen


def finish_window_two(night: Night) -> None:
    night.post("wolf", "see_team")
    night.post("seer", "peek_player", {"player_id": night.users["robber"].id})
    night.post("robber", "swap_with_player", {"player_id": night.users["villager"].id})
    night.post("insomniac", "none")
    assert night.refresh().phase == Phase.DISCUSSION


def ack_from_a_phone(user, url, asked, barrier, replies) -> None:
    """One phone of ``user``: wait for the others, ack ``asked``, record the answer."""
    try:
        client = APIClient()
        client.force_authenticate(user=user)
        barrier.wait(timeout=10)
        response = client.post(url, {"seen": asked}, format="json")
        stored_now = response.data.get("night_results_seen", -1)
        replies.append((asked, response.status_code, stored_now))
    finally:
        connections.close_all()


@pytest.fixture
def dawn(make_night) -> Night:
    """Window 2 has closed: wolf, seer, robber and insomniac each have one result."""
    night = make_night(ROLES, CENTER, night_wave_seconds=60)
    night.start()
    finish_window_two(night)
    return night


class TestSeenCount:
    def test_a_new_player_has_seen_nothing(self, dawn) -> None:
        for name in ROLES:
            assert me(dawn, name)["night_results_seen"] == 0

    def test_me_reports_seen_count(self, dawn) -> None:
        assert ack(dawn, "seer", {"seen": 1}).status_code == status.HTTP_200_OK

        body = me(dawn, "seer")

        assert body["night_results_seen"] == 1
        assert len(body["night_results"]) == 1
        assert stored(dawn, "seer") == 1

    def test_seen_count_is_monotonic(self, dawn) -> None:
        assert ack(dawn, "seer", {"seen": 1}).data == {"night_results_seen": 1}

        # A late, lower or repeated ack changes nothing and says so.
        assert ack(dawn, "seer", {"seen": 0}).data == {"night_results_seen": 1}
        assert ack(dawn, "seer", {"seen": 1}).data == {"night_results_seen": 1}

        assert me(dawn, "seer")["night_results_seen"] == 1
        assert stored(dawn, "seer") == 1

    def test_seen_count_is_player_scoped(self, dawn) -> None:
        assert ack(dawn, "seer", {"seen": 1}).status_code == status.HTTP_200_OK

        assert stored(dawn, "seer") == 1
        for other in ("wolf", "robber", "insomniac", "villager"):
            assert stored(dawn, other) == 0
            assert me(dawn, other)["night_results_seen"] == 0

    def test_a_sleeper_acks_their_unchanged_count_like_everyone(self, dawn) -> None:
        # The villager has no result: the ack is accepted and stays at 0.
        response = ack(dawn, "villager", {"seen": 0})

        assert response.status_code == status.HTTP_200_OK
        assert response.data == {"night_results_seen": 0}

    def test_seen_count_clamped_to_visible_results(self, dawn) -> None:
        # The seer can see exactly one result; claiming more is capped at one.
        assert ack(dawn, "seer", {"seen": 10}).data == {"night_results_seen": 1}
        assert stored(dawn, "seer") == 1
        # Nothing to see (a sleeper) stays 0 whatever is claimed.
        assert ack(dawn, "villager", {"seen": 7}).data == {"night_results_seen": 0}

    def test_an_ack_cannot_cover_a_result_that_is_not_visible_yet(
        self, make_night
    ) -> None:
        """The Doppelganger's look reaches her by socket while window 1 is open, but
        ``night_results`` lists it only once the window closes: an ack sent before
        that is clamped to nothing, so the look is still shown after a restart."""
        night = make_night(
            {"d": "Doppelganger", "s": "Seer", "w": "Werewolf", "v": "Villager"},
            ["Robber", "Tanner", "Hunter"],
        )
        night.start()
        night.post("d", "peek_player", {"player_id": night.users["s"].id})
        assert night.refresh().current_wave == 1  # her follow-up is pending
        assert me(night, "d")["night_results"] == []  # held back while open

        early = ack(night, "d", {"seen": 1})

        assert early.data == {"night_results_seen": 0}
        night.post("d", "peek_center", {"center_indices": [0, 1]})
        assert night.refresh().current_wave == 2
        assert len(me(night, "d")["night_results"]) == 2
        assert me(night, "d")["night_results_seen"] == 0  # both still unseen
        assert ack(night, "d", {"seen": 2}).data == {"night_results_seen": 2}

    @pytest.mark.django_db(transaction=True)
    def test_concurrent_acks_never_lose_the_highest(self, dawn) -> None:
        """Ten phones of one player ack ten DIFFERENT counts at once, round after
        round. A read-modify-write would sometimes end below ten, or let a lower ack
        win; the single GREATEST update never does."""
        seer = dawn.users["seer"]
        entries = 10
        # Ten visible results for the seer (only the log's entries are counted).
        log = [
            {"player_id": seer.id, "wave": 3, "action_type": "peek_player"}
            for _ in range(entries)
        ]
        Game.objects.filter(id=dawn.game.id).update(night_actions_log=log)
        url = reverse("onuw:night-results-seen", kwargs={"game_id": str(dawn.game.id)})
        rounds = 12

        for _ in range(rounds):
            PlayerRole.objects.filter(game=dawn.game, user=seer).update(
                night_results_seen=0
            )
            barrier = threading.Barrier(entries)
            replies: list[tuple[int, int, int]] = []  # (asked, status, stored)
            threads = [
                threading.Thread(
                    target=ack_from_a_phone, args=(seer, url, asked, barrier, replies)
                )
                for asked in range(1, entries + 1)
            ]
            for t in threads:
                t.start()
            for t in threads:
                t.join(timeout=30)

            assert len(replies) == entries
            assert all(code == status.HTTP_200_OK for _, code, _ in replies)
            # Every answer is at least what that phone asked for: nobody's ack
            # was lost or undone by another's.
            assert all(stored_now >= asked for asked, _, stored_now in replies)
            assert stored(dawn, "seer") == entries


class TestRejections:
    @pytest.mark.parametrize(
        "bad",
        [-1, 11, 100, 1.5, "1", "", True, False, None, [1], {"n": 1}],
    )
    def test_seen_rejects_non_integer_and_out_of_range(self, dawn, bad) -> None:
        response = ack(dawn, "seer", {"seen": bad})

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["code"] == "bad_request"
        assert stored(dawn, "seer") == 0

    @pytest.mark.parametrize("body", [{}, [], "seen", None])
    def test_seen_needs_a_body_with_seen(self, dawn, body) -> None:
        assert ack(dawn, "seer", body).status_code == status.HTTP_400_BAD_REQUEST

    def test_the_largest_allowed_value_is_accepted(self, dawn) -> None:
        assert ack(dawn, "seer", {"seen": 10}).status_code == status.HTTP_200_OK

    def test_a_non_player_is_refused_and_changes_nothing(self, dawn) -> None:
        from apps.core.models import User

        outsider = User.objects.create_user(username="outsider", password="x")
        client = APIClient()
        client.force_authenticate(user=outsider)

        response = client.post(
            reverse("onuw:night-results-seen", kwargs={"game_id": str(dawn.game.id)}),
            {"seen": 1},
            format="json",
        )

        assert response.status_code == status.HTTP_403_FORBIDDEN
        assert not PlayerRole.objects.filter(
            game=dawn.game, night_results_seen__gt=0
        ).exists()

    def test_an_unknown_game_is_404_and_a_login_is_required(self, dawn) -> None:
        url = reverse(
            "onuw:night-results-seen",
            kwargs={"game_id": "00000000-0000-0000-0000-000000000000"},
        )
        dawn.client.force_authenticate(user=dawn.users["seer"])
        assert dawn.client.post(url, {"seen": 1}, format="json").status_code == 404
        junk = reverse("onuw:night-results-seen", kwargs={"game_id": "not-a-uuid"})
        assert dawn.client.post(junk, {"seen": 1}, format="json").status_code == 404

        anonymous = APIClient().post(
            reverse("onuw:night-results-seen", kwargs={"game_id": str(dawn.game.id)}),
            {"seen": 1},
            format="json",
        )
        assert anonymous.status_code == status.HTTP_401_UNAUTHORIZED
        assert Game.objects.filter(id=dawn.game.id).exists()
