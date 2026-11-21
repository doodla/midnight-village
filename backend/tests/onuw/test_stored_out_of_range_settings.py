"""
A table whose stored settings the server would refuse today is never stuck.

Older code allowed a night timer of 0 and a minimum window under 5 s on any table it
called the original night; this code refuses both where untimed nights are off
(production). A waiting table stored that way must still take every change that
does not touch those keys, and deal: the deal clamps the stored values
(``engine.validation.clamp_night_timing``) and the game gets the clamped ones.
"""

from django.urls import reverse

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.core.models import Lobby
from apps.onuw.engine.validation import clamp_night_timing
from apps.onuw.models import Game

pytestmark = pytest.mark.django_db

DECK = {"Werewolf": 2, "Seer": 1, "Robber": 1, "Troublemaker": 1, "Villager": 3}
# As older code stored a table it played as the original night, untimed.
STORED = {
    "roles": DECK,
    "night_wave_seconds": 0,
    "night_min_window_seconds": 0,
    "night_doppelganger_window_seconds": 0,
    "discussion_seconds": 0,
    "voting_seconds": 0,
    "night_protocol": 1,
}


def _guest() -> APIClient:
    client = APIClient()
    answer = client.post(reverse("core:guest-create"), {}, format="json")
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {answer.data['access']}")
    return client


@pytest.fixture
def stored_table(settings):
    """Five players at a waiting table whose row older code wrote (``STORED``), on
    a server that refuses untimed nights."""
    clients = [_guest() for _ in range(5)]
    host = clients[0]
    code = host.post(
        reverse("core:lobby-list"), {"game_type": "onuw"}, format="json"
    ).data["code"]
    for client in clients[1:]:
        client.post(reverse("core:lobby-join", kwargs={"code": code}))
    Lobby.objects.filter(code=code).update(settings=STORED)
    settings.ONUW_ALLOW_UNTIMED_NIGHT = False
    return code, host


def _patch(code: str, host: APIClient, given: dict):
    return host.patch(
        reverse("core:lobby-detail", kwargs={"code": code}),
        {"settings": given},
        format="json",
    )


class TestAStoredTableOutOfTodaysRange:
    def test_a_change_that_does_not_touch_the_night_timers_is_taken(
        self, stored_table
    ) -> None:
        code, host = stored_table
        for given in ({"pace": "normal"}, {"deck": "auto", "deck_chip": "simple"}):
            answer = _patch(code, host, given)
            assert answer.status_code == status.HTTP_200_OK, (given, answer.data)

    def test_a_change_to_a_night_timer_is_still_held_to_todays_range(
        self, stored_table
    ) -> None:
        code, host = stored_table
        for given in (
            {"night_min_window_seconds": 3},
            {"night_wave_seconds": 0},
            {"night_doppelganger_window_seconds": 0},
        ):
            answer = _patch(code, host, given)
            assert answer.status_code == status.HTTP_400_BAD_REQUEST, given
        assert _patch(code, host, {"night_min_window_seconds": 8}).status_code == 200

    def test_the_table_says_it_can_be_dealt_and_the_deal_clamps(
        self, stored_table, settings
    ) -> None:
        code, host = stored_table
        settings.DEBUG = True
        assert host.get(reverse("core:lobby-detail", kwargs={"code": code})).data[
            "deal"
        ]["ok"]

        answer = host.post(
            reverse("onuw:game-start", kwargs={"code": code}),
            {"debug": {"seed": 7}},
            format="json",
        )

        assert answer.status_code == status.HTTP_201_CREATED, answer.data
        game = Game.objects.get(id=answer.data["game_id"])
        assert game.settings["night_min_window_seconds"] == 5
        assert "night_wave_seconds" not in game.settings  # the default length
        assert "night_doppelganger_window_seconds" not in game.settings
        assert game.settings["discussion_seconds"] == 0  # the day may be untimed
        assert Lobby.objects.get(code=code).settings == STORED  # the row is kept


class TestClampNightTiming:
    def test_where_untimed_nights_are_allowed_only_bad_values_go(self) -> None:
        stored = {**STORED, "voting_seconds": -4, "card_look_seconds": "30"}
        clamped = clamp_night_timing(stored, allow_untimed=True)
        assert clamped == {
            k: v for k, v in STORED.items() if k not in {"voting_seconds"}
        }

    def test_a_night_window_shorter_than_the_floor_grows_to_it(self) -> None:
        clamped = clamp_night_timing(
            {"night_wave_seconds": 3, "night_min_window_seconds": 2},
            allow_untimed=False,
        )
        assert clamped == {"night_wave_seconds": 5, "night_min_window_seconds": 5}

    def test_values_in_range_are_untouched_and_the_input_is_not_changed(self) -> None:
        stored = {"night_wave_seconds": 30, "night_min_window_seconds": 8}
        assert clamp_night_timing(stored, allow_untimed=False) == stored
        assert clamp_night_timing(STORED, allow_untimed=False) is not STORED
        assert STORED["night_wave_seconds"] == 0
