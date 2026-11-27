"""What is kept of a phone's summary: only times, counts and plain labels.

Hidden information: a summary can only hold what ``summary.clean`` names, so a
mistake on the phone (or a caller making things up) cannot store a player's name,
a role, a join code or an id. Each test hands it something that must not be kept.
"""

from __future__ import annotations

import json

import pytest

from apps.observe.summary import MOST_ENTRIES, MOST_VALUES, clean, device

from .summaries import summary

pytestmark = pytest.mark.unit

TAP = "talk tap main_button POST /api/onuw/games/·/ready/"


def test_a_summary_as_the_app_sends_it_is_kept_whole() -> None:
    sent = summary()
    kept = clean(sent)

    assert kept == sent


@pytest.mark.parametrize(
    "secret",
    ["Ana", "Werewolf", "Seer", "K7QX", "3f2a9c1e-5b"],
)
def test_a_key_that_is_not_named_is_dropped_wherever_it_is(secret: str) -> None:
    sent = summary()
    sent["player"] = secret
    sent["env"]["name"] = secret
    sent["taps"][TAP]["role"] = secret
    sent["frames"]["talk"]["card"] = secret
    sent["cold"][0]["code"] = secret

    kept = json.dumps(clean(sent))

    assert secret not in kept


@pytest.mark.parametrize(
    "label",
    [
        "talk tap main_button POST /api/lobbies/K7QX?name=Ana Bell",
        'night_board tap card "Ana"',
        "talk tap main_button POST /api/onuw/games/7#frag",
        "a" * 121,
    ],
)
def test_a_label_with_anything_but_the_apps_own_characters_is_dropped(
    label: str,
) -> None:
    sent = summary()
    sent["taps"][label] = {"n": 1, "screen": [20.0]}
    sent["requests"][label] = {"n": 1, "round": [20.0]}
    sent["cold"].append({"kind": "boot", "path": label, "round": 2000.0})

    kept = clean(sent)

    assert kept is not None
    assert label not in kept["taps"]
    assert label not in kept["requests"]
    assert all(c["path"] != label for c in kept["cold"])


@pytest.mark.parametrize("bad", [-1, float("inf"), float("nan"), 3_600_001, True, "12"])
def test_a_number_that_is_not_a_time_is_dropped(bad: object) -> None:
    sent = summary()
    sent["taps"][TAP]["screen"] = [12.0, bad, 30.0]
    sent["env"]["cores"] = bad

    kept = clean(sent)

    assert kept is not None
    assert kept["taps"][TAP]["screen"] == [12.0, 30.0]
    assert "cores" not in kept["env"]


def test_lists_and_maps_are_capped() -> None:
    sent = summary()
    sent["taps"] = {
        f"talk tap kind_{i}": {"n": 1, "screen": [float(v) for v in range(50)]}
        for i in range(40)
    }

    kept = clean(sent)

    assert kept is not None
    assert len(kept["taps"]) == MOST_ENTRIES
    assert all(len(e["screen"]) == MOST_VALUES for e in kept["taps"].values())


def test_the_phone_says_what_it_is_but_not_where_it_is() -> None:
    sent = summary()
    sent["env"]["screen"] = "412x915; Ana"
    sent["env"]["agent"] = "x" * 500

    kept = clean(sent)

    assert kept is not None
    assert "screen" not in kept["env"]
    assert len(kept["env"]["agent"]) == 240


@pytest.mark.parametrize(
    "sent",
    [None, [], "summary", {"v": 2}, {"v": 1}, {"v": 1, "taps": {}, "requests": {}}],
)
def test_what_is_not_a_summary_is_refused(sent: object) -> None:
    assert clean(sent) is None


def test_a_commit_that_is_not_one_is_left_blank_and_an_unknown_end_is_hidden() -> None:
    kept = clean(summary(commit="local build", end="vote"))

    assert kept is not None
    assert kept["commit"] == ""
    assert kept["end"] == "hidden"


@pytest.mark.parametrize(
    ("agent", "kind"),
    [
        (summary()["env"]["agent"], "android chrome"),
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
