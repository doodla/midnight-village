"""Record what the server really sends, as contract samples for the app's tests.

A ``Table`` plays games through the real views (DRF test client), services and
consumer handlers. Nothing about the payloads is stubbed:

- HTTP: every request goes through the URL conf to the real view; the sample is
  the response body exactly as rendered.
- Sockets: the channel layer is a ``RecordingLayer`` that keeps every group
  message. A ``Table`` knows which groups each player's sockets join (the same
  names the consumers use) and turns each message into what the phone receives
  by calling the consumer's own handler for it (``GameConsumer`` /
  ``LobbyConsumer``).
- After-commit side effects run when each request's transaction would commit.

- Timers are the real ones (``ScheduledTimer`` rows, cancelled by deleting
  them) with no thread behind them: ``is_scheduled`` is "the row exists", so a
  ``GET /me/`` never takes the lost-timer repair path, and ``Table.fire`` claims
  a row and runs its job the way its thread (or the debug hook) would.

What would differ from run to run is pinned instead of edited out: the clock is
frozen at a past date (``Clock``), user ids start at 1, lobby codes come from a
fixed list, the forced deal's seed is fixed; game ids, guest usernames and
tokens (random by design) are replaced by stable stand-ins
(``Recorder.stable``).

Each socket sample's index entry says which group delivered it (``group``: a
player's own ``player`` group or the table's ``broadcast`` group) and who
receives it (``recipients``), so moving a private event onto the broadcast
group is a sample diff (and ``test_contract_privacy.py`` refuses it).
"""

from __future__ import annotations

import copy
import json
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from typing import Any
from unittest.mock import patch

from django.db import connection
from django.test import override_settings

from asgiref.sync import async_to_sync
from channels.consumer import get_handler_name
from channels.layers import BaseChannelLayer, get_channel_layer
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import AccessToken

from apps.core import host, presence, timers
from apps.core.consumers import LobbyConsumer
from apps.core.models import Lobby, LobbyMember, ScheduledTimer, User
from apps.onuw import night2, services
from apps.onuw.consumers import GameConsumer
from apps.onuw.models import Game, PlayerRole
from apps.onuw.protocol import is_choose_night, stage_token

START = datetime(2024, 3, 7, 20, 50, tzinfo=UTC)
LOBBY_CODES = (
    "K7QX4M",
    "M2RV8P",
    "Q4TW9N",
    # The night-protocol-2 tables (scenarios.protocol_two_tables) come after.
    "R5ZD3H",
    "T8NB6C",
    "V9YC2J",
    "W3XF7K",
    # The results, three-player and ten-player tables (scenarios.results_tables).
    "X2PG5N",
    "Y6HM8R",
    "Z4KQ3T",
    # The lobby table (scenarios.lobby_table).
    "B7DH4Q",
    "C9FJ2K",
)
# Stand-ins for the game ids, in the order the games are dealt.
GAME_IDS = (
    "7d3f2c1a-5b8e-4c2d-9a6f-1e0b3c4d5e6f",
    "9a1e5c7b-3d2f-4b6a-8c0e-2f4a6b8c0d1e",
    *(f"00000000-0000-4000-a000-{n:012d}" for n in range(3, 40)),
)
FORCED_SEED = 424242


class RecordingLayer(BaseChannelLayer):
    """A channel layer that remembers every message sent to a group."""

    extensions = ["groups"]

    def __init__(self, **kwargs: Any) -> None:
        super().__init__(**kwargs)
        self.sent: list[tuple[str, dict[str, Any]]] = []

    async def group_send(self, group: str, message: dict[str, Any]) -> None:
        self.sent.append((group, copy.deepcopy(message)))

    async def group_add(self, group: str, channel: str) -> None:
        pass

    async def group_discard(self, group: str, channel: str) -> None:
        pass


RECORDING_LAYER = {"default": {"BACKEND": "tests.contract.recorder.RecordingLayer"}}


class Clock:
    """The frozen ``timezone.now``; moves only when a scenario says so."""

    def __init__(self, start: datetime) -> None:
        self.now = start

    def __call__(self) -> datetime:
        return self.now

    def advance(self, seconds: float) -> None:
        self.now += timedelta(seconds=seconds)


