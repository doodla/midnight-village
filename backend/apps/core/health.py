"""The deep health check: can this build reach its database and its Redis right now?

``GET /api/health/?deep=1`` (``views_home.health_check``) answers::

    {"status": "ok", "commit": "<sha>", "database": "ok", "redis": "ok"}

with 200 when every part is ok and 503 when one is ``"failed"``. It says nothing else:
no error text, no host, no timing (the reason is logged on the server). ``redis`` is
``"not used"`` where the channel layer is in memory (development, tests).

Each part runs on its own thread with its own connection and has ``TIMEOUT`` seconds;
a part that does not answer in time is ``"failed"`` and the answer does not wait for it.
The database part opens a fresh connection (never the request's), runs ``SELECT 1`` and
closes it; the Redis part sends one ``PING`` on a fresh client. So a call costs one
connection each and one Redis command, and writes nothing. It wakes a sleeping Neon
compute, which is what the scheduled watch wants to know about (docs/dev/deploy-vercel.md,
"The watch between merges").
"""

from __future__ import annotations

import logging
import time
from concurrent.futures import ThreadPoolExecutor
from concurrent.futures import TimeoutError as PartTimedOut

from django.conf import settings
from django.db import connections

logger = logging.getLogger(__name__)

TIMEOUT = 5.0  # seconds per part: a Neon compute wakes in about one


def database_answers() -> bool:
    conn = connections.create_connection("default")
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT 1")
            return cursor.fetchone() == (1,)
    finally:
        conn.close()


def redis_url() -> str | None:
    """The Redis the channel layer uses, or None when it uses none."""
    hosts = settings.CHANNEL_LAYERS["default"].get("CONFIG", {}).get("hosts") or []
    if not hosts:
        return None
    host = hosts[0]
    return host if isinstance(host, str) else host.get("address")


def redis_answers(url: str) -> bool:
    import redis  # channels_redis's own client

    client = redis.Redis.from_url(
        url, socket_timeout=TIMEOUT, socket_connect_timeout=TIMEOUT
    )
    try:
        return client.ping() is True
    finally:
        client.close()


def deep_health() -> dict[str, str]:
    """{"database": ..., "redis": ...}: each "ok", "failed" or (Redis) "not used"."""
    url = redis_url()
    parts = {"database": database_answers}
    if url:
        parts["redis"] = lambda: redis_answers(url)
    pool = ThreadPoolExecutor(max_workers=len(parts))
    futures = {name: pool.submit(check) for name, check in parts.items()}
    deadline = (
        time.monotonic() + TIMEOUT
    )  # the parts run side by side: one limit for all
    result: dict[str, str] = {}
    for name, future in futures.items():
        try:
            left = max(0.0, deadline - time.monotonic())
            result[name] = "ok" if future.result(timeout=left) else "failed"
        except PartTimedOut:
            logger.warning("deep health: %s did not answer in %s s", name, TIMEOUT)
            result[name] = "failed"
        except Exception as e:
            logger.warning("deep health: %s failed: %s", name, type(e).__name__)
            result[name] = "failed"
    pool.shutdown(wait=False, cancel_futures=True)  # never wait for a part that hangs
    result.setdefault("redis", "not used")
    return result
