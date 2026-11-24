"""What one request costs the server: a whole game played through the real views.

``play(run, players)`` plays one game the way the app plays it (a ``defaults: "v2"``
table, every phone signing its requests with its access token and reading ``/me/``
and ``/me/table/`` as it does, the live server's queue timer backend) at a table of
``players`` seats, and returns a ``Cost`` for every request, timer firing and game
socket opening: the database round trips it made (``queries``, with the SQL; each
atomic block's SAVEPOINT / RELEASE stand for the BEGIN / COMMIT the live server
sends), the rows it locked
(``SELECT ... FOR UPDATE``) and how many round trips the lock was then held for
(``lock_span``), the socket messages it handed to the channel layer (``sends``: a
Redis publish each on the live server, made before the answer leaves) and the timer
messages it published (``publishes``: a Vercel Queue send each there, also before the
answer), and how long it took here. The deal is forced (``DEALT``) so that every seat
holds a card that wakes and is told something: work done once per actor grows with the
table and is seen.

Each request is labelled by what the phone did (``Cost.label``): the method, the
app's path and the stage the game was in, with ``closes`` when that tap ended the
stage (the last ready, the last lock). So the same tap at three, six and ten seats
has the same label, which is what ``test_tap_query_budget.py`` compares.

Built on the contract recorder (``tests/contract/recorder.py``): the same pinned
clock, ids and channel layer, real timer rows with no thread.
"""

from __future__ import annotations

import time
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from typing import Any
from unittest.mock import patch

from django.db import connection
from django.test import override_settings
from django.test.utils import CaptureQueriesContext

from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import AccessToken

from apps.core import timers
from apps.core.models import Lobby, ScheduledTimer
from apps.onuw.models import Game
from apps.onuw.protocol import stage_name
from tests.contract.recorder import Player, Recording, Table

NAMES = ("Ana", "Ben", "Cleo", "Dev", "Esme", "Fin", "Gus", "Hana", "Ida", "Jon")
SIZES = (3, 6, 10)

LOBBY = "/lobbies/{code}/"
ME = "/onuw/games/{game_id}/me/"
MY_TABLE = "/me/table/"
ACTION = "/onuw/games/{game_id}/action/"
READY = "/onuw/games/{game_id}/ready/"
VOTE = "/onuw/games/{game_id}/vote/"


@dataclass
class Cost:
    """One request and what it cost the server."""

    label: str
    players: int
    status: int
    sql: list[str]
    sql_ms: float
    ms: float
    sends: int
    publishes: int

    @property
    def queries(self) -> int:
        return len(self.sql)

    @property
    def locks(self) -> int:
        return sum(1 for q in self.sql if "FOR UPDATE" in q)

    @property
    def writes(self) -> int:
        return sum(1 for q in self.sql if q.lstrip().startswith(WRITES))

    @property
    def lock_span(self) -> int:
        """Round trips from the first row lock to the end of its transaction (the
        commit releases it): how long another tap on the same row waits."""
        depth = 0
        start = None
        for index, query in enumerate(self.sql):
            if query.startswith("SAVEPOINT"):
                depth += 1
            elif query.startswith(("RELEASE SAVEPOINT", "ROLLBACK TO SAVEPOINT")):
                depth -= 1
                if depth == 0 and start is not None:
                    return index - start + 1
            elif start is None and "FOR UPDATE" in query:
                start = index
        return 0 if start is None else len(self.sql) - start


WRITES = ("INSERT", "UPDATE", "DELETE")


def _stage(table: Table) -> str:
    """Where the table is now: the game's stage, else the lobby's status."""
    if table.game_id:
        game = Game.objects.filter(id=table.game_id).first()
        if game is not None:
            return stage_name(game) or game.phase
    lobby = Lobby.objects.filter(code=table.code).first()
    return "none" if lobby is None else lobby.status


