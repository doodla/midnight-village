"""One scripted game through the real API, and everything one seat (the viewer) is told.

The script is written by seat, never by role: every seat does what its own ``/me/``
prompt asks, with picks taken by one rule from the seats (``Plan.prefer``). So two games
dealt differently play the same moves seat for seat, and anything the viewer is told
that differs between them can only come from what the viewer must not know.

What the viewer is told: every answer to a request it makes (status, headers, body),
every socket frame its lobby and game sockets would deliver (the table's groups and its
own), and, at every stage, an answer from every route of the urlconf it may call with
GET (a new endpoint is in the sweep by existing).
"""

from __future__ import annotations

import json
import re
from collections.abc import Callable, Iterator
from dataclasses import dataclass
from typing import Any

from django.db import transaction
from django.test import override_settings
from django.urls import URLPattern, URLResolver, get_resolver

from asgiref.sync import async_to_sync
from channels.consumer import get_handler_name

from apps.core.consumers import LobbyConsumer
from apps.onuw.consumers import GameConsumer
from apps.onuw.engine.roles import ROLE_REGISTRY, ActionType
from apps.onuw.models import Game
from tests.contract.recorder import Recording, Table, recording

ME = "/onuw/games/{game_id}/me/"
ACTION = "/onuw/games/{game_id}/action/"
ADVANCE = "/onuw/games/{game_id}/advance-wave/"
READY = "/onuw/games/{game_id}/ready/"
VOTE = "/onuw/games/{game_id}/vote/"
# what changes from one run to the next by design, and says nothing
VOLATILE_HEADER = re.compile(r"dur=[0-9.]+")
CENTRE = 3
# Requests a game refuses whoever sends them, at any stage: bodies of the wrong type.
REFUSED = (
    (ACTION, {"action_type": "choose", "picks": "x"}),
    (ACTION, {"action_type": "choose", "picks": [{"player_id": "x"}]}),
    (VOTE, {"target_player_id": "x"}),
    (READY, {"ready": "x"}),
)


def deck_pool() -> list[str]:
    """Every role of the engine's table once, and a second of each role that wakes to see
    its own kind (a pack of werewolves, two masons): a new role is dealt by existing."""
    pool = []
    for role in ROLE_REGISTRY.values():
        pool.append(role.name)
        if ActionType.SEE_TEAM in role.action_types and role.max_count >= 2:
            pool.append(role.name)
    return pool


def sees_others(role: str) -> bool:
    """A role whose night shows it who holds some cards (its team, or what it copies)."""
    actions = ROLE_REGISTRY[role].action_types
    return ActionType.SEE_TEAM in actions or ROLE_REGISTRY[role].wave == 1


@dataclass(frozen=True)
class Plan:
    """One table: the cards by seat, the centre, the viewer's seat, and the two seats
    whose cards the second deal swaps (``swap``; None: no swap)."""

    dealt: tuple[str, ...]
    centre: tuple[str, ...]
    viewer: int
    swap: tuple[int, int] | None = None
    # the seat whose first, unlocked vote differs in the second game (None: no vote change)
    wavering: int | None = None

    @property
    def names(self) -> list[str]:
        return [f"Seat{n}" for n in range(len(self.dealt))]

    def swapped(self) -> Plan:
        cards = list(self.dealt)
        if self.swap:
            x, y = self.swap
            cards[x], cards[y] = cards[y], cards[x]
        return Plan(tuple(cards), self.centre, self.viewer, self.swap, self.wavering)

    def prefer(self) -> list[int]:
        """The seats picks go to, in order: never the viewer or the swapped pair first, so
        what the viewer may learn by its own picks is the same in both deals."""
        aside = {self.viewer, *(self.swap or ())}
        rest = [s for s in range(len(self.dealt)) if s not in aside]
        return rest + [s for s in (self.swap or ()) if s != self.viewer]


def routes(code: str, game_id: str, player_id: int) -> list[str]:
    """Every route of the urlconf, its parameters filled for this table."""

    def fill(match: re.Match) -> str:
        name = match[2]
        if "code" in name:
            return code
        if "game" in name or "uuid" in (match[1] or ""):
            return game_id
        return str(player_id) if "int" in (match[1] or "") else "x"

    def walk(patterns, prefix: str) -> Iterator[str]:
        for entry in patterns:
            route = prefix + str(entry.pattern)
            if isinstance(entry, URLResolver):
                yield from walk(entry.url_patterns, route)
            elif isinstance(entry, URLPattern) and not route.startswith("admin/"):
                yield "/" + re.sub(r"<(?:(\w+):)?(\w+)>", fill, route)

    return sorted(
        {r.removeprefix("/api") for r in walk(get_resolver().url_patterns, "")}
    )


def socket_frames(
    consumer_cls: type, message: dict[str, Any], user_id: int
) -> list[Any]:
    """What a socket of ``consumer_cls`` held by ``user_id`` sends for a group message."""
    consumer = consumer_cls()
    consumer.user_id = user_id
    out: list[Any] = []

    async def base_send(frame: dict[str, Any]) -> None:
        out.append(json.loads(frame["text"]))

    consumer.base_send = base_send
    handler = getattr(consumer, get_handler_name(message), None)
    if handler is None:
        return [{"unhandled": message["type"]}]
    async_to_sync(handler)(message)
    return out


