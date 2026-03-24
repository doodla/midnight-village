"""WebSocket URL routing for ONUW app."""

from django.urls import path

from . import consumers

websocket_urlpatterns = [
    path("ws/game/<str:game_id>/", consumers.GameConsumer.as_asgi()),
]
