"""Each player's own view as a stage opens (``apps/onuw/own_view.py``).

Played on the six-seat game the contract records (``ws_stream/six_seats``), every
message the server sent read back:

- at every stage change each person already holds a view of the new stage when
  the table's event comes, so a phone reads nothing (the designed number is 0);
- the table's group never carries anything of one player's;
- a view goes only to its own player's group, and the consumer forwards it only to
  that player's socket;
- a view that cannot be built still lets the table hear the stage open.
"""

from __future__ import annotations

import json
from typing import Any
from unittest.mock import patch

import pytest
from asgiref.sync import async_to_sync

from apps.onuw import basics
from apps.onuw.consumers import GameConsumer
from tests.contract.recorder import recording
from tests.contract.stream_scenarios import SIX, StreamTable, stream_table

pytestmark = [pytest.mark.django_db, pytest.mark.uses_timers]

PHASES = ("night", "discussion", "voting", "results")
# The table's events that open a stage, and the stage's place they announce.
STAGE_EVENTS = {"night.window", "phase.change", "vote.reveal", "game.results"}
# What only one player's own view holds: never in a message to the whole table.
OWN_KEYS = {
    "me",
    "your_role",
    "night_results",
    "night_results_seen",
    "action_prompt",
    "my_vote",
    "ready",
    "vote_targets",
    "night_action_data",
    "is_host",
}


def place(phase: str, wave: int) -> tuple[int, int]:
    """Where a stage is in its game: the phase, then the window (only rises)."""
    return (PHASES.index(phase), wave)


def event_place(message: dict[str, Any]) -> tuple[int, int]:
    kind = message["type"]
    if kind == "night.window":
        return place("night", message["window"])
    if kind == "phase.change":
        return place(message["phase"], 0)
    return place("results", 0)


def keys(value: Any) -> set[str]:
    """Every key anywhere in a JSON value."""
    if isinstance(value, dict):
        return set(value) | {k for v in value.values() for k in keys(v)}
    if isinstance(value, list):
        return {k for v in value for k in keys(v)}
    return set()


@pytest.fixture
def game(django_capture_on_commit_callbacks: Any) -> StreamTable:
    with recording(django_capture_on_commit_callbacks) as run:
        return stream_table(run)


def test_at_every_stage_change_each_person_already_holds_the_new_stage(
    game: StreamTable,
) -> None:
    """The designed number of reads at a stage change is 0 for every phone: its
    own view of the new stage is on its own group, in the same batch, BEFORE the
    table's event (a phone compares the two places and reads nothing)."""
    group = f"game_{game.game_id}"
    reads: dict[str, list[int]] = {name: [] for name in SIX}
    held = dict.fromkeys(SIX, (-1, -1))
    for to, message in game.layer.sent:
        for name in SIX:
            own = f"{group}_player_{game.pid(name)}"
            if to == own and message["type"] == "own.view":
                view = message["me"]
                held[name] = max(held[name], place(view["phase"], view["current_wave"]))
            elif to == group and message["type"] in STAGE_EVENTS:
                reads[name].append(0 if held[name] >= event_place(message) else 1)
    # The look's end, window 2's close, the talk's end, the reveal and results.
    assert reads == {name: [0, 0, 0, 0, 0] for name in SIX}


def test_nothing_sent_to_the_whole_table_is_one_players(game: StreamTable) -> None:
    group = f"game_{game.game_id}"
    shared = [m for to, m in game.layer.sent if to == group]
    assert len(shared) > 20
    for message in shared:
        assert not keys(message) & OWN_KEYS, message
    # Nor does any carry another seat's view by its values: no player's card
    # before the results (the deck in a view is public; a card in a shared
    # message would not be).
    before_end = shared[
        : next(i for i, m in enumerate(shared) if m["type"] == "vote.reveal")
    ]
    text = json.dumps(before_end)
    for role in ("Seer", "Robber", "Troublemaker", "Werewolf", "Insomniac"):
        assert role not in text


