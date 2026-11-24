"""
Home extras: ``GET /api/stats/online/`` and ``GET /api/onuw/me/recent-games/``.

The online count is an aggregate of live socket rows (lobby sockets in core, game
sockets through a source the game app registers) and says nothing about anyone.
Recent games lists only the caller's own finished games, with minimal fields.
"""

from datetime import timedelta
from pathlib import Path

from django.urls import reverse
from django.utils import timezone

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.core import online
from apps.core.models import Lobby, LobbyMember, LobbySocket, User
from apps.core.throttles import OnlineStatsThrottle, SignUpThrottle
from apps.core.views import OnlineStatsView
from apps.core.wire import wire_time
from apps.onuw.models import Game, Phase, PlayerRole, SocketPresence
from tests.onuw.test_play_again import Table

pytestmark = pytest.mark.integration


def online_now() -> dict:
    response = APIClient().get(reverse("core:online-stats"))
    assert response.status_code == status.HTTP_200_OK
    return response.data


def lobby_socket(user_id: int, lobby: Lobby, *, age: float = 0, tag: str = "") -> None:
    seen = timezone.now() - timedelta(seconds=age)
    LobbySocket.objects.create(
        user_id=user_id,
        lobby=lobby,
        channel_name=f"lobby-{user_id}-{lobby.pk}-{age}{tag}",
        connected_at=seen,
        last_seen=seen,
    )


def game_socket(user_id: int, game: Game, *, age: float = 0) -> None:
    seen = timezone.now() - timedelta(seconds=age)
    SocketPresence.objects.create(
        user_id=user_id,
        game=game,
        channel_name=f"game-{user_id}-{game.pk}-{age}",
        connected_at=seen,
        last_seen=seen,
    )


@pytest.fixture
def two_tables(db, settings):
    settings.DEBUG = True
    first, second = Table(), Table(players=3)
    game = Game.objects.get(id=first.start().data["game_id"])
    return first, second, game


class TestOnlineCount:
    def test_nobody_connected_is_zero_of_both(self, db) -> None:
        assert online_now() == {"players": 0, "tables": 0}

    def test_online_counts_distinct_users_across_lobby_and_game_sockets(
        self, two_tables
    ) -> None:
        first, second, game = two_tables
        lobby_one, lobby_two = first.lobby(), second.lobby()
        a, b = first.ids[0], first.ids[1]
        # a: a lobby socket AND a game socket at table 1 (and a second tab)
        lobby_socket(a, lobby_one)
        lobby_socket(a, lobby_one, tag="-tab2")
        game_socket(a, game)
        # b: only a game socket at table 1
        game_socket(b, game)
        # c: a lobby socket at table 2
        lobby_socket(second.ids[0], lobby_two)

        assert online_now() == {"players": 3, "tables": 2}

    def test_one_user_at_two_tables_is_one_player_at_two_tables(
        self, two_tables
    ) -> None:
        first, second, _ = two_tables
        lobby_socket(first.ids[0], first.lobby())
        lobby_socket(first.ids[0], second.lobby())

        assert online_now() == {"players": 1, "tables": 2}

    def test_online_ignores_stale_rows(self, two_tables) -> None:
        first, second, game = two_tables
        lobby_socket(first.ids[0], first.lobby())  # fresh
        lobby_socket(second.ids[0], second.lobby(), age=600)  # silent for ten minutes
        game_socket(first.ids[1], game, age=600)

        assert online_now() == {"players": 1, "tables": 1}

    def test_online_has_cache_header_and_no_user_data(self, two_tables) -> None:
        first, _, game = two_tables
        lobby_socket(first.ids[0], first.lobby())
        game_socket(first.ids[1], game)

        response = APIClient().get(reverse("core:online-stats"))

        header = response.headers["Cache-Control"]
        assert {"public", "max-age=15", "s-maxage=15"} <= set(header.split(", "))
        assert set(response.data) == {"players", "tables"}
        body = response.content.decode()
        assert first.code not in body and str(first.ids[0]) not in body

    def test_it_needs_no_login_and_ignores_a_bad_token(self, two_tables) -> None:
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION="Bearer not-a-real-token")

        response = client.get(reverse("core:online-stats"))

        assert response.status_code == status.HTTP_200_OK

    def test_it_has_its_own_throttle_budget(self) -> None:
        assert OnlineStatsView.throttle_classes == [OnlineStatsThrottle]
        assert OnlineStatsThrottle.scope == "online_stats"
        assert (
            OnlineStatsThrottle.scope != SignUpThrottle.scope
        )  # sign-up does not pay for it
        assert OnlineStatsView.authentication_classes == []

    def test_a_game_app_adds_its_sockets_through_a_registered_source(self, db) -> None:
        def another_game() -> list[tuple[int, int]]:
            return [(1, 10), (2, 10), (1, 11)]

        online.register_online_source(another_game)
        online.register_online_source(another_game)  # once only
        try:
            assert online_now() == {"players": 2, "tables": 2}
        finally:
            online._sources.remove(another_game)

    def test_core_online_view_imports_no_game_app(self) -> None:
        core = Path(online.__file__).parent
        for name in ("online.py", "views.py"):
            assert "apps.onuw" not in (core / name).read_text()


