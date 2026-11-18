"""
Host handover: the host role passes on while the host's phone is away.

``Lobby.host`` is the owner and never changes. ``Lobby.acting_host`` is set
while the owner is away; the *effective host* (``Lobby.effective_host_id``) is
the acting host if set, else the owner. Every host-only check goes through
``Lobby.is_host``.

Rules (setting ``host_handover_seconds``, default 60, 0 to 600, 0 = off):

* When the effective host has had no open socket (lobby OR the lobby's newest
  game) for that long, the next lobby member in join order who is connected
  becomes the acting host. If nobody is connected, nothing happens until
  someone connects. If the acting host in turn is away for the same period it
  passes on again, never to the absent owner.
* The moment the owner has an open socket again the acting host is cleared
  (no delay).
* An acting host who leaves the lobby hands the role to the next connected
  member, or to nobody (the role is then back with the owner).

Lobby presence (``LobbyMember.connections`` / ``disconnected_at``) exists only
for this: it is never broadcast and plays no part in the night/vote grace logic.

Lock order (extends the game order): Game -> PlayerRole -> Lobby -> LobbyMember.
Everything here takes Lobby then LobbyMember, and never takes a Game or
PlayerRole lock while holding the Lobby, so it cannot deadlock with the game
code. The game-socket entry points run only after the game presence
transaction has committed. Side effects (socket sends, timers) run after commit.
"""

from __future__ import annotations

import functools
import logging
from typing import Any

from django.db import transaction
from django.utils import timezone

from apps.core.models import Lobby, LobbyMember
from apps.onuw import timers

from .engine.validation import is_valid_timer_value, max_seconds_for
from .models import Game, PlayerRole
from .services import _after_commit, _schedule_after_commit, _send_after_commit

logger = logging.getLogger(__name__)

DEFAULT_HOST_HANDOVER_SECONDS = 60
SETTING_KEY = "host_handover_seconds"


def handover_seconds(lobby: Lobby) -> int:
    """The lobby's host_handover_seconds (a bad stored value falls back to the default)."""
    stored = (
        lobby.settings.get(SETTING_KEY, DEFAULT_HOST_HANDOVER_SECONDS)
        if isinstance(lobby.settings, dict)
        else DEFAULT_HOST_HANDOVER_SECONDS
    )
    if is_valid_timer_value(stored, max_seconds_for(SETTING_KEY)):
        return stored  # type: ignore[return-value]
    return DEFAULT_HOST_HANDOVER_SECONDS


def timer_key(lobby: Lobby | int) -> str:
    """Registry key of a lobby's handover timer.

    Starts with ``lobby:`` so it can never match a game's ``<uuid>:`` prefix:
    game cleanup and the debug fire-timer ``current`` lookup never see it.
    """
    lobby_id = lobby if isinstance(lobby, int) else lobby.pk
    return f"lobby:{lobby_id}:host"


# ── Who is connected, and since when ────────────────────────────────────────


def _newest_game(lobby: Lobby) -> Game | None:
    # pyrefly: ignore [missing-attribute]
    return lobby.games.order_by("-created_at", "-id").first()


class _Presence:
    """A snapshot of who is connected (lobby socket or newest-game socket)."""

    def __init__(self, lobby: Lobby) -> None:
        self.members = list(
            LobbyMember.objects.filter(lobby=lobby).order_by("joined_at", "id")
        )
        game = _newest_game(lobby)
        self.game_rows: dict[int, PlayerRole] = (
            {pr.user_id: pr for pr in PlayerRole.objects.filter(game=game)}  # type: ignore[attr-defined]
            if game is not None
            else {}
        )

    def connected(self, user_id: int) -> bool:
        pr = self.game_rows.get(user_id)
        if pr is not None and pr.connections > 0:
            return True
        return any(m.user_id == user_id and m.connections > 0 for m in self.members)

    def away_seconds(self, user_id: int, now: Any) -> float | None:
        """Seconds with no open socket at all; None if connected or never seen
        connected (nothing to time). A user who is no longer a member counts
        as away forever."""
        if self.connected(user_id):
            return None
        member = next((m for m in self.members if m.user_id == user_id), None)
        if member is None:
            return float("inf")
        stamps = [member.disconnected_at]
        pr = self.game_rows.get(user_id)
        if pr is not None:
            stamps.append(pr.disconnected_at)
        known = [t for t in stamps if t is not None]
        if not known:
            return None
        return (now - max(known)).total_seconds()

    def next_connected(self, exclude: set[int]) -> int | None:
        """First connected member in join order, skipping ``exclude``."""
        for member in self.members:
            user_id: int = member.user_id  # type: ignore[attr-defined]
            if user_id not in exclude and self.connected(user_id):
                return user_id
        return None