class MeteredTable(Table):
    """A ``Table`` that measures every request it makes (``costs``)."""

    players_at_table = 0
    costs: list[Cost]
    _published: int
    _staging = True

    def _staged(
        self, path: str, body: dict[str, Any] | None, game_id: str, who: str
    ) -> dict[str, Any] | None:
        return super()._staged(path, body, game_id, who) if self._staging else body

    def guest(self, name: str, *, sample: str | None = None) -> Player:
        """A guest whose phone signs every request with its access token, as the
        app does (the live server looks the account up on each one)."""
        player = super().guest(name, sample=sample)
        player.client = APIClient()
        token = AccessToken.for_user(player.user)
        player.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
        return player

    def request(  # type: ignore[override]
        self,
        method: str,
        who: str,
        path: str,
        body: dict[str, Any] | None = None,
        **kwargs: Any,
    ) -> tuple[int, Any]:
        # The recorder reads the game to fill in the stage the app sends: done
        # here, before the count, so only the server's own queries are counted.
        game_id = kwargs.get("game_id", self.game_id)
        body = super()._staged(path, body, game_id, who)
        self._staging = False
        outcome: dict[str, int] = {}
        try:
            with self._measured(f"{method} {path}", outcome):
                status, payload = super().request(method, who, path, body, **kwargs)
                outcome["status"] = status
        finally:
            self._staging = True
        return status, payload

    def fire(self, key: str) -> None:
        """A timer firing (a queue message on the live server): it takes the same
        row locks as a tap, so a tap that comes meanwhile waits for it."""
        row = ScheduledTimer.objects.get(key=key.format(game_id=self.game_id))
        with self._measured(f"timer {row.job}", {}):
            super().fire(key)

    def connect(self, name: str) -> None:
        """A game socket opens (its own function on the live server)."""
        with self._measured("socket opens (game)", {}):
            super().connect(name)

    @contextmanager
    def _measured(self, what: str, outcome: dict[str, int]) -> Iterator[None]:
        before = _stage(self)
        sent = len(self.layer.sent)
        published = self._published
        with CaptureQueriesContext(connection) as captured:
            started = time.perf_counter()
            yield
            elapsed = time.perf_counter() - started
        status = outcome.get("status", 200)
        label = f"{what} [{before}]"
        if _stage(self) != before and status < 300:
            label += " closes"
        queries = captured.captured_queries
        self.costs.append(
            Cost(
                label=label,
                players=self.players_at_table,
                status=status,
                sql=[q["sql"] for q in queries],
                sql_ms=sum(float(q["time"]) for q in queries) * 1000,
                ms=elapsed * 1000,
                sends=len(self.layer.sent) - sent,
                publishes=self._published - published,
            )
        )


@contextmanager
def metered(run: Recording) -> Iterator[MeteredTable]:
    """A new metered table in ``run``; timer publishes are counted."""
    table = MeteredTable(
        run.recorder,
        run.clock,
        run.layer,
        run.capture_on_commit,
        run.game_ids,
        next(run.codes),
    )
    table.costs = []
    table._published = 0

    def count_publish(topic: str, payload: dict[str, Any], delay: float) -> None:
        table._published += 1

    # The live server's timer backend (a queue message per timer, ``_arm``) with a
    # sender that only counts: the memory backend's re-arming in ``sweep`` is not
    # what the live server does.
    previous = timers.set_queue_sender(count_publish)
    try:
        with (
            override_settings(ONUW_TIMER_BACKEND=timers.BACKEND_QUEUE),
            patch.object(timers, "_arm", side_effect=timers.send_message),
        ):
            yield table
    finally:
        timers.set_queue_sender(previous)


def _everyone(t: Table, names: list[str], path: str, body: dict[str, Any]) -> None:
    for name in names:
        t.call("POST", name, path, body)


def _reads(t: Table, names: list[str]) -> None:
    """What every phone does when the stage moves: read its ``/me/`` (and one
    reads ``/me/table/``, as the 15 s table poll and a stage change do)."""
    for name in names:
        t.call("GET", name, ME)
    t.call("GET", names[-1], MY_TABLE)


def _choose_left(t: Table, who: str) -> bool:
    prompt = t.request("GET", who, ME)[1].get("action_prompt")
    return bool(prompt) and prompt["chooses_left"] > 0


