"""
Host handover: the host role passes on while the host's phone is away.

``Lobby.host`` is the owner and never changes. ``Lobby.acting_host`` is set
while the owner is away; the *effective host* (``Lobby.effective_host_id``) is
the acting host if set, else the owner. Every host-only check goes through
``Lobby.is_host``.

Shared by every game: what only a game knows (its socket group, who is connected
to it, when its players were noticed gone) comes through ``apps.core.games``.

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
* The OWNER leaving while other members remain does not delete the table: the
  ownership moves for good to the next member in join order (a connected one
  preferred), ``acting_host`` is cleared and everyone is told (reason
  ``transferred``). Only the last member leaving deletes the lobby.

Lobby presence (``LobbySocket`` rows plus ``LobbyMember.disconnected_at``) exists only for this: it is never broadcast and
plays no part in the night/vote grace logic. A socket that dies silently is
noticed by the durable presence check (``check_lobby_presence``).

Lock order (extends the game order): Game -> PlayerRole -> Lobby -> LobbyMember.
Everything here takes Lobby then LobbyMember, and never takes a Game or
PlayerRole lock while holding the Lobby, so it cannot deadlock with the game
code. The game-socket entry points run only after the game presence
transaction has committed. Side effects (socket sends, timers) run after commit.
"""

from __future__ import annotations

import logging
import uuid
from typing import Any

from django.db import transaction
from django.db.models.functions import Now
from django.utils import timezone

from apps.core import games, lobbies, practice, presence, timers
from apps.core.effects import after_commit, schedule_after_commit, send_after_commit
from apps.core.models import Lobby, LobbyMember, LobbySocket
from apps.core.wire import public_name

logger = logging.getLogger(__name__)

DEFAULT_HOST_HANDOVER_SECONDS = 60
MAX_HOST_HANDOVER_SECONDS = 600
SETTING_KEY = "host_handover_seconds"


def handover_seconds(lobby: Lobby) -> int:
    """The lobby's host_handover_seconds (a bad stored value falls back to the default)."""
    stored = (
        lobby.settings.get(SETTING_KEY, DEFAULT_HOST_HANDOVER_SECONDS)
        if isinstance(lobby.settings, dict)
        else DEFAULT_HOST_HANDOVER_SECONDS
    )
    if (
        isinstance(stored, int)
        and not isinstance(stored, bool)
        and 0 <= stored <= MAX_HOST_HANDOVER_SECONDS
    ):
        return stored
    return DEFAULT_HOST_HANDOVER_SECONDS


def timer_key(lobby: Lobby | int) -> str:
    """Registry key of a lobby's handover timer.

    Starts with ``lobby:`` so it can never match a game's ``<uuid>:`` prefix:
    game cleanup and the debug fire-timer ``current`` lookup never see it.
    """
    lobby_id = lobby if isinstance(lobby, int) else lobby.pk
    return f"lobby:{lobby_id}:host"


# ── Who is connected, and since when ────────────────────────────────────────


class _Presence:
    """A snapshot of who is connected (lobby socket or newest-game socket).

    ``members`` are the PEOPLE at the table, in join order: practice players
    (``apps.core.practice``) never host, so no handover or transfer can pick one."""

    def __init__(self, lobby: Lobby) -> None:
        self.members = list(
            LobbyMember.objects.filter(lobby=lobby)
            .exclude(user__username__startswith=practice.USERNAME_PREFIX)
            .order_by("joined_at", "id")
        )
        hooks = games.hooks_for(lobby)
        self.game_stamps = hooks.disconnect_stamps(lobby)
        self._connected = presence.connected_user_ids(
            lobby_id=lobby.pk
        ) | hooks.connected_user_ids(lobby)

    def connected(self, user_id: int) -> bool:
        return user_id in self._connected

    def away_seconds(self, user_id: int, now: Any) -> float | None:
        """Seconds with no open socket at all; None if connected or never seen
        disconnected (nothing to time). A user who is no longer a member counts
        as away forever."""
        if self.connected(user_id):
            return None
        member = next((m for m in self.members if m.user_id == user_id), None)
        if member is None:
            return float("inf")
        stamps = [member.disconnected_at, self.game_stamps.get(user_id)]
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
    """After commit, tell the lobby and the newest game's table who the host is.
    Telling is the bump: the event carries the table's new ``rev``."""
    host = lobby.effective_host
    event = {
        "type": "host.changed",
        "host_id": host.id,
        "host_name": public_name(host),
        "original_host_id": lobby.host_id,
        "reason": reason,
        "rev": lobbies.bump_rev(lobby),
    }
    messages = [(f"lobby_{lobby.code}", event)]
    game_group = games.hooks_for(lobby).newest_game_group(lobby)
    if game_group is not None:
        messages.append((game_group, dict(event)))
    send_after_commit(messages)


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
        after_commit(lambda: timers.cancel(timer_key(lobby)))
        return
    away = presence.away_seconds(lobby.effective_host_id, timezone.now())
    if away is None or away == float("inf"):
        return
    schedule_after_commit(
        timer_key(lobby),
        max(0.0, seconds - away),
        "host_handover",
        {"lobby_id": lobby.pk},
    )


