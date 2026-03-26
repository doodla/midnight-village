"""ONUW game WebSocket consumer."""

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer


class GameConsumer(AsyncJsonWebsocketConsumer):
    """
    WebSocket consumer for an ONUW game session.

    Each connected player joins two channel groups:
    - game_{game_id}: broadcast channel for all players
    - game_{game_id}_player_{user_id}: private channel for player-scoped events
    """

    async def connect(self):
        self.game_id = self.scope["url_route"]["kwargs"]["game_id"]
        user = self.scope.get("user")

        # Validate user is a player in this game
        if user is None or user.is_anonymous:
            await self.close(code=4003)
            return

        is_player = await self._is_player(self.game_id, user.id)
        if not is_player:
            await self.close(code=4003)
            return

        self.user_id = user.id
        self.game_group = f"game_{self.game_id}"
        self.player_group = f"game_{self.game_id}_player_{self.user_id}"

        if self.channel_layer is None:
            await self.close(code=4000)
            return

        # Join both groups
        await self.channel_layer.group_add(self.game_group, self.channel_name)
        await self.channel_layer.group_add(self.player_group, self.channel_name)

        await self.accept()

    async def disconnect(self, code):
        if self.channel_layer is not None and hasattr(self, "game_group"):
            await self.channel_layer.group_discard(self.game_group, self.channel_name)
            await self.channel_layer.group_discard(self.player_group, self.channel_name)

    async def receive_json(self, content, **kwargs):
        """Handle incoming WebSocket messages. Game actions come via HTTP."""
        await self.send_json({"type": "echo", "data": content})

    # ── Event handlers ──────────────────────────────────────────────────────

    async def wave_start(self, event):
        """Broadcast: a new wave has started."""
        await self.send_json(
            {
                "type": "wave_start",
                "wave": event["wave"],
                "deadline": event.get("deadline"),
            }
        )

    async def action_prompt(self, event):
        """Player-scoped: you need to submit an action."""
        await self.send_json(
            {
                "type": "action_prompt",
                "wave": event["wave"],
                "role_acting_as": event["role_acting_as"],
                "action_types": event["action_types"],
                "valid_targets": event["valid_targets"],
            }
        )

    async def action_result(self, event):
        """Player-scoped: result of your submitted action."""
        await self.send_json(
            {
                "type": "action_result",
                "wave": event["wave"],
                "revealed_info": event["revealed_info"],
            }
        )

    async def wave_complete(self, event):
        """Broadcast: a wave has finished resolving."""
        await self.send_json(
            {
                "type": "wave_complete",
                "wave": event["wave"],
            }
        )

    async def phase_change(self, event):
        """Broadcast: the game phase has changed."""
        await self.send_json(
            {
                "type": "phase_change",
                "phase": event["phase"],
            }
        )

    async def wave_waiting(self, event):
        """Player-scoped: you are waiting for this wave to complete."""
        await self.send_json(
            {
                "type": "wave_waiting",
                "wave": event["wave"],
            }
        )

    async def vote_submitted(self, event):
        """Broadcast: a player has submitted their vote (target hidden)."""
        await self.send_json(
            {
                "type": "vote_submitted",
                "player_id": event["player_id"],
            }
        )

    async def vote_reveal(self, event):
        """Broadcast: all votes revealed simultaneously."""
        await self.send_json(
            {
                "type": "vote_reveal",
                "votes": event["votes"],
            }
        )

    async def game_results(self, event):
        """Broadcast: game results after vote resolution."""
        await self.send_json(
            {
                "type": "game_results",
                "data": event["data"],
            }
        )

    # ── Helpers ─────────────────────────────────────────────────────────────

    @database_sync_to_async
    def _is_player(self, game_id, user_id):
        from .models import PlayerRole

        return PlayerRole.objects.filter(game_id=game_id, user_id=user_id).exists()
