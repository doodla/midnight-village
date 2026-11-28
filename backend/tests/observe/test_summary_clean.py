"""What is kept of a phone's summary: only times, counts and words from closed lists.

Hidden information: a kept summary can only hold what ``summary.clean`` names, and every
label only words of ``vocabulary.py`` (the app's screens, controls and socket events,
and this server's own routes with ids as ``·``). So a mistake on the phone, or a caller
making things up, cannot store a player's name, a role, a join code or an id.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from apps.observe import vocabulary
from apps.observe.summary import MOST_ENTRIES, MOST_VALUES, clean, device

from .summaries import AGENT, summary

pytestmark = pytest.mark.django_db  # the routes are read from the urlconf

TAP = "talk tap main_button POST /api/onuw/games/·/ready/"
SAMPLES = Path(__file__).resolve().parents[3] / "contract_samples"


def _kept(sent: dict) -> dict:
    got = clean(sent)
    assert got is not None
    return got[0]


def test_a_summary_as_the_app_sends_it_is_kept_whole_but_the_browser_name() -> None:
    sent = summary()
    kept, kind = clean(sent)  # type: ignore[misc]

    expected = json.loads(json.dumps(sent))
    del expected["env"]["agent"]
    assert kept == expected
    assert kind == "android chrome"


def test_the_apps_own_summary_is_kept_with_nothing_dropped() -> None:
    """The summary the app's own test builds from a real tap (written by
    ``frontend/test/core/perf/field_summary_test.dart``): the two sides agree on
    every word, or something the phone measures would be dropped unseen."""
    sent = json.loads((SAMPLES / "app" / "field_summary.json").read_text())
    kept, kind = clean(sent)  # type: ignore[misc]

    expected = json.loads(json.dumps(sent))
    del expected["env"]["agent"]
    assert kept == expected
    assert kind == "android chrome"


@pytest.mark.parametrize(
    "label",
    [
        "talk tap main_button POST /api/lobbies/K7QX9P/join/",
        "talk tap main_button POST /api/lobbies/k7qx9p/join/",
        "talk tap main_button GET /api/ana/",
        "night_board tap card",
        "nightBoard tap Ana",
        "Ana tap card",
        "talk tap main_button POST /api/onuw/games/·/ready/x",
        "talk tap main_button FETCH /api/me/table/",
        "a" * 121,
    ],
)
def test_a_label_with_a_word_from_outside_the_lists_is_dropped(label: str) -> None:
    sent = summary()
    sent["taps"][label] = {"n": 1, "screen": [20.0]}

    assert label not in _kept(sent)["taps"]


@pytest.mark.parametrize(
    "path",
    [
        "GET /api/lobbies/K7QX9P/",
        "GET /api/onuw/games/3f2a9c1e/me/",
        "GET /api/onuw/games/·/me/?name=Ana",
        "GET /api/nothing/here/",
        "GET /admin/",
    ],
)
def test_a_path_that_is_not_one_of_the_servers_routes_is_dropped(path: str) -> None:
    sent = summary()
    sent["requests"][path] = {"n": 1, "round": [20.0]}
    sent["cold"].append({"kind": "boot", "path": path, "round": 2000.0})

    kept = _kept(sent)

    assert path not in kept["requests"]
    assert all(c["path"] != path for c in kept["cold"])


@pytest.mark.parametrize(
    "change",
    [
        "talk > vote (socket Ana)",
        "talk > Ana (tap)",
        "talk > vote (because)",
    ],
)
def test_a_screen_change_with_an_unknown_screen_or_cause_is_dropped(
    change: str,
) -> None:
    sent = summary()
    sent["screens"][change] = {"n": 1, "first": [20.0]}

    assert change not in _kept(sent)["screens"]


def test_the_lists_hold_the_words_the_server_sends_on_its_sockets() -> None:
    """Every event type in the recorded socket samples is a cause a phone may name."""
    types = set()
    for sample in (SAMPLES / "ws").rglob("*.json"):
        body = json.loads(sample.read_text())
        body = body.get("body", body) if isinstance(body, dict) else body
        if isinstance(body, dict) and isinstance(body.get("type"), str):
            types.add(body["type"])
    assert types, "the scan found the socket samples"
    assert types <= vocabulary.SOCKET_EVENTS


@pytest.mark.parametrize("secret", ["Ana", "Werewolf", "K7QX9P", "3f2a9c1e-5b"])
def test_a_key_that_is_not_named_is_dropped_wherever_it_is(secret: str) -> None:
    sent = summary()
    sent["player"] = secret
    sent["env"]["name"] = secret
    sent["env"]["gpu"] = secret
    sent["env"]["screen"] = secret
    sent["taps"][TAP]["role"] = secret
    sent["frames"]["talk"]["card"] = secret
    sent["cold"][0]["code"] = secret

    assert secret not in json.dumps(_kept(sent))


@pytest.mark.parametrize("bad", [-1, float("inf"), float("nan"), 3_600_001, True, "12"])
def test_a_number_that_is_not_a_time_is_dropped(bad: object) -> None:
    sent = summary()
    sent["taps"][TAP]["screen"] = [12.0, bad, 30.0]
    sent["env"]["cores"] = bad

    kept = _kept(sent)

    assert kept["taps"][TAP]["screen"] == [12.0, 30.0]
    assert "cores" not in kept["env"]


def test_lists_and_maps_are_capped() -> None:
    sent = summary()
    sent["taps"] = {
        f"{screen} tap {control}": {"n": 1, "screen": [float(v) for v in range(50)]}
        for screen in sorted(vocabulary.SCREENS)
        for control in sorted(vocabulary.CONTROLS)
    }

    kept = _kept(sent)

    assert len(kept["taps"]) == MOST_ENTRIES
    assert all(len(e["screen"]) == MOST_VALUES for e in kept["taps"].values())


def test_of_the_phone_only_its_kind_and_coarse_numbers_are_kept() -> None:
    kept, kind = clean(summary())  # type: ignore[misc]

    assert set(kept["env"]) <= {
        "pixel_ratio",
        "cores",
        "memory_gb",
        "first_frame_ms",
        "main_bundle_ms",
        "engine_ms",
        "renderer",
    }
    assert AGENT not in json.dumps(kept)
    assert kind == "android chrome"


@pytest.mark.parametrize(
    "sent",
    [None, [], "summary", {"v": 2}, {"v": 1}, {"v": 1, "taps": {}, "requests": {}}],
)
def test_what_is_not_a_summary_is_refused(sent: object) -> None:
    assert clean(sent) is None


def test_a_commit_that_is_not_one_is_left_blank_and_an_unknown_end_is_hidden() -> None:
    kept = _kept(summary(commit="local build", end="vote"))

    assert kept["commit"] == ""
    assert kept["end"] == "hidden"


@pytest.mark.parametrize(
    ("agent", "kind"),
    [
        (AGENT, "android chrome"),
        (
            "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 "
            "(KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1",
            "iphone safari",
        ),
        (
            "Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko Firefox/133.0",
            "linux firefox",
        ),
        ("", "other other"),
    ],
)
def test_the_device_is_a_kind_of_phone_and_browser(agent: str, kind: str) -> None:
    assert device(agent) == kind