# ── Changing the acting host ────────────────────────────────────────────────


def _announce(lobby: Lobby, reason: str) -> None:
    """After commit, tell the lobby and the newest game's table who the host is."""
    host = lobby.effective_host
    event = {
        "type": "host.changed",
        "host_id": host.id,
        "host_name": host.display_name or host.username,
        "original_host_id": lobby.host_id,
        "reason": reason,
    }
    messages = [(f"lobby_{lobby.code}", event)]
    game = _newest_game(lobby)
    if game is not None:
        messages.append((f"game_{game.id}", dict(event)))
    _send_after_commit(messages)


def _set_acting_host(lobby: Lobby, user_id: int | None, reason: str) -> None:
    lobby.acting_host_id = user_id
    lobby.save(update_fields=["acting_host", "updated_at"])
    if user_id is None:
        lobby.acting_host = None
    else:
        lobby.refresh_from_db(fields=["acting_host"])
    _announce(lobby, reason)


def _hand_over_if_due(lobby: Lobby, presence: _Presence) -> float | None:
    """Pass the role on if the effective host has been away long enough.

    The caller holds the Lobby row lock. Returns the seconds still to wait if
    the effective host is away but not for long enough yet, else None.
    """
    seconds = handover_seconds(lobby)
    if seconds <= 0:
        return None
    effective = lobby.effective_host_id
    away = presence.away_seconds(effective, timezone.now())
    if away is None:
        return None
    if away < seconds:
        return seconds - away
    candidate = presence.next_connected({effective, lobby.host_id})
    if candidate is not None:
        _set_acting_host(lobby, candidate, "handover")
    return None


def _arm_timer(lobby: Lobby, presence: _Presence) -> None:
    """(Re)start the handover timer for the effective host if they are away."""
    seconds = handover_seconds(lobby)
    if seconds <= 0:
        _after_commit(lambda: timers.cancel(timer_key(lobby)))
        return
    away = presence.away_seconds(lobby.effective_host_id, timezone.now())
    if away is None or away == float("inf"):
        return
    _schedule_after_commit(
        timer_key(lobby),
        max(0.0, seconds - away),
        functools.partial(_handover_due, lobby.pk),
    )


def _handover_due(lobby_id: int) -> None:
    """Timer callback: the effective host's handover period may have ended."""
    try:
        with transaction.atomic():
            lobby = _lock(lobby_id)
            if lobby is None:
                return
            remaining = _hand_over_if_due(lobby, _Presence(lobby))
            if remaining is not None:
                # Fired a hair early, or the host is away for less than we
                # thought: wait out the rest.
                _schedule_after_commit(
                    timer_key(lobby),
                    remaining,
                    functools.partial(_handover_due, lobby_id),
                )
    except Exception:
        logger.exception("Host handover failed for lobby %s", lobby_id)


def _lock(lobby_id: int | None = None, *, code: str | None = None) -> Lobby | None:
    """Lock a lobby row (only the lobby row: the acting host is nullable)."""
    queryset = Lobby.objects.select_for_update(of=("self",)).select_related(
        "host", "acting_host"
    )
    return (
        queryset.filter(code=code).first()
        if code is not None
        else queryset.filter(pk=lobby_id).first()
    )


