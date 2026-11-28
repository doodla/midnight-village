# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""One scripted game through the real API, and everything one seat (the viewer) is told.

The script is written by seat, never by role: every seat does what its own ``/me/`` prompt
asks, picking by one rule (``Plan.picks``), and every scripted move must succeed. So two
games dealt differently play the same moves seat for seat, and anything the viewer is told
that differs between them can only come from what the viewer must not know.

What a seat may rightly learn is what its own night reads, and nothing else: the seats
and centre cards its own picks name, the seats holding its kin when its role wakes to see
its team (werewolves for a werewolf-team role, its own role otherwise), and its own card
at the end when its role wakes and picks nothing (the Insomniac). A Doppelganger reads as
the card it copies. ``Plan`` keeps every variation outside that: the viewer's picks avoid
the changed places (and what the changed seats' own picks touch), a variation that moves
the viewer's kin is not made, and nobody picks a viewer who reads its own card.

What the viewer is told: every answer to a request it makes (status, headers, body),
every frame its lobby and game sockets would deliver (the groups worked out from the
consumers' own ``connect``), and, at each stage, an answer from every route of the
urlconf (GET; at two stages also POST, PATCH and DELETE, each in a savepoint undone after).
"""

from __future__ import annotations

import ast
import inspect
import json
import re
import textwrap
from collections.abc import Callable, Iterator
from dataclasses import dataclass, replace
from pathlib import Path
from types import SimpleNamespace
from typing import Any

from django.db import transaction
from django.test import override_settings
from django.urls import URLPattern, URLResolver, get_resolver

from asgiref.sync import async_to_sync
from channels.consumer import get_handler_name

from apps.core import consumers as core_consumers
from apps.onuw import consumers as game_consumers
from apps.onuw.engine.roles import ROLE_REGISTRY, ActionType, Team
from apps.onuw.models import Game, PlayerRole
from tests.contract.recorder import Recording, Table, recording

ME = "/onuw/games/{game_id}/me/"
ACTION = "/onuw/games/{game_id}/action/"
ADVANCE = "/onuw/games/{game_id}/advance-wave/"
READY = "/onuw/games/{game_id}/ready/"
VOTE = "/onuw/games/{game_id}/vote/"
SEEN = "/onuw/games/{game_id}/night-results/seen/"
CENTRE = 3
# Server-Timing's only noise: the measured times of the connection and of the whole answer
TIMING_NOISE = re.compile(r"\b(connect|total);dur=[0-9.]+")
# Requests a game refuses whoever sends them, at any stage: bodies of the wrong type.
REFUSED = (
    (ACTION, {"action_type": "choose", "picks": "x"}),
    (ACTION, {"action_type": "choose", "picks": [{"player_id": "x"}]}),
    (VOTE, {"target_player_id": "x", "lock": False}),
    (READY, {"ready": "x"}),
)
# Routes that mint accounts and tokens, random by design and blind to any game: asked
# with GET only.
MINTS = ("/auth/",)
SETTINGS = Path(__file__).resolve().parents[2] / "config" / "settings"


def live_setting(name: str) -> Any:
    """A setting as the live server has it: read from settings/vercel.py, else base.py."""
    for module in ("vercel.py", "base.py"):
        for node in ast.parse((SETTINGS / module).read_text()).body:
            if isinstance(node, ast.Assign) and any(
                isinstance(t, ast.Name) and t.id == name for t in node.targets
            ):
                return ast.literal_eval(node.value)
    raise LookupError(name)


def deck_pool() -> list[str]:
    """Every role of the engine's table once, and a second of each role that wakes to see
    its own kind (a pack of werewolves, two masons): a new role is dealt by existing."""
    pool = []
    for role in ROLE_REGISTRY.values():
        pool.append(role.name)
        if ActionType.SEE_TEAM in role.action_types and role.max_count >= 2:
            pool.append(role.name)
    return pool


def kin_of(role: str) -> set[str]:
    """Who a role that wakes to see its team sees (nobody, for any other role)."""
    found = ROLE_REGISTRY[role]
    if ActionType.SEE_TEAM not in found.action_types:
        return set()
    if found.team == Team.WEREWOLF:
        return {
            r.name
            for r in ROLE_REGISTRY.values()
            if r.team == Team.WEREWOLF
            and ActionType.SEE_TEAM in r.action_types
            and r.max_count >= 2
        }
    return {role}


def reads_own_card(role: str) -> bool:
    found = ROLE_REGISTRY[role]
    return found.wave is not None and found.action_types == (ActionType.NONE,)


def copies(role: str) -> bool:
    return ROLE_REGISTRY[role].wave == 1


Place = int | str  # a seat, or "c0".."c2" for a centre card


@dataclass(frozen=True)
class Plan:
    """One table: the cards by seat, the centre, the viewer's seat, and what the second
    game changes: two places' cards (``swap``), or one seat's first vote (``wavering``,
    onto the viewer in one game and elsewhere in the other)."""

    dealt: tuple[str, ...]
    centre: tuple[str, ...]
    viewer: int
    swap: tuple[Place, Place] | None = None
    wavering: int | None = None
    second: bool = False  # this is the second game of the pair

    @property
    def names(self) -> list[str]:
        return [f"Seat{n}" for n in range(len(self.dealt))]

    def card(self, place: Place) -> str:
        return (
            self.centre[int(place[1])] if isinstance(place, str) else self.dealt[place]
        )

    def other(self) -> Plan:
        """The second game."""
        dealt, centre = list(self.dealt), list(self.centre)
        if self.swap:
            one, two = self.swap
            a, b = self.card(one), self.card(two)
            for place, card in ((one, b), (two, a)):
                if isinstance(place, str):
                    centre[int(place[1])] = card
                else:
                    dealt[place] = card
        return replace(self, dealt=tuple(dealt), centre=tuple(centre), second=True)

    def first(self) -> Plan:
        return replace(self, second=False)

    def changed(self) -> set[Place]:
        return set(self.swap or ())

    def viewer_role(self) -> str:
        """The role the viewer acts as: a Doppelganger is the card its own pick copies."""
        role = self.dealt[self.viewer]
        if not copies(role):
            return role
        return self.dealt[self.seat_picks(self.viewer, 1, protect=False)[0]]

    def protected(self) -> set[int]:
        """Seats nobody else picks: a viewer that reads its own card at the end."""
        return {self.viewer} if reads_own_card(self.viewer_role()) else set()

    def order(self, seat: int) -> list[int]:
        count = len(self.dealt)
        return [(seat - step) % count for step in range(1, count)]

    def seat_picks(self, seat: int, want: int, *, protect: bool = True) -> list[int]:
        """The seats a seat's picks name: its neighbours to the left, in order. The viewer
        skips the changed places and what the changed seats' own picks name."""
        skip = (self.protected() if protect and seat != self.viewer else set()) | {seat}
        if seat == self.viewer:
            changed = {p for p in self.changed() if isinstance(p, int)}
            skip |= changed | {s for c in changed for s in self.order(c)[:2]}
        return [s for s in self.order(seat) if s not in skip][:want]

    def centre_picks(self, seat: int, want: int) -> list[int]:
        """The viewer looks at the centre from its far end, past the changed cards; the
        others from its near end."""
        if seat != self.viewer:
            return list(range(CENTRE))[:want]
        changed = {int(p[1]) for p in self.changed() if isinstance(p, str)}
        return [i for i in reversed(range(CENTRE)) if i not in changed][:want]

    def effective(self, seat: int) -> str:
        """The role a seat acts as: a Doppelganger is the card its first pick copies."""
        if seat == self.viewer:
            return self.viewer_role()
        role = self.dealt[seat]
        return self.dealt[self.seat_picks(seat, 1)[0]] if copies(role) else role

    def kin_seats(self) -> set[int]:
        kin = kin_of(self.effective(self.viewer))
        return {
            s
            for s in range(len(self.dealt))
            if s != self.viewer and self.effective(s) in kin
        }

    def hidden_from_viewer(self) -> bool:
        """The rule above, checked on both games of the pair."""
        two = self.other()
        if self.viewer in self.changed():
            return False
        if self.kin_seats() != two.kin_seats():
            return False
        return self.effective(self.viewer) == two.effective(self.viewer)


def routes(code: str, game_id: str, player_ids: list[int]) -> list[str]:
    """Every route of the urlconf, its parameters filled for this table (a player id with
    every seat's in turn)."""

    def fills(route: str) -> Iterator[str]:
        ids = player_ids if re.search(r"<int:", route) else [player_ids[0]]
        for pid in ids:

            def fill(match: re.Match, pid: int = pid) -> str:
                kind, name = match[1] or "str", match[2]
                if "code" in name:
                    return code
                if "game" in name or kind == "uuid":
                    return game_id
                return str(pid) if kind == "int" else "x"

            yield "/" + re.sub(r"<(?:(\w+):)?(\w+)>", fill, route)

    def walk(patterns, prefix: str) -> Iterator[str]:
        for entry in patterns:
            route = prefix + str(entry.pattern)
            if isinstance(entry, URLResolver):
                yield from walk(entry.url_patterns, route)
            elif isinstance(entry, URLPattern) and not route.startswith("admin/"):
                yield from fills(route)

    return sorted(
        {r.removeprefix("/api") for r in walk(get_resolver().url_patterns, "")}
    )


def _value(node: ast.expr, space: dict[str, Any]) -> Any:
    """A line of the consumer's own code, worked out (our own source, never input)."""
    return eval(compile(ast.Expression(node), "", "eval"), space)  # noqa: S307


def consumer_groups(module: Any, cls: type, **attrs: Any) -> list[str]:
    """The groups a consumer's own ``connect`` joins, worked out from its code with the
    socket's attributes (game_id, user_id, lobby_code): a new group joins the sweep."""
    tree = ast.parse(textwrap.dedent(inspect.getsource(cls.connect)))
    me = SimpleNamespace(**attrs)
    space = {**vars(module), "self": me}
    groups = []
    for node in sorted(ast.walk(tree), key=lambda n: getattr(n, "lineno", 0)):
        if isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Attribute):
            try:
                setattr(me, node.targets[0].attr, _value(node.value, space))
            except Exception:  # noqa: S112 - not every line of connect names a group
                continue
        elif (
            isinstance(node, ast.Call) and getattr(node.func, "attr", "") == "group_add"
        ):
            groups.append(_value(node.args[0], space))
    return groups


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


class _UndoError(Exception):
    pass


class ViewerTable(Table):
    """A table that keeps everything one seat is told."""

    viewer: str
    told: list[Any]
    seen_messages: int

    def request(self, method: str, who: str, path: str, *args: Any, **kw: Any):
        status, body = super().request(method, who, path, *args, **kw)
        if who == self.viewer:
            headers = {
                k: TIMING_NOISE.sub(r"\1;dur=?", v)
                for k, v in sorted(self.last_response.items())
            }
            self.told.append(["http", method, path, status, headers, body])
        self.drain()
        return status, body

    def groups(self) -> dict[str, type]:
        pid = self.pid(self.viewer)
        mine: dict[str, type] = {}
        for group in consumer_groups(
            core_consumers,
            core_consumers.LobbyConsumer,
            lobby_code=self.code,
            user_id=pid,
        ):
            mine[group] = core_consumers.LobbyConsumer
        if self.game_id:
            for group in consumer_groups(
                game_consumers,
                game_consumers.GameConsumer,
                game_id=self.game_id,
                user_id=pid,
            ):
                mine[group] = game_consumers.GameConsumer
        return mine

    def drain(self) -> None:
        if self.viewer not in self.players:  # no socket of its own yet
            self.seen_messages = len(self.layer.sent)
            return
        mine = self.groups()
        for group, message in self.layer.sent[self.seen_messages :]:
            if group in mine:
                for frame in socket_frames(mine[group], message, self.pid(self.viewer)):
                    self.told.append(
                        ["ws", group.replace(self.game_id, "{game_id}"), frame]
                    )
        self.seen_messages = len(self.layer.sent)

    def sweep(self, *, every_method: bool = False) -> None:
        """The viewer asks every route; a write is undone after it is answered."""
        ids = [self.pid(n) for n in self.players]
        for path in routes(self.code, self.game_id, [self.pid(self.viewer), *ids]):
            self.request("GET", self.viewer, path)
            writes = every_method and not path.startswith(MINTS)
            for method in ("POST", "PATCH", "DELETE") if writes else ():
                try:
                    with transaction.atomic():
                        self.request(method, self.viewer, path, {})
                        raise _UndoError
                except _UndoError:
                    pass
        if self.game_id:  # and is refused, which must not depend on anyone's card
            for path, body in REFUSED:
                self.request("POST", self.viewer, path, body)


def _picks(t: ViewerTable, plan: Plan, seat: int, prompt: dict[str, Any]) -> list[dict]:
    shape = prompt["shapes"][0]
    valid = prompt.get("valid_targets") or {}
    if "players" in shape:
        seats = plan.seat_picks(seat, shape["players"])
        ids = [t.pid(plan.names[s]) for s in seats]
        assert all(i in valid.get("player_ids", []) for i in ids), (seat, prompt)
        return [{"player_id": i} for i in ids]
    if "center" in shape:
        return [{"center_index": i} for i in plan.centre_picks(seat, shape["center"])]
    return []


def _act(t: ViewerTable, plan: Plan, seat: int) -> None:
    """The seat answers each choice its prompt offers; a sleeper sends nothing."""
    who = plan.names[seat]
    for _ in range(4):
        prompt = (t.call("GET", who, ME) or {}).get("action_prompt")
        if not prompt or prompt.get("chooses_left", 0) <= 0:
            return
        picks = _picks(t, plan, seat, prompt)
        t.call("POST", who, ACTION, {"action_type": "choose", "picks": picks})


def _facts(game_id: str) -> dict[str, Any]:
    game = Game.objects.get(id=game_id)
    roles = PlayerRole.objects.filter(game=game).order_by("user_id")
    return {
        "dealt": [pr.original_role for pr in roles],
        "centre": list(game.dealt_center_cards or []),
        "now": [pr.current_role for pr in roles],
        "votes": [pr.vote_target_id for pr in roles],
        "ids": [pr.user_id for pr in roles],
    }


def play(run: Recording, plan: Plan) -> tuple[list[Any], dict[str, Any]]:
    """The game of ``plan``, to just before the vote's last lock: what the viewer was
    told, and what the database held (the night's end, and the votes before any lock)."""
    t = ViewerTable(
        run.recorder,
        run.clock,
        run.layer,
        run.capture_on_commit,
        run.game_ids,
        next(run.codes),
    )
    t.viewer, t.told, t.seen_messages = plan.names[plan.viewer], [], 0
    names, count = plan.names, len(plan.dealt)
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
        t.call("POST", name, READY, {"ready": True})
    for _ in range(8):
        game = Game.objects.get(id=t.game_id)
        if game.phase != "night":
            break
        wave = game.current_wave
        for seat in range(count):
            _act(t, plan, seat)
        t.sweep()
        game.refresh_from_db()
        if game.phase == "night" and game.current_wave == wave:
            t.call("POST", names[0], ADVANCE)
    facts = _facts(t.game_id)
    for name in names:
        t.call("POST", name, SEEN, {"seen": 10})
    t.sweep()
    for name in names:
        t.call("POST", name, READY, {"ready": True})
    t.sweep()
    for seat, name in enumerate(names):
        first = (seat + 1) % count
        if seat == plan.wavering:
            first = plan.viewer if plan.second else (seat + 2) % count
            if first == plan.viewer and not plan.second:
                first = (seat + 3) % count
        t.call(
            "POST", name, VOTE, {"target_player_id": t.pid(names[first]), "lock": False}
        )
    facts["first_votes"] = _facts(t.game_id)["votes"]
    t.sweep(every_method=True)
    for seat, name in enumerate(names[:-1]):
        target = t.pid(names[(seat + 1) % count])
        t.call("POST", name, VOTE, {"target_player_id": target, "lock": True})
    t.sweep()
    return t.recorder._apply(t.told), facts


def told(capture: Callable[..., Any], plan: Plan) -> tuple[list[Any], dict[str, Any]]:
    """Play ``plan`` in a savepoint that is then undone, so the next game starts from the
    same database (the same ids, codes and clock), with the live server's settings."""
    try:
        with (
            transaction.atomic(),
            override_settings(
                SERVER_TIMING_DETAIL=live_setting("SERVER_TIMING_DETAIL")
            ),
            recording(capture) as run,
        ):
            seen = play(run, plan)
            raise _UndoError(seen)
    except _UndoError as undone:
        return undone.args[0]


def first_difference(a: list[Any], b: list[Any]) -> str | None:
    for index, (one, two) in enumerate(zip(a, b, strict=False)):
        if one != two:
            return f"item {index}:\n  first game:  {one}\n  second game: {two}"
    if len(a) != len(b):
        return f"one game told {len(a)} things, the other {len(b)}"
    return None
