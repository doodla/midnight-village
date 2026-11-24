"""
ONUW views: dealing a game, a player's own page (``GET /me/``), and the timer sweep.

The requests a player makes during a game are in ``views_play.py``; the pages that only
read (the player list, the current and recent games, the results) are in
``views_read.py``. Every view here is thin: it checks who is asking, calls the service
and shapes the answer.
"""

import hmac
import logging
import secrets

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import transaction

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core import timers
from apps.core.lobbies import bump_rev, ensure_tokens
from apps.core.models import Lobby

from . import practice
from .deal import deal_refusal, dealt_settings
from .debug import ForcedAssignmentError, parse_forced_assignment
from .engine.assignment import assign_roles
from .engine.decks import auto_deck
from .models import Game, Phase, PlayerRole
from .night_flow import begin_night
from .recovery import ensure_timers, timer_prefixes
from .serializers import (
    GameMeSerializer,
    GameStartResponseSerializer,
)
from .view_helpers import (
    _snapshot_player_roles,
)

logger = logging.getLogger(__name__)


class GameStartView(APIView):
    """Start an ONUW game from a lobby."""

    permission_classes = [IsAuthenticated]

    def post(self, request: Request, code: str) -> Response:
        # The lobby row is locked from the status check to the game's creation:
        # a lobby can hold many games (play again), so nothing else stops a
        # double tap on Start from dealing two games on one table. The second
        # request waits for the lock, then sees the lobby is no longer waiting.
        with transaction.atomic():
            try:
                lobby = Lobby.objects.select_for_update().get(code=code)
            except Lobby.DoesNotExist:
                return Response(
                    {"detail": "Lobby not found."},
                    status=status.HTTP_404_NOT_FOUND,
                )
            outcome = self._deal(request, lobby)
            if isinstance(outcome, Response):
                # A refusal writes nothing: returning from inside atomic() would
                # COMMIT whatever was written before it.
                transaction.set_rollback(True)
                return outcome
            game = outcome

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

    def _deal(self, request: Request, lobby: Lobby) -> "Response | Game":
        """Validate and create the game. The caller holds the lobby row lock
        inside an atomic block. Returns an error Response or the new Game."""
        # Host-only check
        if not lobby.is_host(request.user.id):  # type: ignore[misc]
            return Response(
                {"detail": "Only the host can start the game."},
                status=status.HTTP_403_FORBIDDEN,
            )

        # All players, in join order (their seat order).
        members = list(lobby.players.all())  # type: ignore[misc]
        player_count = len(members)

        # Waiting, valid settings for this many players: the one rule the lobby
        # body's `deal.ok` reports too.
        refusal = deal_refusal(lobby, members)
        if refusal is not None:
            return Response(
                {"detail": refusal},
                status=status.HTTP_400_BAD_REQUEST,
            )

        player_ids = [m.user_id for m in members]
        game_settings = dealt_settings(lobby.settings)
        if game_settings.get("deck") == "auto":
            # The deck is built here, under the Lobby lock, for the players at the
            # table now; the lobby keeps saying "auto" for the next game. (The
            # validation above refused a table size with no deck.)
            game_settings["roles"] = auto_deck(
                player_count, game_settings.get("deck_chip")
            )
        role_counts = game_settings["roles"]

        # DEBUG-only assignment override. Honored ONLY when settings.DEBUG is
        # True; in production the `debug` key is ignored entirely, so it cannot
        # be used to control role assignment.
        debug = request.data.get("debug") if settings.DEBUG else None
        if isinstance(debug, dict) and "forced_assignment" in debug:
            try:
                player_id_to_role, center_cards = parse_forced_assignment(
                    debug["forced_assignment"], role_counts, player_ids
                )
            except ForcedAssignmentError as exc:
                # 400, non-leaky message, create nothing.
                return Response(
                    {"detail": str(exc)},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            # random_seed is non-nullable; a value is recorded but unused when
            # the assignment is explicit.
            seed = secrets.randbits(63)
        else:
            # Random assignment — from a DEBUG-supplied fixed seed when given
            # (reproducible), otherwise a fresh random seed.
            if isinstance(debug, dict) and "seed" in debug:
                try:
                    seed = int(debug["seed"])
                except (TypeError, ValueError):
                    return Response(
                        {"detail": "Invalid seed."},
                        status=status.HTTP_400_BAD_REQUEST,
                    )
            else:
                seed = secrets.randbits(63)
            player_id_to_role, center_cards = assign_roles(
                role_counts, player_ids, seed
            )

        # Everything is validated: from here on the deal writes (same transaction).
        ensure_tokens(lobby, members)  # a member made before tokens existed
        lobby.status = Lobby.Status.IN_GAME
        lobby.save(update_fields=["status", "updated_at"])
        bump_rev(lobby)  # the table's body changed (status, the dealt deck)

        game = Game.objects.create(
            lobby=lobby,
            phase=Phase.NIGHT,
            random_seed=seed,
            settings=game_settings,
            center_cards=center_cards,
            # The night overwrites center_cards as cards are swapped.
            dealt_center_cards=list(center_cards),
        )

        _snapshot_player_roles(game, members, player_id_to_role)

        # Open the first window in the SAME transaction that creates the game,
        # so there is no committed night that never opened (an instance dying
        # between the two). Its sends and timers still run after the commit.
        begin_night(game)

        return game


class GameMeView(APIView):
    """
    Player-scoped game state endpoint.

    Returns only the information the requesting player is allowed to see.
    Includes a list of all players (public info only) and, in an open night
    window, the caller's own ``action_prompt``.

    CRITICAL: Never include other players' roles, night_action_data, or center cards.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request: Request, game_id: str) -> Response:
        # Look up game
        try:
            game = Game.objects.select_related("lobby").get(id=game_id)
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

        # Fetch all player roles for the players list (public info only)
        all_player_roles = list(game.player_roles.select_related("user").all())

        # The backstop for practice players (``practice.behind``: no query at a
        # table without them): if one has not done its part in the stage open now
        # (the drive after the stage opened was lost), it acts now, and this read
        # shows the game after it.
        if practice.behind(game, all_player_roles):
            practice.drive(game.id)
            game.refresh_from_db()
            player_role.refresh_from_db()
            all_player_roles = list(game.player_roles.select_related("user").all())

        # Re-create any timer this game should have but this process lost (a
        # restart). Cheap when they are all registered; never blocks the read.
        try:
            ensure_timers(game, all_player_roles)
            # Re-publish this game's timers whose firing was lost (cheap: one
            # query when nothing is wrong).
            timers.sweep(timer_prefixes(game))
        except Exception:
            logger.exception("ensure_timers failed for game %s", game.id)

        serializer = GameMeSerializer(
            game,
            context={
                "player_role": player_role,
                "all_player_roles": all_player_roles,
                "request": request,
            },
        )
        return Response(serializer.data)


class SweepTimersView(APIView):
    """Re-publish durable timers whose firing was lost (for a platform cron).

    Refused (403) unless ``Authorization: Bearer <secret>`` matches the
    ``CRON_SECRET`` environment variable (setting ``ONUW_CRON_SECRET``); with no
    secret configured it always refuses. Vercel Cron issues a GET with that
    header, so GET and POST are both accepted. Reveals nothing but a count.
    """

    authentication_classes: list = []
    permission_classes = [AllowAny]
    throttle_classes: list = []

    def _sweep(self, request: Request) -> Response:
        secret = getattr(settings, "ONUW_CRON_SECRET", "")
        given = request.headers.get("Authorization", "")
        if not secret or not hmac.compare_digest(
            given.encode(), f"Bearer {secret}".encode()
        ):
            return Response({"detail": "Forbidden."}, status=status.HTTP_403_FORBIDDEN)
        return Response({"republished": timers.sweep()})

    def get(self, request: Request) -> Response:
        return self._sweep(request)

    def post(self, request: Request) -> Response:
        return self._sweep(request)
