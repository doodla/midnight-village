"""
Vercel Queues subscriber for the durable timers (``ONUW_TIMER_BACKEND = "vercel_queue"``).

Registered in ``pyproject.toml`` as::

    [[tool.vercel.subscribers]]
    entrypoint = "apps.onuw.queue_worker"

A timer message is ``{"key", "token"}`` (see ``apps/onuw/timers.py``). Delivery is
at-least-once and a queued message cannot be cancelled, so everything is decided
by the ``ScheduledTimer`` row: ``timers.fire`` runs the job only if the row still
exists with that token and is due, deleting the row in the same transaction. A
stale token, a cancelled key or a duplicate delivery does nothing. A message that
arrives EARLY (beyond the clock-skew tolerance) is re-sent with the remaining
delay instead of running early.

``vercel.queue`` is imported only here, and only if installed (it is an optional
dependency: dev, tests and the debug harness never need it).
"""

import logging
import os
from typing import Any

import django
from django.apps import apps

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.vercel")
if not apps.ready:  # a no-op inside a process Django already set up (tests)
    django.setup()

from asgiref.sync import sync_to_async

from apps.onuw import timers

logger = logging.getLogger(__name__)


def handle_message(payload: Any) -> str:
    """Process one timer message (synchronous; run in a thread by the handler).

    Returns what happened: "ran", "stale", "requeued" or "invalid". Closes this
    thread's database connections afterwards.
    """
    try:
        key = payload.get("key") if isinstance(payload, dict) else None
        token = payload.get("token") if isinstance(payload, dict) else None
        if not isinstance(key, str) or not isinstance(token, str):
            logger.warning("Ignoring a malformed timer message: %r", payload)
            return "invalid"
        result = timers.fire(key, token)
        if result.status == "early":
            timers.send_message(key, token, result.remaining)
            return "requeued"
        return result.status
    except Exception:
        # Let the queue redeliver: the row is still there if the job failed.
        logger.exception("Timer message failed: %r", payload)
        raise
    finally:
        timers.release_connections()


async def process(payload: Any) -> str:
    """Async wrapper used by the subscriber: the work runs in a thread."""
    return await sync_to_async(handle_message, thread_sensitive=False)(payload)


# A failing job is retried by the queue: after RETRY_AFTER_SECONDS, for at most
# MAX_DELIVERIES deliveries. After that the message is dropped; the timer row
# is still there, and the sweep / lazy repair publish it again.
RETRY_AFTER_SECONDS = 15
MAX_DELIVERIES = 5


def retry_decision(delivery_count: int) -> int | None:
    """Seconds to ask the queue to retry after, or None to give up."""
    return RETRY_AFTER_SECONDS if delivery_count < MAX_DELIVERIES else None


try:  # pragma: no cover - only on Vercel, where the package is installed
    # pyrefly: ignore [missing-import]
    from vercel.queue import Message, RetryAfter, subscribe

    @subscribe(topic=f"{timers.queue_topic()}*")
    async def handler(message: Message[dict]) -> None:
        try:
            await process(message.payload)
        except Exception:
            # handle_message already logged it; the job rolled back, so the
            # timer row is intact. Ask the SDK to redeliver (RetryAfter), or
            # give up after MAX_DELIVERIES (the sweep repairs it later).
            delay = retry_decision(message.metadata.delivery_count)
            if delay is None:
                return
            raise RetryAfter(delay) from None

except ImportError:  # pragma: no cover
    pass
