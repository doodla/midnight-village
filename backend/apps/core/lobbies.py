"""Lobby operations shared by every game."""

from __future__ import annotations

import logging
from datetime import timedelta
from typing import Any

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from apps.core import games, presence, tokens
from apps.core.effects import send_after_commit
from apps.core.models import Lobby, LobbyMember

logger = logging.getLogger(__name__)


class LobbyFullError(Exception):
    """No seat is left: the lobby is at ``max_players`` or every token is taken."""


def _log_token(lobby: Lobby, user_id: int, token: str) -> None:
    """Tokens are seeded by the lobby code; the log makes a table replayable."""
    logger.info("lobby %s: user %s takes token %s", lobby.code, user_id, token)


def touch(lobby_id: int) -> None:
    """Record table activity: ``Lobby.updated_at`` is when anything last happened.

    ``save()`` bumps it by itself; a queryset ``update()`` and the changes that
    only touch a member (join, leave) do not, so they call this. "Where am I"
    counts its resume window from here.
    """
    Lobby.objects.filter(pk=lobby_id).update(updated_at=timezone.now())


def add_member(lobby: Lobby, user_id: int) -> LobbyMember:
    """Seat a user at the table with the next free token, logged for replay.

    The caller holds the Lobby row lock inside an atomic block, so the capacity
    check, the token and the insert cannot interleave with another join.

    Raises LobbyFullError.
    """
    token = tokens.assign_token(lobby)
    if token is None or lobby.players.count() >= lobby.max_players:  # type: ignore[attr-defined]
        raise LobbyFullError
    member = LobbyMember.objects.create(lobby=lobby, user_id=user_id, token=token)
    touch(lobby.pk)
    _log_token(lobby, user_id, token)
    return member


def current_table(user_id: int) -> dict[str, Any] | None:
    """The table the user is seated at now, for the app to resume (None = none).

    Starts from membership: the user's newest-joined lobby with activity within
    ``CORE_TABLE_RESUME_HOURS`` (``Lobby.updated_at``: created, joined, left,
    settings, dealt, finished, played again). A table left last week, or a game
    nobody finished, does not pull them back. ``game`` is the lobby's newest game
    when the user plays in it, as the game app's hook reports it; the client
    routes on ``game.phase`` and ``status``.
    """
    member = (
        LobbyMember.objects.filter(user_id=user_id)
        .filter(lobby__updated_at__gte=_resume_cutoff())
        .select_related("lobby")
        .order_by("-joined_at", "-id")
        .first()
    )
    if member is None:
        return None
    lobby = member.lobby
    return {
        "lobby_code": lobby.code,
        "game_type": lobby.game_type,
        "status": lobby.status,
        "is_host": lobby.is_host(user_id),
        "token": member.token,
        "game": games.hooks_for(lobby).member_game(lobby, user_id),
    }


def _resume_cutoff() -> Any:
    return timezone.now() - timedelta(hours=settings.CORE_TABLE_RESUME_HOURS)


def other_active_table(user_id: int, exclude_lobby_id: int) -> Lobby | None:
    """The WAITING table, other than ``exclude_lobby_id``, the user is seated at,
    with activity within ``CORE_TABLE_RESUME_HOURS`` (the "where am I" window).

    Only waiting tables count, because a member can always leave a waiting table
    (``POST /lobbies/<code>/leave/``, the owner included): a refusal that points
    there can never trap anyone. A table in a game cannot be left by its owner,
    so it must not block a join (``/me/table/`` already routes people back to a
    game); a finished table is over."""
    member = (
        LobbyMember.objects.filter(
            user_id=user_id,
            lobby__status=Lobby.Status.WAITING,
            lobby__updated_at__gte=_resume_cutoff(),
        )
        .exclude(lobby_id=exclude_lobby_id)
        .select_related("lobby")
        .order_by("-joined_at", "-id")
        .first()
    )
    return None if member is None else member.lobby


