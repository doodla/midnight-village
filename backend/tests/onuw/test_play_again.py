"""
Play again: one table, several games.

``Game.lobby`` is a foreign key, so a lobby can hold a game after a game; its
current game is its newest. The host's "play again" reopens a finished table
with the same members and the same deck so the next hand can be dealt at once.
All through the real API (guests, lobby, start, night, talk, vote, results).
"""

import asyncio
from typing import Any
from unittest.mock import patch

from django.test import TransactionTestCase
from django.urls import reverse

import pytest
from asgiref.sync import sync_to_async
from channels.db import database_sync_to_async
from channels.testing import WebsocketCommunicator
from rest_framework import status
from rest_framework.test import APIClient

from apps.core.consumers import LobbyConsumer
from apps.core.lobbies import play_again
from apps.core.models import Lobby, LobbyMember
from apps.onuw import services
from apps.onuw.consumers import GameConsumer
from apps.onuw.models import Game, Phase

pytestmark = pytest.mark.integration

# 5 players + 3 centre cards. No Doppelganger: the night is one window the host closes.
DECK = {
    "Werewolf": 2,
    "Seer": 1,
    "Robber": 1,
    "Villager": 2,
    "Drunk": 1,
    "Insomniac": 1,
}
TIMERS_OFF = {
    "night_wave_seconds": 0,
    "night_min_window_seconds": 0,
    "night_doppelganger_window_seconds": 0,
    "discussion_seconds": 0,
    "voting_seconds": 0,
}


class Table:
    """A lobby of guests driven through the public API."""

    def __init__(self, players: int = 5, deck: dict[str, int] | None = None) -> None:
        self.clients: list[APIClient] = []
        self.ids: list[int] = []
        for _ in range(players):
            client = APIClient()
            response = client.post(reverse("core:guest-create"), {}, format="json")
            client.credentials(HTTP_AUTHORIZATION=f"Bearer {response.data['access']}")
            self.clients.append(client)
            self.ids.append(response.data["user"]["id"])
        self.host = self.clients[0]
        self.deck = deck or DECK
        response = self.host.post(
            reverse("core:lobby-list"),
            {"game_type": "onuw", "settings": {"roles": self.deck, **TIMERS_OFF}},
            format="json",
        )
        self.code = response.data["code"]
        for client in self.clients[1:]:
            client.post(reverse("core:lobby-join", kwargs={"code": self.code}))
        for client in self.clients:
            client.post(
                reverse("core:lobby-ready", kwargs={"code": self.code}),
                {"is_ready": True},
                format="json",
            )

    # -- the lobby ---------------------------------------------------------

    def lobby(self) -> Lobby:
        return Lobby.objects.get(code=self.code)

    def lobby_body(self) -> dict[str, Any]:
        return self.host.get(
            reverse("core:lobby-detail", kwargs={"code": self.code})
        ).data

    def play_again(self, client: APIClient | None = None, *, onuw_url: bool = False):
        name = "onuw:lobby-play-again" if onuw_url else "core:lobby-play-again"
        return (client or self.host).post(reverse(name, kwargs={"code": self.code}))

    def current_game(self, index: int = 0) -> dict[str, Any]:
        return self.clients[index].get(reverse("onuw:current-game")).data

    # -- one game ----------------------------------------------------------

    def start(self, seed: int = 7):
        return self.host.post(
            reverse("onuw:game-start", kwargs={"code": self.code}),
            {"debug": {"seed": seed}},
            format="json",
        )

    def play_to_results(self, seed: int = 7) -> str:
        """Deal, close the night, end the talk, everyone votes, results."""
        response = self.start(seed)
        assert response.status_code == status.HTTP_201_CREATED, response.data
        game_id = response.data["game_id"]
        kw = {"game_id": game_id}
        assert (
            self.host.post(reverse("onuw:wave-advance", kwargs=kw)).status_code == 200
        )
        assert (
            self.host.post(reverse("onuw:end-discussion", kwargs=kw)).status_code == 200
        )
        for i, client in enumerate(self.clients):
            target = self.ids[(i + 1) % len(self.ids)]
            reply = client.post(
                reverse("onuw:vote", kwargs=kw),
                {"target_player_id": target},
                format="json",
            )
            assert reply.status_code == status.HTTP_200_OK
        assert Game.objects.get(id=game_id).phase == Phase.RESULTS
        return game_id