def client_event(consumer_cls: type, message: dict[str, Any]) -> dict[str, Any]:
    """What a socket of ``consumer_cls`` sends its phone for a group message,
    produced by the consumer's own handler for that message type."""
    consumer = consumer_cls()
    out: list[dict[str, Any]] = []

    async def base_send(frame: dict[str, Any]) -> None:
        out.append(json.loads(frame["text"]))

    consumer.base_send = base_send
    async_to_sync(getattr(consumer, get_handler_name(message)))(message)
    (event,) = out
    return event


@dataclass
class Sample:
    """One recorded payload and what it is the answer to."""

    name: str
    meta: dict[str, Any]
    payload: Any


@dataclass
class Recorder:
    """Collects samples and the stand-ins for values that are random by design."""

    samples: dict[str, Sample] = field(default_factory=dict)
    replacements: dict[str, str] = field(default_factory=dict)

    def stable(self, real: str, stand_in: str) -> None:
        self.replacements[real] = stand_in

    def add(self, name: str, meta: dict[str, Any], payload: Any) -> None:
        assert name not in self.samples, f"sample {name} recorded twice"
        self.samples[name] = Sample(name, meta, payload)

    def rendered(self) -> dict[str, Any]:
        """Every sample with the stand-ins applied, plus the index."""
        out: dict[str, Any] = {}
        index = []
        for name in sorted(self.samples):
            sample = self.samples[name]
            out[f"{name}.json"] = self._apply(sample.payload)
            index.append({"name": name, **self._apply(sample.meta)})
        out["index.json"] = {
            "about": (
                "Payloads recorded from the real server by "
                "backend/tests/contract/test_contract_samples.py. Do not edit: "
                "run `just samples` and review the diff."
            ),
            "samples": index,
        }
        return out

    def _apply(self, value: Any) -> Any:
        text = json.dumps(value)
        for real, stand_in in self.replacements.items():
            text = text.replace(real, stand_in)
        return json.loads(text)


@dataclass
class Player:
    name: str
    user: User
    client: APIClient
    refresh_token: str


