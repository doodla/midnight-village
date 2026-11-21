"""
Player tokens: a table identity handed out when someone sits down.

Each lobby deals its ten tokens in an order seeded by its code; a member takes the
first token nobody at the table holds. Everything here goes through the lobby API.
"""

import random
import threading
from unittest.mock import patch

from django.db import connections
from django.urls import reverse

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.core import tokens
from apps.core.models import Lobby, LobbyMember, User

pytestmark = pytest.mark.integration

EXPECTED_TOKENS = {
    "crow",
    "key",
    "moth",
    "bell",
    "thorn",
    "antler",
    "hare",
    "lantern",
    "spindle",
    "scythe",
}


def sitter(name: str) -> tuple[User, APIClient]:
    user = User.objects.create_user(username=name, password="pass")
    client = APIClient()
    client.force_authenticate(user=user)
    return user, client


def open_table(host_client: APIClient, **body) -> str:
    response = host_client.post(
        reverse("core:lobby-list"), {"game_type": "onuw", **body}, format="json"
    )
    assert response.status_code == status.HTTP_201_CREATED, response.data
    return response.data["code"]


def join(client: APIClient, code: str):
    return client.post(reverse("core:lobby-join", kwargs={"code": code}))


def leave(client: APIClient, code: str):
    return client.post(reverse("core:lobby-leave", kwargs={"code": code}))


def tokens_in_join_order(client: APIClient, code: str) -> list[str]:
    body = client.get(reverse("core:lobby-detail", kwargs={"code": code})).data
    return [p["token"] for p in body["players"]]


def seat_everyone(count: int, prefix: str = "p", **body) -> tuple[str, list[APIClient]]:
    clients = [sitter(f"{prefix}{i}")[1] for i in range(count)]
    code = open_table(clients[0], **body)
    for client in clients[1:]:
        assert join(client, code).status_code == status.HTTP_200_OK
    return code, clients


class TestEachMemberGetsAToken:
    def test_each_member_gets_distinct_token(self, db) -> None:
        code, clients = seat_everyone(10)

        seats = tokens_in_join_order(clients[0], code)

        assert len(seats) == 10
        assert set(seats) == EXPECTED_TOKENS

    def test_the_host_has_a_token_in_create_and_join_responses(self, db) -> None:
        _, host = sitter("host")
        created = host.post(
            reverse("core:lobby-list"), {"game_type": "onuw"}, format="json"
        )
        _, guest = sitter("guest")
        joined = join(guest, created.data["code"])

        assert [p["token"] for p in created.data["players"]] != [""]
        assert (
            joined.data["players"][0]["token"] == (created.data["players"][0]["token"])
        )
        assert all(p["token"] in EXPECTED_TOKENS for p in joined.data["players"])

    def test_token_assignment_deterministic_for_same_code_and_join_order(
        self, db
    ) -> None:
        def run_table(code: str, prefix: str) -> list[str]:
            with patch("apps.core.models.generate_lobby_code", return_value=code):
                clients = [sitter(f"{prefix}{i}")[1] for i in range(4)]
                open_table(clients[0])
            for client in clients[1:]:
                join(client, code)
            seated = tokens_in_join_order(clients[0], code)
            Lobby.objects.filter(code=code).delete()
            return seated

        first = run_table("DET234", "a")
        again = run_table("DET234", "b")
        other = run_table("OTH567", "c")

        # The code alone fixes the order: its seeded permutation of the ten tokens.
        rng = random.Random("DET234:tokens")  # noqa: S311
        permutation = rng.sample(tokens.TOKENS, 10)
        assert first == again == permutation[:4]
        assert other != first

    def test_different_codes_deal_tokens_in_different_orders(self) -> None:
        orders = {tuple(tokens.token_order(code)) for code in ("AAA111", "BBB222")}
        assert len(orders) == 2
        assert all(set(order) == EXPECTED_TOKENS for order in orders)

    def test_a_joiner_takes_the_first_token_in_the_codes_order(self, db) -> None:
        code, clients = seat_everyone(3)

        assert tokens_in_join_order(clients[0], code) == tokens.token_order(code)[:3]


class TestTokensAreFreedOnLeave:
    def test_token_freed_on_leave_and_reused(self, db) -> None:
        code, clients = seat_everyone(4)
        before = tokens_in_join_order(clients[0], code)
        assert leave(clients[2], code).status_code == status.HTTP_200_OK

        assert tokens_in_join_order(clients[0], code) == [
            before[0],
            before[1],
            before[3],
        ]

        _, newcomer = sitter("newcomer")
        assert join(newcomer, code).status_code == status.HTTP_200_OK

        # The freed token is the first free one in the code's order again.
        assert tokens_in_join_order(clients[0], code) == [
            before[0],
            before[1],
            before[3],
            before[2],
        ]