# What is dealt at each size: every seat holds a card that wakes and is told
# something, so work done once per actor at night grows with the table here (and
# a test sees it). The rest of the deck is in the centre.
DEALT = {
    3: ["Seer", "Robber", "Troublemaker"],
    6: ["Seer", "Robber", "Troublemaker", "Werewolf", "Werewolf", "Insomniac"],
    10: [
        "Seer",
        "Robber",
        "Troublemaker",
        "Werewolf",
        "Werewolf",
        "Insomniac",
        "Minion",
        "Mason",
        "Mason",
        "Drunk",
    ],
}
CENTRE = {
    3: ["Werewolf", "Villager", "Drunk"],
    6: ["Villager", "Drunk", "Minion"],
    10: ["Villager", "Villager", "Hunter"],
}


def _picks(t: Table, names: list[str], seat: int, role: str) -> list[dict[str, Any]]:
    """What the card at ``seat`` chooses: the next seats, or a centre card."""

    def player(step: int) -> dict[str, Any]:
        return {"player_id": t.pid(names[(seat + step) % len(names)])}

    if role in ("Seer", "Robber"):
        return [player(1)]
    if role == "Troublemaker":
        return [player(1), player(2)]
    if role == "Drunk":
        return [{"center_index": 0}]
    return []


def _deck(players: int) -> dict[str, int]:
    counts: dict[str, int] = {}
    for role in [*DEALT[players], *CENTRE[players]]:
        counts[role] = counts.get(role, 0) + 1
    return counts


def play(run: Recording, players: int) -> list[Cost]:
    """One game at ``players`` seats, from the guests' sign-in to play again."""
    names = list(NAMES[:players])
    with metered(run) as t:
        for name in names:
            t.guest(name)
        t.players_at_table = 1
        t.call("POST", names[0], "/lobbies/", {"game_type": "onuw", "defaults": "v2"})
        for count, name in enumerate(names[1:], start=2):
            t.clock.advance(30)
            t.players_at_table = count
            t.call("POST", name, "/lobbies/{code}/join/")
        t.players_at_table = players
        for name in names:
            t.connect_lobby(name)
        t.call("GET", names[-1], LOBBY)
        t.call("GET", names[-1], MY_TABLE)
        deck = {"deck": "custom", "roles": _deck(players), "discussion_seconds": 240}
        t.call("PATCH", names[0], LOBBY, {"settings": deck})
        t.call("GET", names[-1], LOBBY)

        # The deal (the harness's forced deal: the same writes as a random one).
        t.clock.advance(30)
        dealt = dict(zip(names, DEALT[players], strict=True))
        t.start(dealt, CENTRE[players])
        for name in names:
            t.connect(name)
        _reads(t, names)

        # The look stage, then window 2: every phone with a choice chooses.
        _everyone(t, names, READY, {"ready": True})
        _reads(t, names)
        t.clock.advance(5)
        for seat, name in enumerate(names):
            if _choose_left(t, name):
                picks = _picks(t, names, seat, dealt[name])
                t.call("POST", name, ACTION, {"action_type": "choose", "picks": picks})
        t.clock.advance(10)
        key = f"{t.game_id}:wave:2"
        if ScheduledTimer.objects.filter(key=key).exists():
            t.fire(key)
        _reads(t, names)

        # The talk, then the vote; everyone points at the next seat and locks.
        t.clock.advance(60)
        _everyone(t, names, READY, {"ready": True})
        _reads(t, names)
        t.clock.advance(20)
        for index, name in enumerate(names):
            target = t.pid(names[(index + 1) % players])
            t.call("POST", name, VOTE, {"target_player_id": target, "lock": False})
        for index, name in enumerate(names):
            target = t.pid(names[(index + 1) % players])
            t.call("POST", name, VOTE, {"target_player_id": target, "lock": True})
        _reads(t, names)
        for name in names:
            t.call("GET", name, "/onuw/games/{game_id}/results/")
        t.call("POST", names[0], "/lobbies/{code}/play-again/")
        t.call("GET", names[-1], MY_TABLE)
        t.call("GET", names[-1], LOBBY)
        return t.costs


def worst(costs: list[Cost]) -> dict[str, Cost]:
    """The most queries each kind of request made in one game."""
    out: dict[str, Cost] = {}
    for cost in costs:
        if cost.status >= 300:
            continue
        held = out.get(cost.label)
        if held is None or cost.queries > held.queries:
            out[cost.label] = cost
    return out
