"""
Base Django settings for Midnight Village.

Common settings shared across all environments.
"""

import os
from datetime import timedelta
from pathlib import Path

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent.parent

# Application definition
INSTALLED_APPS = [
    "daphne",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # Third-party
    "corsheaders",
    "channels",
    "rest_framework",
    "rest_framework_simplejwt",
    "rest_framework_simplejwt.token_blacklist",
    # Local
    "apps.core",
    "apps.onuw",
    "apps.observe",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    # What the answer cost the server, in its own header (apps/core/server_timing.py).
    # After CORS: a preflight is answered there and costs nothing to time.
    "apps.core.server_timing.ServerTimingMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

# A web app may read only the response headers CORS exposes: the app reads the
# server's clock from `Date` (to draw a stage's time against `deadline` and
# `stage_started_at`), and the field recorder reads `Server-Timing`
# (apps/core/server_timing.py), so a round trip splits into the network and the
# server. The allowed origins stay per environment.
CORS_EXPOSE_HEADERS = ["Date", "Server-Timing"]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"

# Custom User model
AUTH_USER_MODEL = "core.User"

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",
    },
]

# Internationalization
LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

# Static files (CSS, JavaScript, Images)
STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

# Default primary key field type
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# The request header that carries the client's address when a platform we trust
# writes it (the Vercel settings name it). None: the connection's own address.
CLIENT_ADDRESS_HEADER: str | None = None

# Django REST Framework
REST_FRAMEWORK = {
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework_simplejwt.authentication.JWTAuthentication",
        "rest_framework.authentication.SessionAuthentication",
    ],
    "DEFAULT_RENDERER_CLASSES": [
        "rest_framework.renderers.JSONRenderer",
    ],
    # DRF's own three, the JSON one made safe from deep nesting (apps/core/parsers.py).
    "DEFAULT_PARSER_CLASSES": [
        "apps.core.parsers.SafeJSONParser",
        "rest_framework.parsers.FormParser",
        "rest_framework.parsers.MultiPartParser",
    ],
    # Per client address, sized so that tables sharing one network are never
    # refused (apps/core/throttles.py says what these are for).
    "DEFAULT_THROTTLE_RATES": {
        # Guest accounts: two tables of ten signing in and each retrying once is 40.
        "sign_up": "60/minute",
        # GET /api/stats/online/ (the home screen polls it; a CDN absorbs most).
        "online_stats": "600/minute",
        # POST /api/observe/summary/ (apps/observe): a phone sends one at the end of
        # a game and when its tab is hidden; a room of tables shares one address.
        "field_summary": "600/hour",
        # GET /api/observe/report/: the owner reading it, apart from the summaries.
        "field_report": "60/hour",
    },
    "EXCEPTION_HANDLER": "apps.core.exceptions.custom_exception_handler",
}

# JWT Configuration
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=60),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    # Rotated, so the week slides with use; NOT blacklisted after rotation: a
    # renewal whose answer was lost (a slow server, two tabs) is sent again with
    # the same token, and a refusal then would sign the player out of their seat.
    # The blacklist app stays installed: an explicit logout still blacklists.
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": False,
    "AUTH_HEADER_TYPES": ("Bearer",),
}

# Logging configuration
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "verbose": {
            "format": "{levelname} {asctime} {module} {process:d} {thread:d} {message}",
            "style": "{",
        },
        "simple": {
            "format": "{levelname} {message}",
            "style": "{",
        },
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "simple",
        },
    },
    "root": {
        "handlers": ["console"],
        "level": "INFO",
    },
    "loggers": {
        "django": {
            "handlers": ["console"],
            "level": "INFO",
            "propagate": False,
        },
        "apps": {
            "handlers": ["console"],
            "level": "DEBUG",
            "propagate": False,
        },
    },
}

# The owner's key to the phones' speed report (GET /api/observe/report/, apps/observe):
# sent in the X-Field-Report-Key header by `just field-report`. Unset, the report
# answers 404 to everyone (closed by default; the summaries are still kept).
FIELD_REPORT_KEY = os.environ.get("FIELD_REPORT_KEY", "")

# Server-Timing detail (apps/core/server_timing.py): round trips, socket and timer
# messages and each part's time. OFF here and on the live server: those counts can
# depend on other players' hidden moves. On in development, the harness and tests.
SERVER_TIMING_DETAIL = False

# Rebuild the timers of games in progress when the server starts (the in-memory
# timer registry is lost with the process). Off in the test settings.
ONUW_RECOVER_TIMERS_ON_START = True

# How durable timers fire (apps/core/timers.py): "memory" = threading.Timer in
# this process (dev, tests, harness); "vercel_queue" = delayed queue messages
# handled by apps/core/queue_worker.py (no per-process state; see
# docs/dev/deploy-vercel.md).
ONUW_TIMER_BACKEND = "memory"
ONUW_TIMER_QUEUE_TOPIC = "onuw-timers"

# Shared secret of POST/GET /api/onuw/internal/sweep-timers/ (a platform cron;
# Vercel Cron sends "Authorization: Bearer $CRON_SECRET"). Empty = the endpoint
# refuses everything.
ONUW_CRON_SECRET = os.environ.get("CRON_SECRET", "")

# Presence: a socket row is "fresh" while its heartbeat is newer than the stale
# timeout; consumers beat every heartbeat interval (apps/onuw/presence.py).
ONUW_PRESENCE_HEARTBEAT_SECONDS = 15
ONUW_PRESENCE_STALE_SECONDS = 40

# "Where am I" (GET /api/me/table/): a lobby is the caller's table to resume only
# if something happened at it (Lobby.updated_at) within this many hours.
CORE_TABLE_RESUME_HOURS = 12

# A socket consumer that gets a group event it has no handler for: False (here, so
# production) logs a warning and drops it, so an instance older than a deploy keeps
# its players' sockets open; True raises like Channels does, so a misspelled event
# type in new code fails the tests (test, development and harness settings).
ONUW_STRICT_SOCKET_EVENTS = False

# The night (every phone with a choice sends one ``choose``) refuses night timers of 0 seconds
# and a minimum window under 5 seconds: with no deadline one idle phone could
# stall the table, and a window with no length singles out the Doppelganger.
# True only in the test, development and harness settings, which drive the night
# by hand; False here, so production (and Vercel) refuse them.
ONUW_ALLOW_UNTIMED_NIGHT = False

# Channels configuration
ASGI_APPLICATION = "config.asgi.application"