@pytest.fixture
def table(db, settings):
    settings.DEBUG = True  # lets the start endpoint take a fixed seed
    return Table()


class TestTwoGamesOnOneLobby:
    def test_two_full_games_in_a_row_with_the_same_players(self, table) -> None:
        first = table.play_to_results(seed=7)
        assert table.lobby().status == Lobby.Status.FINISHED

        response = table.play_again()
        assert response.status_code == status.HTTP_200_OK
        assert response.data["status"] == "waiting"

        second = table.play_to_results(seed=8)

        assert first != second
        lobby = table.lobby()
        assert lobby.games.count() == 2
        assert lobby.status == Lobby.Status.FINISHED
        # Same members, both games.
        member_ids = set(
            LobbyMember.objects.filter(lobby=lobby).values_list("user_id", flat=True)
        )
        assert member_ids == set(table.ids)
        for game_id in (first, second):
            assert set(
                Game.objects.get(id=game_id).player_roles.values_list(
                    "user_id", flat=True
                )
            ) == set(table.ids)
        # The deck is the same.
        assert Game.objects.get(id=first).settings["roles"] == DECK
        assert Game.objects.get(id=second).settings["roles"] == DECK

    def test_a_third_game_works_too(self, table) -> None:
        table.play_to_results(seed=1)
        table.play_again()
        table.play_to_results(seed=2)
        assert table.play_again().status_code == status.HTTP_200_OK
        table.play_to_results(seed=3)
        assert table.lobby().games.count() == 3

    def test_results_of_game_one_stay_readable_after_game_two_starts(
        self, table
    ) -> None:
        first = table.play_to_results(seed=7)
        before = [
            c.get(reverse("onuw:results", kwargs={"game_id": first})).data
            for c in table.clients
        ]
        table.play_again()
        second = table.start(seed=8).data["game_id"]

        assert Game.objects.get(id=second).phase == Phase.NIGHT
        for client, earlier in zip(table.clients, before, strict=True):
            now = client.get(reverse("onuw:results", kwargs={"game_id": first}))
            assert now.status_code == status.HTTP_200_OK
            assert now.data == earlier
            me = client.get(reverse("onuw:game-me", kwargs={"game_id": first}))
            assert me.status_code == status.HTTP_200_OK
            assert me.data["phase"] == "results"
        # Game two's results are not available yet.
        not_yet = table.clients[0].get(
            reverse("onuw:results", kwargs={"game_id": second})
        )
        assert not_yet.status_code == status.HTTP_403_FORBIDDEN

    def test_the_lobbys_current_game_is_its_newest(self, table) -> None:
        first = table.play_to_results(seed=7)
        table.play_again()
        second = table.start(seed=8).data["game_id"]

        assert str(services.latest_game(table.lobby()).id) == second
        assert second != first

    def test_a_second_game_deals_a_fresh_hand(self, table) -> None:
        table.play_to_results(seed=7)
        table.play_again()
        game_id = table.start(seed=8).data["game_id"]

        me = table.clients[0].get(reverse("onuw:game-me", kwargs={"game_id": game_id}))
        assert me.data["phase"] == "night"
        assert me.data["night_results"] == []
        assert me.data["has_voted"] is False
        assert (
            Game.objects.get(id=game_id).player_roles.filter(has_acted=True).count()
            == 0
        )


