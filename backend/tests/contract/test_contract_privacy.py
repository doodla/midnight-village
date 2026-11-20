"""Private socket events reach only their player (principle 2), checked on the
recorded samples.

Every socket sample's index entry says which group delivered it and who got
it (``recorder.Table.record_event``); ``test_contract_samples.py`` keeps the
committed index equal to what the server sends. So if a change moved a night
prompt or result onto the table's broadcast group, the samples' diff would show
it and this test would fail on the regenerated index.
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

import pytest

from apps.onuw.engine.roles import ROLE_REGISTRY

pytestmark = pytest.mark.contract

SAMPLES_DIR = Path(__file__).resolve().parents[3] / "contract_samples"

# Events about one player's own night: never for anyone else.
PRIVATE = {"action_prompt", "action_result", "wave_waiting"}
# The end of the game: every card is shown to everyone.
AFTER_RESULTS = {"game_results"}
ROLE_NAME = re.compile(
    r"\b(" + "|".join(re.escape(name) for name in ROLE_REGISTRY) + r")\b", re.IGNORECASE
)


def _socket_samples() -> list[dict[str, Any]]:
    index = json.loads((SAMPLES_DIR / "index.json").read_text(encoding="utf-8"))
    return [s for s in index["samples"] if s["kind"] == "ws"]


def _payload(sample: dict[str, Any]) -> Any:
    return json.loads((SAMPLES_DIR / f"{sample['name']}.json").read_text("utf-8"))


def test_every_socket_sample_says_who_received_it() -> None:
    samples = _socket_samples()
    assert samples
    for sample in samples:
        assert sample["group"] in ("player", "broadcast"), sample["name"]
        assert sample["recipients"], sample["name"]


@pytest.mark.parametrize(
    "sample",
    [s for s in _socket_samples() if s["type"] in PRIVATE],
    ids=lambda s: s["name"],
)
def test_a_night_event_goes_to_its_player_alone(sample: dict[str, Any]) -> None:
    assert sample["group"] == "player"
    assert len(sample["recipients"]) == 1


@pytest.mark.parametrize(
    "sample",
    [
        s
        for s in _socket_samples()
        if s["socket"] == "game"
        and s["group"] == "broadcast"
        and s["type"] not in AFTER_RESULTS
    ],
    ids=lambda s: s["name"],
)
def test_nothing_broadcast_to_the_game_before_the_results_names_a_role(
    sample: dict[str, Any],
) -> None:
    found = ROLE_NAME.search(json.dumps(_payload(sample)))
    assert found is None, f"{sample['name']} tells everyone '{found.group()}'"


def _sequence_samples() -> list[dict[str, Any]]:
    index = json.loads((SAMPLES_DIR / "index.json").read_text(encoding="utf-8"))
    return [s for s in index["samples"] if s["kind"] == "ws_sequence"]


def test_there_are_night_protocol_2_sequences_to_check() -> None:
    names = {s["name"] for s in _sequence_samples()}
    assert {
        "ws_sequence/look_stage",
        "ws_sequence/window_1",
        "ws_sequence/window_2",
        "ws_sequence/window_2_doppelganger",
        "ws_sequence/talk_and_vote",
    } <= names


@pytest.mark.parametrize("sample", _sequence_samples(), ids=lambda s: s["name"])
def test_under_night_protocol_2_every_seat_hears_the_same_events_in_the_same_order(
    sample: dict[str, Any],
) -> None:
    """The types and the order of what each seat's socket received in a window are
    the same for every seat, whatever it was dealt, and none of it is a player-only
    night event (a prompt, a result, a waiting notice): a seat whose list differed
    would be telling the table what it holds."""
    sequences: dict[str, list[str]] = _payload(sample)
    assert len(sequences) >= 5
    reference = next(iter(sequences.values()))
    assert reference, "nothing was heard: the sample records nothing"
    for seat, heard in sequences.items():
        assert heard == reference, f"{seat} heard something different"
    assert not {event for event in reference if event in PRIVATE}


@pytest.mark.parametrize(
    "sample",
    [
        s
        for s in _socket_samples()
        if s["type"] in {"night_window", "progress", "wave_complete"}
    ],
    ids=lambda s: s["name"],
)
def test_the_night_window_progress_and_close_events_go_to_the_whole_table(
    sample: dict[str, Any],
) -> None:
    assert sample["group"] == "broadcast"
    assert len(sample["recipients"]) >= 5
    # Counts and window numbers only: no player id, no role.
    allowed = {"type", "stage", "done", "needed", "window", "deadline", "wave"}
    assert set(_payload(sample)) <= allowed
