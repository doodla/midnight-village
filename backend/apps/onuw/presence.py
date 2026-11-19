"""
Who is connected, from socket rows (``SocketPresence``) instead of counters.

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
they feed: ``services.register_connection`` / ``unregister_connection`` /
``check_game_presence`` for a game, ``host.register_lobby_connection`` /
``unregister_lobby_connection`` / ``check_lobby_presence`` for a lobby.
"""

from __future__ import annotations

import logging
from datetime import timedelta
from typing import Any

from django.conf import settings
from django.db.models import F, Min
from django.db.models.functions import Now

from apps.onuw import timers

logger = logging.getLogger(__name__)

DEFAULT_HEARTBEAT_SECONDS = 15
DEFAULT_STALE_SECONDS = 40


def heartbeat_seconds() -> float:
    return float(
        getattr(settings, "ONUW_PRESENCE_HEARTBEAT_SECONDS", DEFAULT_HEARTBEAT_SECONDS)
    )


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


# ── Reads ───────────────────────────────────────────────────────────────────


def fresh_rows(
    *, game_id: Any = None, lobby_id: Any = None, user_id: int | None = None
):
    """Socket rows of a scope seen within the staleness timeout."""
    from .models import SocketPresence

    queryset = SocketPresence.objects.filter(last_seen__gte=cutoff())
    if game_id is not None:
        queryset = queryset.filter(game_id=game_id)
    if lobby_id is not None:
        queryset = queryset.filter(lobby_id=lobby_id)
    if user_id is not None:
        queryset = queryset.filter(user_id=user_id)
    return queryset


def connected_user_ids(*, game_id: Any = None, lobby_id: Any = None) -> set[int]:
    """Users with at least one fresh socket in the scope."""
    return set(
        fresh_rows(game_id=game_id, lobby_id=lobby_id).values_list("user_id", flat=True)
    )


def annotate(player_roles: list, game_id: Any) -> list:
    """Set ``is_connected`` on each PlayerRole from ONE query (returns the list)."""
    connected = connected_user_ids(game_id=game_id)
    for pr in player_roles:
        pr.is_connected = pr.user_id in connected
    return player_roles


async def heartbeat_loop(beat) -> None:
    """Run ``await beat()`` every heartbeat interval until cancelled (one task
    per consumer). A failing beat is logged and the loop carries on."""
    import asyncio

    interval = heartbeat_seconds()
    while True:
        await asyncio.sleep(interval)
        try:
            await beat()
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("Presence heartbeat failed")


# ── The durable check ───────────────────────────────────────────────────────


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
        from . import host, services

        if scope == "game":
            if services.check_game_presence(scope_id, user_id):
                # Host handover has its own transaction and lock order (Lobby
                # then LobbyMember): it runs only after this one has committed.
                services._after_commit(
                    lambda: host.game_presence_changed(scope_id, user_id, False)
                )
        elif scope == "lobby":
            host.check_lobby_presence(scope_id, user_id)
    except Exception:
        logger.exception(
            "Presence check failed for %s %s user %s", scope, scope_id, user_id
        )
        raise  # fire() rolls back and keeps the row: the check is retried
