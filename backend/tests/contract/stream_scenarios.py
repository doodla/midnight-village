"""A whole seeded game at six seats as every phone sees it: ``ws_stream/six_seats``.

For each seat, in order: every event its game socket received once it was open
(the table's group and its own, as ``GameConsumer`` sends them) and the answer to
every request that phone made itself: a ``request`` as it leaves (``method``, the
app's ``path``, the body it ``sent``) and its ``answer`` (``status``, ``body``). What a
request causes is heard between the two
(it is sent at its commit, before the answer leaves), so this is the order
a phone sees when its socket is the faster of the two.

The game is the app's: a ``v2`` table of six, dealt (forced) so that three seats
choose at night (Seer, Robber, Troublemaker) and three have nothing to choose (two
Werewolves, the Insomniac); every phone opens its socket and reads its ``/me/``
once, looks, chooses if it has a choice, holds My night (the ack), is ready to vote,
picks and then locks a vote; the host plays again. The app's request count replays
every seat through its strict mocks
(``frontend/test/features/game/presentation/requests_per_game_test.dart``); the
server's half is ``tests/onuw/test_own_view.py``.

Recorded after every other table (``scenarios.record_all`` calls it last), so no
earlier sample's ids, codes or clocks move.
"""

from __future__ import annotations

from typing import Any

from apps.onuw.consumers import GameConsumer

from .recorder import Recording, Table, client_event

SIX = ["Ana", "Ben", "Cleo", "Dev", "Esme", "Fin"]
DEALT = {
    "Ana": "Seer",
    "Ben": "Robber",
    "Cleo": "Troublemaker",
    "Dev": "Werewolf",
    "Esme": "Werewolf",
    "Fin": "Insomniac",
}
CENTRE = ["Villager", "Drunk", "Minion"]

CREATE = "/lobbies/"
JOIN = "/lobbies/{code}/join/"
LOBBY = "/lobbies/{code}/"
PLAY_AGAIN = "/lobbies/{code}/play-again/"
ME = "/onuw/games/{game_id}/me/"
READY = "/onuw/games/{game_id}/ready/"
ACTION = "/onuw/games/{game_id}/action/"
VOTE = "/onuw/games/{game_id}/vote/"
SEEN = "/onuw/games/{game_id}/night-results/seen/"


class StreamTable(Table):
    """A ``Table`` that keeps, per seat, what that phone saw (``stream``)."""

    def start_stream(self) -> None:
        self.stream: dict[str, list[dict[str, Any]]] = {name: [] for name in SIX}
        self.listening: set[str] = set()
        self._heard = len(self.layer.sent)

    def _flush(self) -> None:
        """Give every open socket the game messages sent since the last flush."""
        sent = self.layer.sent[self._heard :]
        self._heard = len(self.layer.sent)
        if not self.game_id:
            return
        for name in self.listening:
            groups = self._groups(name, "game")
            for group, message in sent:
                if group in groups:
                    event = client_event(GameConsumer, message, user_id=self.pid(name))
                    self.stream[name].append({"event": event})

    def request(  # type: ignore[override]
        self,
        method: str,
        who: str,
        path: str,
        body: dict[str, Any] | None = None,
        **kwargs: Any,
    ) -> tuple[int, Any]:
        sent = self._staged(path, body, self.game_id, who) if self.game_id else body
        mine = bool(self.game_id) and who in self.listening
        if mine:
            # The tap leaves: what it causes is heard between this and its answer.
            self.stream[who].append(
                {"request": {"method": method, "path": path, "sent": sent}}
            )
        status, payload = super().request(method, who, path, body, **kwargs)
        self._flush()
        if mine:
            self.stream[who].append(
                {
                    "answer": {
                        "method": method,
                        "path": path,
                        "status": status,
                        "body": payload,
                    }
                }
            )
        return status, payload

    def connect(self, name: str) -> None:
        super().connect(name)
        self.listening.add(name)
        self._flush()

    def fire(self, key: str) -> None:
        super().fire(key)
        self._flush()

    def last_view(self, name: str) -> dict[str, Any]:
        """The newest ``/me/`` this seat holds: its last own view or read."""
        for item in reversed(self.stream[name]):
            event = item.get("event")
            if event is not None and event["type"] == "me":
                return event["me"]
            answer = item.get("answer")
            if answer is not None and answer["path"] == ME:
                return answer["body"]
        raise AssertionError(f"{name} holds no /me/")


