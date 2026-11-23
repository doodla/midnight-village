"""
The migrations run while the PREVIOUS code is still serving.

That code INSERTs rows without the new columns, so each new NOT NULL column has a
database default; and a member it adds after the token backfill has a blank token,
which the deal fills in. Raw SQL below is the old code's INSERT (the column set
before these migrations; see tests/old_code.py). The old code's member INSERT names
the ready column, which a schema built from the models no longer has, so it runs
only against the real migrations (tests/test_migrations.py).
"""

from django.urls import reverse

import pytest
from rest_framework import status

from apps.core import tokens
from apps.core.models import Lobby, LobbyMember, User
from apps.onuw.models import Game, PlayerRole
from tests.old_code import insert_game, insert_player_role
from tests.onuw.test_play_again import Table

pytestmark = pytest.mark.integration


@pytest.fixture
def lobby_and_user(db):
    user = User.objects.create_user(username="old_code", password="x")
    lobby = Lobby.objects.create(host=user, game_type="onuw")
    return lobby, user


class TestOldCodeInsertsStillWork:
    def test_game_and_player_role_without_the_new_columns(self, lobby_and_user) -> None:
        lobby, user = lobby_and_user

        game_id = insert_game(lobby.pk)
        insert_player_role(game_id, user.pk)

        game = Game.objects.get(pk=game_id)
        pr = PlayerRole.objects.get(game=game)
        assert game.dealt_center_cards == []
        assert (pr.token, pr.seat, pr.phase_ready, pr.night_results_seen) == (
            "",
            None,
            False,
            0,
        )


@pytest.fixture
def table(db, settings):
    settings.DEBUG = True  # fixed seeds and forced assignments
    return Table()


class TestBlankTokensAreFilledAtTheDeal:
    def test_a_member_added_by_old_code_gets_the_next_free_token_at_the_deal(
        self, table
    ) -> None:
        # Two members were seated by code that did not know tokens.
        LobbyMember.objects.filter(
            lobby__code=table.code, user_id__in=[table.ids[1], table.ids[3]]
        ).update(token="")
        kept = {
            m.user_id: m.token
            for m in LobbyMember.objects.filter(lobby__code=table.code).exclude(
                token=""
            )
        }

        game_id = table.start().data["game_id"]

        rows = {pr.user_id: pr for pr in PlayerRole.objects.filter(game_id=game_id)}
        dealt = [rows[uid].token for uid in table.ids]
        assert all(dealt)
        assert len(set(dealt)) == 5
        for uid, token in kept.items():
            assert rows[uid].token == token  # nobody already seated is renamed
        # The lobby shows the same tokens the game snapshotted.
        assert [p["token"] for p in table.lobby_body()["players"]] == dealt

    def test_blank_tokens_are_given_in_join_order_by_the_codes_order(
        self, table
    ) -> None:
        LobbyMember.objects.filter(lobby__code=table.code).update(token="")

        table.start()

        shown = [p["token"] for p in table.lobby_body()["players"]]
        assert shown == tokens.token_order(table.code)[:5]

    def test_serializers_tolerate_a_blank_token_in_an_old_game(self, table) -> None:
        game_id = table.start().data["game_id"]
        PlayerRole.objects.filter(game_id=game_id).update(token="", seat=None)
        LobbyMember.objects.filter(lobby__code=table.code).update(token="")

        me = table.host.get(reverse("onuw:game-me", kwargs={"game_id": game_id}))
        lobby = table.host.get(
            reverse("core:lobby-detail", kwargs={"code": table.code})
        )

        assert me.status_code == lobby.status_code == status.HTTP_200_OK
        assert {p["token"] for p in me.data["players"]} == {""}
        assert {p["token"] for p in lobby.data["players"]} == {""}


class TestDealtCenterIsKept:
    def test_dealt_center_cards_survive_the_night_swaps(self, table) -> None:
        roles = ["Werewolf", "Seer", "Robber", "Drunk", "Insomniac"]
        forced = {
            "player_roles": {
                str(uid): role for uid, role in zip(table.ids, roles, strict=True)
            },
            "center": ["Werewolf", "Villager", "Villager"],
        }
        started = table.host.post(
            reverse("onuw:game-start", kwargs={"code": table.code}),
            {"debug": {"forced_assignment": forced}},
            format="json",
        )
        game_id = started.data["game_id"]
        dealt = Game.objects.get(id=game_id).dealt_center_cards
        assert dealt == ["Werewolf", "Villager", "Villager"]

        # The Drunk does not choose: the server swaps them with a center card.
        stage = table.host.get(
            reverse("onuw:game-me", kwargs={"game_id": game_id})
        ).data["stage"]
        table.host.post(
            reverse("onuw:wave-advance", kwargs={"game_id": game_id}),
            {"stage": stage},
            format="json",
        )

        game = Game.objects.get(id=game_id)
        assert game.center_cards != dealt  # the live center was overwritten
        assert "Drunk" in game.center_cards
        assert game.dealt_center_cards == dealt
        state = table.host.get(
            reverse("onuw:debug-state", kwargs={"game_id": game_id})
        ).data
        assert state["dealt_center_cards"] == dealt
        assert state["center_cards"] == game.center_cards


class TestARefusedDealWritesNothing:
    """Returning an error Response from inside ``transaction.atomic()`` commits what
    was written before it: a start the server refuses must leave the table as it was
    (the blank tokens are filled in only once everything has been validated)."""

    def start(self, table: Table, client=None, body=None):
        return (client or table.host).post(
            reverse("onuw:game-start", kwargs={"code": table.code}),
            body or {},
            format="json",
        )

    @pytest.mark.parametrize(
        "cause",
        ["not_host", "not_waiting", "bad_settings", "bad_assignment", "bad_seed"],
    )
    def test_a_refused_start_changes_nothing(self, table, cause) -> None:
        LobbyMember.objects.filter(lobby__code=table.code).update(token="")
        client, body = table.host, {}
        if cause == "not_host":
            client = table.clients[1]
        elif cause == "not_waiting":
            Lobby.objects.filter(code=table.code).update(status=Lobby.Status.FINISHED)
        elif cause == "bad_settings":
            Lobby.objects.filter(code=table.code).update(
                settings={"roles": {"Seer": 1}}
            )
        elif cause == "bad_assignment":
            body = {"debug": {"forced_assignment": {"player_roles": {}, "center": []}}}
        elif cause == "bad_seed":
            body = {"debug": {"seed": "not a number"}}
        before = list(
            LobbyMember.objects.filter(lobby__code=table.code).values_list(
                "pk", "token"
            )
        )
        status_before = Lobby.objects.get(code=table.code).status

        response = self.start(table, client, body)

        assert 400 <= response.status_code < 500
        assert Game.objects.filter(lobby__code=table.code).count() == 0
        assert Lobby.objects.get(code=table.code).status == status_before
        assert (
            list(
                LobbyMember.objects.filter(lobby__code=table.code).values_list(
                    "pk", "token"
                )
            )
            == before
        )
        assert not any(token for _, token in before)  # tokens still blank

    def test_the_same_start_succeeds_once_the_table_is_valid(self, table) -> None:
        LobbyMember.objects.filter(lobby__code=table.code).update(token="")

        assert self.start(table).status_code == status.HTTP_201_CREATED

        tokens_now = list(
            LobbyMember.objects.filter(lobby__code=table.code).values_list(
                "token", flat=True
            )
        )
        assert all(tokens_now)
