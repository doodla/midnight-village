"""The socket leg of the check after each merge (tool/deployed_check.py calls it).

What it proves, against the live server, that nothing else did: an event the
server sends because of one player's request REACHES the other players'
sockets, soon. The deal and play again are heard only that way (the rescue is
a read every 15 s on a phone), and no check opened a socket before this one.

Three throwaway guests sit at one table; two listen on the lobby's socket; the
host deals: both must hear `game_started` within HEAR seconds. The game is
then played through its stages as fast as the requests go (every length short,
the host moving each stage on), the host plays again, and both must hear the
table reopen (`lobby_update`, status `waiting`). Then all leave, and the last
one out deletes the table and its game. On a failure the lengths are short so
the game ends by its own timers, and leaving is tried until the server lets go.

Only the standard library: a WebSocket client is a handshake and a frame
reader, and the check must run anywhere with no install.
"""

import base64
import json
import os
import socket
import ssl
import struct
import time
import urllib.parse

HEAR = 5.0  # seconds a listener may take to hear an event sent because of another's request
PLAYED = 150.0  # seconds a game of these lengths may take to reach its results
GUEST_NAMES = ("Deploy check A", "Deploy check B", "Deploy check C")
# Six cards for three players; nobody has to act at night for the game to go on.
DECK = {"Werewolf": 2, "Villager": 3, "Seer": 1}
# The shortest the LIVE rules take (a night window is never under 5 s there; a
# local server with relaxed rules would take less and prove nothing about live):
# a game this check abandons ends by itself.
LENGTHS = {
    "card_look_seconds": 5,
    "night_wave_seconds": 5,
    "night_min_window_seconds": 5,
    "night_doppelganger_window_seconds": 5,
    "discussion_seconds": 10,
    "voting_seconds": 10,
}


class SocketFailed(Exception):
    pass


class Listener:
    """One open WebSocket, read only: the events the server sends, as dicts."""

    def __init__(self, url: str, origin: str | None, timeout: float = 15.0):
        parts = urllib.parse.urlsplit(url)
        secure = parts.scheme == "wss"
        port = parts.port or (443 if secure else 80)
        raw = socket.create_connection((parts.hostname, port), timeout=timeout)
        if secure:
            raw = ssl.create_default_context().wrap_socket(
                raw, server_hostname=parts.hostname
            )
        self._sock = raw
        self._buffer = b""
        key = base64.b64encode(os.urandom(16)).decode()
        path = parts.path + (f"?{parts.query}" if parts.query else "")
        host = parts.hostname + ("" if parts.port is None else f":{parts.port}")
        lines = [
            f"GET {path} HTTP/1.1",
            f"Host: {host}",
            "Upgrade: websocket",
            "Connection: Upgrade",
            f"Sec-WebSocket-Key: {key}",
            "Sec-WebSocket-Version: 13",
        ]
        if origin:
            lines.append(f"Origin: {origin}")
        raw.sendall(("\r\n".join(lines) + "\r\n\r\n").encode())
        head = self._until(b"\r\n\r\n")
        status = head.split(b"\r\n", 1)[0].decode(errors="replace")
        if " 101 " not in f"{status} ":
            raise SocketFailed(f"the socket was not accepted: {status}")

    def _fill(self) -> None:
        chunk = self._sock.recv(65536)
        if not chunk:
            raise SocketFailed("the server closed the socket")
        self._buffer += chunk

    def _until(self, mark: bytes) -> bytes:
        while mark not in self._buffer:
            self._fill()
        head, self._buffer = self._buffer.split(mark, 1)
        return head

    def _take(self, count: int) -> bytes:
        while len(self._buffer) < count:
            self._fill()
        taken, self._buffer = self._buffer[:count], self._buffer[count:]
        return taken

    def _send(self, opcode: int, payload: bytes = b"") -> None:
        mask = os.urandom(4)
        masked = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        self._sock.sendall(bytes([0x80 | opcode, 0x80 | len(payload)]) + mask + masked)

    def next_event(self, within: float) -> dict | None:
        """The next JSON event, or None when none came `within` seconds."""
        deadline = time.monotonic() + within
        while True:
            left = deadline - time.monotonic()
            if left <= 0:
                return None
            self._sock.settimeout(left)
            try:
                first, second = self._take(2)
                length = second & 0x7F
                if length == 126:
                    (length,) = struct.unpack(">H", self._take(2))
                elif length == 127:
                    (length,) = struct.unpack(">Q", self._take(8))
                payload = self._take(length)
            except TimeoutError:
                return None
            opcode = first & 0x0F
            if opcode == 0x9:  # a ping: answer it and go on
                self._send(0xA, payload[:125])
            elif opcode == 0x8:
                raise SocketFailed("the server closed the socket")
            elif opcode == 0x1:
                try:
                    event = json.loads(payload.decode())
                except ValueError:
                    continue
                if isinstance(event, dict):
                    return event

    def hear(self, wanted, within: float) -> tuple[dict, float]:
        """(the first event `wanted(event)` accepts, seconds waited); fails after `within`."""
        started = time.monotonic()
        seen = []
        while True:
            event = self.next_event(within - (time.monotonic() - started))
            if event is None:
                raise SocketFailed(
                    f"not heard within {within:.0f} s (heard instead: {seen or 'nothing'})"
                )
            if wanted(event):
                return event, time.monotonic() - started
            seen.append(event.get("type"))

    def close(self) -> None:
        try:
            self._send(0x8)
        except OSError:
            pass
        finally:
            self._sock.close()


def socket_url(api: str, path: str, token: str) -> str:
    scheme = "wss" if api.startswith("https") else "ws"
    return (
        f"{scheme}://{api.split('://', 1)[1]}{path}?token={urllib.parse.quote(token)}"
    )


