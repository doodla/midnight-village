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


def beat_frame() -> dict[str, Any]:
    """What every socket sends its phone at each heartbeat (the first one a beat
    after it opens): the same bytes for every socket, player and role. A phone counts its
    socket as up only while frames keep coming (within about two beats);
    ``every`` says how often they come, so the phone holds no number of ours."""
    return {"type": "beat", "every": heartbeat_seconds()}


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


def connected_user_ids(*, lobby_id: Any = None) -> set[int]:
    """Users with at least one fresh socket on the lobby."""
    return set(fresh_rows(lobby_id=lobby_id).values_list("user_id", flat=True))


async def heartbeat_loop(beat) -> None:
    """Run ``await beat()`` every heartbeat interval until cancelled (one task
    per consumer). A failing beat is logged and the loop carries on.

    Cancelling (the consumer's ``disconnect``) stops it at once while it
    sleeps, but a beat already running is finished first: its database work
    runs in a pool thread that cancelling cannot stop, so returning early would
    let that thread refresh, or re-create, the socket's row AFTER ``disconnect``
    deleted it (a closed socket counted as connected until it went stale).
    However often it is cancelled meanwhile (``disconnect``'s own task can be
    cancelled too: shutdown, a timeout), the beat stays shielded until it ends."""
    import asyncio

    interval = heartbeat_seconds()
    while True:
        await asyncio.sleep(interval)
        running = asyncio.ensure_future(beat())
        cancelled = False
        while not running.done():
            try:
                await asyncio.shield(running)
            except asyncio.CancelledError:
                cancelled = True
            except Exception:
                break  # the beat failed, so it has ended: logged below
        failure = None if running.cancelled() else running.exception()
        if failure is not None:
            logger.error("Presence heartbeat failed", exc_info=failure)
        if cancelled or running.cancelled():
            raise asyncio.CancelledError


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
