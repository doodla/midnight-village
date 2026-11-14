"""The reference games in docs/specs/onuw/reference-games.md, replayed.

Each game is checked three ways: the two rule models (role by role, and one
shared window) must agree with each other and with the recorded outcome, the
engine's night must show every player the same thing, and the engine's vote
and win logic must produce the recorded deaths and winners.
"""

import json
from pathlib import Path

import pytest

from apps.onuw.engine import (
    apply_hunter,
    count_votes,
    determine_elimination,
    evaluate_winner,
)

from .night_rules_reference import engine, normalise, sequential, shared_window

pytestmark = pytest.mark.unit

GAMES = json.loads(
    (Path(__file__).parent / "data" / "reference_games.json").read_text()
)


def _choices(game: dict) -> dict:
    ch = dict(game["ch"])
    for key in ("seer", "doppel_follow"):
        value = ch.get(key)
        if isinstance(value, list) and value and value[0] in ("player", "center"):
            ch[key] = (value[0], value[1])
    return ch


def _recorded_views(game: dict) -> dict:
    def fix(value):
        if isinstance(value, list):
            return tuple(fix(v) for v in value)
        return value

    return {
        int(p): [(kind, fix(value)) for kind, value in items]
        for p, items in game["views"].items()
    }


@pytest.mark.parametrize("game", GAMES, ids=[f"game_{g['num']}" for g in GAMES])
def test_both_night_models_match_the_recorded_night(game: dict) -> None:
    ch = _choices(game)
    seq = sequential(game["dealt"], game["center"], ch)
    shared = shared_window(game["dealt"], game["center"], ch)

    assert seq == shared
    assert seq[0] == game["final"]
    assert seq[1] == game["final_center"]
    assert seq[2] == _recorded_views(game)


@pytest.mark.parametrize("game", GAMES, ids=[f"game_{g['num']}" for g in GAMES])
def test_engine_night_matches_the_rules(game: dict) -> None:
    ch = _choices(game)
    cards, center, views, _ = sequential(game["dealt"], game["center"], ch)
    eng_cards, eng_center, eng_views, _ = engine(game["dealt"], game["center"], ch)

    assert eng_cards == cards
    assert eng_center == center
    assert eng_views == normalise(views)


@pytest.mark.parametrize(
    "game",
    [g for g in GAMES if "votes" in g],
    ids=[f"game_{g['num']}" for g in GAMES if "votes" in g],
)
def test_engine_vote_and_winners_match_the_record(game: dict) -> None:
    roles = dict(enumerate(game["final"]))
    copied = (
        {game["dealt"].index("Doppelganger"): game["copied"]} if game["copied"] else {}
    )
    votes = {int(voter): target for voter, target in game["votes"].items()}

    voted_out = determine_elimination(count_votes(votes))
    dead = apply_hunter(voted_out, roles, votes, copied)
    result = evaluate_winner(dead, roles, copied)

    assert sorted(voted_out) == game["voted_out"]
    assert sorted(dead) == game["dead"]
    assert sorted(result.winning_teams) == game["winners"]
    assert [p for p, o in sorted(result.player_outcomes.items()) if o == "win"] == game[
        "won"
    ]
