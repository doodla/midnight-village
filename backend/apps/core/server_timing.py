"""Every answer says what it cost the server: a ``Server-Timing`` header.

Read from outside (a browser's network panel, ``curl -i``, the deployed check), it
splits a slow answer into its parts with no account on the hosting:

* ``connect``: opening this request's database connection (TCP, TLS and sign-in to
  the database; the live settings close it after every request).
* ``db``: the time spent in database round trips, and how many (``desc``).
* ``sockets``: handing socket messages to the channel layer (Redis on the live
  server), and how many; they go before the answer leaves. Counted where they go
  through ``apps.core.effects`` (every game event); the few lobby events a view sends
  itself (the deal's ``game_started``, join, leave, play again) are in the rest.
* ``queue``: publishing timer messages (Vercel Queues on the live server), and how
  many; also before the answer.
* ``total``: from this middleware's start to the answer; the rest of ``total`` is
  Python (the view, the serialiser, the middleware after this one).

Per request and per thread: a request runs in one thread (Django's handler), and its
after-commit sends run in it too. The numbers say nothing about any other player.
"""

from __future__ import annotations

import contextlib
import threading
import time
from collections.abc import Callable
from typing import Any

from django.db import connection
from django.http import HttpRequest, HttpResponse

_current = threading.local()


def note(part: str, seconds: float) -> None:
    """Add one ``part`` (``sockets``, ``queue``) of ``seconds`` to this request's
    header; nothing outside a request."""
    parts: dict[str, list[float]] | None = getattr(_current, "parts", None)
    if parts is None:
        return
    entry = parts.setdefault(part, [0, 0.0])
    entry[0] += 1
    entry[1] += seconds


class ServerTimingMiddleware:
    def __init__(self, get_response: Callable[[HttpRequest], HttpResponse]) -> None:
        self.get_response = get_response

    def __call__(self, request: HttpRequest) -> HttpResponse:
        started = time.perf_counter()
        parts: dict[str, list[float]] = {}
        _current.parts = parts
        connect = 0.0
        if connection.connection is None:
            connect = time.perf_counter()
            # A database that cannot be reached: the view meets the same error, as
            # it did before this header existed.
            with contextlib.suppress(Exception):
                connection.ensure_connection()
            connect = time.perf_counter() - connect

        def timed(execute: Callable[..., Any], *args: Any) -> Any:
            began = time.perf_counter()
            try:
                return execute(*args)
            finally:
                note("db", time.perf_counter() - began)

        try:
            with connection.execute_wrapper(timed):
                response = self.get_response(request)
        finally:
            _current.parts = None
        total = time.perf_counter() - started
        entries = [f"connect;dur={connect * 1000:.1f}"]
        for part in ("db", "sockets", "queue"):
            count, seconds = parts.get(part, [0, 0.0])
            entries.append(f'{part};dur={seconds * 1000:.1f};desc="{int(count)}"')
        entries.append(f"total;dur={total * 1000:.1f}")
        response["Server-Timing"] = ", ".join(entries)
        return response
