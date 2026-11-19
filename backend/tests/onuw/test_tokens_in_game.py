"""
A game keeps the table identity the lobby had at the deal.

Each ``PlayerRole`` snapshots its member's token and seat (join order) when the
game is dealt, so the players lists and the results stay stable and in seat order
even if someone leaves the lobby later or the game is dealt again.
All through the real API (guests, lobby, start, night, talk, vote, results).
"""

from typing import Any

from django.urls import reverse

import pytest
from rest_framework import status

from apps.core.models import LobbyMember
from apps.onuw.models import PlayerRole
from tests.onuw.test_play_again import Table

pytestmark = pytest.mark.integration


@pytest.fixture
def table(db, settings):
    settings.DEBUG = True  # lets the start endpoint take a fixed seed
    return Table()


def lobby_tokens(table: Table) -> list[str]:
    """Tokens as the lobby shows them, in join order (the seat order)."""
    return [p["token"] for p in table.lobby_body()["players"]]


def me(table: Table, game_id: str, index: int = 0) -> dict[str, Any]:
    url = reverse("onuw:game-me", kwargs={"game_id": game_id})
    response = table.clients[index].get(url)
    assert response.status_code == status.HTTP_200_OK
    return response.data


def seats_of(players: list[dict[str, Any]]) -> list[tuple[int, int, str]]:
    return [(p["seat"], p["player_id"], p["token"]) for p in players]


class TestTheDealSnapshotsTokensAndSeats:
    def test_every_player_role_gets_the_members_token_and_join_order_seat(
        self, table
    ) -> None:
        joined = lobby_tokens(table)
        assert len(set(joined)) == 5

        game_id = table.start().data["game_id"]

        rows = {pr.user_id: pr for pr in PlayerRole.objects.filter(game_id=game_id)}
        assert [rows[uid].seat for uid in table.ids] == [0, 1, 2, 3, 4]
        assert [rows[uid].token for uid in table.ids] == joined

    def test_me_lists_players_in_seat_order_with_token_and_seat(self, table) -> None:
        joined = lobby_tokens(table)
        game_id = table.start().data["game_id"]

        players = me(table, game_id)["players"]

        assert [p["seat"] for p in players] == [0, 1, 2, 3, 4]
        assert [p["player_id"] for p in players] == table.ids
        assert [p["token"] for p in players] == joined

    def test_every_player_sees_the_same_seats_and_tokens(self, table) -> None:
        game_id = table.start().data["game_id"]

        views = [
            seats_of(me(table, game_id, i)["players"]) for i in range(len(table.ids))
        ]

        assert all(view == views[0] for view in views)

    def test_players_list_carries_token_and_seat_in_seat_order(self, table) -> None:
        joined = lobby_tokens(table)
        game_id = table.start().data["game_id"]

        response = table.clients[2].get(
            reverse("onuw:player-list", kwargs={"game_id": game_id})
        )

        players = response.data["players"]
        assert [p["player_id"] for p in players] == table.ids
        assert [p["seat"] for p in players] == [0, 1, 2, 3, 4]
        assert [p["token"] for p in players] == joined
        assert all("connected" in p for p in players)  # existing fields stay

    def test_results_players_carry_token_and_seat_in_seat_order(self, table) -> None:
        joined = lobby_tokens(table)
        game_id = table.play_to_results()

        response = table.clients[3].get(
            reverse("onuw:results", kwargs={"game_id": game_id})
        )

        players = response.data["players"]
        assert [p["player_id"] for p in players] == table.ids
        assert [p["seat"] for p in players] == [0, 1, 2, 3, 4]
        assert [p["token"] for p in players] == joined
        assert {"original_role", "final_role", "vote_target_id"} <= set(players[0])

    def test_the_debug_oracle_reports_tokens_and_seats(self, table) -> None:
        joined = lobby_tokens(table)
        game_id = table.start().data["game_id"]

        state = table.host.get(
            reverse("onuw:debug-state", kwargs={"game_id": game_id})
        ).data

        assert [(p["seat"], p["token"]) for p in state["players"]] == list(
            enumerate(joined)
        )


class TestGamesKeepTheirTokens:
    def test_game_snapshot_tokens_survive_member_leaving(self, table) -> None:
        joined = lobby_tokens(table)
        game_id = table.start().data["game_id"]
        leaver = table.clients[3]  # a non-host may leave while the game runs
        left = leaver.post(reverse("core:lobby-leave", kwargs={"code": table.code}))
        assert left.status_code == status.HTTP_200_OK
        assert not LobbyMember.objects.filter(
            lobby__code=table.code, user_id=table.ids[3]
        ).exists()

        players = me(table, game_id)["players"]

        assert [p["token"] for p in players] == joined
        assert [p["seat"] for p in players] == [0, 1, 2, 3, 4]
        assert [p["token"] for p in table.lobby_body()["players"]] == (
            joined[:3] + joined[4:]
        )

    def test_tokens_stable_across_play_again(self, table) -> None:
        joined = lobby_tokens(table)
        first = table.play_to_results(seed=7)
        assert table.play_again().status_code == status.HTTP_200_OK
        assert lobby_tokens(table) == joined

        second = table.play_to_results(seed=8)

        for game_id in (first, second):
            players = me(table, game_id)["players"]
            assert [p["token"] for p in players] == joined
            assert [p["seat"] for p in players] == [0, 1, 2, 3, 4]

    def test_a_game_dealt_before_seats_lists_by_user_id_with_null_seat(
        self, table
    ) -> None:
        game_id = table.start().data["game_id"]
        PlayerRole.objects.filter(game_id=game_id).update(seat=None, token="")

        players = me(table, game_id)["players"]

        assert [p["player_id"] for p in players] == sorted(table.ids)
        assert all(p["seat"] is None and p["token"] == "" for p in players)