@timers.job("host_handover")
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
                schedule_after_commit(
                    timer_key(lobby),
                    remaining,
                    "host_handover",
                    {"lobby_id": lobby_id},
                )
    except Exception:
        logger.exception("Host handover failed for lobby %s", lobby_id)
        raise  # the timer job: fire() rolls back and keeps the row for a retry


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
        after_commit(lambda: timers.cancel(timer_key(lobby)))
        if lobby.acting_host_id is not None:
            _set_acting_host(lobby, None, "returned")
        return
    if user_id == lobby.effective_host_id:
        after_commit(lambda: timers.cancel(timer_key(lobby)))
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


def _new_channel_name() -> str:
    return f"direct.{uuid.uuid4().hex}"


def register_lobby_connection(
    code: str, user_id: int, channel_name: str | None = None
) -> bool:
    """A lobby socket opened: insert its row under row locks; True when the
    member just went from offline to online (and so may take the role back)."""
    channel_name = channel_name or _new_channel_name()
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
        was_connected = presence.fresh_rows(lobby_id=lobby.pk, user_id=user_id).exists()
        # Whether the table shows this member as here right now (inside a grace
        # period counts): a return is announced only if it was shown as gone, so
        # a flapping phone sends nothing.
        shows = games.hooks_for(lobby).shows_table_extras(lobby)
        shown_before = (
            was_connected or user_id in lobbies.connected_members(lobby)
            if shows
            else True
        )
        LobbySocket.objects.filter(lobby=lobby, user_id=user_id).exclude(
            last_seen__gte=presence.cutoff()
        ).delete()
        LobbySocket.objects.update_or_create(
            channel_name=channel_name,
            defaults={
                "user_id": user_id,
                "lobby": lobby,
                "connected_at": Now(),
                "last_seen": Now(),
            },
        )
        if was_connected:
            after_commit(
                lambda: presence.ensure_check_timer("lobby", lobby.pk, user_id)
            )
            return False
        # 0 to 1: whatever check was pending (the end of a grace period) is
        # replaced by a staleness check, so a silent death right after a blip is
        # noticed on time.
        after_commit(
            lambda: timers.schedule(
                presence.check_key("lobby", lobby.pk, user_id),
                presence.stale_seconds(),
                "presence_check",
                presence.check_params("lobby", lobby.pk, user_id),
            )
        )
        if member.disconnected_at is not None:
            member.disconnected_at = None
            member.save(update_fields=["disconnected_at"])
        _on_connected(lobby, user_id)
        if not shown_before:
            lobbies.announce_lobby(lobby)  # shown as gone: back at the table
        return True


def _lobby_went_offline(lobby: Lobby, member: LobbyMember, user_id: int) -> None:
    """The member has no fresh lobby socket left (clean close or silent death).

    At a table whose game shows presence (``GameHooks.shows_table_extras``) the member
    still shows as connected for the game's grace period; the durable presence
    check is armed for its end, and then announces the drop
    (``_announce_if_dropped``)."""
    member.disconnected_at = timezone.now()
    member.save(update_fields=["disconnected_at"])
    _on_disconnected(lobby, user_id)
    hooks = games.hooks_for(lobby)
    if not hooks.shows_table_extras(lobby):
        return
    schedule_after_commit(
        presence.check_key("lobby", lobby.pk, user_id),
        max(float(hooks.presence_grace_seconds(lobby)), 0.0),
        "presence_check",
        presence.check_params("lobby", lobby.pk, user_id),
    )


def _announce_if_dropped(lobby_id: Any, user_id: int) -> None:
    """The presence check fired for a member with no socket row left: once their
    grace period is over (and they have no game socket either) the table is
    told (``lobby_update``, ``connected`` false); fired early, it re-arms for
    the rest of the grace. Only at tables whose game shows presence."""
    with transaction.atomic():
        lobby = _lock(int(lobby_id))
        if lobby is None:
            return
        hooks = games.hooks_for(lobby)
        if not hooks.shows_table_extras(lobby):
            return
        member = (
            LobbyMember.objects.select_for_update()
            .filter(lobby=lobby, user_id=user_id)
            .first()
        )
        if member is None or member.disconnected_at is None:
            return  # left the table, or back already
        if user_id in hooks.connected_user_ids(lobby):
            return  # reachable on the game's socket
        grace = hooks.presence_grace_seconds(lobby)
        # Instance clock, as disconnected_at is written (lobbies.connected_members).
        away = (timezone.now() - member.disconnected_at).total_seconds()
        if away < grace:
            schedule_after_commit(
                presence.check_key("lobby", lobby.pk, user_id),
                grace - away,
                "presence_check",
                presence.check_params("lobby", lobby.pk, user_id),
            )
            return
        lobbies.announce_lobby(lobby)


