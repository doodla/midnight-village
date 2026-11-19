"""ONUW app views."""

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
from apps.core.lobbies import ensure_tokens
from apps.core.models import Lobby

from . import presence
from .debug import ForcedAssignmentError, parse_forced_assignment
from .engine.assignment import assign_roles
from .engine.validation import validate_onuw_settings
from .models import Game, Phase, PlayerRole
from .serializers import (
    GameMeSerializer,
    GameStartResponseSerializer,
    player_identity,
)
from .services import (
    AlreadyActedError,
    advance_wave,
    check_and_maybe_advance,
    end_discussion,
    ensure_timers,
    get_player_acting_role_for_wave,
    resolve_doppelganger_look,
    reveal_votes,
    start_night_phase,
    submit_vote,
    timer_prefixes,
    validate_night_action,
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

        # Lobby must be in waiting state
        if lobby.status != Lobby.Status.WAITING:
            return Response(
                {"detail": "Lobby is not in waiting state."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # All players, in join order (their seat order).
        members = list(lobby.players.all())  # type: ignore[misc]
        player_count = len(members)
        ensure_tokens(lobby, members)  # a member made before tokens existed

        # All players must be ready
        if not all(m.is_ready for m in members):
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

        player_ids = [m.user_id for m in members]
        role_counts = lobby.settings["roles"]

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

        # Create game state and update lobby (same transaction as the checks)
        lobby.status = Lobby.Status.IN_GAME
        lobby.save(update_fields=["status", "updated_at"])

        game = Game.objects.create(
            lobby=lobby,
            phase=Phase.NIGHT,
            random_seed=seed,
            settings=lobby.settings,
            center_cards=center_cards,
            # The night overwrites center_cards as cards are swapped.
            dealt_center_cards=list(center_cards),
        )

        # Snapshot each member's token and seat (join order) into the game: the
        # game keeps them even if the member later leaves the lobby.
        seats = {m.user_id: (seat, m.token) for seat, m in enumerate(members)}
        player_roles = [
            PlayerRole(
                game=game,
                user_id=player_id,
                original_role=role_name,
                current_role=role_name,
                seat=seats[player_id][0],
                token=seats[player_id][1],
            )
            for player_id, role_name in player_id_to_role.items()
        ]
        PlayerRole.objects.bulk_create(player_roles)

        # Open the first window in the SAME transaction that creates the game,
        # so there is no committed night that never opened (an instance dying
        # between the two). Its sends and timers still run after the commit.
        start_night_phase(game)

        return game


class GameMeView(APIView):
    """
    Player-scoped game state endpoint.

    Returns only the information the requesting player is allowed to see.
    Includes a list of all players (public info only) and, during night
    phase, an action_prompt if the player needs to act in the current wave.

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

        # 3-7. Lock the Game row, then the PlayerRole row, and validate and
        # store the action atomically. The Game lock (same order as the timer
        # callbacks and check_and_maybe_advance: Game, then PlayerRole) makes
        # current_wave consistent and keeps a submission from landing in the
        # middle of a window closing. The PlayerRole lock prevents the TOCTOU
        # race on has_acted.
        with transaction.atomic():
            game = Game.objects.select_for_update().get(id=game.id)
            if game.phase != Phase.NIGHT:
                return Response(
                    {"detail": "Game is not in the night phase."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Lock the player role row
            try:
                pr = PlayerRole.objects.select_for_update().get(
                    game=game, user=request.user
                )
            except PlayerRole.DoesNotExist:
                return Response(
                    {"detail": "You are not a player in this game."},
                    status=status.HTTP_403_FORBIDDEN,
                )

            # 4. Check player hasn't already acted this window.
            # Return 409 Conflict (not 400) so the frontend can treat
            # duplicate submissions as idempotent success.
            if pr.has_acted:
                return Response(
                    {"detail": "You have already acted this wave."},
                    status=status.HTTP_409_CONFLICT,
                )

            # 5. Determine what role they're acting as this window
            wave = game.current_wave
            acting_role = get_player_acting_role_for_wave(pr, wave)
            if acting_role is None:
                return Response(
                    {"detail": "You do not act in the current wave."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # 6. Extract and validate action
            action_type = request.data.get("action_type")
            targets = request.data.get("targets")
            if targets is None:
                targets = {}

            if not action_type:
                return Response(
                    {"detail": "action_type is required."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            if not isinstance(action_type, str) or not isinstance(targets, dict):
                return Response(
                    {"detail": ["Invalid action."]},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            errors = validate_night_action(game, pr, action_type, targets)
            if errors:
                return Response(
                    {"detail": errors},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # 7. Store action in night_action_data, set has_acted=True
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

            # The Doppelganger's look resolves in the SAME transaction that stores
            # it: no committed look is ever waiting for a later step.
            if wave == 1 and acting_role == "Doppelganger":
                resolve_doppelganger_look(game)

        # 8. Check if all actors submitted -- auto-advance if so
        # Refresh game to get latest state
        game.refresh_from_db()
        check_and_maybe_advance(game)

        return Response({"status": "submitted"})


class WaveAdvanceView(APIView):
    """Close the current night window now (host only). Marks non-submitters as skipped."""

    permission_classes = [IsAuthenticated]

    def post(self, request: Request, game_id: str) -> Response:
        # Look up game (unlocked read for 404 and auth checks)
        try:
            game = Game.objects.select_related("lobby").get(id=game_id)
        except (Game.DoesNotExist, ValueError, ValidationError):
            return Response(
                {"detail": "Game not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Host-only check
        if not game.lobby.is_host(request.user.id):  # type: ignore[misc]
            return Response(
                {"detail": "Only the host can force-advance the wave."},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Acquire row lock and re-check phase to prevent race with timer
        # callbacks. Without this, concurrent timer + host requests can
        # double-process a wave, duplicating log entries and resetting
        # has_acted for the next wave (losing already-submitted actions).
        with transaction.atomic():
            game = Game.objects.select_for_update().get(id=game_id)
            if game.phase != Phase.NIGHT:
                return Response(
                    {"detail": "Game is not in the night phase."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
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
        # Look up game (unlocked read for 404 and auth checks)
        try:
            game = Game.objects.select_related("lobby").get(id=game_id)
        except (Game.DoesNotExist, ValueError, ValidationError):
            return Response(
                {"detail": "Game not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Host-only check
        if not game.lobby.is_host(request.user.id):  # type: ignore[misc]
            return Response(
                {"detail": "Only the host can end the discussion."},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Acquire row lock and re-check phase to prevent race with the
        # discussion timer callback. Without this, both paths can call
        # transition_to_voting, and the second resets has_acted/vote_target
        # for all players — deleting any votes submitted in the window.
        with transaction.atomic():
            game = Game.objects.select_for_update().get(id=game_id)
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

        # Check player membership (403) before delegating to service
        if not PlayerRole.objects.filter(game=game, user=request.user).exists():
            return Response(
                {"detail": "You are not a player in this game."},
                status=status.HTTP_403_FORBIDDEN,
            )

        try:
            errors = submit_vote(game, request.user.id, target_player_id)  # type: ignore[misc]
        except AlreadyActedError:
            return Response(
                {"detail": "You have already voted."},
                status=status.HTTP_409_CONFLICT,
            )
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
        # Look up game (unlocked read for 404 and auth checks)
        try:
            game = Game.objects.select_related("lobby").get(id=game_id)
        except (Game.DoesNotExist, ValueError, ValidationError):
            return Response(
                {"detail": "Game not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Host-only check
        if not game.lobby.is_host(request.user.id):  # type: ignore[misc]
            return Response(
                {"detail": "Only the host can force-reveal votes."},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Acquire row lock and re-check phase to prevent race with the
        # voting timer callback. Without this, both paths can call
        # reveal_votes, producing duplicate vote_reveal and game_results
        # WebSocket events.
        with transaction.atomic():
            game = Game.objects.select_for_update().get(id=game_id)
            if game.phase != Phase.VOTING:
                return Response(
                    {"detail": "Game is not in the voting phase."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            reveal_votes(game)

        return Response({"status": "revealed"})


class PlayerListView(APIView):
    """
    List all players in a game with public info only.

    Returns player IDs, display names and whether each player is connected.
    During voting phase, also includes has_voted status for each player.

    CRITICAL: Never reveals roles, night_action_data, or vote targets.
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

        # Check caller is a player in this game
        if not PlayerRole.objects.filter(game=game, user=request.user).exists():
            return Response(
                {"detail": "You are not a player in this game."},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Fetch all player roles with user info
        all_prs = game.player_roles.select_related("user").all()
        connected_ids = presence.connected_user_ids(game_id=game.id)

        players = []
        for pr in all_prs:
            entry = {
                **player_identity(pr),
                # Presence is public: is any of their sockets open right now?
                "connected": pr.user_id in connected_ids,
            }
            if game.phase == Phase.VOTING:
                entry["has_voted"] = bool(pr.has_acted)
            players.append(entry)

        return Response({"players": players})


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


class CurrentGameView(APIView):
    """
    Look up the authenticated user's current active game.

    Returns the game ID, phase, and lobby code if the user is currently
    in an active game (any phase except results). Returns {"game": null}
    if not in any active game.

    If the user is somehow in multiple active games (should not happen),
    returns the most recently created one.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        # Find the user's most recent active game (phase != results)
        active_pr = (
            PlayerRole.objects.filter(user=request.user)
            .exclude(game__phase=Phase.RESULTS)
            .select_related("game", "game__lobby")
            .order_by("-game__created_at")
            .first()
        )

        if active_pr is None:
            return Response({"game": None})

        game = active_pr.game
        return Response(
            {
                "game_id": str(game.id),
                "phase": game.phase,
                "lobby_code": game.lobby.code,
            }
        )


class ResultsView(APIView):
    """
    Get full game results after the game has ended.

    Returns all information (game is over, nothing is hidden):
    - Winning team and reason
    - Eliminated players with their roles
    - All player original and final roles, outcomes, and vote targets
    - Center cards (original and final)
    - Night actions log
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

        # Check user is a player in this game
        try:
            PlayerRole.objects.get(game=game, user=request.user)
        except PlayerRole.DoesNotExist:
            return Response(
                {"detail": "You are not a player in this game."},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Game must be in RESULTS phase
        if game.phase != Phase.RESULTS:
            return Response(
                {"detail": "Game results are not available yet."},
                status=status.HTTP_403_FORBIDDEN,
            )

        # Build full results response
        player_roles_qs = game.player_roles.select_related("user", "vote_target").all()

        # Build eliminated player details
        eliminated_ids = set(game.results.get("eliminated_players", []))
        elimination_reasons: dict[str, str] = game.results.get(
            "elimination_reasons", {}
        )

        # Build role/team lookup for effective team computation
        current_roles: dict[int, str] = {}
        doppelganger_copied: dict[int, str] = {}
        for pr in player_roles_qs:
            current_roles[pr.user_id] = pr.current_role
            if pr.original_role == "Doppelganger" and pr.night_action_data.get(
                "copied_role"
            ):
                doppelganger_copied[pr.user_id] = pr.night_action_data["copied_role"]

        from .engine.win_conditions import get_effective_team

        eliminated_details = []
        players_data = []

        for pr in player_roles_qs:
            is_eliminated = pr.user_id in eliminated_ids
            player_info = {
                **player_identity(pr),
                "original_role": pr.original_role,
                "final_role": pr.current_role,
                "team": get_effective_team(
                    pr.user_id, current_roles, doppelganger_copied
                ),
                "is_eliminated": is_eliminated,
                "elimination_reason": elimination_reasons.get(str(pr.user_id)),
                "outcome": game.results.get("player_outcomes", {}).get(
                    str(pr.user_id), "lose"
                ),
                "vote_target_id": pr.vote_target_id,
            }
            players_data.append(player_info)

            if is_eliminated:
                eliminated_details.append(
                    {
                        "player_id": pr.user_id,
                        "display_name": pr.user.display_name or pr.user.username,
                        "role": pr.current_role,
                        "elimination_reason": elimination_reasons.get(str(pr.user_id)),
                    }
                )

        response_data = {
            "winning_teams": game.results.get("winning_teams", []),
            "reason": game.results.get("reason", ""),
            "eliminated_players": eliminated_details,
            "players": players_data,
            "center_cards": list(game.center_cards),
            "night_actions_log": list(game.night_actions_log),
        }

        return Response(response_data)
