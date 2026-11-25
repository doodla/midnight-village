"""Every answer says what it cost the server: a ``Server-Timing`` header.

On the live server (``SERVER_TIMING_DETAIL`` off, the default and the Vercel
settings) it carries only what cannot tell anyone about the game:

* ``connect``: how long this request took to get its database connection, only
  when one was opened for it (TCP, TLS and the sign-in). Live, a warm instance's
  pool lends a connection again (``apps.core.pooled_postgres``): no ``connect``;
* ``total``: from this middleware's start to the answer, rounded to
  ``TOTAL_STEP_MS``, so it says no more than a stopwatch on the phone does.

Nothing else: a count of round trips, socket or timer messages, or a part's exact
time can depend on what OTHER players did (the host's "move on" in window 1 does one
more write when the Doppelganger's copy acted), so it never goes on a live answer.
``tests/perf/test_header_hides_play.py`` holds that rule.

With ``SERVER_TIMING_DETAIL`` on (development, the harness and the tests) it also
carries ``db`` (round trips and their time), ``sockets`` (channel layer sends made
through ``apps.core.effects``; the few lobby events a view sends itself are not
counted) and ``queue`` (timer messages): ``just server-timing`` and a local browser
read them.

It never opens a connection the request would not have opened (the connection is
timed where Django makes it), and nothing here can fail or delay an answer: a
problem building the header leaves the header out.
"""

from __future__ import annotations

import contextlib
import threading
import time
from collections.abc import Callable
from typing import Any

from django.conf import settings
from django.db import connection
from django.db.backends.base.base import BaseDatabaseWrapper
from django.http import HttpRequest, HttpResponse

TOTAL_STEP_MS = 50
DETAIL_PARTS = ("db", "sockets", "queue")

_current = threading.local()


def note(part: str, seconds: float) -> None:
    """Add one ``part`` (``connect``, ``db``, ``sockets``, ``queue``) of ``seconds``
    to this request's header; nothing outside a request."""
    with contextlib.suppress(Exception):
        parts: dict[str, list[float]] | None = getattr(_current, "parts", None)
        if parts is None:
            return
        entry = parts.setdefault(part, [0, 0.0])
        entry[0] += 1
        entry[1] += seconds


def _timed_connect(original: Callable[..., Any]) -> Callable[..., Any]:
    def connect(self: BaseDatabaseWrapper) -> Any:
        began = time.perf_counter()
        try:
            return original(self)
        finally:
            # A connection the live pool lent again was not made: no ``connect``.
            if not getattr(self, "reused_connection", False):
                note("connect", time.perf_counter() - began)

    connect.timed_by_server_timing = True  # type: ignore[attr-defined]
    return connect


def install() -> None:
    """Time every database connection where Django makes it (once per process)."""
    if not getattr(BaseDatabaseWrapper.connect, "timed_by_server_timing", False):
        BaseDatabaseWrapper.connect = _timed_connect(BaseDatabaseWrapper.connect)


def header(parts: dict[str, list[float]], total: float, *, detail: bool) -> str:
    entries = []
    if "connect" in parts:
        entries.append(f"connect;dur={parts['connect'][1] * 1000:.1f}")
    if detail:
        for part in DETAIL_PARTS:
            count, seconds = parts.get(part, [0, 0.0])
            entries.append(f'{part};dur={seconds * 1000:.1f};desc="{int(count)}"')
        entries.append(f"total;dur={total * 1000:.1f}")
    else:
        step = TOTAL_STEP_MS
        entries.append(f"total;dur={round(total * 1000 / step) * step}")
    return ", ".join(entries)


class ServerTimingMiddleware:
    def __init__(self, get_response: Callable[[HttpRequest], HttpResponse]) -> None:
        self.get_response = get_response
        install()

    def __call__(self, request: HttpRequest) -> HttpResponse:
        started = time.perf_counter()
        detail = bool(getattr(settings, "SERVER_TIMING_DETAIL", False))
        parts: dict[str, list[float]] = {}
        _current.parts = parts

        def timed(execute: Callable[..., Any], *args: Any) -> Any:
            began = time.perf_counter()
            try:
                return execute(*args)
            finally:
                note("db", time.perf_counter() - began)

        try:
            if detail:
                with connection.execute_wrapper(timed):
                    response = self.get_response(request)
            else:
                response = self.get_response(request)
        finally:
            _current.parts = None
        with contextlib.suppress(Exception):
            total = time.perf_counter() - started
            response["Server-Timing"] = header(parts, total, detail=detail)
        return response
