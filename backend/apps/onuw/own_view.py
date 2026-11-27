"""Each player's own view (``GET /me/``'s body), sent on that player's own socket
when a stage opens, so no phone has to ask for what it was just told.

Sent by ``basics._send_stage_after_commit`` (this module is plugged into it at
start-up, ``apps.py``: the service's layers cannot import the serializers).
A stage opening (a night window, the talk, the vote, the results) tells the table
with one group event as before (``night_window``, ``phase_change``, ``vote_reveal``
and ``game_results``), and now, FIRST in the same batch, every person at the table
their own view: ``{"type": "me", "me": <their GET /me/ body>}`` and, at the
results, ``"results": <GET .../results/>`` (the same for everyone). A phone that
holds a view of that stage when the group event comes reads nothing; one that does
not (an older server, a lost message) reads ``/me/`` as before. Within a game the
stage only moves forward (phase, then window: ``protocol``), so "newest wins" is a
compare of the stage's place, on the phone.

Hidden information, by construction (principle 2):

- A view is built from ONE player's row and goes to the group named from that same
  row's user id (``_own_message``); it carries that id as its ``player_id``.
- The game consumer forwards an own view only to a socket whose signed-in user is
  that ``player_id`` (``GameConsumer.own_view``): a view on any other group, a bug
  here, reaches nobody.
- The table's group events carry nothing per player
  (``tests/onuw/test_own_view.py`` reads every message of whole games).

Cost: the views are built after the stage's transaction commits, from the
committed rows, in a fixed number of queries whatever the table's size (the game,
its rows, the count; ``tests/perf/test_tap_query_budget.py``). Practice players
have no phone and get none.
"""

from __future__ import annotations

from typing import Any

from apps.core.practice import is_practice

from .basics import game_state_from
from .models import Game, Phase, PlayerRole
from .readiness import stage_progress
from .results import results_body
from .serializers import GameMeSerializer

# The channel message type (``GameConsumer.own_view``); the phone hears ``me``.
OWN_VIEW = "own.view"


def player_group(game_id: Any, user_id: int) -> str:
    """The game group of one player's own sockets (``GameConsumer``)."""
    return f"game_{game_id}_player_{user_id}"


def me_body(
    game: Game,
    player_role: PlayerRole,
    all_player_roles: list[PlayerRole],
    shared: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """``GET /me/``'s body for ``player_role``: the ONE builder, for the endpoint
    and for the view sent on the player's socket, so the two cannot differ.
    ``all_player_roles``: every row of the game in seat order, ``user`` loaded.
    ``shared``: the parts that are the same for every player, built once by a
    caller that builds several (``views_for``)."""
    context: dict[str, Any] = {
        "player_role": player_role,
        "all_player_roles": all_player_roles,
        **(shared or {}),
    }
    return GameMeSerializer(game, context=context).data


def views_for(game: Game, all_player_roles: list[PlayerRole]) -> list[dict[str, Any]]:
    """Every person's own view (practice players have no phone), in seat order:
    the count and the engine state are built once for all of them."""
    shared = {
        "progress": stage_progress(game),
        "game_state": game_state_from(game, all_player_roles),
    }
    return [
        me_body(game, pr, all_player_roles, shared)
        for pr in all_player_roles
        if not is_practice(pr.user)
    ]


def _own_message(
    game_id: Any, view: dict[str, Any], results: dict[str, Any] | None
) -> tuple[str, dict[str, Any]]:
    """One player's view on that player's own group: the group is named from the
    view's own ``player_id``, so a view can only be addressed to its owner."""
    message: dict[str, Any] = {"type": OWN_VIEW, "me": view}
    if results is not None:
        message["results"] = results
    return player_group(game_id, view["player_id"]), message


def own_view_messages(game_id: Any) -> list[tuple[str, dict[str, Any]]]:
    """Every person's own view of ``game_id`` as it is now (committed), each on
    their own group; at the results each also carries the results."""
    game = Game.objects.select_related("lobby").get(id=game_id)
    # pyrefly: ignore [missing-attribute]
    prs = list(game.player_roles.select_related("user").all())
    results = results_body(game, prs) if game.phase == Phase.RESULTS else None
    return [_own_message(game.id, view, results) for view in views_for(game, prs)]
