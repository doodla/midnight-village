"""ONUW app views."""

import secrets

from django.core.exceptions import ValidationError
from django.db import transaction

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.models import Lobby

from .engine.assignment import assign_roles
from .engine.validation import validate_onuw_settings
from .models import Game, Phase, PlayerRole
from .serializers import GameMeSerializer, GameStartResponseSerializer


class GameStartView(APIView):
    """Start an ONUW game from a lobby."""

    permission_classes = [IsAuthenticated]

    def post(self, request: Request, code: str) -> Response:
        # Look up lobby
        try:
            lobby = Lobby.objects.select_related("host").get(code=code)
        except Lobby.DoesNotExist:
            return Response(
                {"detail": "Lobby not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Host-only check
        if lobby.host_id != request.user.id:  # type: ignore[misc]
            return Response(
                {"detail": "Only the host can start the game."},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Lobby must be in waiting state
        if lobby.status != Lobby.Status.WAITING:
            return Response(
                {"detail": "Lobby is not in waiting state."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Get all players
        members = lobby.players.select_related("user").all()  # type: ignore[misc]
        player_count = members.count()

        # All players must be ready
        if members.filter(is_ready=False).exists():
            return Response(
                {"detail": "Not all players are ready."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Validate ONUW settings
        errors = validate_onuw_settings(lobby.settings, player_count)
        if errors:
            return Response(
                {"detail": errors},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Generate a random seed for deterministic assignment
        seed = secrets.randbits(63)

        # Assign roles
        player_ids = [m.user_id for m in members]
        role_counts = lobby.settings["roles"]
        player_id_to_role, center_cards = assign_roles(role_counts, player_ids, seed)

        # Atomically create game state and update lobby
        with transaction.atomic():
            lobby.status = Lobby.Status.IN_GAME
            lobby.save(update_fields=["status", "updated_at"])

            game = Game.objects.create(
                lobby=lobby,
                phase=Phase.NIGHT,
                random_seed=seed,
                settings=lobby.settings,
                center_cards=center_cards,
            )

            player_roles = [
                PlayerRole(
                    game=game,
                    user_id=player_id,
                    original_role=role_name,
                    current_role=role_name,
                )
                for player_id, role_name in player_id_to_role.items()
            ]
            PlayerRole.objects.bulk_create(player_roles)

        # Broadcast game_started event
        channel_layer = get_channel_layer()
        if channel_layer is not None:
            async_to_sync(channel_layer.group_send)(
                f"lobby_{lobby.code}",
                {
                    "type": "game.started",
                    "game_id": str(game.id),
                    "phase": game.phase,
                },
            )

        serializer = GameStartResponseSerializer(
            {"game_id": game.id, "phase": game.phase}
        )
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class GameMeView(APIView):
    """
    Player-scoped game state endpoint.

    Returns only the information the requesting player is allowed to see.
    CRITICAL: Never include other players' roles, night_action_data, or center cards.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request: Request, game_id: str) -> Response:
        # Look up game
        try:
            game = Game.objects.get(id=game_id)
        except (Game.DoesNotExist, ValueError, ValidationError):
            return Response(
                {"detail": "Game not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Look up player role — 403 if not in this game
        try:
            player_role = PlayerRole.objects.get(game=game, user=request.user)
        except PlayerRole.DoesNotExist:
            return Response(
                {"detail": "You are not a player in this game."},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = GameMeSerializer(
            game,
            context={"player_role": player_role, "request": request},
        )
        return Response(serializer.data)