class Table:
    """One lobby and its games, driven through the real API."""

    def __init__(
        self,
        recorder: Recorder,
        clock: Clock,
        layer: RecordingLayer,
        capture_on_commit: Callable[..., Any],
        game_ids: Iterator[str],
        lobby_code: str,
    ) -> None:
        self.recorder = recorder
        self.clock = clock
        self.layer = layer
        self._capture_on_commit = capture_on_commit
        self._game_ids = game_ids
        self.code = lobby_code
        self.players: dict[str, Player] = {}
        self.game_id = ""

    # -- HTTP -------------------------------------------------------------

    def request(
        self,
        method: str,
        who: str,
        path: str,
        body: dict[str, Any] | None = None,
        *,
        debug: bool = False,
        bearer: str | None = None,
        **fill: str,
    ) -> tuple[int, Any]:
        """Call the real view as ``who`` (a player name, or "" for nobody);
        ``path`` is the app's path (no ``/api``), with ``{code}`` / ``{game_id}``.
        ``fill`` overrides those (an unknown code, say). Returns (status, body)
        with the on-commit side effects run, as on a commit. ``bearer`` sends
        that access token instead of signing ``who`` in directly."""
        if bearer is not None:
            client = APIClient()
            client.credentials(HTTP_AUTHORIZATION=f"Bearer {bearer}")
        else:
            client = self.players[who].client if who else APIClient()
        ids = {"code": self.code, "game_id": self.game_id, **fill}
        url = "/api" + path.format(**ids)
        body = self._staged(path, body, ids["game_id"], who)
        send = getattr(client, method.lower())
        with self._capture_on_commit(execute=True), override_settings(DEBUG=debug):
            response = send(url, body, format="json")
        return response.status_code, json.loads(response.content or b"null")

    STAGE_ENDPOINTS = (
        "/action/",
        "/ready/",
        "/vote/",
        "/advance-wave/",
        "/end-discussion/",
        "/reveal-votes/",
    )

    def _staged(
        self, path: str, body: dict[str, Any] | None, game_id: str, who: str
    ) -> dict[str, Any] | None:
        """The way the app sends it: a request to a stage-scoped endpoint of a game
        that plays night protocol 2 names the stage the game is in NOW (read from
        ``/me/``'s own function), unless the scenario names one (a stale token), and
        a ``choose`` answers the caller's prompt as it is now (``chosen``), unless
        the scenario names a count (a resend)."""
        if not game_id or not path.endswith(self.STAGE_ENDPOINTS):
            return body
        if body is not None and not isinstance(body, dict):
            return body
        game = Game.objects.filter(id=game_id).first()
        if game is None or not is_choose_night(game):
            return body
        staged = dict(body or {})
        if "stage" not in staged:
            staged["stage"] = stage_token(game)
        if staged.get("action_type") == "choose" and "chosen" not in staged:
            # The prompt the phone answers: its own count in the open window.
            pr = (
                PlayerRole.objects.filter(
                    game=game, user=self.players[who].user
                ).first()
                if who in self.players
                else None
            )
            staged["chosen"] = (
                0 if pr is None else night2.chose_count(pr, game.current_wave)
            )
        return staged

    def stage_now(self) -> str:
        """The stage token the game is in now, to be sent LATER as a stale one."""
        token = stage_token(Game.objects.get(id=self.game_id))
        assert token is not None
        return token

    def record(
        self,
        name: str,
        method: str,
        who: str,
        path: str,
        body: dict[str, Any] | None = None,
        *,
        status: int,
        about: str,
        debug: bool = False,
        bearer: str | None = None,
        **fill: str,
    ) -> Any:
        """``request`` and keep the response as sample ``http/<name>``."""
        got, payload = self.request(
            method, who, path, body, debug=debug, bearer=bearer, **fill
        )
        assert got == status, f"{name}: expected {status}, got {got}: {payload}"
        self.recorder.add(
            f"http/{name}",
            {
                "kind": "http",
                "method": method,
                "path": path,
                "status": status,
                "description": about,
            },
            payload,
        )
        return payload

    def call(
        self, method: str, who: str, path: str, body: dict[str, Any] | None = None
    ) -> Any:
        """A request whose answer is not a sample; it must succeed."""
        got, payload = self.request(method, who, path, body)
        assert got < 300, f"{method} {path} as {who}: {got} {payload}"
        return payload

    # -- players ----------------------------------------------------------

    def guest(self, name: str, *, sample: str | None = None) -> Player:
        """A guest account through ``POST /auth/guest/`` (as the app signs in)."""
        body = {"display_name": name}
        if sample:
            payload = self.record(
                sample,
                "POST",
                "",
                "/auth/guest/",
                body,
                status=201,
                about="A guest account is created.",
            )
        else:
            payload = self.call("POST", "", "/auth/guest/", body)
        user = User.objects.get(id=payload["user"]["id"])
        number = f"{user.id:012d}"
        self.recorder.stable(user.username, f"00000000-0000-4000-8000-{number}")
        self.recorder.stable(payload["access"], f"access-token-{user.id}")
        self.recorder.stable(payload["refresh"], f"refresh-token-{user.id}")
        client = APIClient()
        client.force_authenticate(user=user)
        player = Player(name, user, client, payload["refresh"])
        self.players[name] = player
        return player

    def expired_access_token(self, name: str) -> str:
        """A real access token for ``name`` whose lifetime ended in 2020."""
        token = AccessToken.for_user(self.players[name].user)
        token.set_exp(from_time=datetime(2020, 1, 1, tzinfo=UTC))
        return str(token)

    def pid(self, name: str) -> int:
        return self.players[name].user.id  # type: ignore[return-value]

    # -- sockets ----------------------------------------------------------

    def _groups(self, name: str, socket: str) -> set[str]:
        if socket == "lobby":
            return {f"lobby_{self.code}"}
        game = f"game_{self.game_id}"
        return {game, f"{game}_player_{self.pid(name)}"}

    def events(
        self, name: str, socket: str, kind: str
    ) -> list[tuple[str, dict[str, Any]]]:
        """Every ``kind`` event ``name``'s lobby or game socket has received,
        with the group that delivered it."""
        consumer = LobbyConsumer if socket == "lobby" else GameConsumer
        groups = self._groups(name, socket)
        wanted = kind.replace("_", ".")
        return [
            (group, client_event(consumer, message))
            for group, message in self.layer.sent
            if group in groups and message["type"] == wanted
        ]

    def _recipients(self, group: str, socket: str) -> list[str]:
        """Who holds a socket in ``group``: a player's own group is theirs; the
        broadcast group is every member of the lobby (lobby socket) or every
        player of the game (game socket)."""
        if socket == "lobby":
            ids = LobbyMember.objects.filter(lobby__code=self.code).values_list(
                "user_id", flat=True
            )
        else:
            ids = PlayerRole.objects.filter(game_id=self.game_id).values_list(
                "user_id", flat=True
            )
        held = set(ids)
        return sorted(
            name
            for name, player in self.players.items()
            if player.user.id in held and group in self._groups(name, socket)
        )

    def record_event(
        self, name: str, who: str, socket: str, kind: str, *, about: str
    ) -> dict[str, Any]:
        """Keep the latest ``kind`` event ``who`` received as ``ws/<name>``,
        noting which group delivered it and who else got it."""
        received = self.events(who, socket, kind)
        assert received, f"{who} received no {kind} on the {socket} socket"
        group, event = received[-1]
        self.recorder.add(
            f"ws/{name}",
            {
                "kind": "ws",
                "socket": socket,
                "type": kind,
                "group": "player" if "_player_" in group else "broadcast",
                "recipients": self._recipients(group, socket),
                "description": about,
            },
            event,
        )
        return event

    def connect(self, name: str) -> None:
        """A game socket opens: what ``GameConsumer`` does on connect."""
        channel = f"socket.{self.pid(name)}"
        with self._capture_on_commit(execute=True):
            if services.register_connection(self.game_id, self.pid(name), channel):
                services.report_game_presence(self.game_id, self.pid(name), True)

    def disconnect(self, name: str) -> None:
        """The game socket closes: what ``GameConsumer`` does on disconnect."""
        channel = f"socket.{self.pid(name)}"
        with self._capture_on_commit(execute=True):
            if services.unregister_connection(self.game_id, self.pid(name), channel):
                services.report_game_presence(self.game_id, self.pid(name), False)

    def connect_lobby(self, name: str) -> None:
        """A lobby socket opens: what ``LobbyConsumer`` does on connect."""
        with self._capture_on_commit(execute=True):
            host.register_lobby_connection(
                self.code, self.pid(name), f"lobby-socket.{self.pid(name)}"
            )

    def disconnect_lobby(self, name: str) -> None:
        """The lobby socket closes: what ``LobbyConsumer`` does on disconnect."""
        with self._capture_on_commit(execute=True):
            host.unregister_lobby_connection(
                self.code, self.pid(name), f"lobby-socket.{self.pid(name)}"
            )

    def lobby_presence_key(self, name: str) -> str:
        """The durable presence check of ``name`` at this table."""
        lobby_id = Lobby.objects.get(code=self.code).pk
        return presence.check_key("lobby", lobby_id, self.pid(name))

    # -- the game ---------------------------------------------------------

    def start(
        self, roles: dict[str, str], center: list[str], *, sample: str | None = None
    ) -> None:
        """The host deals the given cards (the DEBUG forced deal; the response
        is the same as for a random deal, kept as ``http/<sample>``)."""
        body = {
            "debug": {
                "forced_assignment": {
                    "player_roles": {str(self.pid(n)): r for n, r in roles.items()},
                    "center": center,
                }
            }
        }
        host = next(iter(self.players))
        with patch("secrets.randbits", return_value=FORCED_SEED):
            got, payload = self.request(
                "POST", host, "/onuw/lobbies/{code}/start/", body, debug=True
            )
        assert got == 201, payload
        self.game_id = payload["game_id"]
        self._pin_game_id()
        if sample:
            self.recorder.add(
                f"http/{sample}",
                {
                    "kind": "http",
                    "method": "POST",
                    "path": "/onuw/lobbies/{code}/start/",
                    "status": 201,
                    "description": "The host deals; everyone opens the game.",
                },
                payload,
            )

    def _pin_game_id(self) -> None:
        """The game id is random: its stand-in, and the piece of it a stage token
        carries (``/me/``'s ``stage``), are fixed."""
        stand_in = next(self._game_ids)
        self.recorder.stable(self.game_id, stand_in)
        self.recorder.stable(self.game_id.replace("-", "")[:12], stand_in[-12:])

    def start_random(self, seed: int, *, sample: str | None = None) -> dict[str, Any]:
        """The host deals a random hand from a fixed seed (the DEBUG seed), as
        for a table whose deck the server builds."""
        host = next(iter(self.players))
        got, payload = self.request(
            "POST",
            host,
            "/onuw/lobbies/{code}/start/",
            {"debug": {"seed": seed}},
            debug=True,
        )
        assert got == 201, payload
        self.game_id = payload["game_id"]
        self._pin_game_id()
        if sample:
            self.recorder.add(
                f"http/{sample}",
                {
                    "kind": "http",
                    "method": "POST",
                    "path": "/onuw/lobbies/{code}/start/",
                    "status": 201,
                    "description": "The host deals; the server built the deck.",
                },
                payload,
            )
        return payload

    def mark(self) -> int:
        """A point in the stream of socket messages, for ``record_sequence``."""
        return len(self.layer.sent)

    def record_sequence(self, name: str, since: int, *, about: str) -> None:
        """Keep, per player, the TYPES of the game messages that player's socket
        received since ``since``, in order, as ``ws_sequence/<name>``: the
        broadcast group and the player's own group (what their phone would see).
        Under night protocol 2 these lists must be the same for every seat."""
        sequences: dict[str, list[str]] = {}
        for who in self.players:
            groups = self._groups(who, "game")
            sequences[who] = [
                message["type"].replace(".", "_")
                for group, message in self.layer.sent[since:]
                if group in groups
            ]
        self.recorder.add(
            f"ws_sequence/{name}",
            {"kind": "ws_sequence", "socket": "game", "description": about},
            sequences,
        )

    def fire(self, key: str) -> None:
        """Fire the pending timer under ``key`` (``{game_id}`` is filled in) now:
        claim its row and run its job, as its thread would when due."""
        key = key.format(game_id=self.game_id)
        with self._capture_on_commit(execute=True):
            result = timers.fire(key, None, force=True)
        assert result.status == "ran", f"no pending timer {key}: {result}"