def test_an_own_view_goes_only_to_its_own_player(game: StreamTable) -> None:
    views = [(to, m) for to, m in game.layer.sent if "_player_" in to]
    # One per person at each of the four stage openings (the reveal and the
    # results open one), nothing else.
    assert len(views) == 4 * len(SIX)
    for to, message in views:
        assert message["type"] == "own.view"
        assert to == f"game_{game.game_id}_player_{message['me']['player_id']}"
    # Each phone heard only its own: what its socket got names it alone.
    for name, items in game.stream.items():
        seen = [
            i["event"] for i in items if "event" in i and i["event"]["type"] == "me"
        ]
        assert {view["me"]["player_id"] for view in seen} == {game.pid(name)}


def _sent_by_consumer(user_id: int, message: dict[str, Any]) -> list[dict]:
    consumer = GameConsumer()
    consumer.user_id = user_id
    out: list[dict] = []

    async def base_send(frame: dict[str, Any]) -> None:
        out.append(json.loads(frame["text"]))

    consumer.base_send = base_send
    async_to_sync(consumer.own_view)(message)
    return out


def test_the_socket_forwards_a_view_only_to_the_player_it_names() -> None:
    view = {"type": "own.view", "me": {"player_id": 7, "phase": "night"}}
    assert _sent_by_consumer(7, view) == [{"type": "me", "me": view["me"]}]
    # Addressed to the wrong socket (a bug upstream): it reaches nobody.
    assert _sent_by_consumer(8, view) == []
    assert _sent_by_consumer(8, {"type": "own.view"}) == []


def test_a_view_that_cannot_be_built_still_lets_the_table_hear(
    django_capture_on_commit_callbacks: Any,
) -> None:
    def broken(game_id: Any) -> list:
        raise RuntimeError("no view")

    with (
        patch.object(basics, "own_views", broken),
        patch.object(StreamTable, "record_event", lambda *a, **k: None),
    ):
        with recording(django_capture_on_commit_callbacks) as run:
            game = stream_table(run)
    group = f"game_{game.game_id}"
    assert not [to for to, _ in game.layer.sent if "_player_" in to]
    kinds = [m["type"] for to, m in game.layer.sent if to == group]
    assert [k for k in kinds if k in STAGE_EVENTS] == [
        "night.window",
        "phase.change",
        "phase.change",
        "vote.reveal",
        "game.results",
    ]


def test_the_results_go_once_on_the_tables_game_results(game: StreamTable) -> None:
    """At the end the results are public and the same for everyone: they ride
    once on the table's ``game.results`` (the end board needs no read), never
    inside the private views."""
    group = f"game_{game.game_id}"
    ends = [
        m for to, m in game.layer.sent if to == group and m["type"] == "game.results"
    ]
    assert len(ends) == 1
    results = ends[0]["data"]["results"]
    assert {"players", "winning_teams", "night_timeline"} <= set(results)
    assert len(results["players"]) == len(SIX)
    views = [m for to, m in game.layer.sent if m["type"] == "own.view"]
    assert views and not [v for v in views if "results" in v]


def test_a_view_goes_out_only_when_a_stage_opens(game: StreamTable) -> None:
    """The phone drops a view of the stage it already holds (a stage is its
    phase and window). So the server never sends a second view within a stage:
    for each player the views' places strictly rise. Fails the day a view is
    pushed within a stage (a moved deadline, a re-announce), which would then
    need a sequence number per game."""
    for name in SIX:
        own = f"game_{game.game_id}_player_{game.pid(name)}"
        places = [
            place(m["me"]["phase"], m["me"]["current_wave"])
            for to, m in game.layer.sent
            if to == own
        ]
        assert places == sorted(set(places)), f"{name}: {places}"


def test_a_view_that_cannot_be_packed_still_lets_the_table_hear(
    django_capture_on_commit_callbacks: Any,
) -> None:
    """A view the live layer cannot carry (here an int-keyed dict, which
    msgpack refuses to unpack) fails the batch: the table's events go out alone,
    as they were, and the phones read when they hear them."""
    from apps.core import effects

    table = [("game_x", {"type": "phase.change", "phase": "voting"})]

    def unpackable(sent: list) -> tuple[list, list]:
        return [("game_x_player_1", {"type": "own.view", "me": {1: "x"}})], sent

    with recording(django_capture_on_commit_callbacks) as run:
        with (
            patch("apps.core.effects.get_channel_layer", return_value=run.layer),
            django_capture_on_commit_callbacks(execute=True),
        ):
            effects.send_built_after_commit(unpackable, table)
        assert run.layer.sent == table
