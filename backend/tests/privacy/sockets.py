# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""The viewer's sockets in the two-deal test (two_deals.py): its real consumers, and every
frame they send, recorded into what the viewer is told."""

from __future__ import annotations

import asyncio
import contextlib
import json
from collections.abc import Callable
from typing import Any
from unittest.mock import patch

from asgiref.sync import async_to_sync

# The sockets a phone holds at a table, each a real consumer: every frame of each is
# kept, and each must be heard beating in every game (test_two_deals.py).
SOCKETS = ("lobby", "game")


class _Joins:
    """The channel layer as a socket's consumer sees it: the groups it joins are kept
    (that is where the layer delivers to it); everything else is the real layer's."""

    def __init__(self, layer: Any, joined: set[str]) -> None:
        self.layer, self.joined = layer, joined

    async def group_add(self, group: str, channel: str) -> None:
        self.joined.add(group)

    async def group_discard(self, group: str, channel: str) -> None:
        self.joined.discard(group)

    def __getattr__(self, name: str) -> Any:
        return getattr(self.layer, name)


class ViewerSocket:
    """One of the viewer's sockets: its REAL consumer, and every frame it sends.

    Channels would run the consumer's database work in another thread, whose connection
    cannot see the test's transaction. Here every call runs through ``async_to_sync``
    from the test's thread, so the consumer's thread-sensitive database work runs in
    this thread, on this connection (Channels' own closing of "old" connections around
    it is switched off: inside the test's transaction it would close this one). The
    heartbeat's timing is the one thing not the consumer's own: its loop is stopped as
    connect starts it, and ``beat`` does one beat as the loop would (the beat's
    database work, then its frame)."""

    def __init__(self, table: Any, kind: str, cls: type, **kwargs: str) -> None:
        self.table, self.kind = table, kind
        self.joined: set[str] = set()
        self.since = len(table.layer.sent)  # what the layer carried before it opened
        consumer = cls()
        consumer.scope = {
            "type": "websocket",
            "user": table.players[table.viewer].user,
            "url_route": {"kwargs": kwargs},
        }
        consumer.channel_layer = _Joins(table.layer, self.joined)
        consumer.channel_name = f"viewer-{kind}-socket"
        consumer.base_send = self._sent
        self.consumer = consumer
        self._run(self._open)

    async def _sent(self, message: dict[str, Any]) -> None:
        frame = json.loads(message["text"]) if "text" in message else message
        self.table.told.append(["ws", self.kind, frame])

    async def _open(self) -> None:
        await self.consumer.websocket_connect({"type": "websocket.connect"})
        task = getattr(self.consumer, "_heartbeat_task", None)
        if task is not None:
            task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await task

    def _run(self, work: Callable[..., Any], *args: Any) -> None:
        with (
            patch("channels.db.close_old_connections", lambda: None),
            self.table._capture_on_commit(execute=True),
        ):
            async_to_sync(work)(*args)

    def deliver(self, index: int, group: str, message: dict[str, Any]) -> None:
        if index >= self.since and group in self.joined:
            self._run(self.consumer.dispatch, message)

    def beat(self) -> None:
        with self.table._capture_on_commit(execute=True):
            self.consumer._beat_work()
        self._run(self.consumer._send_beat)
