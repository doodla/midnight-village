"""The only words a kept summary may hold: a closed list for every part of a label.

A label is built by the phone from the app's own names (``field_summary.dart``):

* a kind of tap: ``<screen> <tap|hold> <control>[ <METHOD> <path>]``
  (``talk tap main_button POST /api/onuw/games/·/ready/``);
* a screen change: ``<screen> > <screen> (<cause>)``, the cause ``tap``, ``none`` or
  ``socket <event>`` (``talk > vote (socket phase_change)``);
* a screen (frames): ``<screen>``;
* a request or a cold start: ``<METHOD> <path>``.

Each part must be one of the words below, and a path must be one of this server's own
routes with every id or code as ``·``: a word the server has no route for (a join code,
a name, anything made up) makes the label fail, and its entry is dropped. So nothing a
person typed or was dealt can be kept, whatever a phone sends.

The lists are the app's (``frontend``'s tests check each against these, so a new screen,
control or socket event is added on both sides at once): ``SCREENS`` are ``AppScreen``'s
names and ``HomeGate``'s own places, ``CONTROLS`` ``control_kind.dart``'s kinds,
``SOCKET_EVENTS`` every event type the server sends (``tests/observe`` checks the
recorded socket samples against it).
"""

from __future__ import annotations

import functools
import re

from django.urls import Resolver404, get_resolver, resolve
from django.urls.resolvers import URLPattern, URLResolver

SCREENS = frozenset(
    {
        # AppScreen (frontend/lib/features/game/domain/screen_table.dart)
        "join",
        "table",
        "deck",
        "yourCard",
        "nightBoard",
        "talk",
        "vote",
        "end",
        # HomeGate's own places, and the recorder's first
        "opening",
        "elsewhere",
    }
)
CONTROLS = frozenset(
    {
        "perf",
        "main_button",
        "second_button",
        "text_action",
        "icon_action",
        "scrap",
        "preset",
        "player_row",
        "vote_slip",
        "card",
        "role_card",
        "deck_pile",
        "stepper",
        "hold",
        "text_field",
        "other",
    }
)
SOCKET_EVENTS = frozenset(
    {
        "error",
        "game_results",
        "game_started",
        "host_changed",
        "lobby_update",
        "night_window",
        "phase_change",
        "play_again",
        "player_joined",
        "player_left",
        "player_presence",
        "progress",
        "vote_reveal",
        # a player's own view as a stage opens, and the heartbeat's frame
        # (which the phone swallows: it never names it, but the server sends it)
        "me",
        "beat",
        # the recorder's word for a message with no type it knows
        "message",
    }
)
METHODS = frozenset({"GET", "POST", "PUT", "PATCH", "DELETE"})
HIDDEN = "·"

_TAP = re.compile(
    r"^(?P<screen>\w+) (?:tap|hold) (?P<control>\w+)"
    r"(?: (?P<method>[A-Z]+) (?P<path>/\S+))?$"
)
_CHANGE = re.compile(r"^(?P<from>\w+) > (?P<to>\w+) \((?P<cause>[a-z_ ]+)\)$")
_REQUEST = re.compile(r"^(?P<method>[A-Z]+) (?P<path>/\S+)$")


@functools.cache
def route_words() -> frozenset[str]:
    """Every fixed word of this server's routes under ``api/`` (not the admin's)."""
    words: set[str] = set()

    def walk(patterns: list, prefix: str) -> None:
        for entry in patterns:
            route = prefix + str(entry.pattern)
            if isinstance(entry, URLResolver):
                walk(entry.url_patterns, route)
            elif isinstance(entry, URLPattern) and route.startswith("api/"):
                words.update(
                    part for part in route.split("/") if part and "<" not in part
                )

    walk(get_resolver().url_patterns, "")
    return frozenset(words)


def _route(path: str) -> bool:
    """``path`` is one of this server's routes with its ids and codes as ``·``."""
    parts = path.split("/")
    if len(path) > 120 or parts[0] or parts[-1] or not path.startswith("/api/"):
        return False
    words = route_words()
    if any(part not in words and part != HIDDEN for part in parts[1:-1]):
        return False
    # What a hidden part stood for: a word, a number or a uuid (whatever the route's
    # converter takes).
    for stand_in in ("x", "1", "8f14e45f-ceea-467a-9b36-5b2ba8d5b3a1"):
        try:
            resolve(path.replace(HIDDEN, stand_in))
        except Resolver404:
            continue
        return True
    return False


def _request(method: str | None, path: str | None) -> bool:
    return method in METHODS and path is not None and _route(path)


def tap_kind(label: str) -> bool:
    m = _TAP.match(label)
    if not m or m["screen"] not in SCREENS or m["control"] not in CONTROLS:
        return False
    return m["method"] is None or _request(m["method"], m["path"])


def screen_change(label: str) -> bool:
    m = _CHANGE.match(label)
    if not m or m["from"] not in SCREENS or m["to"] not in SCREENS:
        return False
    cause = m["cause"]
    if cause in ("tap", "none"):
        return True
    kind, _, event = cause.partition(" ")
    return kind == "socket" and event in SOCKET_EVENTS


def screen(label: str) -> bool:
    return label in SCREENS


def request(label: str) -> bool:
    m = _REQUEST.match(label)
    return bool(m) and _request(m["method"], m["path"])
