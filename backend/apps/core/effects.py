"""
Side effects that must wait for the surrounding transaction to commit.

WebSocket sends and timer changes made inside an atomic block must not happen
until it has committed: otherwise a rollback would leave players told about
something that never happened (and its timer cancelled). ``transaction.on_commit``
runs at once when there is no open transaction.

Shared by every app (game logic, host handover, presence, durable timers).
"""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

from django.db import transaction

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

from apps.core import timers


def after_commit(func: Callable[[], None]) -> None:
    """Run func once the outermost atomic block commits (robust: log, don't abort)."""
    transaction.on_commit(func, robust=True)


def send_after_commit(messages: list[tuple[str, dict[str, Any]]]) -> None:
    """Send channel messages (group, event) once the transaction commits.

    The payloads are built by the caller inside the transaction, so they
    describe the state that is about to be committed.
    """
    channel_layer = get_channel_layer()
    if channel_layer is None or not messages:
        return

    def _send() -> None:
        send = async_to_sync(channel_layer.group_send)
        for group, event in messages:
            send(group, event)

    after_commit(_send)


def schedule_after_commit(
    key: str, delay: float, job: str, params: dict[str, Any] | None = None
) -> None:
    """Schedule a named timer job once the transaction commits (see timers.py)."""
    after_commit(lambda: timers.schedule(key, delay, job, params))


def cancel_after_commit(key: str) -> None:
    after_commit(lambda: timers.cancel(key))
