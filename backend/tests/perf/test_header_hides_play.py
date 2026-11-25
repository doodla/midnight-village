"""The live ``Server-Timing`` header says nothing about other players' hidden play.

The rule: nothing in an answer, body or header, may vary with game state the caller
cannot see. The host's answers are compared under two games that differ only in
what the Doppelganger (another seat) did in window 1: she copies the Seer and looks
at a card, or she copies a Villager and does nothing. With the header's detail on,
the host's "move on" in window 1 makes one more round trip in the first game (her
follow-up is written), so the counts would tell; live (detail off) every answer the
host gets must carry the same header but for the rounded time.
"""

from __future__ import annotations

import re
from typing import Any

from django.test import override_settings

import pytest

from apps.core.models import ScheduledTimer
from tests.contract.recorder import Recording, Table, recording

pytestmark = [pytest.mark.django_db, pytest.mark.uses_timers]

NAMES = ["Ana", "Ben", "Cleo", "Dev", "Esme"]
DEALT = {
    "Ana": "Villager",
    "Ben": "Doppelganger",
    "Cleo": "Seer",
    "Dev": "Werewolf",
    "Esme": "Robber",
}
CENTRE = ["Villager", "Troublemaker", "Insomniac"]
ME = "/onuw/games/{game_id}/me/"
ACTION = "/onuw/games/{game_id}/action/"
ADVANCE = "/onuw/games/{game_id}/advance-wave/"
READY = "/onuw/games/{game_id}/ready/"
VOTE = "/onuw/games/{game_id}/vote/"


class HostsHeaders(Table):
    """A table that keeps every header the host (Ana) is answered with."""

    seen: list[tuple[str, str]]

    def request(self, method: str, who: str, path: str, *args: Any, **kw: Any):
        status, body = super().request(method, who, path, *args, **kw)
        if who == "Ana":
            self.seen.append((f"{method} {path}", self.last_response["Server-Timing"]))
        return status, body


def _choose(t: Table, who: str, picks: list[dict[str, Any]]) -> None:
    t.call("POST", who, ACTION, {"action_type": "choose", "picks": picks})


def _player(t: Table, name: str) -> dict[str, Any]:
    return {"player_id": t.pid(name)}


def _host_headers(run: Recording, copies: str) -> list[tuple[str, str]]:
    """One game; the Doppelganger copies ``copies``'s card. The host's headers."""
    t = HostsHeaders(
        run.recorder,
        run.clock,
        run.layer,
        run.capture_on_commit,
        run.game_ids,
        next(run.codes),
    )
    t.seen = []
    for name in NAMES:
        t.guest(name)
    t.call("POST", "Ana", "/lobbies/", {"game_type": "onuw", "defaults": "v2"})
    for name in NAMES[1:]:
        t.clock.advance(30)
        t.call("POST", name, "/lobbies/{code}/join/")
    deck: dict[str, int] = {}
    for role in [*DEALT.values(), *CENTRE]:
        deck[role] = deck.get(role, 0) + 1
    t.call(
        "PATCH",
        "Ana",
        "/lobbies/{code}/",
        {"settings": {"deck": "custom", "roles": deck}},
    )
    t.clock.advance(30)
    t.start(DEALT, CENTRE)
    for name in NAMES:
        t.connect(name)
    for name in NAMES:  # the host is not the last to look
        t.call("POST", name, READY, {"ready": True})

    # Window 1: only the Doppelganger acts; the host moves the night on.
    t.call("GET", "Ana", ME)
    _choose(t, "Ben", [_player(t, copies)])
    if copies == "Cleo":  # as the Seer she also looks at a card
        _choose(t, "Ben", [_player(t, "Dev")])
    t.call("GET", "Ana", ME)
    t.call("POST", "Ana", ADVANCE)

    # Window 2: every phone with a choice chooses; the host moves it on too.
    t.call("GET", "Ana", ME)
    _choose(t, "Ana", [])
    _choose(t, "Cleo", [_player(t, "Dev")])
    _choose(t, "Esme", [_player(t, "Dev")])
    _choose(t, "Dev", [{"center_index": 0}])
    if ScheduledTimer.objects.filter(key=f"{t.game_id}:wave:2").exists():
        t.call("POST", "Ana", ADVANCE)

    # The talk and the vote.
    t.call("GET", "Ana", ME)
    for name in NAMES:
        t.call("POST", name, READY, {"ready": True})
    t.call("GET", "Ana", ME)
    for index, name in enumerate(NAMES):
        target = t.pid(NAMES[(index + 1) % len(NAMES)])
        t.call("POST", name, VOTE, {"target_player_id": target, "lock": True})
    t.call("GET", "Ana", "/onuw/games/{game_id}/results/")
    return t.seen


def _without_times(seen: list[tuple[str, str]]) -> list[tuple[str, str]]:
    return [(what, re.sub(r"dur=[0-9.]+", "dur=?", header)) for what, header in seen]


def _played(capture: Any, *, detail: bool) -> tuple[list, list]:
    with override_settings(SERVER_TIMING_DETAIL=detail), recording(capture) as run:
        return _host_headers(run, "Cleo"), _host_headers(run, "Ana")


def test_the_hosts_live_headers_are_the_same_whatever_the_doppelganger_did(
    django_capture_on_commit_callbacks: Any,
) -> None:
    looked, idle = _played(django_capture_on_commit_callbacks, detail=False)

    assert _without_times(looked) == _without_times(idle)
    for _, header in looked + idle:
        assert "desc=" not in header
        total = float(header.rsplit("total;dur=", 1)[1])
        assert total % 50 == 0


def test_with_detail_the_hosts_move_on_would_tell_what_she_did(
    django_capture_on_commit_callbacks: Any,
) -> None:
    """The case above is a real one: the counts the live header leaves out differ."""
    looked, idle = _played(django_capture_on_commit_callbacks, detail=True)

    assert [what for what, _ in looked] == [what for what, _ in idle]
    assert _without_times(looked) != _without_times(idle)
