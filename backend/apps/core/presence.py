"""
Who is connected, from socket rows instead of counters (shared by every app).

Counters drift when an instance dies without running ``disconnect`` and were
zeroed at every process start, which is wrong where instances start and stop at
any time. Here each open socket is a row; the consumer refreshes ``last_seen``
every ~``ONUW_PRESENCE_HEARTBEAT_SECONDS`` (15) and a user is *connected* in a
scope (a game or a lobby) while one of their rows has been seen within
``ONUW_PRESENCE_STALE_SECONDS`` (40). Nothing is ever reset at server start.

Silent deaths. When a row is created or refreshed we make sure a durable
``presence_check`` timer exists for that (scope, user), due at
``last_seen + stale``. At most one is pending per scope and user, and a
heartbeat writes nothing to it: when it fires early (the heartbeats kept the
user fresh) it simply re-arms itself for the new ``last_seen + stale``, so the
timer is written about once per staleness period however long the socket lives.
When it fires and the user has no fresh row it runs EXACTLY the code of a clean
last-socket disconnect (presence event, grace timer, host handover clock) and
deletes the stale rows.

The "went offline / came back" transitions themselves live next to the logic
they feed: ``apps.core.host`` for a lobby (``LobbySocket`` rows), the game app's
services for a game (its own socket rows). A game app registers its scope with
``register_scope`` so the durable check can reach it.
"""

from __future__ import annotations

import logging
from collections.abc import Callable
from datetime import timedelta
from typing import Any

from django.conf import settings
from django.db.models import F, Min
from django.db.models.functions import Now

from apps.core import timers

logger = logging.getLogger(__name__)

DEFAULT_HEARTBEAT_SECONDS = 15
DEFAULT_STALE_SECONDS = 40


def heartbeat_seconds() -> float:
    return float(
        getattr(settings, "ONUW_PRESENCE_HEARTBEAT_SECONDS", DEFAULT_HEARTBEAT_SECONDS)
    )


def beat_frame(token: dict[str, Any] | None = None) -> dict[str, Any]:
    """What a socket sends its phone as it opens and at each heartbeat. A phone
    counts its socket as up only while frames keep coming (within about two
    beats); ``every`` says how often they come, so the phone holds no number of
    ours. ``token`` is what every seat at the table already knows of where it is
    (the lobby's ``rev``; a game's ``phase``, ``window`` and ``moved_on``), the
    same for every socket of one table: a phone holding less reads once, so a
    frame lost on a socket that stays alive costs one read, not a stuck screen."""
    return {"type": "beat", "every": heartbeat_seconds(), **(token or {})}


def stale_seconds() -> float:
    return float(
        getattr(settings, "ONUW_PRESENCE_STALE_SECONDS", DEFAULT_STALE_SECONDS)
    )


def cutoff() -> Any:
    """Rows seen before this are stale: an expression on the DATABASE clock, so
    instances with skewed clocks agree on who is connected."""
    return Now() - timedelta(seconds=stale_seconds())


def seconds_since_newest(rows) -> float | None:
    """Age in seconds (database clock) of the newest row's ``last_seen``, or
    None if there is no row."""
    age = rows.aggregate(age=Min(Now() - F("last_seen")))["age"]
    return None if age is None else age.total_seconds()


def next_check_delay(age: float) -> float:
    """Seconds until a presence check should look again, given the newest
    row's age: when that row would go stale."""
    return max(stale_seconds() - age, 1.0)


def check_key(scope: str, scope_id: Any, user_id: int) -> str:
    """Timer key of the presence check for a user in a scope ("game" / "lobby").

    Starts with ``presence:``, so it never matches a game's ``<uuid>:`` prefix.
    """
    return f"presence:{scope}:{scope_id}:{user_id}"


def check_params(scope: str, scope_id: Any, user_id: int) -> dict[str, Any]:
    return {"scope": scope, "scope_id": str(scope_id), "user_id": user_id}


# ── Lobby sockets ───────────────────────────────────────────────────────────


def fresh_rows(*, lobby_id: Any = None, user_id: int | None = None):
    """Lobby socket rows seen within the staleness timeout."""
    from .models import LobbySocket

    queryset = LobbySocket.objects.filter(last_seen__gte=cutoff())
    if lobby_id is not None:
        queryset = queryset.filter(lobby_id=lobby_id)
    if user_id is not None:
        queryset = queryset.filter(user_id=user_id)
    return queryset


