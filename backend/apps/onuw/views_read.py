"""
ONUW views that only read: the players of a game, a lobby's current game, a player's
recent games, and the results.
"""

import logging

from django.core.exceptions import ValidationError
from django.db.models import Count

from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.core.practice import is_practice
from apps.core.wire import wire_time

from . import presence
from .models import Game, Phase, PlayerRole
from .night_results import night_timeline_for
from .serializers import (
    player_identity,
)

logger = logging.getLogger(__name__)


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
                    "ended_at": wire_time(pr.game.updated_at),
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
