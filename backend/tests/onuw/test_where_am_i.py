"""
"Where am I": ``GET /api/me/table/`` starts from the caller's lobby membership and
asks the game app (through the ``member_game`` hook) about the lobby's newest game.

The old ``current-game`` answer was empty between games (the newest game is in
``results``, or the lobby is waiting with no new game) although the player is
still seated. All through the real API with five guests.
"""

from datetime import timedelta
from typing import Any

from django.urls import reverse
from django.utils import timezone

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.core.models import Lobby
from tests.onuw.test_play_again import Table

pytestmark = pytest.mark.integration


@pytest.fixture
def table(db, settings):
    settings.DEBUG = True  # fixed seeds
    return Table()


def where(client: APIClient) -> dict[str, Any]:
    response = client.get(reverse("core:my-table"))
    assert response.status_code == status.HTTP_200_OK
    return response.data["table"]


def make_stale(code: str, hours: float) -> None:
    # update() skips auto_now, so this really moves the clock back.
    Lobby.objects.filter(code=code).update(
        updated_at=timezone.now() - timedelta(hours=hours)
    )


class TestWhereAmI:
    def test_where_am_i_waiting_lobby_member_gets_table(self, table) -> None:
        member = table.clients[2]
        token = table.lobby_body()["players"][2]["token"]

        assert where(member) == {
            "lobby_code": table.code,
            "game_type": "onuw",
            "status": "waiting",
            "is_host": False,
            "token": token,
            "game": None,
        }
        assert where(table.host)["is_host"] is True

    def test_where_am_i_running_game(self, table) -> None:
        game_id = table.start().data["game_id"]

        for client in table.clients:
            answer = where(client)
            assert answer["status"] == "in_game"
            assert answer["game"] == {"game_id": game_id, "phase": "night"}

    def test_where_am_i_after_results_before_play_again_gets_results_game(
        self, table
    ) -> None:
        game_id = table.play_to_results()

        # The old endpoint has nothing for them: this is the bug.
        assert table.current_game(1) == {"game": None}
        for client in table.clients:
            answer = where(client)
            assert answer["status"] == "finished"
            assert answer["game"] == {"game_id": game_id, "phase": "results"}

    def test_where_am_i_after_play_again_gets_waiting_lobby(self, table) -> None:
        game_id = table.play_to_results()
        table.play_again()

        answer = where(table.clients[3])

        # A waiting lobby: the client routes to it (the game is only the old one).
        assert answer["status"] == "waiting"
        assert answer["game"] == {"game_id": game_id, "phase": "results"}

    def test_a_newcomer_to_a_replayed_table_has_no_game_of_their_own(
        self, table
    ) -> None:
        table.play_to_results()
        table.play_again()
        # A fresh guest, not part of the first game.
        guest = APIClient()
        response = guest.post(reverse("core:guest-create"), {}, format="json")
        guest.credentials(HTTP_AUTHORIZATION=f"Bearer {response.data['access']}")
        guest.post(reverse("core:lobby-join", kwargs={"code": table.code}))

        answer = where(guest)

        assert answer["status"] == "waiting"
        assert answer["lobby_code"] == table.code
        assert answer["game"] is None  # the newest game is not theirs

    def test_where_am_i_after_leave_is_null(self, table) -> None:
        leaver = table.clients[4]
        assert where(leaver) is not None

        leaver.post(reverse("core:lobby-leave", kwargs={"code": table.code}))

        assert leaver.get(reverse("core:my-table")).data == {"table": None}

    def test_where_am_i_for_someone_in_no_lobby_is_null(self, db) -> None:
        guest = APIClient()
        response = guest.post(reverse("core:guest-create"), {}, format="json")
        guest.credentials(HTTP_AUTHORIZATION=f"Bearer {response.data['access']}")

        assert guest.get(reverse("core:my-table")).data == {"table": None}

    def test_where_am_i_needs_a_login(self, db) -> None:
        response = APIClient().get(reverse("core:my-table"))

        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    def test_where_am_i_ignores_stale_table(self, table, settings) -> None:
        table.play_to_results()
        make_stale(table.code, hours=13)  # older than the default 12 h

        assert table.clients[1].get(reverse("core:my-table")).data == {"table": None}

        settings.CORE_TABLE_RESUME_HOURS = 14  # the window is a setting
        assert where(table.clients[1])["status"] == "finished"

    def test_an_abandoned_running_game_stops_pulling_players_back(self, table) -> None:
        table.start()
        make_stale(table.code, hours=30)  # nothing happened for 30 hours

        assert table.clients[1].get(reverse("core:my-table")).data == {"table": None}

    def test_what_happens_at_the_table_is_activity(self, table) -> None:
        """Counted from the last real activity, not from creation: a queryset
        update (finishing the game) and joining or leaving must bump it too."""
        game_id = table.start().data["game_id"]
        make_stale(table.code, hours=30)
        assert table.clients[1].get(reverse("core:my-table")).data == {"table": None}

        table.finish_game(game_id)  # the game ends: finished is a fresh activity

        assert where(table.clients[1])["status"] == "finished"

    def test_a_join_or_a_leave_is_activity(self, table) -> None:
        make_stale(table.code, hours=30)
        assert table.host.get(reverse("core:my-table")).data == {"table": None}

        table.clients[4].post(reverse("core:lobby-leave", kwargs={"code": table.code}))

        assert where(table.host)["lobby_code"] == table.code
        make_stale(table.code, hours=30)
        guest = APIClient()
        response = guest.post(reverse("core:guest-create"), {}, format="json")
        guest.credentials(HTTP_AUTHORIZATION=f"Bearer {response.data['access']}")
        guest.post(reverse("core:lobby-join", kwargs={"code": table.code}))
        assert where(table.host)["lobby_code"] == table.code
        assert where(guest)["lobby_code"] == table.code

    def test_where_am_i_picks_newest_membership(self, table) -> None:
        # Player 0 hosts the first table (in a game, so it does not hold them: one
        # WAITING table at a time) and later sits down at a second one.
        second = Table(players=3)
        Lobby.objects.filter(code=table.code).update(status=Lobby.Status.IN_GAME)
        guest = table.host
        response = guest.post(reverse("core:lobby-join", kwargs={"code": second.code}))
        assert response.status_code == status.HTTP_200_OK

        assert where(guest)["lobby_code"] == second.code

        # And back: leaving the newer table falls back to the older one.
        guest.post(reverse("core:lobby-leave", kwargs={"code": second.code}))
        assert where(guest)["lobby_code"] == table.code
