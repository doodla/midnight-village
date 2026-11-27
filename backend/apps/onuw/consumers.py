"""ONUW game WebSocket consumer."""

import asyncio
import contextlib
import logging

from channels.db import database_sync_to_async

from apps.core.consumers import TolerantJsonWebsocketConsumer

from . import groups, presence

logger = logging.getLogger(__name__)


def _host_presence(game_id, user_id, connected: bool) -> None:
    """Tell host handover about a game socket opening / closing (never fatal)."""
    from . import services

    try:
        services.report_game_presence(game_id, user_id, connected)
    except Exception:
        logger.exception("Host handover check failed for game %s", game_id)


class GameConsumer(TolerantJsonWebsocketConsumer):
    """
    WebSocket consumer for an ONUW game session.

    Each connected player joins two channel groups:
    - game_{game_id}: broadcast channel for all players (every table event:
      counts, windows, phases, the reveal, the results, presence, host, play again)
    - game_{game_id}_player_{user_id}: this player's own channel: their own view
      as each stage opens (``own_view``), and nothing else

    An event type with no handler here (one an older deployment still sends while
    a new one goes live) is dropped by ``TolerantJsonWebsocketConsumer``.
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
        self.game_group = groups.game_group(self.game_id)
        self.player_group = groups.player_group(self.game_id, self.user_id)

        if self.channel_layer is None:
            await self.close(code=4000)
            return

        # Join both groups
        await self.channel_layer.group_add(self.game_group, self.channel_name)
        await self.channel_layer.group_add(self.player_group, self.channel_name)

        await self.accept()

        # Presence: count this socket (a player may have several open). After
        # accept, so the group already includes this client and it hears its
        # own "connected" event.
        await self._register_presence()
        self._presence_counted = True
        self._heartbeat_task = asyncio.ensure_future(
            presence.heartbeat_loop(self._beat)
        )

    async def disconnect(self, code):
        if self.channel_layer is not None and hasattr(self, "game_group"):
            await self.channel_layer.group_discard(self.game_group, self.channel_name)
            await self.channel_layer.group_discard(self.player_group, self.channel_name)
        task = getattr(self, "_heartbeat_task", None)
        if task is not None:
            task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await task
        # Only a socket that was counted can be uncounted (a rejected
        # connection also reaches disconnect).
        if getattr(self, "_presence_counted", False):
            self._presence_counted = False
            await self._unregister_presence()

    async def receive_json(self, content, **kwargs):
        """Reject client-sent messages — game actions go through HTTP API."""
        await self.send_json(
            {"type": "error", "detail": "Use the HTTP API for game actions."}
        )

    # ── Event handlers ──────────────────────────────────────────────────────

    async def night_window(self, event):
        """Broadcast: a night window opened. The same event for every phone; its
        prompt came just before, in its own view (``own_view``)."""
        await self.send_json(
            {
                "type": "night_window",
                "window": event["window"],
                "deadline": event.get("deadline"),
            }
        )

    async def phase_change(self, event):
        """Broadcast: the game phase has changed."""
        await self.send_json(
            {
                "type": "phase_change",
                "phase": event["phase"],
                "deadline": event.get("deadline"),
            }
        )

    async def progress(self, event):
        """Broadcast: how many players have locked in / are ready (counts only)."""
        await self.send_json(
            {
                "type": "progress",
                "stage": event["stage"],
                "done": event["done"],
                "needed": event["needed"],
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

    async def player_presence(self, event):
        """Broadcast: a player's connection changed (public information)."""
        await self.send_json(
            {
                "type": "player_presence",
                "player_id": event["player_id"],
                "connected": event["connected"],
            }
        )

    async def host_changed(self, event):
        """Broadcast: the host role passed on, or went back to the owner."""
        await self.send_json(
            {
                "type": "host_changed",
                "host_id": event["host_id"],
                "host_name": event["host_name"],
                "original_host_id": event["original_host_id"],
                "reason": event["reason"],
                # The table's ``rev`` (absent from an older instance's event).
                **({"rev": event["rev"]} if "rev" in event else {}),
            }
        )

    async def play_again(self, event):
        """Broadcast: the host reopened the lobby for another game."""
        await self.send_json(
            {
                "type": "play_again",
                "lobby_code": event["lobby_code"],
            }
        )

    async def own_view(self, event):
        """Private: this player's own view as a stage opens (``own_view``), sent to
        the player's own group. Forwarded only when it is this socket's player's
        own (its ``player_id``): a view addressed anywhere else reaches nobody."""
        view = event.get("me")
        if not isinstance(view, dict) or view.get("player_id") != self.user_id:
            logger.error("An own view reached a socket it is not for: dropped")
            return
        await self.send_json({"type": "me", "me": view})

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
    def _register_presence(self):
        from . import game_presence

        if game_presence.register_connection(
            self.game_id, self.user_id, self.channel_name
        ):
            _host_presence(self.game_id, self.user_id, True)

    @database_sync_to_async
    def _unregister_presence(self):
        from . import game_presence

        if game_presence.unregister_connection(
            self.game_id, self.user_id, self.channel_name
        ):
            _host_presence(self.game_id, self.user_id, False)

    async def _beat(self):
        """One heartbeat: the beat frame to the phone (the same for every
        socket), this socket's row refreshed (its own short DB use) and, from
        the game's oldest fresh socket, the game's lazy repair (``repair.py``: a
        lost timer or practice move must not wait for a phone to read)."""
        from . import repair

        await self.send_json(presence.beat_frame())
        # Not thread-sensitive: a pool thread does the beat and releases its
        # database connection, so nothing stays open between beats and the beats
        # never queue behind (or close the connection of) other consumers' work.
        came_back = await database_sync_to_async(
            self._refresh_presence, thread_sensitive=False
        )()
        if came_back:
            await database_sync_to_async(_host_presence)(
                self.game_id, self.user_id, True
            )
        await database_sync_to_async(repair.repair_on_beat, thread_sensitive=False)(
            self.game_id, self.channel_name
        )

    def _refresh_presence(self):
        from . import game_presence

        return game_presence.refresh_connection(
            self.game_id, self.user_id, self.channel_name
        )

    @database_sync_to_async
    def _is_player(self, game_id, user_id):
        from .models import PlayerRole

        return PlayerRole.objects.filter(game_id=game_id, user_id=user_id).exists()
