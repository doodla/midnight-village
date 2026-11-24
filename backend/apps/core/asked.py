"""
A late, lost request must not overwrite a newer tap (issue #16).

A phone may put ``"asked": <int>`` in a request: when the tap was made on that
phone, in milliseconds since the Unix epoch by the phone's own clock (never a
count from app start, which would start again with the app), strictly increasing
per phone, at most 2**53 - 1 (what every phone's JSON number holds exactly). The server never compares
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
MOST = 2**53 - 1
STALE_CODE = "stale_request"
STALE_DETAIL = "A newer tap from this phone already got there."
BAD_DETAIL = "asked must be a whole number (when the phone was tapped)."


class StaleRequestError(Exception):
    """A request tapped before one already applied: nothing changes. ``newest``
    is the stored ``asked`` it lost to (the requester's own, for its own lane)."""

    def __init__(self, newest: int) -> None:
        super().__init__(newest)
        self.newest = newest


def read(data: Any) -> tuple[int | None, Response | None]:
    """The request's ``asked``: (None, None) when absent; a 400 ``bad_request``
    when present but not a plain non-negative JSON integer (a bool is not one)."""
    if not isinstance(data, dict) or FIELD not in data:
        return None, None
    asked = data[FIELD]
    if type(asked) is not int or not 0 <= asked <= MOST:
        return None, Response(
            {"detail": BAD_DETAIL, "code": "bad_request"},
            status=status.HTTP_400_BAD_REQUEST,
        )
    return asked, None


def stale_response(newest: int) -> Response:
    """409 ``stale_request``, the one body every stale refusal has; nothing was
    changed. ``newest`` is the stored ``asked`` the request lost to: always the
    requester's own number for its own lane (an entry of another user or another
    stage is never compared, so never told), so a phone whose newest tap lost
    (its clock is behind) can send it again with an ``asked`` above it."""
    return Response(
        {"detail": STALE_DETAIL, "code": STALE_CODE, "newest": newest},
        status=status.HTTP_409_CONFLICT,
    )


def newer(entries: Any, lane: str, scope: Any, asked: int | None) -> int | None:
    """The stored ``asked`` when ``entries[lane]`` is ``[scope, stored]`` with
    ``stored > asked`` (the request is stale), else None."""
    if asked is None or not isinstance(entries, dict):
        return None
    entry = entries.get(lane)
    if not isinstance(entry, list) or len(entry) != 2:
        return None
    stored_scope, stored = entry
    if stored_scope == scope and type(stored) is int and stored > asked:
        return stored
    return None


def fresh(
    entries: Any, given: dict[str, Any], scope: Any, asked: int | None
) -> tuple[dict[str, Any], int | None]:
    """The keys of ``given`` that are not stale (all of them without ``asked``),
    and the largest stored ``asked`` among the stale ones (None if none is)."""
    kept: dict[str, Any] = {}
    lost: list[int] = []
    for key, value in given.items():
        stored = newer(entries, key, scope, asked)
        if stored is None:
            kept[key] = value
        else:
            lost.append(stored)
    return kept, max(lost, default=None)


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
