"""
Two start-up safety nets.

* Start can only deal one game per table, however fast it is tapped: the lobby
  row is locked from the status check to the game's creation (a lobby may hold
  many games, so nothing else forbids a second).
* Start-up recovery works whether or not the server imports the app inside a
  running event loop.
"""

import asyncio
import threading
from datetime import timedelta
from unittest.mock import patch

from django.core.exceptions import SynchronousOnlyOperation
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.urls import reverse
from django.utils import timezone

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.core.models import Lobby, LobbyMember, User
from apps.onuw import services
from apps.onuw.models import Game, Phase, PlayerRole, SocketPresence
from apps.onuw.views import GameStartView
from tests.onuw.test_play_again import Table

pytestmark = pytest.mark.integration


@pytest.fixture
def table(db, settings):
    settings.DEBUG = True  # fixed seeds
    return Table()


class TestStartDealsOneGame:
    def test_a_double_tap_creates_one_game_and_the_second_is_refused(
        self, table
    ) -> None:
        first = table.start(seed=1)
        second = table.start(seed=2)

        assert first.status_code == status.HTTP_201_CREATED
        assert second.status_code == status.HTTP_400_BAD_REQUEST
        assert second.data["detail"] == "Lobby is not in waiting state."
        assert Game.objects.filter(lobby__code=table.code).count() == 1

    def test_a_start_after_play_again_is_still_one_game_per_deal(self, table) -> None:
        table.play_to_results(seed=1)
        table.play_again()

        assert table.start(seed=2).status_code == status.HTTP_201_CREATED
        assert table.start(seed=3).status_code == status.HTTP_400_BAD_REQUEST
        assert Game.objects.filter(lobby__code=table.code).count() == 2

    def test_the_status_check_runs_under_the_lobby_lock(self, table) -> None:
        seen: dict[str, object] = {}
        real_deal = GameStartView._deal

        def spy(self, request, lobby):
            seen["in_atomic"] = connection.in_atomic_block
            seen["queries_before_check"] = [q["sql"] for q in ctx.captured_queries]
            return real_deal(self, request, lobby)

        with (
            CaptureQueriesContext(connection) as ctx,
            patch.object(GameStartView, "_deal", spy),
        ):
            response = table.start(seed=1)

        assert response.status_code == status.HTTP_201_CREATED
        assert seen["in_atomic"] is True
        locked = [
            sql
            for sql in seen["queries_before_check"]  # type: ignore[union-attr]
            if 'FROM "core_lobby"' in sql and "FOR UPDATE" in sql
        ]
        assert locked, "the lobby row must be locked before its status is read"
        # ...and the game is created inside the same transaction, after the lock.
        sqls = [q["sql"] for q in ctx.captured_queries]
        lock_at = next(
            i for i, q in enumerate(sqls) if "FOR UPDATE" in q and "core_lobby" in q
        )
        insert_at = next(
            i for i, q in enumerate(sqls) if q.startswith('INSERT INTO "onuw_game"')
        )
        assert lock_at < insert_at

    @pytest.mark.django_db(transaction=True)
    def test_two_simultaneous_starts_deal_exactly_one_game(self, settings) -> None:
        settings.DEBUG = True
        table = Table()
        barrier = threading.Barrier(2)
        codes: list[int] = []

        def tap() -> None:
            from django.db import connections

            try:
                client = APIClient()
                client.credentials(
                    **{
                        "HTTP_AUTHORIZATION": table.host._credentials[
                            "HTTP_AUTHORIZATION"
                        ]
                    }
                )
                barrier.wait(timeout=10)
                codes.append(
                    client.post(
                        reverse("onuw:game-start", kwargs={"code": table.code}),
                        {"debug": {"seed": 5}},
                        format="json",
                    ).status_code
                )
            finally:
                connections.close_all()

        threads = [threading.Thread(target=tap) for _ in range(2)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=30)

        assert sorted(codes) == [status.HTTP_201_CREATED, status.HTTP_400_BAD_REQUEST]
        assert Game.objects.filter(lobby__code=table.code).count() == 1


