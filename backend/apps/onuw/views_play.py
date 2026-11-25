"""
ONUW views: what a player sends during a game.

A night choice, the ack of night results, the host's advance, ending the talk, a vote,
"ready", and the forced reveal. Each checks who is asking and the stage they name, then
calls the service.
"""

import logging
from typing import Any

from django.core.exceptions import ValidationError
from django.db import transaction

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core import asked as ask

from .basics import AlreadyActedError
from .choose_night import CHOOSE_ERROR_CODES, submit_choose
from .models import Game, PlayerRole
from .night_flow import advance_wave
from .night_results import acknowledge_night_results
from .protocol import (
    LOOK,
    NIGHT_CHOOSE_STAGES,
    TALK,
    VOTE,
    WrongStageError,
    require_stage,
)
from .view_helpers import MAX_NIGHT_RESULTS_SEEN, _bad_request, _stage_of, _wrong_stage
from .voting import (
    READY_ERROR_CODES,
    VOTE_ERROR_CODES,
    end_discussion,
    reveal_votes,
    set_ready,
    submit_vote,
)

logger = logging.getLogger(__name__)


class NightActionView(APIView):
    """A phone's ``choose`` for the open night window."""

    permission_classes = [IsAuthenticated]

    def post(self, request: Request, game_id: str) -> Response:
        """``{"action_type": "choose", "picks": [...], "chosen": <the prompt's
        chosen>, "stage": <the stage from /me/>}`` from EVERY phone. The answer is
        ``{"status": "submitted", "night_results": [...], "chooses_left": n}`` for
        everyone, a resend of a choose already taken included (``chosen`` lower
        than the stored count): the caller's own results as ``GET /me/`` lists them
        now (a result already settled at the choose among them) and what the
        prompt still expects. The only refusals are ``wrong_stage`` (409),
        ``already_chosen`` (409) and ``bad_request`` (400), none of them depending
        on the caller's role. What the picks MEAN is the server's business
        (``choose_night``)."""
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
            errors, answer = submit_choose(
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
        return Response({"status": "submitted", **answer})


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
        asked, asked_refusal = ask.read(body)  # optional: the phone's tap time
        if asked_refusal is not None:
            return asked_refusal

        try:
            errors = submit_vote(
                game,
                request.user.id,
                target_player_id,
                lock=lock,
                stage=stage,  # type: ignore[misc]
                asked=asked,
            )
        except WrongStageError:
            return _wrong_stage()
        except ask.StaleRequestError as stale:
            return ask.stale_response(stale.newest)
        except AlreadyActedError:
            return refuse(
                "You have already locked in your vote.",
                "vote_locked",
                status.HTTP_409_CONFLICT,
            )
        if errors:
            # One message, a string, as every other refusal's ``detail`` is.
            return refuse(
                errors[0],
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
        asked, refusal = ask.read(body)  # optional: the phone's tap time
        if refusal is not None:
            return refusal
        try:
            errors = set_ready(game, request.user.id, ready, stage, asked)  # type: ignore[misc]
        except WrongStageError:
            return _wrong_stage()
        except ask.StaleRequestError as stale:
            return ask.stale_response(stale.newest)
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
