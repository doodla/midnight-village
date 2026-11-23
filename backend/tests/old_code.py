"""
What the code BEFORE a change wrote and how it read, frozen.

INSERTs as the code BEFORE the v2 migrations wrote them (raw SQL, only the columns
that existed then).

During a deploy ``migrate`` runs while the previous code still serves, so after a
migration these statements must keep working: every column a migration adds to a
table that this code writes needs a database default. These functions stay in the
OLD shape for good (never add a column to them): the migration test and
``test_rollout_safe_schema`` run them against the new schema.
"""

import uuid
from datetime import datetime

from django.db import connection
from django.utils import timezone


def _insert(sql: str, params: list) -> None:
    with connection.cursor() as cursor:
        cursor.execute(sql, params)


def insert_member(
    lobby_id: int, user_id: int, joined_at: datetime | None = None
) -> None:
    """A LobbyMember row as the old code wrote it (no ``token``)."""
    _insert(
        "INSERT INTO core_lobbymember (lobby_id, user_id, is_ready, joined_at)"
        " VALUES (%s, %s, false, %s)",
        [lobby_id, user_id, joined_at or timezone.now()],
    )


def insert_game(lobby_id: int) -> uuid.UUID:
    """A Game row as the old code wrote it (no ``dealt_center_cards``)."""
    game_id = uuid.uuid4()
    now = timezone.now()
    _insert(
        "INSERT INTO onuw_game (id, lobby_id, phase, current_wave, random_seed,"
        " night_actions_log, settings, center_cards, results, created_at,"
        " updated_at) VALUES (%s, %s, 'night', 0, 1, '[]', '{}', '[]', '{}',"
        " %s, %s)",
        [game_id, lobby_id, now, now],
    )
    return game_id


def insert_player_role(game_id: uuid.UUID, user_id: int) -> None:
    """A PlayerRole row as the old code wrote it (no token, seat, ready, ack)."""
    _insert(
        "INSERT INTO onuw_playerrole (id, game_id, user_id, original_role,"
        ' "current_role", night_action_data, has_acted)'
        " VALUES (%s, %s, %s, 'Villager', 'Villager', '{}', false)",
        [uuid.uuid4(), game_id, user_id],
    )