@dataclass
class Recording:
    """The pinned environment of one recording run."""

    recorder: Recorder
    clock: Clock
    layer: RecordingLayer
    capture_on_commit: Callable[..., Any]
    codes: Iterator[str]
    game_ids: Iterator[str]

    def table(self) -> Table:
        """A new lobby (the next fixed lobby code)."""
        return Table(
            self.recorder,
            self.clock,
            self.layer,
            self.capture_on_commit,
            self.game_ids,
            next(self.codes),
        )


@contextmanager
def recording(capture_on_commit: Callable[..., Any]) -> Iterator[Recording]:
    """Pin the clock, ids, lobby codes, channel layer and timers for a run.

    Timers keep their rows (``timers.schedule`` / ``cancel`` are the real
    ones) but arm no thread; a timer is scheduled while its row exists."""
    codes = iter(LOBBY_CODES)

    def row_exists(key: str) -> bool:
        return ScheduledTimer.objects.filter(key=key).exists()

    with connection.cursor() as cursor:
        cursor.execute(
            "SELECT setval(pg_get_serial_sequence(%s, 'id'), 1, false)",
            [User._meta.db_table],
        )
    clock = Clock(START)
    with (
        override_settings(CHANNEL_LAYERS=RECORDING_LAYER),
        patch("django.utils.timezone.now", new=clock),
        patch("apps.core.models.generate_lobby_code", side_effect=iter(LOBBY_CODES)),
        patch("apps.core.timers._arm"),
        patch("apps.core.timers.is_scheduled", side_effect=row_exists),
    ):
        layer = get_channel_layer()
        assert isinstance(layer, RecordingLayer)
        yield Recording(
            Recorder(), clock, layer, capture_on_commit, codes, iter(GAME_IDS)
        )
