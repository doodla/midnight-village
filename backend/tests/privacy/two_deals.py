# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""One scripted game through the real API, and everything one seat (the viewer) is told.

The script is written by seat, never by role: every seat does what its own ``/me/`` prompt
asks, picking by one rule (``Plan.seat_picks``), and every scripted move must succeed. So
two games dealt differently play the same moves seat for seat, and anything the viewer is
told that differs between them can only come from what the viewer must not know. A move
the server refuses, or a case whose two games do not differ as it says, is a
``ScriptError``: the script could not play, which is not the comparison failing (a break
that only does that proves nothing, tool/breaks_verdict.py).

What a seat may rightly learn is what its own night reads, and nothing else, decided by
the ACTION TYPE of each pick (``reads``): a look (``PEEK_PLAYER``, ``PEEK_CENTER``, the
lone werewolf's look at the centre) reads the card it looks at, a robbery
(``SWAP_WITH_PLAYER``) the card it takes; a swap of two others (``SWAP_OTHERS``) and a
blind take from the centre (``SWAP_WITH_CENTER``) read nothing. Besides: the seats holding
its kin when its role wakes to see its team (werewolves for a werewolf-team role, its own
role otherwise), and its own card at the end when its role wakes and picks nothing (the
Insomniac). A Doppelganger reads the card it copies, then acts as it. ``Plan`` keeps every
variation outside that: a pick that reads avoids the changed places (and what the changed
seats' own picks touch); a pick that reads nothing goes where it would anyway, so a case
can change exactly the card it lands on; a variation that moves the viewer's kin is not
made, and nobody picks a viewer who reads its own card.

What the viewer is told: every answer to a request it makes (status, headers, body), and
every frame its lobby and game sockets send. Those are the viewer's REAL consumers
(``LobbyConsumer``, ``GameConsumer``): their own ``connect`` (the groups it joins, what it
sends at once, the first beat), every group message the layer carries to a group they
joined, through their own handlers, and one heartbeat at each stage. They run in the
test's own thread and database connection (``ViewerSocket``), so they see the test's
transaction. At each stage, an answer from every route of the urlconf (GET; while voting
also POST, PATCH and DELETE, each in a savepoint undone after).
"""

from __future__ import annotations

import ast
import re
from collections.abc import Callable, Iterator
from dataclasses import dataclass, replace
from pathlib import Path
from typing import Any

from django.db import transaction
from django.test import override_settings
from django.urls import URLPattern, URLResolver, get_resolver

from apps.core.consumers import LobbyConsumer
from apps.onuw.consumers import GameConsumer
from apps.onuw.engine.choose import pick_shapes
from apps.onuw.engine.roles import ROLE_REGISTRY, ActionType, Team
from apps.onuw.models import Game, PlayerRole
from tests.contract.recorder import Recording, Table, recording
from tests.privacy.sockets import ViewerSocket

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


# The action types whose pick of a seat reads the card picked: a look, a robbery.
SEAT_READS = {ActionType.PEEK_PLAYER, ActionType.SWAP_WITH_PLAYER}


def reads(role: str, kind: str) -> bool:
    """Whether a pick by ``role`` of a seat (``kind`` "players") or of a centre card
    ("center") reads the card picked, from the role's action types. A swap of two others
    and a blind take from the centre read nothing. The one centre pick a team-seeing role
    makes is the lone werewolf's look (engine/choose.pick_shapes), which reads."""
    found = ROLE_REGISTRY[role]
    types = set(found.action_types)
    if kind == "players":
        return bool(types & SEAT_READS)
    return ActionType.PEEK_CENTER in types or (
        ActionType.SEE_TEAM in types and found.team == Team.WEREWOLF
    )


def first_shape(role: str, *, lone: bool = False) -> tuple[str, int]:
    """The pick a phone acting as ``role`` makes: its prompt's first shape (``_picks``)."""
    ((kind, want),) = pick_shapes(role, lone_werewolf=lone)[0].items()
    return kind, want


class ScriptError(Exception):
    """The script could not play as written: a move refused, a pick off the prompt, a
    case whose two games do not differ as it says. Not an AssertionError on purpose:
    it is not the comparison, so a break that only causes it kills nothing."""


def script_check(ok: object, why: str) -> None:
    if not ok:
        raise ScriptError(f"the script could not play: {why}")


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
        picks = self.seat_picks(self.viewer, 1, protect=False)
        return self.dealt[picks[0]] if copies(role) and picks else role

    def protected(self) -> set[int]:
        """Seats nobody else picks: a viewer that reads its own card at the end."""
        return {self.viewer} if reads_own_card(self.viewer_role()) else set()

    def order(self, seat: int) -> list[int]:
        count = len(self.dealt)
        return [(seat - step) % count for step in range(1, count)]

    def seat_picks(
        self, seat: int, want: int, *, protect: bool = True, reading: bool = True
    ) -> list[int]:
        """The seats a seat's picks name: its neighbours to the left, in order. A
        viewer's pick that reads skips the changed places and what the changed seats'
        own picks name; one that reads nothing skips nothing."""
        skip = (self.protected() if protect and seat != self.viewer else set()) | {seat}
        if seat == self.viewer and reading:
            changed = {p for p in self.changed() if isinstance(p, int)}
            skip |= changed | {s for c in changed for s in self.order(c)[:2]}
        return [s for s in self.order(seat) if s not in skip][:want]

    def centre_picks(self, seat: int, want: int, *, reading: bool = True) -> list[int]:
        """The viewer picks from the centre's far end, a look past the changed cards;
        the others from its near end."""
        if seat != self.viewer:
            return list(range(CENTRE))[:want]
        changed = {int(p[1]) for p in self.changed() if isinstance(p, str)}
        skip = changed if reading else set()
        return [i for i in reversed(range(CENTRE)) if i not in skip][:want]

    def blind_landing(self) -> list[Place]:
        """Where the viewer's pick that reads nothing lands (a Troublemaker's two seats,
        the Drunk's centre card, a Doppelganger's once it acts as either): [] for a
        viewer whose picks all read."""
        acting = self.viewer_role()
        kind, want = first_shape(acting)
        if kind not in ("players", "center") or reads(acting, kind):
            return []
        if kind == "players":
            return list(self.seat_picks(self.viewer, want, reading=False))
        return [f"c{i}" for i in self.centre_picks(self.viewer, want, reading=False)]

    def looks_at_centre(self) -> bool:
        acting = self.viewer_role()
        return first_shape(acting, lone=not self.kin_seats())[0] == "center"

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


class _UndoError(Exception):
    pass


class ViewerTable(Table):
    """A table that keeps everything one seat is told."""

    viewer: str
    told: list[Any]
    seen_messages: int
    sockets: list[ViewerSocket]

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

    def call(self, method: str, who: str, path: str, body: Any = None) -> Any:
        """A scripted move: refused, it is the script that cannot play."""
        got, payload = self.request(method, who, path, body)
        script_check(got < 300, f"{method} {path} as {who}: {got} {payload}")
        return payload

    def connect(self, name: str) -> None:
        """A game socket opens: the viewer's is its real consumer."""
        if name != self.viewer:
            super().connect(name)
            return
        self.sockets.append(
            ViewerSocket(self, "game", GameConsumer, game_id=str(self.game_id))
        )
        self.drain()

    def connect_lobby(self, name: str) -> None:
        if name != self.viewer:
            super().connect_lobby(name)
            return
        self.sockets.append(ViewerSocket(self, "lobby", LobbyConsumer, code=self.code))
        self.drain()

    def drain(self) -> None:
        """Every message the layer carried since, to the viewer's sockets that joined
        its group (each socket's own handler says what its phone is sent)."""
        while self.seen_messages < len(self.layer.sent):
            index = self.seen_messages
            group, message = self.layer.sent[index]
            self.seen_messages += 1
            for socket in self.sockets:
                socket.deliver(index, group, message)

    def beat(self) -> None:
        for socket in self.sockets:
            socket.beat()
        self.drain()

    def sweep(self, *, every_method: bool = False) -> None:
        """A beat of each of the viewer's sockets, then the viewer asks every route; a
        write is undone after it is answered."""
        self.beat()
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
    """The seat's picks for its prompt's first shape; whether they read is the action
    type of the role the prompt says the seat acts as (``reads``)."""
    shape = prompt["shapes"][0]
    valid = prompt.get("valid_targets") or {}
    acting = prompt.get("role_acting_as") or plan.effective(seat)
    if "players" in shape:
        reading = reads(acting, "players")
        seats = plan.seat_picks(seat, shape["players"], reading=reading)
        ids = [t.pid(plan.names[s]) for s in seats]
        script_check(
            all(i in valid.get("player_ids", []) for i in ids),
            f"seat {seat} picks {seats}, off its prompt {prompt}",
        )
        return [{"player_id": i} for i in ids]
    if "center" in shape:
        reading = reads(acting, "center")
        indices = plan.centre_picks(seat, shape["center"], reading=reading)
        return [{"center_index": i} for i in indices]
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
        "log": list(game.night_actions_log or []),
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
    t.sockets = []
    names, count = plan.names, len(plan.dealt)
    for name in names:
        t.guest(name)
    t.call("POST", names[0], "/lobbies/", {"game_type": "onuw", "defaults": "v2"})
    for name in names[1:]:
        t.clock.advance(30)
        t.call("POST", name, "/lobbies/{code}/join/")
        if name == t.viewer:
            t.connect_lobby(name)
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
