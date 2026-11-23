"""
Real migrations, run against data shaped like production's.

The rest of the suite builds its database from the models (``--nomigrations``), so
nothing else proves that a migration works on rows that already exist, or that the
previous code can still write after it. These tests apply the actual migrations
(``just test-migrations``; they skip under ``--nomigrations``): migrate to the state
before, create rows through the historical models as that code would, migrate
forward, assert, check the old code's INSERTs still work, then migrate back and
forward again.

To cover a new migration: add its ``(app, name)`` nodes to a new ``BEFORE`` /
``AFTER`` pair, seed old-shape rows with ``migrator.apply(BEFORE)``, and assert
after ``migrator.apply(AFTER)``. ``tests/old_code.py`` holds the old code's INSERTs.
"""

from collections.abc import Iterator
from datetime import timedelta
from typing import Any

from django.db import IntegrityError, ProgrammingError, connection, transaction
from django.db.migrations.executor import MigrationExecutor
from django.utils import timezone

import pytest

from apps.core import tokens
from tests.old_code import (
    insert_game,
    insert_member,
    insert_member_without_ready,
    insert_player_role,
)

pytestmark = [pytest.mark.migration, pytest.mark.django_db(transaction=True)]

# Before and after the v2 migrations (tokens, PlayerRole columns, dealt centre).
BEFORE = [("core", "0009_scheduledtimer"), ("onuw", "0009_core_owns_timers")]
AFTER = [("core", "0010_lobbymember_token"), ("onuw", "0010_playerrole_v2_fields")]


class Migrator:
    """Moves the database between migration states and returns that state's models."""

    def apply(self, targets):
        executor = MigrationExecutor(connection)
        executor.migrate(targets)
        return executor.loader.project_state(targets).apps

    def to_latest(self) -> None:
        executor = MigrationExecutor(connection)
        executor.migrate(executor.loader.graph.leaf_nodes())


@pytest.fixture
def migrator() -> Iterator[Migrator]:
    loader = MigrationExecutor(connection).loader
    if AFTER[0] not in loader.graph.nodes:
        pytest.skip("migrations are disabled (--nomigrations): `just test-migrations`")
    migrator = Migrator()
    try:
        yield migrator
    finally:
        migrator.to_latest()  # whatever the test did, leave the schema current


def seed_old_tables(old) -> dict[str, Any]:
    """Rows as production has them before the v2 migrations."""
    user_model = old.get_model("core", "User")
    lobby_model = old.get_model("core", "Lobby")
    member_model = old.get_model("core", "LobbyMember")
    users = [user_model.objects.create(username=f"m{i}") for i in range(14)]

    def lobby(code: str, status: str, members: int, *, max_players: int = 10):
        row = lobby_model.objects.create(
            code=code,
            host=users[0],
            game_type="onuw",
            status=status,
            max_players=max_players,
        )
        for user in users[:members]:
            member_model.objects.create(lobby=row, user=user)
        return row

    big = lobby("BIG234", "waiting", 12, max_players=12)
    tied = lobby("TIE234", "waiting", 4)
    # Members who share one joined_at: the id breaks the tie.
    same = timezone.now() - timedelta(hours=1)
    member_model.objects.filter(lobby=tied).update(joined_at=same)
    empty = lobby("EMP234", "waiting", 0)
    done = lobby("DON234", "finished", 3)
    running = lobby("RUN234", "in_game", 3)
    game_id = insert_game(running.pk)
    for user in users[:3]:
        insert_player_role(game_id, user.pk)
    return {
        "big": big,
        "tied": tied,
        "empty": empty,
        "done": done,
        "running": running,
        "game_id": game_id,
        "users": users,
    }


def tokens_of(new, code: str) -> list[str]:
    members = new.get_model("core", "LobbyMember").objects.filter(lobby__code=code)
    return [m.token for m in members.order_by("joined_at", "id")]


