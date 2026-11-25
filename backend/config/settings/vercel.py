"""
Vercel settings for Midnight Village.

The server runs as short-lived function instances (several at once, started and
stopped at any time), so nothing may live in one process: timers are durable
rows fired by Vercel Queues (``ONUW_TIMER_BACKEND = "vercel_queue"``), presence
is rows with heartbeats, the Channels layer is Redis, and nothing resets or
re-arms at start-up. See ``docs/dev/deploy-vercel.md``.

Environment (no secrets in the repo):

* ``SECRET_KEY``               required
* ``DATABASE_URL``             required, ``postgres://user:pass@host:port/dbname``
                               (use the POOLED connection string)
* ``REDIS_URL``                required (Channels layer)
* ``ALLOWED_HOSTS``            comma-separated; ``VERCEL_URL`` /
                               ``VERCEL_PROJECT_PRODUCTION_URL`` are added if set
* ``CORS_ALLOWED_ORIGINS``     comma-separated origins of the app
* ``CSRF_TRUSTED_ORIGINS``     comma-separated origins (admin only)
* ``DB_POOL_MAX_SIZE``         optional, default 5 (connections one instance keeps)
* ``DB_SSLMODE``               optional, default ``require``
"""

import os
from urllib.parse import unquote, urlparse

from .base import *
from .base import INSTALLED_APPS as _BASE_APPS


def _env_list(name: str) -> list[str]:
    return [
        item.strip() for item in os.environ.get(name, "").split(",") if item.strip()
    ]


def _database_from_url(url: str) -> dict:
    parsed = urlparse(url)
    if parsed.scheme not in ("postgres", "postgresql"):
        raise ValueError("DATABASE_URL must be a postgres:// URL")
    return {
        # Django's backend with its psycopg pool, checked on every borrow (the
        # pool's module says why it is not Django's own engine).
        "ENGINE": "apps.core.pooled_postgres",
        "NAME": parsed.path.lstrip("/"),
        "USER": unquote(parsed.username or ""),
        "PASSWORD": unquote(parsed.password or ""),
        "HOST": parsed.hostname or "",
        "PORT": str(parsed.port or 5432),
        # A pool, not persistent connections: under ASGI every request runs in its
        # own thread, so a per-thread connection is never reused. Django refuses a
        # pool with CONN_MAX_AGE set, so it is not read from the environment.
        "CONN_MAX_AGE": 0,
        # Safe behind PgBouncer in transaction mode (Neon's pooled host) and on a
        # direct host alike; prepared statements are already off (Django's default).
        "DISABLE_SERVER_SIDE_CURSORS": True,
        "OPTIONS": {
            "sslmode": os.environ.get("DB_SSLMODE", "require"),
            # A connection whose packets go unanswered (its path vanished while the
            # instance was frozen) fails within 3 s, not TCP's minutes.
            "tcp_user_timeout": 3_000,
            # Opening one: room for waking a database that scaled to zero (Neon
            # wakes in about a second).
            "connect_timeout": 5,
            "pool": pool_options(),
        },
    }


def pool_options() -> dict[str, int]:
    """A warm instance keeps up to ``max_size`` connections between requests
    (``apps/core/pooled_postgres`` says how a lent one is trusted). Worst case on
    the database: ``max_size`` per instance alive, running or frozen (5 x 20 =
    100); deploy-vercel.md, "Database connections"."""
    return {
        "min_size": 0,
        "max_size": int(os.environ.get("DB_POOL_MAX_SIZE", "5")),
        # psycopg closes at most one idle connection per this many seconds.
        "max_idle": 300,
        "max_lifetime": 1800,
        # The longest a request waits for its connection: one dead probe (3 s)
        # and one connect that wakes the database (5 s). Under the app's own 10 s,
        # so the phone gets an answer (an error) rather than its own timeout.
        "timeout": 8,
    }


SECRET_KEY = os.environ["SECRET_KEY"]

# Daphne's app only swaps in its own `runserver`; Vercel serves the ASGI app itself,
# and loading it imports Twisted (about 0.17 s of every cold start).
INSTALLED_APPS = [app for app in _BASE_APPS if app != "daphne"]

# Never on: it also keeps the debug harness endpoints (forced assignment,
# oracle, fire-timer) answering 403.
DEBUG = False

# The live Server-Timing header carries only the connection time and a rounded total:
# its counts can depend on other players' hidden moves (apps/core/server_timing.py).
SERVER_TIMING_DETAIL = False

# Vercel writes this header itself from the connection it received: the address the
# request limits count by (apps/core/throttles.py takes it only as one valid address).
CLIENT_ADDRESS_HEADER = "HTTP_X_VERCEL_FORWARDED_FOR"

ALLOWED_HOSTS = _env_list("ALLOWED_HOSTS")
for _host_var in ("VERCEL_URL", "VERCEL_PROJECT_PRODUCTION_URL"):
    _host = os.environ.get(_host_var)
    if _host and _host not in ALLOWED_HOSTS:
        ALLOWED_HOSTS.append(_host)

DATABASES = {"default": _database_from_url(os.environ["DATABASE_URL"])}

CHANNEL_LAYERS = {
    "default": {
        # channels_redis, with a commit's messages sent at once (core/channel_layer.py).
        "BACKEND": "apps.core.channel_layer.BatchingRedisChannelLayer",
        "CONFIG": {"hosts": [os.environ["REDIS_URL"]]},
    },
}

# Durable timers fired by Vercel Queues; presence is row-based with heartbeats.
ONUW_TIMER_BACKEND = "vercel_queue"
ONUW_TIMER_QUEUE_TOPIC = os.environ.get("ONUW_TIMER_QUEUE_TOPIC", "onuw-timers")
# Belt and braces: even if something imports config.asgi, never run start-up
# recovery (run_startup_recovery also refuses under the queue backend).
ONUW_RECOVER_TIMERS_ON_START = False

# Security
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000
SECURE_CONTENT_TYPE_NOSNIFF = True

CORS_ALLOWED_ORIGINS = _env_list("CORS_ALLOWED_ORIGINS")
CSRF_TRUSTED_ORIGINS = _env_list("CSRF_TRUSTED_ORIGINS")
