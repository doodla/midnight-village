"""
ASGI config for Midnight Village.

Configures both HTTP and WebSocket protocol routing.
"""

import os

from django.core.asgi import get_asgi_application

from channels.routing import ProtocolTypeRouter, URLRouter
from channels.security.websocket import AllowedHostsOriginValidator

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.development")

# Initialize Django ASGI application early to ensure the AppRegistry
# is populated before importing code that may import ORM models.
django_asgi_app = get_asgi_application()

from apps.core.middleware import JWTAuthMiddleware  # noqa: E402
from apps.core.routing import websocket_urlpatterns as core_ws  # noqa: E402
from apps.onuw.routing import websocket_urlpatterns as onuw_ws  # noqa: E402

application = ProtocolTypeRouter(
    {
        "http": django_asgi_app,
        "websocket": AllowedHostsOriginValidator(
            JWTAuthMiddleware(URLRouter(core_ws + onuw_ws))
        ),
    }
)