class TestTokenAndPlayerRoleMigrations:
    def test_backfill_migration_assigns_tokens(self, migrator) -> None:
        old = migrator.apply(BEFORE)
        seeded = seed_old_tables(old)

        new = migrator.apply(AFTER)

        # A lobby of 12 (legacy: max_players above 10): ten tokens, two blanks.
        order = tokens.token_order("BIG234")
        assert tokens_of(new, "BIG234") == [*order, "", ""]
        # Joined at the same instant: tokens go by id, which is creation order.
        tied_ids = list(
            new.get_model("core", "LobbyMember")
            .objects.filter(lobby__code="TIE234")
            .order_by("id")
            .values_list("token", flat=True)
        )
        assert tied_ids == tokens.token_order("TIE234")[:4]
        assert tokens_of(new, "EMP234") == []  # an empty lobby is fine
        # A finished table is left alone (blank tokens are handled lazily).
        assert tokens_of(new, "DON234") == ["", "", ""]
        # A running one gets them.
        assert tokens_of(new, "RUN234") == tokens.token_order("RUN234")[:3]
        # Old games and players take the column defaults.
        game = new.get_model("onuw", "Game").objects.get(id=seeded["game_id"])
        assert game.dealt_center_cards == []
        roles = new.get_model("onuw", "PlayerRole").objects.filter(game=game)
        assert roles.count() == 3
        for role in roles:
            assert (role.token, role.seat, role.phase_ready) == ("", None, False)
            assert role.night_results_seen == 0

    def test_the_unique_rule_ignores_blanks_but_stops_a_repeated_token(
        self, migrator
    ) -> None:
        seed_old_tables(migrator.apply(BEFORE))
        new = migrator.apply(AFTER)
        member_model = new.get_model("core", "LobbyMember")
        user_model = new.get_model("core", "User")
        done = member_model.objects.filter(lobby__code="DON234")
        assert done.filter(token="").count() == 3  # three blanks, no clash
        lobby = new.get_model("core", "Lobby").objects.get(code="TIE234")
        taken = member_model.objects.filter(lobby=lobby).first().token

        with pytest.raises(IntegrityError), transaction.atomic():
            member_model.objects.create(
                lobby=lobby, user=user_model.objects.get(username="m9"), token=taken
            )

    def test_the_old_code_can_still_write_after_the_migrations(self, migrator) -> None:
        seeded = seed_old_tables(migrator.apply(BEFORE))
        new = migrator.apply(AFTER)
        tied = seeded["tied"]
        late_user = seeded["users"][9]

        insert_member(tied.pk, late_user.pk)  # a join by the previous instance
        game_id = insert_game(tied.pk)
        insert_player_role(game_id, late_user.pk)

        late = new.get_model("core", "LobbyMember").objects.get(
            lobby_id=tied.pk, user_id=late_user.pk
        )
        assert late.token == ""  # the deal fills it in
        role = new.get_model("onuw", "PlayerRole").objects.get(game_id=game_id)
        assert (role.token, role.seat, role.phase_ready, role.night_results_seen) == (
            "",
            None,
            False,
            0,
        )
        game = new.get_model("onuw", "Game").objects.get(id=game_id)
        assert game.dealt_center_cards == []

    def test_migrating_back_and_forward_again_keeps_the_result(self, migrator) -> None:
        seeded = seed_old_tables(migrator.apply(BEFORE))
        migrator.apply(AFTER)

        back = migrator.apply(BEFORE)
        columns = {f.name for f in back.get_model("core", "LobbyMember")._meta.fields}
        assert "token" not in columns
        # The previous code writes while the schema is old again.
        insert_member(seeded["tied"].pk, seeded["users"][9].pk)
        again = migrator.apply(AFTER)

        # Forward a second time: the backfill reruns, now including that member.
        assert tokens_of(again, "TIE234") == tokens.token_order("TIE234")[:5]
        assert tokens_of(again, "BIG234") == [*tokens.token_order("BIG234"), "", ""]
        assert tokens_of(again, "DON234") == ["", "", ""]


# Before and after the ready flag is left to the database (core 0011).
READY_BEFORE = [
    ("core", "0010_lobbymember_token"),
    ("onuw", "0010_playerrole_v2_fields"),
]
READY_AFTER = [
    ("core", "0011_lobbymember_is_ready_left_to_the_database"),
    ("onuw", "0010_playerrole_v2_fields"),
]


def ready_flags(lobby_id: int) -> list[bool]:
    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT is_ready FROM core_lobbymember WHERE lobby_id = %s ORDER BY id",
            [lobby_id],
        )
        return [row[0] for row in cursor.fetchall()]