def _on_connected(lobby: Lobby, user_id: int) -> None:
    """Someone has an open socket (the caller holds the Lobby lock)."""
    presence = _Presence(lobby)
    if user_id == lobby.host_id:
        # The owner is back: the role goes back at once.
        _after_commit(lambda: timers.cancel(timer_key(lobby)))
        if lobby.acting_host_id is not None:
            _set_acting_host(lobby, None, "returned")
        return
    if user_id == lobby.effective_host_id:
        _after_commit(lambda: timers.cancel(timer_key(lobby)))
        return
    # A member other than the host: if the host's time is already up and
    # nobody could take over before, they can now.
    remaining = _hand_over_if_due(lobby, presence)
    if remaining is not None:
        _arm_timer(lobby, presence)


def _on_disconnected(lobby: Lobby, user_id: int) -> None:
    """Someone lost their last socket (the caller holds the Lobby lock)."""
    if user_id != lobby.effective_host_id:
        return
    presence = _Presence(lobby)
    if presence.connected(user_id):
        return  # still reachable through the other kind of socket
    _arm_timer(lobby, presence)


# ── Entry points (sync; called by the consumers) ────────────────────────────


def register_lobby_connection(code: str, user_id: int) -> bool:
    """A lobby socket opened. Counts it under row locks; True on 0 -> 1."""
    with transaction.atomic():
        lobby = _lock(code=code)
        if lobby is None:
            return False
        member = (
            LobbyMember.objects.select_for_update()
            .filter(lobby=lobby, user_id=user_id)
            .first()
        )
        if member is None:
            return False
        came_back = member.connections == 0
        member.connections += 1
        fields = ["connections"]
        if came_back:
            member.disconnected_at = None
            fields.append("disconnected_at")
        member.save(update_fields=fields)
        if came_back:
            _on_connected(lobby, user_id)
        return came_back


def unregister_lobby_connection(code: str, user_id: int) -> bool:
    """A lobby socket closed. Never below zero; True on 1 -> 0."""
    with transaction.atomic():
        lobby = _lock(code=code)
        if lobby is None:
            return False
        member = (
            LobbyMember.objects.select_for_update()
            .filter(lobby=lobby, user_id=user_id)
            .first()
        )
        if member is None or member.connections == 0:
            return False
        member.connections -= 1
        if member.connections > 0:
            member.save(update_fields=["connections"])
            return False
        member.disconnected_at = timezone.now()
        member.save(update_fields=["connections", "disconnected_at"])
        _on_disconnected(lobby, user_id)
        return True


def game_presence_changed(game_id: Any, user_id: int, connected: bool) -> None:
    """A game socket opened (0 -> 1) or closed (1 -> 0). Call only after the
    game presence transaction has committed."""
    game = Game.objects.filter(id=game_id).only("lobby_id").first()
    if game is None:
        return
    with transaction.atomic():
        lobby = _lock(game.lobby_id)
        if lobby is None:
            return
        # Only the newest game's sockets count for the lobby.
        newest = _newest_game(lobby)
        if newest is None or newest.id != game.id:
            return
        if connected:
            _on_connected(lobby, user_id)
        else:
            _on_disconnected(lobby, user_id)


def member_leaving(lobby: Lobby, user_id: int) -> None:
    """A non-owner is leaving (their membership is deleted by the caller, who
    holds the Lobby lock). If they hold the acting role, pass it to the next
    connected member, or to nobody (the role is back with the owner)."""
    if lobby.acting_host_id != user_id:
        return
    presence = _Presence(lobby)
    candidate = presence.next_connected({user_id, lobby.host_id})
    _set_acting_host(
        lobby, candidate, "handover" if candidate is not None else "returned"
    )
    _arm_timer(lobby, _Presence(lobby))


def ensure_timers_after_restart() -> None:
    """Start-up recovery: arm the handover timer of every waiting / in-game
    lobby whose effective host is away. After a restart everyone was stamped
    disconnected "now", so the host's clock starts at the restart; nobody is
    connected, so nothing is handed over until someone connects."""
    for lobby in Lobby.objects.filter(
        status__in=(Lobby.Status.WAITING, Lobby.Status.IN_GAME)
    ).select_related("host", "acting_host"):
        try:
            with transaction.atomic():
                locked = _lock(lobby.pk)
                if locked is not None:
                    _arm_timer(locked, _Presence(locked))
        except Exception:
            logger.exception("Could not arm host handover for lobby %s", lobby.pk)
