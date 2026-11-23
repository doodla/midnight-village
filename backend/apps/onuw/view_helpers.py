"""
What the game's views share: the refusals every endpoint answers alike, reading the
stage a request names, and one snapshot of a game's players.
"""

import logging

from rest_framework import status
from rest_framework.request import Request
from rest_framework.response import Response

from apps.core.models import LobbyMember

from .models import Game, PlayerRole
from .protocol import (
    WRONG_STAGE_CODE,
    WRONG_STAGE_DETAIL,
)

logger = logging.getLogger(__name__)

MAX_NIGHT_RESULTS_SEEN = 10


def _wrong_stage() -> Response:
    """409 ``wrong_stage``: the request named a stage that is over. The same body
    for every role and every endpoint; nothing was stored."""
    return Response(
        {"detail": WRONG_STAGE_DETAIL, "code": WRONG_STAGE_CODE},
        status=status.HTTP_409_CONFLICT,
    )


def _stage_of(request: Request) -> tuple[str, Response | None]:
    """The ``stage`` a request echoes (``GET /me/``'s ``stage``): required."""
    body = request.data if isinstance(request.data, dict) else {}
    stage = body.get("stage")
    if not isinstance(stage, str) or not stage:
        return "", _bad_request("stage is required.")
    return stage, None


def _bad_request(detail: str) -> Response:
    """A malformed request: 400 with the machine-readable ``bad_request`` code."""
    return Response(
        {"detail": detail, "code": "bad_request"},
        status=status.HTTP_400_BAD_REQUEST,
    )


def _snapshot_player_roles(
    game: Game, members: list[LobbyMember], roles: dict[int, str]
) -> None:
    """Create the game's PlayerRoles from the dealt ``roles`` (user id -> role).

    Each takes its member's token and seat (join order, 0-based) as they are now:
    the game keeps them even if the member later leaves the lobby.
    """
    seats = {m.user_id: (seat, m.token) for seat, m in enumerate(members)}
    PlayerRole.objects.bulk_create(
        PlayerRole(
            game=game,
            user_id=user_id,
            original_role=role,
            current_role=role,
            seat=seats[user_id][0],
            token=seats[user_id][1],
        )
        for user_id, role in roles.items()
    )