def connected_members(lobby: Lobby) -> set[int]:
    """Members shown as connected at the table: a fresh lobby socket or a socket
    on the lobby's newest game, or a phone that went away less than the game's
    ``presence_grace_seconds`` ago (so a blip is not shown). A member never seen
    with a socket is not connected.

    The grace is measured on the instance clock (``timezone.now()``), as
    ``LobbyMember.disconnected_at`` is written with it (like the game's own
    grace); socket freshness itself is on the database clock."""
    hooks = games.hooks_for(lobby)
    connected = presence.connected_user_ids(
        lobby_id=lobby.pk
    ) | hooks.connected_user_ids(lobby)
    grace = hooks.presence_grace_seconds(lobby)
    if grace > 0:
        recent = timezone.now() - timedelta(seconds=grace)
        connected |= set(
            LobbyMember.objects.filter(
                lobby=lobby, disconnected_at__gt=recent
            ).values_list("user_id", flat=True)
        )
    return connected


def announce_lobby(lobby: Lobby) -> None:
    """After commit, send the lobby body to the table (``lobby_update``), for a
    table whose game opts in (``GameHooks.shows_table_extras``); nothing otherwise. The
    body is built now, inside the caller's transaction."""
    from apps.core.serializers import LobbySerializer

    if not games.hooks_for(lobby).shows_table_extras(lobby):
        return
    send_after_commit(
        [
            (
                f"lobby_{lobby.code}",
                {"type": "lobby.update", "data": LobbySerializer(lobby).data},
            )
        ]
    )


def ensure_tokens(lobby: Lobby, members: list[LobbyMember]) -> None:
    """Give a token to every member who has none (join order); call before a deal.

    A member made by code that predates tokens (a rollout, or a row created
    outside ``add_member``) is blank. With the Lobby row locked, each takes the
    next free token in the lobby's order; a legacy table over ten keeps blanks
    for the members beyond the tenth.
    """
    for member in members:
        if member.token:
            continue
        token = tokens.assign_token(lobby)
        if token is None:
            return
        LobbyMember.objects.filter(pk=member.pk).update(token=token)
        member.token = token
        _log_token(lobby, member.user_id, token)


class PlayAgainError(Exception):
    """Play again refused. ``status_code`` is the HTTP status to answer with."""

    def __init__(self, status_code: int, detail: str) -> None:
        super().__init__(detail)
        self.status_code = status_code
        self.detail = detail


def play_again(code: str, user_id: int) -> Lobby:
    """Reopen a lobby whose game has finished, for the host to deal again.

    Keeps the members and the lobby's settings (the deck); sets the lobby back
    to waiting with everyone ready so the host can start straight away (anyone
    can still un-ready or leave). Atomic. After commit, tells the old game's
    players (``play.again``) and the lobby screens (``lobby.update``). The old
    game and its results are left untouched. A repeated request while the lobby
    is already waiting is a no-op that returns the lobby.

    Raises PlayAgainError: 404 unknown lobby, 403 not the host, 409 the lobby's
    newest game is not finished.
    """
    from apps.core.serializers import LobbySerializer

    with transaction.atomic():
        try:
            lobby = Lobby.objects.select_for_update().get(code=code)
        except Lobby.DoesNotExist:
            raise PlayAgainError(404, "Lobby not found.") from None
        if not lobby.is_host(user_id):
            raise PlayAgainError(403, "Only the host can start another game.")
        hooks = games.hooks_for(lobby)
        if not hooks.newest_game_finished(lobby):
            raise PlayAgainError(409, "The game is not finished yet.")
        if lobby.status == Lobby.Status.WAITING:
            return lobby  # Already reopened (a double tap).

        lobby.status = Lobby.Status.WAITING
        lobby.save(update_fields=["status", "updated_at"])
        LobbyMember.objects.filter(lobby=lobby).update(is_ready=True)

        messages = [
            (
                f"lobby_{lobby.code}",
                {"type": "lobby.update", "data": LobbySerializer(lobby).data},
            )
        ]
        game_group = hooks.newest_game_group(lobby)
        if game_group is not None:
            messages.insert(
                0, (game_group, {"type": "play.again", "lobby_code": lobby.code})
            )
        send_after_commit(messages)
    return lobby
