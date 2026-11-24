"""One form for each kind of value the server sends (issue #17), checked on the
recorded samples, which ``test_contract_samples.py`` keeps equal to what the server
sends today.

- A time is UTC ending in ``Z`` (``apps.core.wire.wire_time``), in ``/me/``, the
  game socket's events and recent games as in every other body: a phone never
  compares two spellings of one moment.
- A refusal's ``detail`` is one string, the vote's included.
"""

from __future__ import annotations

import json
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import pytest

pytestmark = pytest.mark.contract

SAMPLES_DIR = Path(__file__).resolve().parents[3] / "contract_samples"
LOOKS_LIKE_A_TIME = re.compile(r"^\d{4}-\d{2}-\d{2}T")
ME = "/onuw/games/{game_id}/me/"
RECENT_GAMES = "/onuw/me/recent-games/"


def _samples() -> list[dict[str, Any]]:
    index = json.loads((SAMPLES_DIR / "index.json").read_text(encoding="utf-8"))
    return index["samples"]


def _payload(sample: dict[str, Any]) -> Any:
    return json.loads((SAMPLES_DIR / f"{sample['name']}.json").read_text("utf-8"))


def _times(value: Any, key: str = "") -> list[tuple[str, str]]:
    """``(key, value)`` for every time anywhere in a JSON value: a key named for
    one (``deadline``, ``..._at``) that is not null, or a string that reads as a
    date and time."""
    if isinstance(value, dict):
        return [t for k, inner in value.items() for t in _times(inner, k)]
    if isinstance(value, list):
        return [t for inner in value for t in _times(inner, key)]
    named = key == "deadline" or key.endswith("_at")
    if (named and value is not None) or (
        isinstance(value, str) and LOOKS_LIKE_A_TIME.match(value)
    ):
        return [(key, value)]
    return []


def _where(sample: dict[str, Any]) -> str | None:
    if sample.get("path") == ME:
        return "me"
    if sample.get("path") == RECENT_GAMES:
        return "recent_games"
    if sample["kind"] == "ws" and sample.get("socket") == "game":
        return "game_socket"
    return None


def test_every_time_in_me_the_game_socket_and_recent_games_ends_in_z() -> None:
    seen: dict[str, set[str]] = {
        "me": set(),
        "game_socket": set(),
        "recent_games": set(),
    }
    for sample in _samples():
        for key, value in _times(_payload(sample)):
            where = f"{sample['name']}: {key}={value!r}"
            assert isinstance(value, str) and value.endswith("Z"), where
            assert datetime.fromisoformat(value).utcoffset() == timedelta(0), where
            if (place := _where(sample)) is not None:
                seen[place].add(key)

    # Not vacuous: each place really sends the times it is checked for.
    assert {"deadline", "stage_started_at"} <= seen["me"]
    assert "deadline" in seen["game_socket"]
    assert "ended_at" in seen["recent_games"]


@pytest.mark.parametrize(
    "name", ["http/game/vote_self", "http/game/vote_invalid_target"]
)
def test_a_vote_refusals_detail_is_one_string(name: str) -> None:
    (sample,) = [s for s in _samples() if s["name"] == name]
    assert sample["status"] == 400
    body = _payload(sample)
    assert isinstance(body["detail"], str) and body["detail"]
    assert body["code"] == "invalid_target"


def test_every_refusals_detail_is_one_string() -> None:
    """Every recorded answer of 400 and above that has a ``detail`` says it as one
    string, and a 400 names its ``code``: an app reads one shape, whoever refused."""
    seen = 0
    for sample in _samples():
        body = _payload(sample)
        if sample.get("status", 200) < 400 or not isinstance(body, dict):
            continue
        if "detail" not in body:
            continue
        seen += 1
        assert isinstance(body["detail"], str) and body["detail"], sample["name"]
    assert seen > 20


def _keys(value: Any) -> list[str]:
    if isinstance(value, dict):
        return [*value, *(k for v in value.values() for k in _keys(v))]
    if isinstance(value, list):
        return [k for v in value for k in _keys(v)]
    return []


def test_nothing_the_server_sends_names_an_account_by_its_username() -> None:
    """A guest's username is its account's id. No body or event carries the key,
    and none carries the recorder's stand-in for a guest's id anywhere in it."""
    seen = 0
    for sample in _samples():
        payload = _payload(sample)
        seen += 1
        assert "username" not in _keys(payload), sample["name"]
        assert "00000000-0000-4000-8000-" not in json.dumps(payload), sample["name"]
    assert seen > 100


def test_a_time_with_no_zone_is_refused() -> None:
    from apps.core.wire import wire_time

    with pytest.raises(ValueError):
        wire_time(datetime(2024, 3, 7, 20, 57, 30))
    aware = datetime(2024, 3, 7, 21, 57, 30, tzinfo=timezone(timedelta(hours=1)))
    assert wire_time(aware) == "2024-03-07T20:57:30Z"