def play_to_results(call, game: str, tokens: list[str]) -> None:
    """Every player does what their `/me/` asks, the host moves each stage on, until
    the game shows its results. `call(what, method, path, want, token, body)` is the
    check's JSON request; it returns (status, body) and accepts any status in `want`."""
    host = tokens[0]
    deadline, before = time.monotonic() + PLAYED, None
    while time.monotonic() < deadline:
        me = call("read the game", "GET", f"/api/onuw/games/{game}/me/", (200,), host)[
            1
        ]
        phase, stage = me.get("phase"), me.get("stage")
        if phase == "results":
            return
        if stage == before:
            time.sleep(0.5)  # the server did not move on yet (a window's least length)
        before = stage
        staged = {"stage": stage}
        any_status = (200, 201, 400, 403, 409)  # a stage that just moved on answers 409
        if me.get("ready") is not None and phase not in ("discussion", "voting"):
            for token in tokens:  # the look at your card
                call(
                    "ready",
                    "POST",
                    f"/api/onuw/games/{game}/ready/",
                    any_status,
                    token,
                    {**staged, "ready": True},
                )
        elif phase == "night":
            call(
                "the night moves on",
                "POST",
                f"/api/onuw/games/{game}/advance-wave/",
                any_status,
                host,
                staged,
            )
        elif phase == "discussion":
            call(
                "the talk ends",
                "POST",
                f"/api/onuw/games/{game}/end-discussion/",
                any_status,
                host,
                staged,
            )
        elif phase == "voting":
            for token in tokens:
                mine = call(
                    "read the vote", "GET", f"/api/onuw/games/{game}/me/", (200,), token
                )[1]
                targets = mine.get("vote_targets") or []
                if targets and mine.get("phase") == "voting":
                    target = (
                        targets[0]["id"] if isinstance(targets[0], dict) else targets[0]
                    )
                    call(
                        "vote",
                        "POST",
                        f"/api/onuw/games/{game}/vote/",
                        any_status,
                        token,
                        {
                            "stage": mine.get("stage"),
                            "target_player_id": target,
                            "lock": True,
                        },
                    )
            call(
                "the votes are shown",
                "POST",
                f"/api/onuw/games/{game}/reveal-votes/",
                any_status,
                host,
                staged,
            )
    raise SocketFailed(f"the game did not reach its results in {PLAYED:.0f} s")


def deal_is_heard(
    call, api: str, origin: str | None, guest, say=print, heard=None, repeats=0
) -> None:
    """The whole leg. `guest(name)` makes a guest and returns its token (the check's
    own, so its clean-up knows them). For the latency leg: `repeats` more of each
    read and three settings changes (so each kind of request has several times),
    and `heard(event, seconds)` is told how long after its request was SENT each
    listener had the event."""
    tokens = [guest(name) for name in GUEST_NAMES]
    host, listeners = tokens[0], []
    table = call(
        "open a table",
        "POST",
        "/api/lobbies/",
        (201,),
        host,
        {"game_type": "onuw", "defaults": "v2"},
    )[1]
    code = table["code"]
    for token in tokens[1:]:
        call("join", "POST", f"/api/lobbies/{code}/join/", (200,), token, {})
    call(
        "set a short game",
        "PATCH",
        f"/api/lobbies/{code}/",
        (200,),
        host,
        {"settings": {"deck": "custom", "roles": DECK, "seats": 3, **LENGTHS}},
    )
    short = {"settings": {"deck": "custom", "roles": DECK, "seats": 3, **LENGTHS}}
    for _ in range(repeats):
        call("read the table", "GET", f"/api/lobbies/{code}/", (200,), tokens[1])
        call("where am I", "GET", "/api/me/table/", (200,), tokens[1])
    for _ in range(min(repeats, 3)):
        call("set a short game", "PATCH", f"/api/lobbies/{code}/", (200,), host, short)
    try:
        for token in tokens[1:]:
            # a socket is accepted only from an origin the server knows: the app's,
            # or with no app (a local server) the server's own
            listeners.append(
                Listener(socket_url(api, f"/ws/lobby/{code}/", token), origin or api)
            )
        sent = time.monotonic()
        game = call(
            "deal", "POST", f"/api/onuw/lobbies/{code}/start/", (201,), host, {}
        )[1]["game_id"]
        took = time.monotonic() - sent
        for number, listener in enumerate(listeners, 2):
            try:
                _, waited = listener.hear(
                    lambda e: e.get("type") == "game_started", HEAR
                )
            except SocketFailed as e:
                raise SocketFailed(
                    f"guest {number} did not hear the deal: {e}"
                ) from None
            say(
                f"  guest {number} heard game_started {waited:.2f} s after the deal's answer (the deal took {took:.2f} s)"
            )
            if heard:
                heard("game_started", took + waited)
        for _ in range(repeats):
            call(
                "read the game", "GET", f"/api/onuw/games/{game}/me/", (200,), tokens[1]
            )
        play_to_results(call, game, tokens)
        sent = time.monotonic()
        call("play again", "POST", f"/api/lobbies/{code}/play-again/", (200,), host, {})
        took = time.monotonic() - sent
        for number, listener in enumerate(listeners, 2):
            try:
                _, waited = listener.hear(
                    lambda e: (
                        e.get("type") == "lobby_update"
                        and (e.get("data") or {}).get("status") == "waiting"
                    ),
                    HEAR,
                )
            except SocketFailed as e:
                raise SocketFailed(
                    f"guest {number} did not hear play again: {e}"
                ) from None
            say(
                f"  guest {number} heard the table reopen {waited:.2f} s after play again's answer"
            )
            if heard:
                heard("lobby_update (play again)", took + waited)
    finally:
        for listener in listeners:
            listener.close()
