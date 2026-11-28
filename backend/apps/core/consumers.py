"""WebSocket consumers for core app."""

import asyncio
import contextlib
import logging

from django.conf import settings

from channels.consumer import get_handler_name
from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer

from . import frames
from .serializers import without_usernames

logger = logging.getLogger(__name__)


class TolerantJsonWebsocketConsumer(AsyncJsonWebsocketConsumer):
    """A consumer that drops group events it has no handler for.

    During a rollout the channel layer can hand an older instance an event type
    that only the new code knows; Channels would raise and close the player's
    socket. Here the event is logged at WARNING and ignored, so the socket stays
    open. With ``ONUW_STRICT_SOCKET_EVENTS`` (test, development, harness) it raises
    as Channels does, so a misspelled type in new code still fails the suite. Only
    the consumer's own events are affected: its connect, receive and disconnect
    handlers still dispatch as usual.

    A frame the phone sent (``websocket.receive``) is handled inside
    ``frames.received``: any database write it makes is refused (principle 7).
    """

    async def dispatch(self, message):
        if getattr(self, get_handler_name(message), None) is None:
            if getattr(settings, "ONUW_STRICT_SOCKET_EVENTS", False):
                raise ValueError(f"No handler for message type {message['type']}")
            logger.warning("Ignoring event with no handler: %s", message.get("type"))
            return
        if message["type"] == "websocket.receive":
            with frames.received(type(self).__name__):
                await super().dispatch(message)
            return
        await super().dispatch(message)


class LobbyConsumer(TolerantJsonWebsocketConsumer):
    """WebSocket consumer for lobby real-time updates."""

    # The lobby's ``rev`` for the next beat frame (None until read).
    _rev: int | None = None

    async def connect(self):
        self.lobby_code = self.scope["url_route"]["kwargs"]["code"]
        self.lobby_group_name = f"lobby_{self.lobby_code}"

        # Authenticate
        user = self.scope.get("user")
        if user is None or user.is_anonymous:
            await self.close(code=4001)
            return

        # Check lobby exists and user is a member
        is_member = await self._check_lobby_membership(self.lobby_code, user.id)
        if not is_member:
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
        from apps.core import presence

        # Presence, for host handover only (never broadcast). Counted after
        # accept; a rejected connection is never counted.
        await self._count_connection(True)
        self._presence_counted = True

        # The first beat at once: the phone learns the pace (and the table's
        # ``rev``) from the start, so the first interval is watched too.
        await self._send_beat()
        self._heartbeat_task = asyncio.ensure_future(
            presence.heartbeat_loop(self._send_beat, self._beat_db)
        )

    async def disconnect(self, code):
        # Leave lobby group
        if self.channel_layer is not None and hasattr(self, "lobby_group_name"):
            await self.channel_layer.group_discard(
                self.lobby_group_name,
                self.channel_name,
            )
        task = getattr(self, "_heartbeat_task", None)
        if task is not None:
            task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await task
        if getattr(self, "_presence_counted", False):
            self._presence_counted = False
            await self._count_connection(False)

    async def receive_json(self, content, **kwargs):
        """Reject client-sent messages — lobby actions go through HTTP API."""
        await self.send_json(
            {"type": "error", "detail": "Use the HTTP API for lobby actions."}
        )

    # Event handlers for channel layer messages

    async def player_joined(self, event):
        """Handle player joined event."""
        await self.send_json(
            # Who joined is in the lobby body the phone reads next (its id and
            # display name). The account's username is nobody else's to know.
            {"type": "player_joined"}
        )

    async def player_left(self, event):
        """Handle player left event."""
        await self.send_json({"type": "player_left"})

    async def lobby_update(self, event):
        """Handle generic lobby update."""
        await self.send_json(
            {
                "type": "lobby_update",
                # An older server instance, during a deploy, still builds this
                # body with usernames: they are taken out here too.
                "data": without_usernames(event["data"]),
            }
        )

    async def host_changed(self, event):
        """The host role passed on, or went back to the owner."""
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

    async def game_started(self, event):
        """Handle game started event — forward to all lobby WebSocket clients."""
        await self.send_json(
            {
                "type": "game_started",
                "game_id": event["game_id"],
            }
        )

    @database_sync_to_async
    def _count_connection(self, opened: bool):
        """Count this socket for host handover. Never fatal to the connection."""
        import logging

        from apps.core import host

        try:
            if opened:
                host.register_lobby_connection(
                    self.lobby_code, self.scope["user"].id, self.channel_name
                )
                self._rev = self._read_rev()
            else:
                host.unregister_lobby_connection(
                    self.lobby_code, self.scope["user"].id, self.channel_name
                )
        except Exception:
            logging.getLogger(__name__).exception(
                "Host handover bookkeeping failed for lobby %s", self.lobby_code
            )

    async def _send_beat(self):
        """The beat frame (``presence.beat_frame``) with the lobby's ``rev`` as
        the last beat read it: the same for every socket of the table. On time,
        whatever the database is doing."""
        from apps.core import presence

        token = None if self._rev is None else {"rev": self._rev}
        await self.send_json(presence.beat_frame(token))

    async def _beat_db(self):
        """One heartbeat's database work, beside its frame. Not thread-sensitive:
        a pool thread does it and releases its connection (nothing stays open
        between beats)."""
        await database_sync_to_async(self._beat_work, thread_sensitive=False)()

    def _beat_work(self) -> None:
        """This socket's row refreshed and the lobby's ``rev`` read, in one
        statement (``presence.lobby_beat``); a row that is gone is registered
        again. Never fatal; the connection is closed at the end."""
        import logging

        from apps.core import host, presence, timers

        try:
            beat = presence.lobby_beat(self.channel_name)
            if beat is not None:
                lobby_id, self._rev = beat
                presence.ensure_check_timer("lobby", lobby_id, self.scope["user"].id)
            else:
                host.register_lobby_connection(
                    self.lobby_code, self.scope["user"].id, self.channel_name
                )
                self._rev = self._read_rev()
        except Exception:
            logging.getLogger(__name__).exception(
                "Lobby presence heartbeat failed for %s", self.lobby_code
            )
        finally:
            timers.release_connections()

    def _read_rev(self) -> int | None:
        from apps.core.models import Lobby

        return (
            Lobby.objects.filter(code=self.lobby_code)
            .values_list("rev", flat=True)
            .first()
        )

    @database_sync_to_async
    def _check_lobby_membership(self, code, user_id):
        """Check if lobby exists and user is a member."""
        from apps.core.models import LobbyMember

        return LobbyMember.objects.filter(lobby__code=code, user_id=user_id).exists()
