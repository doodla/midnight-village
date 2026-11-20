"""The 29 reference games, played through the real API the app speaks.

``test_reference_games.py`` checks the rules on the pure engine; this plays the
same games (``data/reference_games.json``) end to end through the HTTP API, the
way phones play: a table made with ``defaults: "v2"``, the forced deal (DEBUG),
the look stage (every phone taps ready), every phone sending ONE ``choose`` per
window (the Doppelganger a second for her follow-up when her prompt asks for it),
the talk ended by the host, lock-in votes and the host's reveal. Every request
names the stage ``GET /me/`` carries. The outcome is read from the debug oracle
and compared with the record: every final card, the centre, the teams, the
copied role, what each player learned (rebuilt from the night log, as the e2e
harness does), and for full games the votes, who was voted out, who died, the
winners, who won and the reason.

How a recorded choice becomes picks (the runner reads the KIND of the prompt the
server shows each phone and decides nothing about the rules):

* ``doppel_target`` p: her look, ``[{player_id: p}]``.
* ``doppel_follow``: her second choose, read like the copied role's choice below.
* ``seer`` ``["player", p]``: ``[{player_id: p}]``; ``["center", [i, j]]``:
  ``[{center_index: i}, {center_index: j}]``.
* ``robber`` p: ``[{player_id: p}]``; ``troublemaker`` [a, b]: both players in
  that order; ``drunk`` c: ``[{center_index: c}]``.
* ``wolf_center`` c: ``[{center_index: c}]``, sent only when the prompt's kind is
  ``lone_werewolf`` (a Werewolf in a pack has nothing to choose, as before).
* A missing choice (the recorded "does nothing", which the original night sent
  as an explicit ``skip`` for the Seer, Robber and Troublemaker) and every role
  with nothing to choose: an empty choose, ``[]``. The server applies the role's
  default: a skip, the team view, the Insomniac's look, the Drunk's server swap.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from django.urls import reverse

import pytest
from rest_framework.test import APIClient

from apps.core.models import User
from apps.onuw.models import Game, Phase

pytestmark = pytest.mark.integration

GAMES = json.loads(
    (Path(__file__).parent / "data" / "reference_games.json").read_text()
)

# Every stage ends the moment everyone has done their part; nothing waits on a
# clock (the test settings allow untimed nights).
TIMERS = {
    "night_wave_seconds": 600,
    "night_min_window_seconds": 0,
    "night_doppelganger_window_seconds": 0,
    "discussion_seconds": 0,
    "voting_seconds": 0,
}


class Table:
    """One reference game at a real table, every request through the API."""

    def __init__(self, game: dict[str, Any], commit: Any) -> None:
        self.game = game
        self._commit = commit
        self.client = APIClient()
        self.users = [
            User.objects.create_user(username=f"ref_{i}_{name}", display_name=name)
            for i, name in enumerate(game["players"])
        ]
        self.ids = [u.id for u in self.users]
        self.game_id = ""

    # -- requests ----------------------------------------------------------

    def _as(self, index: int) -> APIClient:
        self.client.force_authenticate(user=self.users[index])
        return self.client

    def post(self, index: int, url: str, body: Any = None, expect: int = 200) -> Any:
        with self._commit(execute=True):
            response = self._as(index).post(url, body, format="json")
        assert response.status_code == expect, (url, body, response.data)
        return response.data

    def me(self, index: int) -> dict[str, Any]:
        response = self._as(index).get(
            reverse("onuw:game-me", kwargs={"game_id": self.game_id})
        )
        assert response.status_code == 200
        return response.data

    def staged(self, index: int, name: str, body: dict[str, Any]) -> Any:
        """A stage-scoped request naming the stage the caller's ``/me/`` shows."""
        stage = self.me(index)["stage"]
        url = reverse(f"onuw:{name}", kwargs={"game_id": self.game_id})
        return self.post(index, url, {**body, "stage": stage})

    def oracle(self) -> dict[str, Any]:
        response = self._as(0).get(
            reverse("onuw:debug-state", kwargs={"game_id": self.game_id})
        )
        assert response.status_code == 200
        return response.data

    def phase(self) -> str:
        return Game.objects.values_list("phase", flat=True).get(id=self.game_id)

    # -- the game ----------------------------------------------------------

    def deal(self) -> None:
        code = self.post(
            0, reverse("core:lobby-list"), {"game_type": "onuw", "defaults": "v2"}, 201
        )["code"]
        for i in range(1, len(self.users)):
            self.post(i, reverse("core:lobby-join", kwargs={"code": code}))
        counts: dict[str, int] = {}
        for role in [*self.game["dealt"], *self.game["center"]]:
            counts[role] = counts.get(role, 0) + 1
        with self._commit(execute=True):
            response = self._as(0).patch(
                reverse("core:lobby-detail", kwargs={"code": code}),
                {"settings": {"deck": "custom", "roles": counts, **TIMERS}},
                format="json",
            )
        assert response.status_code == 200, response.data
        forced = {
            "player_roles": {
                str(uid): role
                for uid, role in zip(self.ids, self.game["dealt"], strict=True)
            },
            "center": self.game["center"],
        }
        started = self.post(
            0,
            reverse("onuw:game-start", kwargs={"code": code}),
            {"debug": {"forced_assignment": forced}},
            201,
        )
        self.game_id = started["game_id"]

    def look(self) -> None:
        """The look stage: every phone taps ready, then the night opens."""
        assert self.me(0)["progress"]["stage"] == "look"
        for i in range(len(self.users)):
            self.staged(i, "ready", {"ready": True})

    def picks(self, index: int, prompt: dict[str, Any]) -> list[dict[str, Any]]:
        """What player ``index`` picks for ``prompt`` (see the module docstring)."""
        ch = self.game["ch"] or {}
        kind = prompt["kind"]
        doppel = self.game["dealt"][index] == "Doppelganger"

        def player(p: int) -> dict[str, int]:
            return {"player_id": self.ids[p]}

        def own(key: str) -> Any:
            return ch.get("doppel_follow" if doppel else key)

        if kind == "doppelganger_look":
            target = ch.get("doppel_target")
            return [] if target is None else [player(target)]
        if kind == "seer":
            c = own("seer")
            if c is None:
                return []
            if c[0] == "player":
                return [player(c[1])]
            return [{"center_index": i} for i in c[1]]
        if kind == "robber":
            c = own("robber")
            return [] if c is None else [player(c)]
        if kind == "troublemaker":
            c = own("troublemaker")
            return [] if c is None else [player(c[0]), player(c[1])]
        if kind == "drunk":
            c = own("drunk")
            return [] if c is None else [{"center_index": c}]
        if kind == "lone_werewolf":
            c = ch.get("wolf_center")
            return [] if c is None else [{"center_index": c}]
        assert kind == "none", kind
        return []

    def night(self) -> None:
        """Every phone answers its prompt until the night is over (bounded)."""
        for _ in range(12):
            if self.phase() != Phase.NIGHT:
                return
            for i in range(len(self.users)):
                me = self.me(i)
                prompt = me["action_prompt"]
                if (
                    me["phase"] != Phase.NIGHT
                    or not prompt
                    or not prompt["chooses_left"]
                ):
                    continue
                self.staged(
                    i,
                    "night-action",
                    {
                        "action_type": "choose",
                        "picks": self.picks(i, prompt),
                        "chosen": prompt["chosen"],
                    },
                )
        raise AssertionError(f"game {self.game['num']}: still in the night")

    def day(self) -> None:
        """The host ends the talk; everyone votes as recorded; the host reveals."""
        self.staged(0, "end-discussion", {})
        for voter, target in self.game["votes"].items():
            if target is not None:
                self.staged(
                    int(voter),
                    "vote",
                    {"target_player_id": self.ids[target], "lock": True},
                )
        if self.phase() == Phase.VOTING:
            self.staged(0, "reveal-votes", {})
        assert self.phase() == Phase.RESULTS

    # -- the record --------------------------------------------------------

    def index(self, user_id: int) -> int:
        return self.ids.index(user_id)

    def views(self, state: dict[str, Any], index: int) -> list[list[Any]]:
        """What player ``index`` learned, rebuilt from the oracle's night log in the
        recorded shape (the e2e harness's ``viewsFromLog``)."""
        out: list[list[Any]] = []
        for entry in state["night_actions_log"]:
            if entry["player_id"] != self.ids[index] or entry["action_type"] == "skip":
                continue
            r = entry["result"]
            if "copied_role" in r:
                out.append(["copied", r["copied_role"]])
            elif "peeked_role" in r:
                target = self.index(entry["targets"]["player_id"])
                out.append(["saw_player", [target, r["peeked_role"]]])
            elif "peeked_center" in r:
                out.append(
                    [
                        "saw_center",
                        [[c["index"], c["role"]] for c in r["peeked_center"]],
                    ]
                )
            elif "new_role" in r:
                out.append(["took", r["new_role"]])
            elif "werewolves" in r:
                out.append(
                    ["werewolves", sorted(self.index(p) for p in r["werewolves"])]
                )
                if r.get("center_card"):
                    c = r["center_card"]
                    out.append(["saw_center", [[c["index"], c["role"]]]])
            elif "masons" in r:
                out.append(["masons", sorted(self.index(p) for p in r["masons"])])
            elif "current_role" in r:
                out.append(["own_card", r["current_role"]])
        return out

    def assert_night(self) -> None:
        state = self.oracle()
        by_index = sorted(state["players"], key=lambda p: self.index(p["user_id"]))
        copied = [
            p["doppelganger_copied_role"]
            for p in by_index
            if p["doppelganger_copied_role"]
        ]
        assert [p["current_role"] for p in by_index] == self.game["final"]
        assert state["center_cards"] == self.game["final_center"]
        assert [p["team"] for p in by_index] == self.game["teams"]
        assert (copied[0] if copied else None) == self.game["copied"]
        for i in range(len(self.users)):
            assert self.views(state, i) == json.loads(
                json.dumps(self.game["views"].get(str(i), []))
            ), (i, self.game["players"][i])

    def assert_results(self) -> None:
        state = self.oracle()
        results = state["results"]
        votes = {
            str(self.index(int(voter))): None if target is None else self.index(target)
            for voter, target in state["votes"].items()
        }
        assert votes == self.game["votes"]
        reasons = results["elimination_reasons"]
        assert sorted(
            self.index(int(p)) for p, r in reasons.items() if r == "vote"
        ) == sorted(self.game["voted_out"])
        assert sorted(self.index(p) for p in results["eliminated_players"]) == sorted(
            self.game["dead"]
        )
        assert sorted(results["winning_teams"]) == sorted(self.game["winners"])
        won = [
            self.index(int(p))
            for p, o in results["player_outcomes"].items()
            if o == "win"
        ]
        assert sorted(won) == sorted(self.game["won"])
        assert results["reason"] == self.game["reason"]


@pytest.mark.django_db
@pytest.mark.parametrize("game", GAMES, ids=[f"game_{g['num']}" for g in GAMES])
def test_reference_game_through_the_choose_api(
    game: dict[str, Any], settings: Any, django_capture_on_commit_callbacks: Any
) -> None:
    settings.DEBUG = True  # the forced deal and the oracle
    table = Table(game, django_capture_on_commit_callbacks)
    table.deal()
    table.look()
    table.night()
    assert table.phase() == Phase.DISCUSSION
    table.assert_night()
    if "votes" in game:
        table.day()
        table.assert_results()
