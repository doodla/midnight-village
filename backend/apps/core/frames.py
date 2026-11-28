"""Nothing a socket RECEIVES writes to the database (CLAUDE.md principle 7).

A player's action goes over HTTP; a socket only carries events out. So while a consumer
handles a frame the phone sent (``websocket.receive``), every statement that writes is
refused with ``WriteFromAFrameError``, on every server (live too: nothing writes there today,
so the refusal changes no play, and a mistake cannot ship quietly).

``TolerantJsonWebsocketConsumer.dispatch`` (every routed consumer's base; a test walks the
router) runs the frame's handler inside ``received()``. The mark is a context variable,
so it follows the handler into ``database_sync_to_async`` and into any task it starts.
A socket's own work (connect, disconnect, its heartbeat's presence repair, group events)
is not a received frame and writes as before. ``refuse_writes_from_frames`` is put on
every database connection as it opens (``CoreConfig.ready``).
"""

from __future__ import annotations

import contextlib
import contextvars
import re
import traceback
from collections.abc import Iterator

_RECEIVING: contextvars.ContextVar[str | None] = contextvars.ContextVar(
    "received_frame", default=None
)

WRITES = frozenset(
    {
        "INSERT",
        "UPDATE",
        "DELETE",
        "MERGE",
        "TRUNCATE",
        "CREATE",
        "ALTER",
        "DROP",
        "COPY",
    }
)
_WORD = re.compile(r"[A-Za-z]+")


class WriteFromAFrameError(RuntimeError):
    """A statement that writes ran while a consumer handled a frame a phone sent."""


@contextlib.contextmanager
def received(consumer: str) -> Iterator[None]:
    """Mark the handling of one frame a phone sent to ``consumer``."""
    token = _RECEIVING.set(consumer)
    try:
        yield
    finally:
        _RECEIVING.reset(token)


def is_write(sql: str) -> bool:
    """The statement changes data or schema (its first word; anywhere, after a WITH)."""
    words = _WORD.findall(sql[:2000])
    if not words:
        return False
    first = words[0].upper()
    if first == "WITH":
        return any(word.upper() in WRITES for word in words)
    return first in WRITES


def refuse_writes_from_frames(execute, sql, params, many, context):
    consumer = _RECEIVING.get()
    if consumer is not None and is_write(str(sql)):
        raise WriteFromAFrameError(
            f"{_writer()}: {consumer} wrote to the database while handling a frame a"
            f" phone sent ({str(sql)[:80]}...). A player's action goes over HTTP (CLAUDE.md"
            " principle 7); a socket only sends events. Fix: move it to a view."
        )
    return execute(sql, params, many, context)


def _writer() -> str:
    """file:line of the project's innermost code that made the write."""
    for frame in reversed(traceback.extract_stack()):
        name = frame.filename
        if "/apps/" in name and not name.endswith("frames.py"):
            return f"apps/{name.rsplit('/apps/', 1)[-1]}:{frame.lineno}"
    return "(no app frame)"


def install(connection, **_kwargs) -> None:
    """Put the refusal on ``connection`` (the ``connection_created`` receiver), first:
    ``execute_wrapper()`` removes the last wrapper when its block ends, so a connection
    that opens inside one must not have the refusal last."""
    if refuse_writes_from_frames not in connection.execute_wrappers:
        connection.execute_wrappers.insert(0, refuse_writes_from_frames)
