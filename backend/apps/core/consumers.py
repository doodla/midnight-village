"""WebSocket consumers for core app."""

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer


class LobbyConsumer(AsyncJsonWebsocketConsumer):
    """WebSocket consumer for lobby real-time updates."""

    async def connect(self):
        self.lobby_code = self.scope["url_route"]["kwargs"]["code"]
        self.lobby_group_name = f"lobby_{self.lobby_code}"

        # Check if lobby exists
        lobby_exists = await self.lobby_exists(self.lobby_code)
        if not lobby_exists:
            await self.close(code=4004)
            return

        # Join lobby group
        if self.channel_layer is None:
            await self.close(code=4000)
            return
        await self.channel_layer.group_add(
            self.lobby_group_name,
            self.channel_name,
        )

        await self.accept()

    async def disconnect(self, code):
        # Leave lobby group
        if self.channel_layer is not None:
            await self.channel_layer.group_discard(
                self.lobby_group_name,
                self.channel_name,
            )

    async def receive_json(self, content, **kwargs):
        """Handle incoming WebSocket messages."""
        # For now, just echo back - game-specific handling comes later
        await self.send_json({"type": "echo", "data": content})

    # Event handlers for channel layer messages

    async def player_joined(self, event):
        """Handle player joined event."""
        await self.send_json(
            {
                "type": "player_joined",
                "username": event["username"],
            }
        )

    async def player_left(self, event):
        """Handle player left event."""
        await self.send_json(
            {
                "type": "player_left",
                "username": event["username"],
            }
        )

    async def player_ready(self, event):
        """Handle player ready state change."""
        await self.send_json(
            {
                "type": "player_ready",
                "username": event["username"],
                "is_ready": event["is_ready"],
            }
        )

    async def lobby_update(self, event):
        """Handle generic lobby update."""
        await self.send_json(
            {
                "type": "lobby_update",
                "data": event["data"],
            }
        )

    @database_sync_to_async
    def lobby_exists(self, code):
        from apps.core.models import Lobby

        return Lobby.objects.filter(code=code).exists()