class TestPlayAgainRules:
    def test_non_host_is_refused_and_nothing_changes(self, table) -> None:
        table.play_to_results()

        response = table.play_again(table.clients[1])

        assert response.status_code == status.HTTP_403_FORBIDDEN
        assert table.lobby().status == Lobby.Status.FINISHED

    def test_refused_while_a_game_is_still_running(self, table) -> None:
        table.start()

        response = table.play_again()

        assert response.status_code == status.HTTP_409_CONFLICT
        assert table.lobby().status == Lobby.Status.IN_GAME

    @pytest.mark.parametrize("phase", [Phase.DISCUSSION, Phase.VOTING])
    def test_refused_in_every_phase_before_the_results(self, table, phase: str) -> None:
        game_id = table.start().data["game_id"]
        Game.objects.filter(id=game_id).update(phase=phase)

        assert table.play_again().status_code == status.HTTP_409_CONFLICT

    def test_refused_before_any_game_was_played(self, table) -> None:
        assert table.play_again().status_code == status.HTTP_409_CONFLICT

    def test_refused_while_the_second_game_is_running(self, table) -> None:
        table.play_to_results(seed=7)
        table.play_again()
        table.start(seed=8)

        assert table.play_again().status_code == status.HTTP_409_CONFLICT

    def test_unknown_lobby_is_404(self, table) -> None:
        response = table.host.post(
            reverse("core:lobby-play-again", kwargs={"code": "ZZZZZZ"})
        )
        assert response.status_code == status.HTTP_404_NOT_FOUND

    def test_a_stranger_is_refused(self, table) -> None:
        table.play_to_results()
        stranger = APIClient()
        token = stranger.post(reverse("core:guest-create"), {}, format="json").data[
            "access"
        ]
        stranger.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

        assert table.play_again(stranger).status_code == status.HTTP_403_FORBIDDEN

    def test_login_is_required(self, table) -> None:
        response = APIClient().post(
            reverse("core:lobby-play-again", kwargs={"code": table.code})
        )
        assert response.status_code in (401, 403)

    def test_both_url_prefixes_reach_the_same_view(self, table) -> None:
        assert (
            reverse("core:lobby-play-again", kwargs={"code": "ABC123"})
            == "/api/lobbies/ABC123/play-again/"
        )
        assert (
            reverse("onuw:lobby-play-again", kwargs={"code": "ABC123"})
            == "/api/onuw/lobbies/ABC123/play-again/"
        )
        table.play_to_results()
        assert table.play_again(onuw_url=True).status_code == status.HTTP_200_OK

    def test_response_is_the_lobby_detail_body(self, table) -> None:
        table.play_to_results()

        response = table.play_again()

        assert response.status_code == status.HTTP_200_OK
        assert response.data == table.lobby_body()
        assert response.data["status"] == "waiting"
        assert response.data["settings"]["roles"] == DECK
        assert {p["user"]["id"] for p in response.data["players"]} == set(table.ids)

    def test_everyone_is_ready_so_the_host_can_deal_straight_away(self, table) -> None:
        table.play_to_results()
        # Someone un-readied before the game ended; the table is reopened ready.
        LobbyMember.objects.filter(lobby=table.lobby(), user_id=table.ids[2]).update(
            is_ready=False
        )

        response = table.play_again()

        assert all(p["is_ready"] for p in response.data["players"])
        assert table.start(seed=9).status_code == status.HTTP_201_CREATED

    def test_a_double_tap_is_harmless(self, table) -> None:
        table.play_to_results()
        assert table.play_again().status_code == status.HTTP_200_OK

        again = table.play_again()

        assert again.status_code == status.HTTP_200_OK
        assert table.lobby().games.count() == 1  # nothing dealt by it

    def test_the_host_can_still_not_start_a_second_game_without_play_again(
        self, table
    ) -> None:
        table.play_to_results()

        assert table.start(seed=8).status_code == status.HTTP_400_BAD_REQUEST


class TestCurrentGameLookup:
    def test_nobody_is_sent_back_into_the_finished_game(self, table) -> None:
        table.play_to_results()
        assert table.current_game() == {"game": None}

        table.play_again()

        for i in range(len(table.clients)):
            assert table.current_game(i) == {"game": None}

    def test_the_new_game_is_the_current_one_once_it_starts(self, table) -> None:
        first = table.play_to_results(seed=7)
        table.play_again()
        second = table.start(seed=8).data["game_id"]

        current = table.current_game(1)

        assert current["game_id"] == second
        assert current["game_id"] != first
        assert current["lobby_code"] == table.code
        assert current["phase"] == "night"