def unregister_lobby_connection(
    code: str, user_id: int, channel_name: str | None = None
) -> bool:
    """A lobby socket closed: delete its row; True on going fully offline."""
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
        rows = LobbySocket.objects.filter(lobby=lobby, user_id=user_id)
        if channel_name is not None:
            rows = rows.filter(channel_name=channel_name)
        else:
            newest = rows.order_by("-connected_at", "-id").first()
            rows = rows.filter(pk=newest.pk) if newest else rows.none()
        if not rows.delete()[0]:
            return False
        if presence.fresh_rows(lobby_id=lobby.pk, user_id=user_id).exists():
            return False
        LobbySocket.objects.filter(lobby=lobby, user_id=user_id).delete()
        after_commit(
            lambda: timers.cancel(presence.check_key("lobby", lobby.pk, user_id))
        )
        _lobby_went_offline(lobby, member, user_id)
        return True


def refresh_lobby_connection(code: str, user_id: int, channel_name: str) -> bool:
    """Heartbeat of a lobby socket (see game_presence.refresh_connection)."""
    try:
        lobby_id = Lobby.objects.filter(code=code).values_list("pk", flat=True).first()
        if lobby_id is None:
            return False
        updated = LobbySocket.objects.filter(channel_name=channel_name).update(
            last_seen=Now()
        )
        if not updated:
            return register_lobby_connection(code, user_id, channel_name)
        presence.ensure_check_timer("lobby", lobby_id, user_id)
        return False
    finally:
        timers.release_connections()


def check_lobby_presence(lobby_id: Any, user_id: int) -> bool:
    """The durable presence check of a (lobby, member) fired: re-arm if a row is
    fresh (no lock taken), else, under Lobby then LobbyMember locks, delete the
    dead rows and go offline exactly as a clean close. Returns True if the
    member went offline."""

    def rearm(age: float) -> None:
        schedule_after_commit(
            presence.check_key("lobby", lobby_id, user_id),
            presence.next_check_delay(age),
            "presence_check",
            presence.check_params("lobby", lobby_id, user_id),
        )

    rows = LobbySocket.objects.filter(lobby_id=int(lobby_id), user_id=user_id)
    age = presence.seconds_since_newest(rows)
    if age is None:
        # No socket left: the end of a dropped member's grace period.
        _announce_if_dropped(lobby_id, user_id)
        return False
    if age <= presence.stale_seconds():
        rearm(age)
        return False
    with transaction.atomic():
        lobby = _lock(int(lobby_id))
        if lobby is None:
            return False  # the lobby was deleted meanwhile (owner left)
        member = (
            LobbyMember.objects.select_for_update()
            .filter(lobby=lobby, user_id=user_id)
            .first()
        )
        rows = LobbySocket.objects.filter(lobby=lobby, user_id=user_id)
        age = presence.seconds_since_newest(rows)
        if age is None or member is None:
            return False
        if age <= presence.stale_seconds():
            rearm(age)
            return False
        rows.delete()
        _lobby_went_offline(lobby, member, user_id)
        return True


def member_presence_changed(lobby_id: int, user_id: int, connected: bool) -> None:
    """A member's socket on the lobby's newest game opened (0 -> 1) or closed
    (1 -> 0), reported by the game app after ITS presence transaction has
    committed (so no game lock is held here)."""
    with transaction.atomic():
        lobby = _lock(lobby_id)
        if lobby is None:
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


def transfer_ownership(lobby: Lobby, leaver_id: int) -> int | None:
    """The OWNER is leaving. If anyone else is in the lobby, ownership moves for
    good to the next member in join order (a connected one preferred), the
    acting host is cleared, the leaver's membership and sockets go, everyone is
    told (``host.changed``, reason ``transferred``, ``host_id`` and
    ``original_host_id`` both the new owner), and the new owner's id is returned.
    Returns None, changing nothing, when nobody else is there, or only practice
    players (the caller closes the table). The caller holds the Lobby row lock
    inside an atomic block.
    """
    from apps.core.models import User

    presence = _Presence(lobby)
    # People only (``_Presence``): with nobody else but practice players the
    # caller closes the table (``practice.close_table``).
    others = [m.user_id for m in presence.members if m.user_id != leaver_id]
    if not others:
        return None
    new_owner: int = presence.next_connected({leaver_id}) or others[0]  # type: ignore[assignment]

    LobbyMember.objects.filter(lobby=lobby, user_id=leaver_id).delete()
    LobbySocket.objects.filter(lobby=lobby, user_id=leaver_id).delete()
    after_commit(lambda: timers.cancel(presence_check_key(lobby.pk, leaver_id)))
    lobby.host = User.objects.get(pk=new_owner)
    lobby.acting_host = None
    lobby.save(update_fields=["host", "acting_host", "updated_at"])
    _announce(lobby, "transferred")
    # The handover clock now belongs to the new owner (connected = no timer).
    after_commit(lambda: timers.cancel(timer_key(lobby)))
    _arm_timer(lobby, _Presence(lobby))
    return new_owner


def presence_check_key(lobby_id: int, user_id: int) -> str:
    return presence.check_key("lobby", lobby_id, user_id)


def ensure_timers_after_restart() -> None:
    """Start-up recovery (memory backend): arm the handover timer of every
    waiting / in-game lobby whose effective host is away (noticed gone, by a
    clean close or a presence check). Nothing is reset at a restart: a host
    whose socket died with the old process is noticed by the re-armed presence
    check, and their handover clock starts then."""
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
