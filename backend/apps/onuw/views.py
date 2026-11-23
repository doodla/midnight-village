"""ONUW app views."""

import hmac
import logging
import secrets
from typing import Any

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import transaction
from django.db.models import Count

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core import timers
from apps.core.lobbies import ensure_tokens
from apps.core.models import Lobby, LobbyMember
from apps.core.practice import is_practice

from . import practice, presence
from .choose_night import CHOOSE_ERROR_CODES, submit_choose
from .deal import deal_refusal, dealt_settings
from .debug import ForcedAssignmentError, parse_forced_assignment
from .engine.assignment import assign_roles
from .engine.decks import auto_deck
from .models import Game, Phase, PlayerRole
from .night_results import acknowledge_night_results, night_timeline_for
from .protocol import (
    LOOK,
    NIGHT_CHOOSE_STAGES,
    TALK,
    VOTE,
    WRONG_STAGE_CODE,
    WRONG_STAGE_DETAIL,
    WrongStageError,
    require_stage,
)
from .serializers import (
    GameMeSerializer,
    GameStartResponseSerializer,
    player_identity,
)
from .services import (
    READY_ERROR_CODES,
    VOTE_ERROR_CODES,
    AlreadyActedError,
    advance_wave,
    begin_night,
    end_discussion,
    ensure_timers,
    reveal_votes,
    set_ready,
    submit_vote,
    timer_prefixes,
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


class NightActionView(APIView):
    """A phone's ``choose`` for the open night window."""

    permission_classes = [IsAuthenticated]

    def post(self, request: Request, game_id: str) -> Response:
        """``{"action_type": "choose", "picks": [...], "chosen": <the prompt's
        chosen>, "stage": <the stage from /me/>}`` from EVERY phone. The answer is
        ``{"status": "submitted"}`` for everyone, a resend of a choose already taken
        included (``chosen`` lower than the stored count); the only refusals are
        ``wrong_stage`` (409), ``already_chosen`` (409) and ``bad_request`` (400),
        none of them depending on the caller's role. What the picks MEAN is the
        server's business, decided when the stage ends (``choose_night``)."""
        try:
            game = Game.objects.get(id=game_id)
        except (Game.DoesNotExist, ValueError, ValidationError):
            return Response(
                {"detail": "Game not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        body = request.data if isinstance(request.data, dict) else {}
        if body.get("action_type") != "choose" or "picks" not in body:
            return _bad_request("Invalid action.")
        answered = body.get("chosen")
        # A plain JSON integer only (a bool is not a count): required, so a resend
        # can always be told from a new choose.
        if type(answered) is not int or answered < 0:
            return _bad_request("chosen is required (the prompt's chosen).")
        stage, refusal = _stage_of(request)
        if refusal is not None:
            return refusal
        if not PlayerRole.objects.filter(game=game, user=request.user).exists():
            return Response(
                {"detail": "You are not a player in this game."},
                status=status.HTTP_403_FORBIDDEN,
            )
        try:
            errors = submit_choose(
                game,
                request.user.id,  # type: ignore[misc]
                body["picks"],
                stage,
                answered,
            )
        except WrongStageError:
            return _wrong_stage()
        except AlreadyActedError:
            return Response(
                {"detail": "You have already chosen.", "code": "already_chosen"},
                status=status.HTTP_409_CONFLICT,
            )
        if errors:
            return Response(
                {
                    "detail": errors[0],
                    "code": CHOOSE_ERROR_CODES.get(errors[0], "bad_request"),
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        return Response({"status": "submitted"})


class NightResultsSeenView(APIView):
    """Acknowledge night results the caller has shown, so a restart does not show
    them again. ``{"seen": n}`` (a whole number, 0 to 10) answers
    ``{"night_results_seen": <stored count>}``. The count only goes up and is
    capped at the results the caller can see; it is the caller's own."""

    permission_classes = [IsAuthenticated]

    def post(self, request: Request, game_id: str) -> Response:
        try:
            game = Game.objects.get(id=game_id)
        except (Game.DoesNotExist, ValueError, ValidationError):
            return Response(
                {"detail": "Game not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        seen = request.data.get("seen") if isinstance(request.data, dict) else None
        # A plain JSON integer only: a bool, float or string is never coerced.
        if type(seen) is not int or not 0 <= seen <= MAX_NIGHT_RESULTS_SEEN:
            return Response(
                {
                    "detail": f"seen must be a whole number from 0 to {MAX_NIGHT_RESULTS_SEEN}.",
                    "code": "bad_request",
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        stored = acknowledge_night_results(game, request.user.id, seen)  # type: ignore[misc]
        if stored is None:
            return Response(
                {"detail": "You are not a player in this game."},
                status=status.HTTP_403_FORBIDDEN,
            )
        return Response({"night_results_seen": stored})


class WaveAdvanceView(APIView):
    """Close the current night window now (host only): a phone that has not chosen
    gets its role's default. In the look stage it opens the night."""

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

        # The stage the host saw when they tapped: a stale tap (the window already
        # moved on) must not close the next one.
        stage, refusal = _stage_of(request)
        if refusal is not None:
            return refusal

        # Acquire row lock and re-check phase to prevent race with timer
        # callbacks. Without this, concurrent timer + host requests can
        # double-process a wave, duplicating log entries and resetting
        # has_acted for the next wave (losing already-submitted actions).
        with transaction.atomic():
            game = Game.objects.select_for_update().get(id=game_id)
            try:
                require_stage(game, stage, expected=(LOOK, *NIGHT_CHOOSE_STAGES))
            except WrongStageError:
                return _wrong_stage()
            advance_wave(game)  # at window 0 it opens the first window

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
        stage, refusal = _stage_of(request)
        if refusal is not None:
            return refusal
        with transaction.atomic():
            game = Game.objects.select_for_update().get(id=game_id)
            try:
                require_stage(game, stage, expected=(TALK,))
            except WrongStageError:
                return _wrong_stage()
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

        def refuse(detail: Any, code: str, http_status: int) -> Response:
            return Response({"detail": detail, "code": code}, status=http_status)

        body = request.data if isinstance(request.data, dict) else None
        if body is None:
            return refuse("Body must be an object.", "bad_request", 400)

        # A plain JSON integer only: a bool, float or string is never coerced.
        target_player_id = body.get("target_player_id")
        if target_player_id is None:
            return refuse("target_player_id is required.", "bad_request", 400)
        if type(target_player_id) is not int:
            return refuse("target_player_id must be an integer.", "bad_request", 400)

        # ``lock`` is required: a pick (false) or a lock (true), never guessed.
        lock = body.get("lock")
        if type(lock) is not bool:
            return refuse("lock must be true or false", "bad_request", 400)

        stage, stage_refusal = _stage_of(request)
        if stage_refusal is not None:
            return stage_refusal

        # Check player membership (403) before delegating to service
        if not PlayerRole.objects.filter(game=game, user=request.user).exists():
            return Response(
                {"detail": "You are not a player in this game."},
                status=status.HTTP_403_FORBIDDEN,
            )

        try:
            errors = submit_vote(
                game,
                request.user.id,
                target_player_id,
                lock=lock,
                stage=stage,  # type: ignore[misc]
            )
        except WrongStageError:
            return _wrong_stage()
        except AlreadyActedError:
            return refuse(
                "You have already locked in your vote.",
                "vote_locked",
                status.HTTP_409_CONFLICT,
            )
        if errors:
            # ``detail`` stays a list of messages, as it always was.
            return refuse(
                errors,
                VOTE_ERROR_CODES.get(errors[0], "bad_request"),
                status.HTTP_400_BAD_REQUEST,
            )

        if lock:
            return Response({"status": "submitted"})
        # The stored pick, echoed: a lost or reordered request shows what stuck.
        return Response({"status": "picked", "target_player_id": target_player_id})


class ReadyView(APIView):
    """Tap "ready" at the stage that asks for it: ``{"ready": true | false}``.

    In the talk it toggles "ready to vote"; when every present player is ready the
    server ends the talk (what the host's button does). Answers
    ``{"status": "ok", "ready": <stored>}``. 409 ``wrong_stage`` anywhere else.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request: Request, game_id: str) -> Response:
        try:
            game = Game.objects.get(id=game_id)
        except (Game.DoesNotExist, ValueError, ValidationError):
            return Response(
                {"detail": "Game not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        body = request.data if isinstance(request.data, dict) else {}
        ready = body.get("ready")
        if type(ready) is not bool:
            return _bad_request("ready must be true or false")

        if not PlayerRole.objects.filter(game=game, user=request.user).exists():
            return Response(
                {"detail": "You are not a player in this game."},
                status=status.HTTP_403_FORBIDDEN,
            )

        stage, refusal = _stage_of(request)
        if refusal is not None:
            return refusal
        try:
            errors = set_ready(game, request.user.id, ready, stage)  # type: ignore[misc]
        except WrongStageError:
            return _wrong_stage()
        if errors:
            return Response(
                {
                    "detail": errors[0],
                    "code": READY_ERROR_CODES.get(errors[0], "bad_request"),
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        return Response({"status": "ok", "ready": ready})


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
        stage, refusal = _stage_of(request)
        if refusal is not None:
            return refusal
        with transaction.atomic():
            game = Game.objects.select_for_update().get(id=game_id)
            try:
                require_stage(game, stage, expected=(VOTE,))
            except WrongStageError:
                return _wrong_stage()
            reveal_votes(game)

        return Response({"status": "revealed"})


class PlayerListView(APIView):
    """
    List all players in a game with public info only.

    Returns player IDs, display names, tokens, seats and whether each player is
    connected. Never who has voted (the vote announces counts only).

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

        players = [
            {
                **player_identity(pr),
                # Presence is public: is any of their sockets open right now? A
                # practice player has no phone to drop: always here.
                "connected": pr.user_id in connected_ids or is_practice(pr.user),
            }
            for pr in all_prs
        ]

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


RECENT_GAMES_DEFAULT = 5
RECENT_GAMES_MAX = 10


def _recent_games_limit(raw: str | None) -> int:
    """``?limit=`` clamped to 1..10; a missing or unreadable value is the default."""
    try:
        return max(1, min(int(raw), RECENT_GAMES_MAX))  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return RECENT_GAMES_DEFAULT


class RecentGamesView(APIView):
    """The caller's finished games, newest first, with just enough for a list.

    Only games in ``results`` in which the caller played: an unfinished game holds
    live hidden information and "where am I" covers it. Nothing about anyone
    else's role, and no lobby code (it would let anyone read the lobby). The full
    detail stays behind ``results/``, which checks membership.
    """

    permission_classes = [IsAuthenticated]

    def get(self, request: Request) -> Response:
        limit = _recent_games_limit(request.query_params.get("limit"))
        mine = (
            PlayerRole.objects.filter(user=request.user, game__phase=Phase.RESULTS)
            .select_related("game")
            .annotate(player_count=Count("game__player_roles"))
            .order_by("-game__updated_at", "-game_id")[:limit]
        )
        games = []
        for pr in mine:
            outcomes = pr.game.results.get("player_outcomes", {})
            games.append(
                {
                    "game_id": str(pr.game_id),  # type: ignore[attr-defined]
                    "ended_at": pr.game.updated_at.isoformat(),
                    "player_count": pr.player_count,  # type: ignore[attr-defined]
                    "winning_teams": list(pr.game.results.get("winning_teams", [])),
                    "you_won": outcomes.get(str(request.user.id)) == "win",
                    "token": pr.token,
                    "seat": pr.seat,
                }
            )
        return Response({"games": games})


class ResultsView(APIView):
    """
    Get full game results after the game has ended.

    Returns all information (game is over, nothing is hidden):
    - Winning team and reason
    - Eliminated players with their roles
    - All player original and final roles, outcomes, and vote targets
    - Center cards (the final ones; the dealt ones are in the timeline)
    - Night actions log
    - The night timeline (null if the log cannot be replayed)
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
        player_roles_qs = list(
            game.player_roles.select_related("user", "vote_target").all()
        )

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
            "night_timeline": night_timeline_for(game, player_roles_qs),
        }

        return Response(response_data)