class TestBetweenGames:
    def test_a_player_can_leave_while_the_table_waits_between_games(
        self, table
    ) -> None:
        table.play_to_results()
        table.play_again()

        left = table.clients[4].post(
            reverse("core:lobby-leave", kwargs={"code": table.code})
        )

        assert left.status_code == status.HTTP_200_OK
        assert LobbyMember.objects.filter(lobby=table.lobby()).count() == 4
        # The deck no longer fits four players: the host must adjust it first,
        # as at any table, and then deals the new hand.
        stale = table.start(seed=8)
        assert stale.status_code == status.HTTP_400_BAD_REQUEST
        four_player_deck = {
            "Werewolf": 2,
            "Seer": 1,
            "Robber": 1,
            "Villager": 2,
            "Drunk": 1,
        }
        patched = table.host.patch(
            reverse("core:lobby-detail", kwargs={"code": table.code}),
            {"settings": {"roles": four_player_deck, **TIMERS_OFF}},
            format="json",
        )
        assert patched.status_code == status.HTTP_200_OK
        for client in table.clients[:4]:
            client.post(
                reverse("core:lobby-ready", kwargs={"code": table.code}),
                {"is_ready": True},
                format="json",
            )
        second = table.start(seed=8)
        assert second.status_code == status.HTTP_201_CREATED
        game = Game.objects.get(id=second.data["game_id"])
        assert game.player_roles.count() == 4
        # The first game, with five players, is intact.
        assert Game.objects.filter(lobby=table.lobby()).count() == 2

    def test_a_new_player_can_join_the_waiting_table(self, table) -> None:
        table.play_to_results()
        table.play_again()
        newcomer = APIClient()
        token = newcomer.post(reverse("core:guest-create"), {}, format="json").data[
            "access"
        ]
        newcomer.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")

        joined = newcomer.post(reverse("core:lobby-join", kwargs={"code": table.code}))

        assert joined.status_code == status.HTTP_200_OK

    def test_the_host_leaving_between_games_hands_the_table_to_the_next_member(
        self, table
    ) -> None:
        table.play_to_results()
        table.play_again()

        left = table.host.post(reverse("core:lobby-leave", kwargs={"code": table.code}))

        assert left.status_code == status.HTTP_200_OK
        lobby = table.lobby()  # the table survives
        assert lobby.host_id == table.ids[1]  # next in join order
        assert lobby.acting_host_id is None

    def test_the_host_cannot_leave_while_the_second_game_runs(self, table) -> None:
        table.play_to_results()
        table.play_again()
        table.start(seed=8)

        left = table.host.post(reverse("core:lobby-leave", kwargs={"code": table.code}))

        assert left.status_code == status.HTTP_409_CONFLICT


class TestBroadcasts:
    def test_old_game_group_and_lobby_group_are_told_after_commit(
        self, table, django_capture_on_commit_callbacks
    ) -> None:
        game_id = table.play_to_results()
        sent: list[tuple[str, dict[str, Any]]] = []
        layer = type("L", (), {"group_send": lambda self, g, e: sent.append((g, e))})()

        with (
            patch("apps.core.effects.get_channel_layer", return_value=layer),
            patch("apps.core.effects.async_to_sync", side_effect=lambda f: f),
        ):
            with django_capture_on_commit_callbacks(execute=False) as callbacks:
                assert table.play_again().status_code == status.HTTP_200_OK
            assert sent == []  # nothing goes out before the commit
            for callback in callbacks:
                callback()

        by_group = dict(sent)
        assert by_group[f"game_{game_id}"] == {
            "type": "play.again",
            "lobby_code": table.code,
        }
        update = by_group[f"lobby_{table.code}"]
        assert update["type"] == "lobby.update"
        assert update["data"]["status"] == "waiting"
        assert len(sent) == 2

    def test_nothing_is_sent_when_it_is_refused(
        self, table, django_capture_on_commit_callbacks
    ) -> None:
        table.start()
        sent: list[Any] = []
        layer = type("L", (), {"group_send": lambda self, g, e: sent.append((g, e))})()

        with (
            patch("apps.core.effects.get_channel_layer", return_value=layer),
            patch("apps.core.effects.async_to_sync", side_effect=lambda f: f),
            django_capture_on_commit_callbacks(execute=True),
        ):
            assert table.play_again().status_code == status.HTTP_409_CONFLICT
            assert (
                table.play_again(table.clients[1]).status_code
                == status.HTTP_403_FORBIDDEN
            )

        assert sent == []


