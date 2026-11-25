"""``persist_wave_results`` writes only the rows that changed."""

import dataclasses

from django.db import connection
from django.test.utils import CaptureQueriesContext

import pytest

from apps.onuw import basics, night_window
from apps.onuw.engine.state import ActionResult

pytestmark = pytest.mark.integration

ROLES = {
    "wolf": "Werewolf",
    "seer": "Seer",
    "robber": "Robber",
    "villager": "Villager",
    "tanner": "Tanner",
}
CENTER = ["Villager", "Tanner", "Hunter"]


def player_role_updates(queries: CaptureQueriesContext) -> list[str]:
    return [
        q["sql"]
        for q in queries.captured_queries
        if q["sql"].startswith('UPDATE "onuw_playerrole"')
    ]


def test_a_window_with_no_swap_and_no_result_updates_no_player_row(make_night) -> None:
    night = make_night(ROLES, CENTER, night_wave_seconds=60)
    state = basics.build_game_state(night.game)

    with CaptureQueriesContext(connection) as queries:
        night_window.persist_wave_results(night.game, state, [], 2)

    assert player_role_updates(queries) == []


def rows_written(update: str) -> int:
    """How many rows one (bulk) UPDATE names in its ``WHERE id IN (...)``."""
    names = update.rsplit(" IN (", 1)[1]
    return names.count(",") + 1


def test_only_the_two_players_whose_cards_moved_are_updated_in_one_write(
    make_night,
) -> None:
    night = make_night(ROLES, CENTER, night_wave_seconds=60)
    state = basics.build_game_state(night.game)
    roles = dict(state.player_roles)
    robber, seer = night.users["robber"].id, night.users["seer"].id
    roles[robber], roles[seer] = roles[seer], roles[robber]
    moved = dataclasses.replace(state, player_roles=roles)

    with CaptureQueriesContext(connection) as queries:
        night_window.persist_wave_results(night.game, moved, [], 2)

    (update,) = player_role_updates(queries)
    assert rows_written(update) == 2
    assert night.role_of("robber").current_role == "Seer"
    assert night.role_of("seer").current_role == "Robber"
    assert night.role_of("wolf").current_role == "Werewolf"


def test_a_player_with_a_result_gets_one_write_and_the_others_none(
    make_night,
) -> None:
    night = make_night(ROLES, CENTER, night_wave_seconds=60)
    state = basics.build_game_state(night.game)
    seer = night.users["seer"].id
    result = ActionResult(
        player_id=seer,
        revealed_info={"roles": ["Villager", "Tanner"]},
        state_mutations=[],
    )

    with CaptureQueriesContext(connection) as queries:
        night_window.persist_wave_results(night.game, state, [result], 2)

    (update,) = player_role_updates(queries)
    assert rows_written(update) == 1
    data = night.role_of("seer").night_action_data
    assert data["wave_2_result"] == {"roles": ["Villager", "Tanner"]}
    assert night.role_of("wolf").night_action_data == {}


def test_moved_cards_and_results_of_several_players_are_one_write(make_night) -> None:
    night = make_night(ROLES, CENTER, night_wave_seconds=60)
    state = basics.build_game_state(night.game)
    roles = dict(state.player_roles)
    robber, seer = night.users["robber"].id, night.users["seer"].id
    wolf = night.users["wolf"].id
    roles[robber], roles[seer] = roles[seer], roles[robber]
    moved = dataclasses.replace(state, player_roles=roles)
    results = [
        ActionResult(
            player_id=robber, revealed_info={"new_role": "Seer"}, state_mutations=[]
        ),
        ActionResult(
            player_id=wolf, revealed_info={"pack": [wolf]}, state_mutations=[]
        ),
    ]

    with CaptureQueriesContext(connection) as queries:
        night_window.persist_wave_results(night.game, moved, results, 2)

    (update,) = player_role_updates(queries)
    assert rows_written(update) == 3
    robbed = night.role_of("robber")
    assert robbed.current_role == "Seer"
    assert robbed.night_action_data["wave_2_result"] == {"new_role": "Seer"}
    assert night.role_of("seer").current_role == "Robber"
    assert night.role_of("seer").night_action_data == {}
    assert night.role_of("wolf").current_role == "Werewolf"
    assert night.role_of("wolf").night_action_data["wave_2_result"] == {"pack": [wolf]}
    assert night.role_of("villager").night_action_data == {}