def sit(user_id: int, game: Game, role: str) -> None:
    PlayerRole.objects.create(
        game=game, user_id=user_id, original_role=role, current_role=role
    )


class TestRecentGames:
    def url(self, limit=None) -> str:
        base = reverse("onuw:recent-games")
        return base if limit is None else f"{base}?limit={limit}"

    def test_recent_games_only_finished_games_of_caller(self, db, settings) -> None:
        settings.DEBUG = True
        mine = Table()
        theirs = Table(
            players=4, deck={"Werewolf": 2, "Seer": 1, "Villager": 3, "Drunk": 1}
        )
        first = mine.play_to_results(seed=1)
        mine.play_again()
        second = mine.play_to_results(seed=2)
        elsewhere = theirs.play_to_results(seed=3)
        caller = mine.clients[2]

        body = caller.get(self.url()).data

        ids = [g["game_id"] for g in body["games"]]
        assert ids == [second, first]  # newest first
        assert elsewhere not in ids
        newest = body["games"][0]
        stored = Game.objects.get(id=second)
        assert set(newest) == {
            "game_id",
            "ended_at",
            "player_count",
            "winning_teams",
            "you_won",
            "token",
            "seat",
        }
        assert newest["player_count"] == 5
        assert newest["winning_teams"] == stored.results["winning_teams"]
        assert newest["you_won"] == (
            stored.results["player_outcomes"][str(mine.ids[2])] == "win"
        )
        pr = PlayerRole.objects.get(game=stored, user_id=mine.ids[2])
        assert (newest["token"], newest["seat"]) == (pr.token, 2)
        assert newest["ended_at"] == wire_time(stored.updated_at)

    def test_you_won_follows_each_players_own_outcome(self, db, settings) -> None:
        settings.DEBUG = True
        table = Table()
        game_id = table.play_to_results(seed=5)
        outcomes = Game.objects.get(id=game_id).results["player_outcomes"]

        seen = {
            uid: client.get(self.url()).data["games"][0]["you_won"]
            for uid, client in zip(table.ids, table.clients, strict=True)
        }

        assert seen == {uid: outcomes[str(uid)] == "win" for uid in table.ids}
        assert len(set(seen.values())) == 2  # the seed gives both winners and losers

    def test_recent_games_excludes_running_game(self, db, settings) -> None:
        settings.DEBUG = True
        table = Table()
        finished = table.play_to_results(seed=1)
        table.play_again()
        running = table.start(seed=2).data["game_id"]

        ids = [g["game_id"] for g in table.host.get(self.url()).data["games"]]

        assert ids == [finished]
        assert running not in ids
        assert Game.objects.get(id=running).phase == Phase.NIGHT

    def test_recent_games_limit_clamped(self, db) -> None:
        host = User.objects.create_user(username="long_time_player", password="x")
        lobby = Lobby.objects.create(host=host, game_type="onuw")
        LobbyMember.objects.create(lobby=lobby, user=host)
        made = []
        for seed in range(12):
            game = Game.objects.create(
                lobby=lobby,
                phase=Phase.RESULTS,
                random_seed=seed,
                results={"winning_teams": ["village"], "player_outcomes": {}},
            )
            sit(host.id, game, "Villager")
            made.append(str(game.id))
        client = APIClient()
        client.force_authenticate(user=host)

        def count(limit=None) -> int:
            return len(client.get(self.url(limit)).data["games"])

        assert count() == 5  # the default
        assert count(3) == 3
        assert count(50) == 10  # the ceiling
        assert count(0) == 1
        assert count(-4) == 1
        assert count("abc") == 5  # unreadable: the default
        newest = client.get(self.url(2)).data["games"]
        assert [g["game_id"] for g in newest] == [made[-1], made[-2]]

    def test_recent_games_other_user_sees_nothing(self, db, settings) -> None:
        settings.DEBUG = True
        table = Table()
        table.play_to_results()
        stranger = User.objects.create_user(username="stranger", password="x")
        client = APIClient()
        client.force_authenticate(user=stranger)

        assert client.get(self.url()).data == {"games": []}

    def test_it_needs_a_login(self, db) -> None:
        response = APIClient().get(self.url())

        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    def test_a_game_with_no_results_yet_does_not_break_the_list(self, db) -> None:
        host = User.objects.create_user(username="odd_game", password="x")
        lobby = Lobby.objects.create(host=host, game_type="onuw")
        game = Game.objects.create(
            lobby=lobby, phase=Phase.RESULTS, random_seed=1, results={}
        )
        sit(host.id, game, "Villager")
        client = APIClient()
        client.force_authenticate(user=host)

        (entry,) = client.get(self.url()).data["games"]

        assert entry["winning_teams"] == [] and entry["you_won"] is False