@database_sync_to_async
def _finished_table():
    from django.contrib.auth import get_user_model

    user_model = get_user_model()
    host = user_model.objects.create_user(username="pa_host", password="x")
    other = user_model.objects.create_user(username="pa_other", password="x")
    lobby = Lobby.objects.create(
        host=host,
        game_type="onuw",
        status=Lobby.Status.FINISHED,
        settings={"roles": {}},
    )
    game = Game.objects.create(
        lobby=lobby, phase=Phase.RESULTS, random_seed=1, settings={}, center_cards=[]
    )
    for user in (host, other):
        LobbyMember.objects.create(lobby=lobby, user=user)
        game.player_roles.create(
            user=user, original_role="Villager", current_role="Villager"
        )
    return lobby, game, host, other


class TestClientsHearIt(TransactionTestCase):
    @pytest.mark.asyncio
    async def test_game_socket_gets_play_again_and_lobby_socket_gets_the_lobby(self):
        lobby, game, host, other = await _finished_table()

        game_ws = WebsocketCommunicator(GameConsumer.as_asgi(), f"/ws/game/{game.id}/")
        game_ws.scope["user"] = other
        game_ws.scope["url_route"] = {"kwargs": {"game_id": str(game.id)}}
        lobby_ws = WebsocketCommunicator(
            LobbyConsumer.as_asgi(), f"/ws/lobby/{lobby.code}/"
        )
        lobby_ws.scope["user"] = other
        lobby_ws.scope["url_route"] = {"kwargs": {"code": lobby.code}}
        assert (await game_ws.connect())[0]
        assert (await lobby_ws.connect())[0]
        await game_ws.receive_json_from(timeout=2)  # its own presence

        await sync_to_async(play_again)(lobby.code, host.id)

        assert await game_ws.receive_json_from(timeout=2) == {
            "type": "play_again",
            "lobby_code": lobby.code,
        }
        update = await asyncio.wait_for(lobby_ws.receive_json_from(), timeout=2)
        assert update["type"] == "lobby_update"
        assert update["data"]["status"] == "waiting"
        await game_ws.disconnect()
        await lobby_ws.disconnect()


class TestMeCarriesTheLobbyCode:
    """The results screen needs the table's code to play again or leave."""

    @pytest.mark.parametrize(
        "phase",
        [Phase.NIGHT, Phase.DISCUSSION, Phase.VOTING, Phase.RESULTS],
    )
    def test_lobby_code_is_in_every_phase_for_every_player(
        self, table, phase: str
    ) -> None:
        game_id = table.start().data["game_id"]
        Game.objects.filter(id=game_id).update(phase=phase)

        for client in table.clients:
            data = client.get(reverse("onuw:game-me", kwargs={"game_id": game_id})).data
            assert data["phase"] == phase
            assert data["lobby_code"] == table.code

    def test_each_game_reports_its_own_lobby(self, table) -> None:
        first = table.play_to_results(seed=7)
        other = Table()
        other_game = other.start(seed=3).data["game_id"]

        mine = table.host.get(reverse("onuw:game-me", kwargs={"game_id": first})).data
        theirs = other.host.get(
            reverse("onuw:game-me", kwargs={"game_id": other_game})
        ).data

        assert mine["lobby_code"] == table.code
        assert theirs["lobby_code"] == other.code
        assert mine["lobby_code"] != theirs["lobby_code"]