class TestReadyFlagLeftToTheDatabase:
    def seed(self, old) -> tuple[Any, list[Any]]:
        users = [
            old.get_model("core", "User").objects.create(username=f"r{i}")
            for i in range(4)
        ]
        lobby = old.get_model("core", "Lobby").objects.create(
            code="RDY234", host=users[0], game_type="onuw", status="waiting"
        )
        member = old.get_model("core", "LobbyMember")
        member.objects.create(lobby=lobby, user=users[0], is_ready=True)
        return lobby, users

    def test_both_builds_can_seat_a_player_after_it(self, migrator) -> None:
        lobby, users = self.seed(migrator.apply(READY_BEFORE))
        new = migrator.apply(READY_AFTER)

        member = new.get_model("core", "LobbyMember")
        assert "is_ready" not in {f.name for f in member._meta.fields}
        # This build's INSERT does not name the column: the database fills it in.
        member.objects.create(lobby_id=lobby.pk, user_id=users[1].pk)
        # The previous build's INSERT names it, and still works.
        insert_member(lobby.pk, users[2].pk)

        assert member.objects.filter(lobby_id=lobby.pk).count() == 3
        assert ready_flags(lobby.pk) == [True, False, False]  # stored values are kept

    def test_back_and_forward_again(self, migrator) -> None:
        lobby, users = self.seed(migrator.apply(READY_BEFORE))
        migrator.apply(READY_AFTER)

        back = migrator.apply(READY_BEFORE)
        member = back.get_model("core", "LobbyMember")
        assert "is_ready" in {f.name for f in member._meta.fields}
        with pytest.raises(IntegrityError), transaction.atomic():
            # without the database default, an INSERT that leaves the column out fails:
            # this is what the previous build would hit if the column had no default
            with connection.cursor() as cursor:
                cursor.execute(
                    "INSERT INTO core_lobbymember (lobby_id, user_id, joined_at, token)"
                    " VALUES (%s, %s, now(), '')",
                    [lobby.pk, users[1].pk],
                )
        insert_member(lobby.pk, users[2].pk)

        again = migrator.apply(READY_AFTER)
        again.get_model("core", "LobbyMember").objects.create(
            lobby_id=lobby.pk, user_id=users[3].pk
        )
        assert ready_flags(lobby.pk) == [True, False, False]


# Before and after the ready column is dropped (core 0012).
DROPPED_AFTER = [
    ("core", "0012_lobbymember_drop_is_ready"),
    ("onuw", "0010_playerrole_v2_fields"),
]


def member_columns() -> set[str]:
    with connection.cursor() as cursor:
        return {
            column.name
            for column in connection.introspection.get_table_description(
                cursor, "core_lobbymember"
            )
        }


class TestReadyColumnDropped:
    def seed(self, state) -> tuple[Any, list[Any]]:
        users = [
            state.get_model("core", "User").objects.create(username=f"d{i}")
            for i in range(4)
        ]
        lobby = state.get_model("core", "Lobby").objects.create(
            code="DRP234", host=users[0], game_type="onuw", status="waiting"
        )
        state.get_model("core", "LobbyMember").objects.create(
            lobby=lobby, user=users[0], token="fox"
        )
        return lobby, users

    def test_the_column_goes_and_both_builds_can_seat_a_player(self, migrator) -> None:
        lobby, users = self.seed(migrator.apply(READY_AFTER))
        assert "is_ready" in member_columns()

        new = migrator.apply(DROPPED_AFTER)

        assert "is_ready" not in member_columns()
        member = new.get_model("core", "LobbyMember")
        member.objects.create(lobby_id=lobby.pk, user_id=users[1].pk, token="owl")
        # The previous build (after 0011) never names the column: its INSERT works.
        insert_member_without_ready(lobby.pk, users[2].pk, token="elk")
        rows = member.objects.filter(lobby_id=lobby.pk).order_by("id")
        assert [m.token for m in rows] == ["fox", "owl", "elk"]  # rows are kept

    def test_a_build_from_before_0011_can_no_longer_seat_a_player(
        self, migrator
    ) -> None:
        """Written down as a test: this is why a rollback past 0011 is not allowed."""
        lobby, users = self.seed(migrator.apply(READY_AFTER))
        migrator.apply(DROPPED_AFTER)

        with pytest.raises(ProgrammingError), transaction.atomic():
            insert_member(lobby.pk, users[1].pk)

    def test_back_and_forward_again(self, migrator) -> None:
        lobby, users = self.seed(migrator.apply(READY_AFTER))
        migrator.apply(DROPPED_AFTER)

        back = migrator.apply(READY_AFTER)
        # As 0011 left it: both shapes of INSERT work, and old rows read false.
        back.get_model("core", "LobbyMember").objects.create(
            lobby_id=lobby.pk, user_id=users[1].pk
        )
        insert_member(lobby.pk, users[2].pk)
        assert ready_flags(lobby.pk) == [False, False, False]
        with connection.cursor() as cursor:
            described = connection.introspection.get_table_description(
                cursor, "core_lobbymember"
            )
        assert [c.null_ok for c in described if c.name == "is_ready"] == [False]

        again = migrator.apply(DROPPED_AFTER)
        assert "is_ready" not in member_columns()
        again.get_model("core", "LobbyMember").objects.create(
            lobby_id=lobby.pk, user_id=users[3].pk
        )
        assert again.get_model("core", "LobbyMember").objects.count() == 4
