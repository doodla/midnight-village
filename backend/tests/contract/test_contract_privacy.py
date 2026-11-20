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
