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
from .services import (
    check_and_maybe_advance,
    end_discussion,
    get_player_acting_role_for_wave,
    reveal_votes,
    start_night_phase,
    submit_vote,
    validate_night_action,
)


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

        # Initialize the night phase (find first wave, send prompts)
        start_night_phase(game)

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

        # Look up player role -- 403 if not in this game
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


class NightActionView(APIView):
    """Submit a night action during the night phase."""

    permission_classes = [IsAuthenticated]

    def post(self, request: Request, game_id: str) -> Response:
        # 1. Look up game
        try:
            game = Game.objects.get(id=game_id)
        except (Game.DoesNotExist, ValueError, ValidationError):
            return Response(
                {"detail": "Game not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # 2. Validate game is in NIGHT phase
        if game.phase != Phase.NIGHT:
            return Response(
                {"detail": "Game is not in the night phase."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # 3. Look up PlayerRole (403 if not in game)
        try:
            pr = PlayerRole.objects.get(game=game, user=request.user)
        except PlayerRole.DoesNotExist:
            return Response(
                {"detail": "You are not a player in this game."},
                status=status.HTTP_403_FORBIDDEN,
            )

        # 4. Check player hasn't already acted this wave
        if pr.has_acted:
            return Response(
                {"detail": "You have already acted this wave."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # 5. Determine what role they're acting as this wave
        wave = game.current_wave
        acting_role = get_player_acting_role_for_wave(pr, wave)
        if acting_role is None:
            return Response(
                {"detail": "You do not act in the current wave."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # 6. Extract and validate action
        # pyrefly: ignore [missing-attribute]
        action_type = request.data.get("action_type")
        # pyrefly: ignore [missing-attribute]
        targets = request.data.get("targets", {})

        if not action_type:
            return Response(
                {"detail": "action_type is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        errors = validate_night_action(game, pr, action_type, targets)
        if errors:
            return Response(
                {"detail": errors},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # 7. Store action in night_action_data, set has_acted=True
        with transaction.atomic():
            # Preserve previously stored data (copied_role, wave_N_result keys)
            preserved = {
                k: v
                for k, v in pr.night_action_data.items()
                if k == "copied_role" or k.startswith("wave_")
            }
            pr.night_action_data = {
                **preserved,
                "wave": wave,
                "role_acting_as": acting_role,
                "action_type": action_type,
                "targets": targets,
            }
            pr.has_acted = True
            pr.save(update_fields=["night_action_data", "has_acted"])

        # 8. Check if all actors submitted -- auto-advance if so
        # Refresh game to get latest state
        game.refresh_from_db()
        check_and_maybe_advance(game)

        return Response({"status": "submitted"})


class WaveAdvanceView(APIView):
    """Force-advance the current wave (host only). Marks non-submitters as skipped."""

    permission_classes = [IsAuthenticated]

    def post(self, request: Request, game_id: str) -> Response:
        # Look up game
        try:
            game = Game.objects.get(id=game_id)
        except (Game.DoesNotExist, ValueError, ValidationError):
            return Response(
                {"detail": "Game not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Host-only check
        if game.lobby.host_id != request.user.id:  # type: ignore[misc]
            return Response(
                {"detail": "Only the host can force-advance the wave."},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Game must be in NIGHT phase
        if game.phase != Phase.NIGHT:
            return Response(
                {"detail": "Game is not in the night phase."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        from .services import advance_wave

        advance_wave(game)

        # Refresh to get updated state
        game.refresh_from_db()

        return Response(
            {
                "status": "advanced",
                "phase": game.phase,
                "current_wave": game.current_wave,
            }
        )


class EndDiscussionView(APIView):
    """End discussion early and transition to voting (host only)."""

    permission_classes = [IsAuthenticated]

    def post(self, request: Request, game_id: str) -> Response:
        # Look up game
        try:
            game = Game.objects.select_related("lobby").get(id=game_id)
        except (Game.DoesNotExist, ValueError, ValidationError):
            return Response(
                {"detail": "Game not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Host-only check
        if game.lobby.host_id != request.user.id:  # type: ignore[misc]
            return Response(
                {"detail": "Only the host can end the discussion."},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Game must be in DISCUSSION phase
        if game.phase != Phase.DISCUSSION:
            return Response(
                {"detail": "Game is not in the discussion phase."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        end_discussion(game)

        return Response({"status": "voting_started"})


class VoteView(APIView):
    """Submit a vote during the voting phase."""

    permission_classes = [IsAuthenticated]

    def post(self, request: Request, game_id: str) -> Response:
        # Look up game
        try:
            game = Game.objects.get(id=game_id)
        except (Game.DoesNotExist, ValueError, ValidationError):
            return Response(
                {"detail": "Game not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Extract target_player_id from request body
        # pyrefly: ignore [missing-attribute]
        target_player_id = request.data.get("target_player_id")
        if target_player_id is None:
            return Response(
                {"detail": "target_player_id is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            target_player_id = int(target_player_id)
        except (TypeError, ValueError):
            return Response(
                {"detail": "target_player_id must be an integer."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        errors = submit_vote(game, request.user.id, target_player_id)  # type: ignore[misc]
        if errors:
            return Response(
                {"detail": errors},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response({"status": "submitted"})


class ForceRevealView(APIView):
    """Force-reveal all votes (host only). Marks non-voters as abstaining."""

    permission_classes = [IsAuthenticated]

    def post(self, request: Request, game_id: str) -> Response:
        # Look up game
        try:
            game = Game.objects.select_related("lobby").get(id=game_id)
        except (Game.DoesNotExist, ValueError, ValidationError):
            return Response(
                {"detail": "Game not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Host-only check
        if game.lobby.host_id != request.user.id:  # type: ignore[misc]
            return Response(
                {"detail": "Only the host can force-reveal votes."},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Game must be in VOTING phase
        if game.phase != Phase.VOTING:
            return Response(
                {"detail": "Game is not in the voting phase."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        reveal_votes(game)

        return Response({"status": "revealed"})
