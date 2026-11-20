"""
DEBUG-gated HTTP views for the ONUW developer harness.

Every view here returns 403 and does nothing when ``settings.DEBUG`` is False
(via ``debug_disabled_response``). The debug-state oracle exposes all players'
roles, so production-reachability would be a hidden-information leak.
"""

from __future__ import annotations

from django.core.exceptions import ValidationError

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from .debug import (
    ForcedAssignmentError,
    build_debug_state,
    debug_disabled_response,
    fire_timer,
)
from .models import Game, PlayerRole


class DebugStateView(APIView):
    """Read-only authoritative oracle for a game (DEBUG only; 403 otherwise).

    Returns EVERY player's ground truth (original + current role, copied role,
    effective team), the full night-action log, all votes, and results once
    available. This is the harness assertion oracle and the toolbar god panel.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request: Request, game_id: str) -> Response:
        disabled = debug_disabled_response()
        if disabled is not None:
            return disabled

        try:
            game = Game.objects.select_related("lobby").get(id=game_id)
        except (Game.DoesNotExist, ValueError, ValidationError):
            return Response(
                {"detail": "Game not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Caller must be a player in this game — same membership bar as every
        # other game endpoint, so the oracle is not reachable by an arbitrary
        # authenticated user even in DEBUG.
        if not PlayerRole.objects.filter(game=game, user=request.user).exists():
            return Response(
                {"detail": "You are not a player in this game."},
                status=status.HTTP_403_FORBIDDEN,
            )

        return Response(build_debug_state(game))


class DebugFireTimerView(APIView):
    """Synchronously fire a game's pending phase/wave timer (DEBUG only).

    Request body: ``{"key": "wave:1" | "wave:2" | "discussion" | "voting" | "current"}``
    (``wave:n`` is night window n; firing it closes that window now).
    See ``apps.onuw.debug.fire_timer`` for the firing mechanism and the
    ``current`` resolution rule.

    Response:
        200 ``{"fired": bool, "key": "<resolved registry key>"}`` — ``fired`` is
        False when no timer was pending for the resolved key (safe no-op).
        400 when ``key`` is missing/invalid, or ``current`` is ambiguous.
        403 when DEBUG is False.
        404 when the game does not exist.
    """

    permission_classes = [IsAuthenticated]

    _ALLOWED_FIXED_SUFFIXES = {"discussion", "voting", "look", "current"}

    def post(self, request: Request, game_id: str) -> Response:
        disabled = debug_disabled_response()
        if disabled is not None:
            return disabled

        try:
            game = Game.objects.select_related("lobby").get(id=game_id)
        except (Game.DoesNotExist, ValueError, ValidationError):
            return Response(
                {"detail": "Game not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        if not PlayerRole.objects.filter(game=game, user=request.user).exists():
            return Response(
                {"detail": "You are not a player in this game."},
                status=status.HTTP_403_FORBIDDEN,
            )

        key = request.data.get("key")
        if not self._is_valid_key(key):
            return Response(
                {"detail": "Invalid timer key."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            fired, resolved_key = fire_timer(game, key)
        except ForcedAssignmentError as exc:
            return Response(
                {"detail": str(exc)},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # The resolved key is the full registry key (e.g. "<game_id>:wave:2");
        # strip the game prefix so the response echoes a stable suffix.
        suffix = resolved_key.removeprefix(f"{game.id}:")
        return Response({"fired": fired, "key": suffix})

    @classmethod
    def _is_valid_key(cls, key: object) -> bool:
        if not isinstance(key, str):
            return False
        if key in cls._ALLOWED_FIXED_SUFFIXES:
            return True
        # wave:{n} with n a non-negative int.
        if key.startswith("wave:"):
            _, _, n = key.partition(":")
            return n.isdigit()
        return False