class TestCapacity:
    def test_max_players_over_10_rejected(self, db) -> None:
        _, host = sitter("host")

        response = host.post(
            reverse("core:lobby-list"),
            {"game_type": "onuw", "max_players": 11},
            format="json",
        )

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "max_players" in response.data["error"]["detail"]
        assert Lobby.objects.count() == 0

    @pytest.mark.parametrize("bad", [0, -1])
    def test_max_players_must_be_positive(self, db, bad) -> None:
        _, host = sitter("host")

        response = host.post(
            reverse("core:lobby-list"),
            {"game_type": "onuw", "max_players": bad},
            format="json",
        )

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "max_players" in response.data["error"]["detail"]

    @pytest.mark.parametrize("ok", [2, 3, 10])
    def test_max_players_up_to_the_token_count_is_accepted(self, db, ok) -> None:
        """Core only caps at the number of tokens; the game checks its own minimum
        when it deals (see the start tests)."""
        _, host = sitter("host")

        response = host.post(
            reverse("core:lobby-list"),
            {"game_type": "onuw", "max_players": ok},
            format="json",
        )

        assert response.status_code == status.HTTP_201_CREATED
        assert response.data["max_players"] == ok

    def test_the_game_refuses_to_deal_a_table_that_is_too_small(self, db) -> None:
        code, clients = seat_everyone(2, max_players=2)

        response = clients[0].post(reverse("onuw:game-start", kwargs={"code": code}))

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert any("At least 3 players" in error for error in response.data["detail"])

    def test_the_table_limit_has_one_home(self) -> None:
        assert tokens.MAX_TABLE_SIZE == len(tokens.TOKENS) == 10

    def test_a_full_table_refuses_the_next_player_with_a_machine_code(self, db) -> None:
        code, _ = seat_everyone(3, max_players=3)
        _, late = sitter("late")

        response = join(late, code)

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data == {"detail": "Lobby is full.", "code": "lobby_full"}
        assert LobbyMember.objects.filter(lobby__code=code).count() == 3

    def test_a_legacy_lobby_over_ten_never_runs_out_of_tokens_into_blanks(
        self, db
    ) -> None:
        """max_players above 10 existed before the cap: the 11th is refused, not
        seated with a blank (or duplicate) token."""
        users = [sitter(f"big{i}")[0] for i in range(12)]
        lobby = Lobby.objects.create(host=users[0], game_type="onuw", max_players=12)
        for user, token in zip(users[:10], tokens.token_order(lobby.code), strict=True):
            LobbyMember.objects.create(lobby=lobby, user=user, token=token)
        late = APIClient()
        late.force_authenticate(user=users[10])

        response = join(late, lobby.code)

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["code"] == "lobby_full"

    @pytest.mark.django_db(transaction=True)
    def test_concurrent_joins_get_distinct_tokens_and_respect_capacity(self) -> None:
        capacity, joiners = 5, 9
        users = [sitter(f"race{i}")[0] for i in range(joiners + 1)]
        host = APIClient()
        host.force_authenticate(user=users[0])
        code = open_table(host, max_players=capacity)
        barrier = threading.Barrier(joiners)
        outcomes: list[tuple[int, str | None]] = []

        def tap(user: User) -> None:
            try:
                client = APIClient()
                client.force_authenticate(user=user)
                barrier.wait(timeout=10)
                response = join(client, code)
                outcomes.append((response.status_code, response.data.get("code")))
            finally:
                connections.close_all()

        threads = [threading.Thread(target=tap, args=(u,)) for u in users[1:]]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=30)

        accepted = [o for o in outcomes if o[0] == status.HTTP_200_OK]
        refused = [o for o in outcomes if o[0] == status.HTTP_400_BAD_REQUEST]
        assert len(outcomes) == joiners
        assert len(accepted) == capacity - 1  # the host already holds one seat
        assert refused and all(code == "lobby_full" for _, code in refused)
        seated = list(LobbyMember.objects.filter(lobby__code=code))
        assert len(seated) == capacity
        assert len({m.token for m in seated}) == capacity
        assert all(m.token in EXPECTED_TOKENS for m in seated)


class TestJoinRefusalsCarryACode:
    def test_every_refusal_has_a_machine_code_and_keeps_its_status(self, db) -> None:
        code, clients = seat_everyone(3, max_players=3)
        _, outsider = sitter("outsider")

        unknown = join(outsider, "ZZZZZZ")
        again = join(clients[1], code)
        full = join(outsider, code)

        assert (unknown.status_code, unknown.data["code"]) == (404, "lobby_not_found")
        assert (again.status_code, again.data["code"]) == (400, "already_in_lobby")
        assert (full.status_code, full.data["code"]) == (400, "lobby_full")
        assert all(r.data["detail"] for r in (unknown, again, full))

    def test_a_lobby_in_a_game_is_closed(self, db) -> None:
        code, _ = seat_everyone(3)
        Lobby.objects.filter(code=code).update(status=Lobby.Status.IN_GAME)
        _, outsider = sitter("outsider")

        response = join(outsider, code)

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["code"] == "lobby_closed"