def stream_table(run: Recording) -> StreamTable:
    """The six-seat game, from the deal to play again, kept as ``ws_stream``."""
    t = StreamTable(
        run.recorder,
        run.clock,
        run.layer,
        run.capture_on_commit,
        run.game_ids,
        next(run.codes),
    )
    t.start_stream()
    for name in SIX:
        t.guest(name)
    created = t.call("POST", "Ana", CREATE, {"game_type": "onuw", "defaults": "v2"})
    t.code = created["code"]
    for name in SIX[1:]:
        t.clock.advance(20)
        t.call("POST", name, JOIN)
    deck: dict[str, int] = {}
    for role in [*DEALT.values(), *CENTRE]:
        deck[role] = deck.get(role, 0) + 1
    t.call("PATCH", "Ana", LOBBY, {"settings": {"deck": "custom", "roles": deck}})
    t.clock.advance(30)
    t.start(DEALT, CENTRE)

    # Every phone opens its game: the socket, then its one read of /me/.
    for name in SIX:
        t.connect(name)
        t.call("GET", name, ME)
    # The look: everyone has looked; the last one opens the night.
    for name in SIX:
        t.clock.advance(4)
        t.call("POST", name, READY, {"ready": True})
    _record_view(t, "night", "window 2 opened: her prompt, her card")
    # Window 2: the phones with a choice choose; the window closes at its minimum.
    t.clock.advance(5)
    picks = {
        "Ana": [{"player_id": t.pid("Ben")}],
        "Ben": [{"player_id": t.pid("Cleo")}],
        "Cleo": [{"player_id": t.pid("Dev")}, {"player_id": t.pid("Esme")}],
    }
    for name, chosen in picks.items():
        t.call("POST", name, ACTION, {"action_type": "choose", "picks": chosen})
    t.clock.advance(5)
    t.fire("{game_id}:wave:2")
    _record_view(t, "talk", "the talk opened: what her night told her")
    # The talk: each holds My night (the ack of what it lists), then is ready.
    for name in SIX:
        seen = len(t.last_view(name)["night_results"])
        t.call("POST", name, SEEN, {"seen": seen})
    for name in SIX:
        t.clock.advance(10)
        t.call("POST", name, READY, {"ready": True})
    _record_view(t, "vote", "the vote opened: who she may vote for")
    # The vote: each picks the next seat, then locks it; the last lock reveals.
    for index, name in enumerate(SIX):
        target = t.pid(SIX[(index + 1) % len(SIX)])
        t.clock.advance(3)
        t.call("POST", name, VOTE, {"target_player_id": target, "lock": False})
    for index, name in enumerate(SIX):
        target = t.pid(SIX[(index + 1) % len(SIX)])
        t.clock.advance(3)
        t.call("POST", name, VOTE, {"target_player_id": target, "lock": True})
    _record_view(t, "results", "the game ended: her final card, and the results")
    # The host plays again: the table is waiting, every game socket is told.
    t.clock.advance(20)
    t.record(
        "lobby/play_again_app_table",
        "POST",
        "Ana",
        PLAY_AGAIN,
        status=200,
        about="Play again at a table opened the way the app opens it (its "
        "settings carry the starting set): the lobby, waiting.",
    )

    t.recorder.add(
        "ws_stream/six_seats",
        {
            "kind": "ws_stream",
            "socket": "game",
            "description": (
                "A whole game at six seats as each phone saw it: every event its "
                "game socket received and the answer to each of its own requests, "
                "in order (a request's events before its answer)."
            ),
        },
        t.stream,
    )
    # The stream is closed: a read now is no phone's. Every seat's /me/ at the
    # results (each card's own night data), so each view the stream holds is one
    # the samples know.
    t.listening.clear()
    for name, role in DEALT.items():
        t.record(
            f"game/me_results_six_{name.lower()}",
            "GET",
            name,
            ME,
            status=200,
            about=f"The {role}'s /me/ at the results of the six-seat game: the "
            "final card and the night's own data.",
        )
    return t


def _record_view(t: StreamTable, stage: str, what: str) -> None:
    """Ana's own view as a stage opened, as her socket got it (``ws/game/me_*``)."""
    t.record_event(
        f"game/me_{stage}",
        "Ana",
        "game",
        "own_view",
        about=f"Her own view, on her own group only, sent before the table's "
        f"event: {what}. The body is her GET /me/.",
    )
