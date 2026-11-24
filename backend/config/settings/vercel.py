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
* ``DB_CONN_MAX_AGE``          optional, default 0
"""

import os
from urllib.parse import unquote, urlparse

from .base import *


def _env_list(name: str) -> list[str]:
    return [
        item.strip() for item in os.environ.get(name, "").split(",") if item.strip()
    ]


def _database_from_url(url: str) -> dict:
    parsed = urlparse(url)
    if parsed.scheme not in ("postgres", "postgresql"):
        raise ValueError("DATABASE_URL must be a postgres:// URL")
    return {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": parsed.path.lstrip("/"),
        "USER": unquote(parsed.username or ""),
        "PASSWORD": unquote(parsed.password or ""),
        "HOST": parsed.hostname or "",
        "PORT": str(parsed.port or 5432),
        # Instances are short-lived and the URL is a pooled endpoint: do not
        # hold connections between requests unless asked to.
        "CONN_MAX_AGE": int(os.environ.get("DB_CONN_MAX_AGE", "0")),
        "OPTIONS": {"sslmode": os.environ.get("DB_SSLMODE", "require")},
    }


SECRET_KEY = os.environ["SECRET_KEY"]

# Never on: it also keeps the debug harness endpoints (forced assignment,
# oracle, fire-timer) answering 403.
DEBUG = False

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
        "BACKEND": "channels_redis.core.RedisChannelLayer",
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
