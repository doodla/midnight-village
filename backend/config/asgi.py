"""
ASGI config for Midnight Village.

It exposes the ASGI callable as a module-level variable named ``application``.
"""

import os

from django.core.asgi import get_asgi_application

# WARNING: In production deployments, ensure DJANGO_SETTINGS_MODULE is explicitly
# set to "config.settings.production" in the environment. The default below is
# only used if the environment variable is not set.
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.development")

application = get_asgi_application()
