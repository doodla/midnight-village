"""The results of a finished game: ``GET .../results/``'s body.

The same for every player (the game is over, nothing is hidden), so it is built
once from the rows the caller read and sent as it is: by the results view, and
with each player's own view on their socket when the game ends (``own_view``).
"""

from __future__ import annotations

from typing import Any

from apps.core.wire import public_name

from .engine.win_conditions import get_effective_team
from .models import Game, PlayerRole
from .night_results import night_timeline_for
from .serializers import player_identity


def results_body(game: Game, player_roles: list[PlayerRole]) -> dict[str, Any]:
    """The results of ``game`` (in ``results``), from every one of its rows in seat
    order with ``user`` loaded: the winning teams and reason, the eliminated, every
    player's dealt and final card, team, outcome and vote, the centre, the night's
    log and its timeline (null when it cannot be built)."""
    eliminated_ids = set(game.results.get("eliminated_players", []))
    elimination_reasons: dict[str, str] = game.results.get("elimination_reasons", {})
    outcomes: dict[str, str] = game.results.get("player_outcomes", {})

    current_roles: dict[int, str] = {}
    doppelganger_copied: dict[int, str] = {}
    for pr in player_roles:
        current_roles[pr.user_id] = pr.current_role
        if pr.original_role == "Doppelganger" and pr.night_action_data.get(
            "copied_role"
        ):
            doppelganger_copied[pr.user_id] = pr.night_action_data["copied_role"]

    eliminated_details = []
    players_data = []
    for pr in player_roles:
        is_eliminated = pr.user_id in eliminated_ids
        players_data.append(
            {
                **player_identity(pr),
                "original_role": pr.original_role,
                "final_role": pr.current_role,
                "team": get_effective_team(
                    pr.user_id, current_roles, doppelganger_copied
                ),
                "is_eliminated": is_eliminated,
                "elimination_reason": elimination_reasons.get(str(pr.user_id)),
                "outcome": outcomes.get(str(pr.user_id), "lose"),
                "vote_target_id": pr.vote_target_id,
            }
        )
        if is_eliminated:
            eliminated_details.append(
                {
                    "player_id": pr.user_id,
                    "display_name": public_name(pr.user),
                    "role": pr.current_role,
                    "elimination_reason": elimination_reasons.get(str(pr.user_id)),
                }
            )

    return {
        "winning_teams": game.results.get("winning_teams", []),
        "reason": game.results.get("reason", ""),
        "eliminated_players": eliminated_details,
        "players": players_data,
        "center_cards": list(game.center_cards),
        "night_actions_log": list(game.night_actions_log),
        "night_timeline": night_timeline_for(game, player_roles),
    }
