"""
Rows this code writes are read right by the code before the protocol-1 cleanup.

During a deploy the previous code keeps serving for a moment, on the same database,
while this code already creates tables and deals games. The previous code read a
table or game without ``night_protocol: 2`` as the old night: a look stage refused
on every lobby change, a deal refused until everyone tapped ready, a ``/me/``
without a ``stage``. So this code still writes the flag (it ignores it itself) on a
table the app opens and on every game it deals. ``tests/old_code.py`` holds the old
read rules, frozen; these tests run them on rows written through this code's API.
"""

from typing import Any

from django.urls import reverse

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.core.models import Lobby
from apps.onuw.models import Game
from tests import old_code

pytestmark = pytest.mark.django_db

DECK = {"Werewolf": 2, "Seer": 1, "Robber": 1, "Troublemaker": 1, "Villager": 3}
# What the app writes on 03: a pace and a chip (the deck stays automatic).
APP_PATCHES: list[dict[str, Any]] = [
    {"deck": "auto", "deck_chip": "classic"},
    {"discussion_seconds": 300, "voting_seconds": 90, "night_wave_seconds": 30},
    {"pace": "normal"},
]


def _guest() -> APIClient:
    client = APIClient()
    answer = client.post(reverse("core:guest-create"), {}, format="json")
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {answer.data['access']}")
    return client


def _table(body: dict[str, Any], players: int = 5) -> tuple[str, APIClient]:
    """A table of ``players`` opened by this code's API with ``body``."""
    clients = [_guest() for _ in range(players)]
    host = clients[0]
    answer = host.post(reverse("core:lobby-list"), body, format="json")
    assert answer.status_code == status.HTTP_201_CREATED, answer.data
    code = answer.data["code"]
    for client in clients[1:]:
        client.post(reverse("core:lobby-join", kwargs={"code": code}))
    return code, host


def _deal(code: str, host: APIClient) -> Game:
    answer = host.post(
        reverse("onuw:game-start", kwargs={"code": code}),
        {"debug": {"seed": 7}},
        format="json",
    )
    assert answer.status_code == status.HTTP_201_CREATED, answer.data
    return Game.objects.get(id=answer.data["game_id"])


def _old_code_plays_the_choose_night(stored: Any, *, allow_untimed: bool) -> None:
    assert old_code.reads_as_choose_night(stored)
    assert not old_code.deal_needs_everyone_ready(stored)
    assert old_code.night_protocol_errors(stored, allow_untimed=allow_untimed) == []


class TestATableTheAppOpens:
    @pytest.mark.parametrize("untimed", [True, False], ids=["untimed_ok", "timed"])
    def test_old_code_reads_it_as_the_choose_night_after_every_change_the_app_makes(
        self, settings, untimed
    ) -> None:
        settings.ONUW_ALLOW_UNTIMED_NIGHT = untimed
        code, host = _table({"game_type": "onuw", "defaults": "v2"})

        stored = Lobby.objects.get(code=code).settings
        _old_code_plays_the_choose_night(stored, allow_untimed=untimed)
        assert stored["night_protocol"] == 2
        for patch in APP_PATCHES:
            answer = host.patch(
                reverse("core:lobby-detail", kwargs={"code": code}),
                {"settings": patch},
                format="json",
            )
            assert answer.status_code == status.HTTP_200_OK, answer.data
            _old_code_plays_the_choose_night(
                Lobby.objects.get(code=code).settings, allow_untimed=untimed
            )


class TestEveryGameThisCodeDeals:
    @pytest.mark.parametrize(
        "stored_flag",
        [None, 1, 2],
        ids=["table_without_the_flag", "table_older_code_wrote_as_1", "flag_2"],
    )
    def test_old_code_reads_the_game_as_the_choose_night(
        self, settings, stored_flag
    ) -> None:
        settings.DEBUG = True
        code, host = _table(
            {"game_type": "onuw", "settings": {"roles": DECK, "card_look_seconds": 0}}
        )
        lobby = Lobby.objects.get(code=code)
        stored = {k: v for k, v in lobby.settings.items() if k != "night_protocol"}
        if stored_flag is not None:
            stored["night_protocol"] = stored_flag
        Lobby.objects.filter(code=code).update(settings=stored)

        game = _deal(code, host)

        _old_code_plays_the_choose_night(game.settings, allow_untimed=True)
        assert game.settings["night_protocol"] == 2
        # The lobby row is left as it was: only the game is this code's.
        assert Lobby.objects.get(code=code).settings == stored

    def test_a_game_dealt_from_an_app_table_too(self, settings) -> None:
        settings.DEBUG = True
        code, host = _table({"game_type": "onuw", "defaults": "v2"})

        game = _deal(code, host)

        _old_code_plays_the_choose_night(game.settings, allow_untimed=True)
