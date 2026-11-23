"""Every night story the app can be asked to show has a recorded sample.

The cases are not a list kept here: they come from the engine's own role table
(``ROLE_REGISTRY``). A new role, or a new kind of night action for a role, fails
this until a scenario records it (``story_scenarios.py``), so the app's tests
never fall back to a hand-built body for it.
"""

import json
from pathlib import Path

import pytest

from apps.onuw.engine.roles import ROLE_REGISTRY, ActionType

pytestmark = pytest.mark.contract

SAMPLES = Path(__file__).resolve().parents[3] / "contract_samples"


def _bodies(prefix: str) -> list[dict]:
    index = json.loads((SAMPLES / "index.json").read_text())["samples"]
    found = []
    for entry in index:
        if entry["name"].startswith(prefix) and entry.get("status") == 200:
            sample = json.loads((SAMPLES / f"{entry['name']}.json").read_text())
            body = sample.get("body", sample)
            body = body.get("response", body) if isinstance(body, dict) else body
            if isinstance(body, dict):
                found.append(body)
    return found


@pytest.fixture(scope="module")
def talks() -> list[dict]:
    """Every recorded ``/me/`` taken in the talk: the night is over and told."""
    return [b for b in _bodies("http/game/me_") if b.get("phase") == "discussion"]


@pytest.fixture(scope="module")
def results() -> list[dict]:
    return [b for b in _bodies("http/game/results") if b.get("players")]


def test_every_role_has_a_talk_me(talks) -> None:
    dealt = {b["your_role"]["original_role"] for b in talks}
    assert set(ROLE_REGISTRY) - dealt == set()


def test_every_night_action_a_role_can_take_is_recorded_for_it(talks) -> None:
    seen = {
        (b["your_role"]["original_role"], result["action_type"])
        for b in talks
        for result in b.get("night_results") or []
    }
    wanted = {
        (role.name, action.value)
        for role in ROLE_REGISTRY.values()
        for action in role.action_types
        if action is not ActionType.NONE
    }
    assert wanted - seen == set()


def test_the_doppelganger_is_recorded_copying_every_other_role(talks) -> None:
    copied = {
        result["revealed_info"]["copied_role"]
        for b in talks
        for result in b.get("night_results") or []
        if (result.get("revealed_info") or {}).get("copied_role")
    }
    assert set(ROLE_REGISTRY) - {"Doppelganger"} - copied == set()


def test_a_choice_left_unmade_is_recorded(talks) -> None:
    """The server's default for a phone that chose nothing, told as such."""
    assert any(
        (result.get("revealed_info") or {}).get("nothing_chosen")
        for b in talks
        for result in b.get("night_results") or []
    )


def test_every_role_is_dealt_in_some_recorded_results(results) -> None:
    dealt = {p["original_role"] for b in results for p in b["players"]}
    assert set(ROLE_REGISTRY) - dealt == set()
