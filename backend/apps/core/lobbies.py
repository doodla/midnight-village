"""Lobby operations shared by every game."""

from __future__ import annotations

from django.db import transaction

from apps.core import games
from apps.core.effects import send_after_commit
from apps.core.models import Lobby, LobbyMember


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