class ViewerTable(Table):
    """A table that keeps everything one seat is told."""

    viewer: str
    told: list[Any]
    seen_messages: int

    def request(self, method: str, who: str, path: str, *args: Any, **kw: Any):
        status, body = super().request(method, who, path, *args, **kw)
        if who == self.viewer:
            headers = {
                k: VOLATILE_HEADER.sub("dur=?", v)
                for k, v in sorted(self.last_response.items())
            }
            self.told.append(["http", method, path, status, headers, body])
        self.drain()
        return status, body

    def drain(self) -> None:
        mine: dict[str, type] = {f"lobby_{self.code}": LobbyConsumer}
        if self.game_id:
            mine[f"game_{self.game_id}"] = GameConsumer
            mine[f"game_{self.game_id}_player_{self.pid(self.viewer)}"] = GameConsumer
        for group, message in self.layer.sent[self.seen_messages :]:
            if group in mine:
                for frame in socket_frames(mine[group], message, self.pid(self.viewer)):
                    self.told.append(
                        ["ws", "own" if "_player_" in group else "table", frame]
                    )
        self.seen_messages = len(self.layer.sent)

    def sweep(self) -> None:
        """The viewer asks every route with GET."""
        for path in routes(self.code, self.game_id, self.pid(self.viewer)):
            self.request("GET", self.viewer, path)
        if self.game_id:  # and is refused, which must not depend on anyone's card
            for path, body in REFUSED:
                self.request("POST", self.viewer, path, body)


def _picks(t: ViewerTable, plan: Plan, seat: int, prompt: dict[str, Any]) -> list[dict]:
    shape = prompt["shapes"][0]
    valid = prompt.get("valid_targets") or {}
    if "players" in shape:
        ids = [t.pid(plan.names[s]) for s in plan.prefer() if s != seat]
        ids = [i for i in ids if i in valid.get("player_ids", [])]
        return [{"player_id": i} for i in ids[: shape["players"]]]
    if "center" in shape:
        return [
            {"center_index": i}
            for i in valid.get("center_indices", [])[: shape["center"]]
        ]
    return []


def _act(t: ViewerTable, plan: Plan, seat: int) -> None:
    """The seat does what its prompt asks; one with nothing to choose answers it empty."""
    who = plan.names[seat]
    for _ in range(4):
        _, me = t.request("GET", who, ME)
        prompt = (me or {}).get("action_prompt")
        if not prompt:
            return
        if prompt.get("chooses_left", 0) > 0:
            picks = _picks(t, plan, seat, prompt)
        elif prompt.get("chosen", 0) == 0:
            picks = []
        else:
            return
        status, _ = t.request(
            "POST", who, ACTION, {"action_type": "choose", "picks": picks}
        )
        if status >= 300 or not picks:
            return


def play(run: Recording, plan: Plan) -> list[Any]:
    """The game of ``plan``, to the vote's last lock; what the viewer was told."""
    t = ViewerTable(
        run.recorder,
        run.clock,
        run.layer,
        run.capture_on_commit,
        run.game_ids,
        next(run.codes),
    )
    t.viewer, t.told, t.seen_messages = plan.names[plan.viewer], [], 0
    names = plan.names
    for name in names:
        t.guest(name)
    t.call("POST", names[0], "/lobbies/", {"game_type": "onuw", "defaults": "v2"})
    for name in names[1:]:
        t.clock.advance(30)
        t.call("POST", name, "/lobbies/{code}/join/")
    deck: dict[str, int] = {}
    for role in (*plan.dealt, *plan.centre):
        deck[role] = deck.get(role, 0) + 1
    t.call(
        "PATCH",
        names[0],
        "/lobbies/{code}/",
        {"settings": {"deck": "custom", "roles": deck}},
    )
    t.start(dict(zip(names, plan.dealt, strict=True)), list(plan.centre))
    for name in names:
        t.connect(name)
    t.sweep()
    for name in names:
        t.request("POST", name, READY, {"ready": True})
    for _ in range(8):
        game = Game.objects.get(id=t.game_id)
        if game.phase != "night":
            break
        wave = game.current_wave
        for seat in range(len(names)):
            _act(t, plan, seat)
        t.sweep()
        game.refresh_from_db()
        if game.phase == "night" and game.current_wave == wave:
            t.request("POST", names[0], ADVANCE)
    t.sweep()
    for name in names:
        t.request("POST", name, READY, {"ready": True})
    t.sweep()
    count = len(names)
    for seat, name in enumerate(names):
        first = (seat + (2 if seat == plan.wavering else 1)) % count
        t.request("POST", name, VOTE, {"target_player_id": t.pid(names[first])})
    t.sweep()
    for seat, name in enumerate(names[:-1]):
        target = t.pid(names[(seat + 1) % count])
        t.request("POST", name, VOTE, {"target_player_id": target, "lock": True})
    t.sweep()
    return t.recorder._apply(t.told)


class _UndoError(Exception):
    pass


def told(capture: Callable[..., Any], plan: Plan) -> list[Any]:
    """Play ``plan`` in a savepoint that is then undone, so the next game starts from the
    same database (the same ids, codes and clock)."""
    try:
        with (
            transaction.atomic(),
            override_settings(SERVER_TIMING_DETAIL=False),  # as live: no counts
            recording(capture) as run,
        ):
            seen = play(run, plan)
            raise _UndoError(seen)
    except _UndoError as undone:
        return undone.args[0]


def first_difference(a: list[Any], b: list[Any]) -> str | None:
    for index, (one, two) in enumerate(zip(a, b, strict=False)):
        if one != two:
            return f"item {index}:\n  first deal:  {one}\n  second deal: {two}"
    if len(a) != len(b):
        return f"one deal told {len(a)} things, the other {len(b)}"
    return None
