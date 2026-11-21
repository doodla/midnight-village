"""
What the code BEFORE a change wrote and how it read, frozen.

INSERTs as the code BEFORE the v2 migrations wrote them (raw SQL, only the columns
that existed then).

During a deploy ``migrate`` runs while the previous code still serves, so after a
migration these statements must keep working: every column a migration adds to a
table that this code writes needs a database default. These functions stay in the
OLD shape for good (never add a column to them): the migration test and
``test_rollout_safe_schema`` run them against the new schema.

The read rules at the end are the other direction: how the code before the
protocol-1 cleanup read a table or game, run on rows the new code writes.
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


# ── How the code BEFORE the protocol-1 cleanup READ rows ──────────────────────
#
# The same promise the other way round: for the seconds a deploy is promoted, the
# previous code still serves and reads rows THIS code wrote (a table a new instance
# created, a game it dealt). These are the rules that code applied, copied from it
# (commit ed9008b) and frozen: never change them to match new code.
# ``tests/onuw/test_old_code_reads_new_rows.py`` runs them on rows the new code wrote.

OLD_NIGHT_PROTOCOLS = (1, 2)
OLD_PROTOCOL_2_TIMED_KEYS = ("night_wave_seconds", "night_doppelganger_window_seconds")
OLD_MIN_PROTOCOL_2_MIN_WINDOW_SECONDS = 5


def reads_as_choose_night(settings: object) -> bool:
    """The old ``protocol.is_choose_night`` / ``deal.is_v2_table`` /
    ``hooks.shows_table_extras``: only ``night_protocol: 2`` plays the choose night
    (stages, lobby extras, no ready check); anything else is the old night."""
    return isinstance(settings, dict) and settings.get("night_protocol") == 2


def deal_needs_everyone_ready(settings: object) -> bool:
    """The old ``deal.deal_refusal``: a table that is not protocol 2 needs every
    member ready."""
    return not reads_as_choose_night(settings)


def night_protocol_errors(settings: dict, *, allow_untimed: bool = True) -> list[str]:
    """The old ``engine.validation.validate_night_protocol``, run on every lobby
    PATCH and at every deal."""
    protocol = settings.get("night_protocol", 1)
    if "night_protocol" in settings and (
        type(protocol) is not int or protocol not in OLD_NIGHT_PROTOCOLS
    ):
        return ["'night_protocol' must be 1 or 2."]
    errors: list[str] = []
    look = settings.get("card_look_seconds")
    if protocol != 2 and type(look) is int and look > 0:
        errors.append("'card_look_seconds' needs 'night_protocol' 2.")
    if protocol != 2 or allow_untimed:
        return errors
    errors += [
        f"{key!r} cannot be 0 when every phone chooses at night."
        for key in OLD_PROTOCOL_2_TIMED_KEYS
        if type(settings.get(key)) is int and settings.get(key) == 0
    ]
    window_min = settings.get("night_min_window_seconds")
    if type(window_min) is int and window_min < OLD_MIN_PROTOCOL_2_MIN_WINDOW_SECONDS:
        errors.append("'night_min_window_seconds' must be at least 5.")
    return errors