class TestStartupRecoveryInsideAnEventLoop:
    @pytest.mark.django_db(transaction=True)
    def test_recovery_really_runs_when_the_app_is_imported_inside_a_running_loop(
        self, settings
    ) -> None:
        settings.ONUW_RECOVER_TIMERS_ON_START = True
        host = User.objects.create_user(username="loop_host", password="x")
        other = User.objects.create_user(username="loop_other", password="x")
        lobby = Lobby.objects.create(
            host=host, game_type="onuw", settings={"roles": {}}
        )
        game = Game.objects.create(
            lobby=lobby,
            phase=Phase.DISCUSSION,
            random_seed=1,
            settings={},
            center_cards=["Villager"] * 3,
            phase_deadline=timezone.now() - timedelta(seconds=30),
        )
        for user in (host, other):
            LobbyMember.objects.create(lobby=lobby, user=user)
            PlayerRole.objects.create(
                game=game,
                user=user,
                original_role="Villager",
                current_role="Villager",
            )
            SocketPresence.objects.create(
                user=user,
                game=game,
                channel_name=f"loop-{user.id}",
                connected_at=timezone.now(),
                last_seen=timezone.now(),
            )

        async def import_the_app_in_a_loop() -> None:
            # What an ASGI server does: the app is built with a loop running.
            with pytest.raises(SynchronousOnlyOperation):
                services.recover_timers()  # the premise: direct ORM use is refused
            services.run_startup_recovery()  # must work anyway

        with patch("apps.onuw.timers.schedule") as schedule:
            asyncio.run(import_the_app_in_a_loop())

        assert [
            t for t in threading.enumerate() if t.name == "onuw-timer-recovery"
        ] == []
        # Presence is never reset at start-up.
        assert SocketPresence.objects.filter(game=game).count() == 2
        keys = [call.args[0] for call in schedule.call_args_list]
        assert f"{game.id}:discussion" in keys
        game.refresh_from_db()
        assert game.phase_deadline is not None
        assert game.phase_deadline > timezone.now()  # the reconnect allowance

    def test_it_still_works_with_no_loop_running(self, db, settings) -> None:
        settings.ONUW_RECOVER_TIMERS_ON_START = True
        with patch("apps.onuw.services.recover_timers", return_value=0) as recover:
            services.run_startup_recovery()
        recover.assert_called_once()

    def test_the_recovery_thread_closes_its_own_database_connections(
        self, db, settings
    ) -> None:
        settings.ONUW_RECOVER_TIMERS_ON_START = True
        closed: list[bool] = []

        with (
            patch("apps.onuw.services.recover_timers", return_value=0),
            patch(
                "django.db.connections.close_all",
                side_effect=lambda: closed.append(True),
            ),
        ):
            services.run_startup_recovery()

        assert closed == [True]


class TestAStartedNightAlwaysOpens:
    def test_starting_a_game_opens_its_first_window_in_the_same_transaction(
        self, table
    ) -> None:
        response = table.start(seed=1)

        game = Game.objects.get(id=response.data["game_id"])
        assert game.phase == Phase.NIGHT
        assert game.current_wave in (1, 2)  # no committed night without a window

    def test_if_opening_fails_nothing_was_created_and_the_table_can_start_again(
        self, table
    ) -> None:
        with patch(
            "apps.onuw.views.start_night_phase", side_effect=RuntimeError("boom")
        ):
            with pytest.raises(RuntimeError):
                table.start(seed=1)

        assert Game.objects.filter(lobby__code=table.code).count() == 0
        assert table.lobby().status == Lobby.Status.WAITING
        assert table.start(seed=1).status_code == status.HTTP_201_CREATED

    def test_a_night_stuck_without_a_window_is_opened_by_the_next_game_state_fetch(
        self, make_night
    ) -> None:
        night = make_night(
            {"a": "Werewolf", "b": "Seer", "c": "Villager"}, night_wave_seconds=60
        )
        assert night.game.current_wave == 0  # committed, never opened
        Game.objects.filter(id=night.game.id).update(
            created_at=timezone.now() - timedelta(minutes=5)
        )
        night.client.force_authenticate(user=night.users["a"])

        with night.committed():
            response = night.client.get(
                reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})
            )

        assert response.status_code == status.HTTP_200_OK
        assert night.refresh().current_wave == 2
        assert [e["wave"] for e in night.broadcasts("wave.start")] == [2]

    def test_a_night_that_has_only_just_started_is_left_to_its_starter(
        self, make_night
    ) -> None:
        night = make_night({"a": "Werewolf", "b": "Seer", "c": "Villager"})
        night.client.force_authenticate(user=night.users["a"])

        night.client.get(
            reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})
        )

        assert night.refresh().current_wave == 0  # only a stuck night is repaired

    def test_two_fetches_do_not_open_the_night_twice(self, make_night) -> None:
        night = make_night({"a": "Werewolf", "b": "Seer", "c": "Villager"})
        Game.objects.filter(id=night.game.id).update(
            created_at=timezone.now() - timedelta(minutes=5)
        )
        night.client.force_authenticate(user=night.users["a"])
        url = reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})

        with night.committed():
            night.client.get(url)
        with night.committed():
            night.client.get(url)

        assert [e["wave"] for e in night.broadcasts("wave.start")] == [2]
