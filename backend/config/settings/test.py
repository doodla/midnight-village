"""
Test settings for Midnight Village.

Optimized for fast test execution while maintaining PostgreSQL parity.
"""

import os

from dotenv import load_dotenv

from config.test_database import run_database_name

from .base import *

load_dotenv()

SECRET_KEY = "django-insecure-test-key-not-for-production"

DEBUG = False

# The Server-Timing header's counts and parts (off live: base.py says why).
SERVER_TIMING_DETAIL = True

# A socket event type with no handler is a bug in new code: fail, do not drop it
# (production, base.py, drops it so an older instance keeps its sockets open).
ONUW_STRICT_SOCKET_EVENTS = True

# Tests drive the night by hand: zero night timers are allowed (see base.py).
ONUW_ALLOW_UNTIMED_NIGHT = True

# Tests never recover timers at import time (they build their own state).
ONUW_RECOVER_TIMERS_ON_START = False

ALLOWED_HOSTS = ["localhost", "127.0.0.1", "testserver"]

# Use PostgreSQL for test environment parity (per spec requirement)
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ.get("DB_NAME", "midnight_village_test"),
        "USER": os.environ.get("DB_USER", ""),
        "PASSWORD": os.environ.get("DB_PASSWORD", ""),
        "HOST": os.environ.get("DB_HOST", "localhost"),
        "PORT": os.environ.get("DB_PORT", "5432"),
        # Each run has its own database, so runs side by side never collide
        # (config/test_database.py; leftovers are dropped in tests/conftest.py).
        "TEST": {
            "NAME": run_database_name(
                os.environ.get("DB_NAME", "midnight_village_test"), os.getpid()
            )
        },
    }
}

# Faster password hashing for tests
PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.MD5PasswordHasher",
]

# Disable logging during tests
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {
        "null": {
            "class": "logging.NullHandler",
        },
    },
    "root": {
        "handlers": ["null"],
    },
}

# Channels - Use in-memory layer for fast test execution
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer",
    },
}

# Effectively disable throttling during tests with very high rates
REST_FRAMEWORK = {
    **globals().get("REST_FRAMEWORK", {}),
    "DEFAULT_THROTTLE_CLASSES": [],
    "DEFAULT_THROTTLE_RATES": {
        "sign_up": "1000/minute",
        "online_stats": "1000/minute",
        "field_summary": "1000/minute",
        "field_report": "1000/minute",
    },
}
