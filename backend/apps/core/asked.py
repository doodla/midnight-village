"""
A late, lost request must not overwrite a newer tap (issue #16).

A phone may put ``"asked": <int>`` in a request: when the tap was made on that
phone, in milliseconds, strictly increasing per phone. The server never compares
it with its own clock, only with the newest ``asked`` it applied for the same
thing (a lane), kept as an entry ``[scope, asked]``:

- a lobby settings key or practice: ``Lobby.asked[key] = [user_id, asked]``;
- a game lane (``vote``, ``ready``): ``PlayerRole.asked[lane] = [stage, asked]``.

A request is STALE when the stored entry has the same scope (the same user; the
same stage) and a GREATER ``asked``: it was tapped before a tap already applied,
so it changes nothing and is answered ``409 stale_request``. An equal ``asked``
is the same tap sent again (not stale). Another scope is never compared: a host
handover, or a new stage, starts afresh. A request without ``asked`` (an older
phone) is never stale and leaves the entries as they are.

The compare and the store run under the row lock the request already holds.
"""

from __future__ import annotations

from typing import Any

from rest_framework import status
from rest_framework.response import Response

FIELD = "asked"
STALE_CODE = "stale_request"
STALE_DETAIL = "A newer tap from this phone already got there."
BAD_DETAIL = "asked must be a whole number (when the phone was tapped)."


class StaleRequestError(Exception):
    """A request tapped before one already applied: nothing changes."""


def read(data: Any) -> tuple[int | None, Response | None]:
    """The request's ``asked``: (None, None) when absent; a 400 ``bad_request``
    when present but not a plain non-negative JSON integer (a bool is not one)."""
    if not isinstance(data, dict) or FIELD not in data:
        return None, None
    asked = data[FIELD]
    if type(asked) is not int or asked < 0:
        return None, Response(
            {"detail": BAD_DETAIL, "code": "bad_request"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    return asked, None


def stale_response() -> Response:
    """409 ``stale_request``: the same body everywhere; nothing was changed."""
    return Response(
        {"detail": STALE_DETAIL, "code": STALE_CODE},
        status=status.HTTP_409_CONFLICT,
    )


def is_stale(entries: Any, lane: str, scope: Any, asked: int | None) -> bool:
    """True when ``entries[lane]`` is ``[scope, newer]`` with ``newer > asked``."""
    if asked is None or not isinstance(entries, dict):
        return False
    entry = entries.get(lane)
    if not isinstance(entry, list) or len(entry) != 2:
        return False
    stored_scope, stored = entry
    return stored_scope == scope and type(stored) is int and stored > asked


def fresh(
    entries: Any, given: dict[str, Any], scope: Any, asked: int | None
) -> dict[str, Any]:
    """The keys of ``given`` that are not stale (all of them without ``asked``)."""
    return {k: v for k, v in given.items() if not is_stale(entries, k, scope, asked)}


def noted(
    entries: Any, lanes: list[str], scope: Any, asked: int | None
) -> dict[str, Any]:
    """``entries`` with every one of ``lanes`` set to ``[scope, asked]`` (a copy;
    unchanged when the request carried no ``asked``)."""
    out = dict(entries) if isinstance(entries, dict) else {}
    if asked is not None:
        for lane in lanes:
            out[lane] = [scope, asked]
    return out
