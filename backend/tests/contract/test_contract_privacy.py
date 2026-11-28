# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""What the sockets tell the table never gives a seat away (principle 2),
checked on the recorded samples.

Every socket sample's index entry says which group delivered it and who got
it (``recorder.Table.record_event``); ``test_contract_samples.py`` keeps the
committed index equal to what the server sends. The only thing a seat's socket
hears that another seat's does not is its own view (``me``, its own ``GET /me/``
on its own group, at the same moments for every seat, whatever it was dealt);
every other event, and the beat each socket sends its phone, is the same for
every seat.
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

# Events about one player's own night: never sent at all (a phone that got one
# while the others did not would be telling the table it acts).
PRIVATE = {"action_prompt", "action_result", "wave_waiting", "wave_start"}
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
        assert sample["group"] in ("player", "broadcast", "socket"), sample["name"]
        assert sample["recipients"], sample["name"]


# The beat's exact keys per socket: how often beats come, and the table's token
# (what every seat already knows: the lobby's number; the game's phase and
# window and whether its table moved on). Nothing about anyone.
BEAT_KEYS = {
    "lobby": {"type", "every", "rev"},
    "game": {"type", "every", "phase", "window", "moved_on"},
}


def test_what_a_socket_sends_its_own_phone_is_the_same_for_every_socket() -> None:
    """The one frame a consumer sends its socket directly (``group: socket``) is
    the beat, one shape per socket, exactly these keys; its values are the
    table's, so every seat's beat is the same bytes."""
    direct = [s for s in _socket_samples() if s["group"] == "socket"]
    assert sorted((s["socket"], s["type"]) for s in direct) == [
        ("game", "beat"),
        ("lobby", "beat"),
    ]
    for sample in direct:
        payload = _payload(sample)
        assert set(payload) == BEAT_KEYS[sample["socket"]], sample["name"]
        assert isinstance(payload["every"], float)
        assert not ROLE_NAME.search(json.dumps(payload))
    game = next(_payload(s) for s in direct if s["socket"] == "game")
    assert isinstance(game["window"], int) and isinstance(game["moved_on"], bool)
    assert game["phase"] in {"night", "discussion", "voting", "results"}


def test_no_socket_sample_is_a_per_player_night_event() -> None:
    names = [s["name"] for s in _socket_samples() if s["type"] in PRIVATE]
    assert names == []


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


def test_there_are_window_sequences_to_check() -> None:
    names = {s["name"] for s in _sequence_samples()}
    assert {
        "ws_sequence/look_stage",
        "ws_sequence/window_1",
        "ws_sequence/window_2",
        "ws_sequence/window_2_doppelganger",
        "ws_sequence/talk_and_vote",
    } <= names


@pytest.mark.parametrize("sample", _sequence_samples(), ids=lambda s: s["name"])
def test_every_seat_hears_the_same_events_in_the_same_order(
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
    # Who voted or locked in is never announced: counts only.
    assert "vote_submitted" not in reference


@pytest.mark.parametrize(
    "sample",
    [s for s in _socket_samples() if s["type"] in {"night_window", "progress"}],
    ids=lambda s: s["name"],
)
def test_the_night_window_and_progress_events_go_to_the_whole_table(
    sample: dict[str, Any],
) -> None:
    assert sample["group"] == "broadcast"
    assert len(sample["recipients"]) >= 5
    # Counts and window numbers only: no player id, no role.
    allowed = {"type", "stage", "done", "needed", "window", "deadline"}
    assert set(_payload(sample)) <= allowed


@pytest.mark.parametrize(
    "sample",
    [s for s in _socket_samples() if s["type"] == "me"],
    ids=lambda s: s["name"],
)
def test_an_own_view_goes_to_one_player_on_their_own_group(
    sample: dict[str, Any],
) -> None:
    assert sample["group"] == "player"
    assert len(sample["recipients"]) == 1


def _streams() -> list[dict[str, Any]]:
    index = json.loads((SAMPLES_DIR / "index.json").read_text(encoding="utf-8"))
    return [s for s in index["samples"] if s["kind"] == "ws_stream"]


def test_there_is_a_whole_game_stream_to_check() -> None:
    assert {s["name"] for s in _streams()} == {"ws_stream/six_seats"}


@pytest.mark.parametrize("sample", _streams(), ids=lambda s: s["name"])
def test_in_a_whole_game_every_seat_hears_the_same_kinds_and_only_its_own_view(
    sample: dict[str, Any],
) -> None:
    """Every seat's socket hears the same kinds of event in the same order (who
    connected before it aside), whatever it was dealt; each ``me`` it hears is
    its own (the ``player_id`` its own ``/me/`` answered), and no other event
    holds a key of a player's own view."""
    own_keys = {"me", "your_role", "night_results", "action_prompt", "my_vote"}
    streams: dict[str, list[dict[str, Any]]] = _payload(sample)
    assert len(streams) >= 5
    heard = {}
    for seat, items in streams.items():
        events = [i["event"] for i in items if "event" in i]
        heard[seat] = [e["type"] for e in events if e["type"] != "player_presence"]
        reads = [i["answer"] for i in items if "answer" in i]
        mine = next(a for a in reads if a["method"] == "GET")["body"]["player_id"]
        for event in events:
            if event["type"] == "me":
                assert event["me"]["player_id"] == mine, f"{seat}: another's view"
            else:
                assert not set(event) & own_keys, f"{seat}: {event['type']}"
    reference = next(iter(heard.values()))
    assert "me" in reference
    for seat, kinds in heard.items():
        assert kinds == reference, f"{seat} heard something different"
