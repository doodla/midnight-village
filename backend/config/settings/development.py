"""
Development settings for Midnight Village.

These settings are for local development only.
"""

import os

from dotenv import load_dotenv

from .base import *
from .base import REST_FRAMEWORK

load_dotenv()

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = os.environ.get(
    "SECRET_KEY", "django-insecure-dev-key-change-in-production"
)

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True

ALLOWED_HOSTS = ["localhost", "127.0.0.1"]

# Database
# Note: On macOS with Homebrew, DB_USER/DB_PASSWORD default to empty (uses system user)
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ.get("DB_NAME", "midnight_village_dev"),
        "USER": os.environ.get("DB_USER", ""),
        "PASSWORD": os.environ.get("DB_PASSWORD", ""),
        "HOST": os.environ.get("DB_HOST", "localhost"),
        "PORT": os.environ.get("DB_PORT", "5432"),
    }
}

# Add browsable API renderer for development (extends base REST_FRAMEWORK)
REST_FRAMEWORK["DEFAULT_RENDERER_CLASSES"] = [
    "rest_framework.renderers.JSONRenderer",
    "rest_framework.renderers.BrowsableAPIRenderer",
]

# Channels - Use in-memory layer for simple local development
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels.layers.InMemoryChannelLayer",
    },
}

# CORS settings for development
CORS_ALLOW_ALL_ORIGINS = True