def lobby_beat(channel_name: str) -> tuple[Any, int] | None:
    """A lobby socket's heartbeat in one statement: its row refreshed, and its
    lobby's id and ``rev`` (the table's number: the beat frame's token, the same
    for every seat). None when the row is gone. Leaves the connection open."""
    from django.db import connection

    from .models import Lobby, LobbySocket

    sockets = LobbySocket._meta.db_table
    lobbies = Lobby._meta.db_table
    sql = f"""
        UPDATE {sockets} AS s SET last_seen = STATEMENT_TIMESTAMP()
        FROM {lobbies} AS l
        WHERE s.channel_name = %s AND l.id = s.lobby_id
        RETURNING l.id, l.rev
    """  # noqa: S608 (table names from the models, values as parameters)
    with connection.cursor() as cursor:
        cursor.execute(sql, [channel_name])
        row = cursor.fetchone()
    return None if row is None else (row[0], row[1])


def connected_user_ids(*, lobby_id: Any = None) -> set[int]:
    """Users with at least one fresh socket on the lobby."""
    return set(fresh_rows(lobby_id=lobby_id).values_list("user_id", flat=True))


async def heartbeat_loop(frame, work) -> None:
    """Every heartbeat interval until cancelled (one task per consumer): ``await
    frame()`` on time, then ``work()`` (the beat's database work) beside it.

    The frame never waits for the database: a slow database must not make
    every phone drop a healthy socket. A beat whose work from the last beat is
    still running starts none (they never pile up). A failing frame or work is
    logged and the loop carries on.

    Cancelling (the consumer's ``disconnect``) stops it at once, but work
    already running is finished first: it runs in a pool thread that
    cancelling cannot stop, so returning early would let that thread refresh,
    or re-create, the socket's row AFTER ``disconnect`` deleted it (a closed
    socket counted as connected until it went stale). However often it is
    cancelled meanwhile (``disconnect``'s own task can be cancelled too:
    shutdown, a timeout), the work stays shielded until it ends."""
    import asyncio

    interval = heartbeat_seconds()
    running: asyncio.Future | None = None
    try:
        while True:
            await asyncio.sleep(interval)
            try:
                await frame()
            except Exception:
                logger.exception("Heartbeat frame failed")
            if running is not None and not running.done():
                continue  # the last beat's work still runs: no second one
            _log_failure(running)
            running = asyncio.ensure_future(work())
    except asyncio.CancelledError:
        while running is not None and not running.done():
            try:
                await asyncio.shield(running)
            except asyncio.CancelledError:
                pass
            except Exception:
                break  # it failed, so it has ended: logged below
        _log_failure(running)
        raise


def _log_failure(running: Any) -> None:
    if running is None or not running.done() or running.cancelled():
        return
    failure = running.exception()
    if failure is not None:
        logger.error("Presence heartbeat failed", exc_info=failure)


# ── The durable check ───────────────────────────────────────────────────────

# scope ("game", "lobby", ...) -> checker(scope_id, user_id). The checker runs
# inside the timer's transaction and raises on failure (so the timer is retried).
_SCOPES: dict[str, Callable[[str, int], None]] = {}


def register_scope(scope: str, checker: Callable[[str, int], None]) -> None:
    """Teach the durable check about another socket scope (a game app's)."""
    _SCOPES[scope] = checker


def ensure_check_timer(scope: str, scope_id: Any, user_id: int) -> None:
    """Make sure a presence check is pending for the user (a no-op if one is).

    Called when a socket row is created or refreshed. The timer re-arms itself
    when it fires early, so a pending one is never rewritten by a heartbeat.
    """
    key = check_key(scope, scope_id, user_id)
    if timers.is_scheduled(key):
        return
    timers.schedule(
        key, stale_seconds(), "presence_check", check_params(scope, scope_id, user_id)
    )


@timers.job("presence_check")
def _job_presence_check(scope: str, scope_id: str, user_id: int) -> None:
    """Timer: has this user's socket silently died? (see the module docstring)"""
    try:
        checker = _SCOPES.get(scope)
        if checker is None:
            # A scope is registered when its module is imported, and the timers
            # import every job module before a job runs: a scope still unknown
            # here means its check would be skipped for good. Say so loudly.
            logger.error(
                "Presence check for an unknown scope %r (%s, user %s): nothing"
                " registered it, so nobody will notice this socket dying",
                scope,
                scope_id,
                user_id,
            )
            return
        checker(scope_id, user_id)
    except Exception:
        logger.exception(
            "Presence check failed for %s %s user %s", scope, scope_id, user_id
        )
        raise  # fire() rolls back and keeps the row: the check is retried


def _check_lobby(scope_id: str, user_id: int) -> None:
    from . import host

    host.check_lobby_presence(scope_id, user_id)


register_scope("lobby", _check_lobby)
