"""A phone's speed summary, cut to what may be kept.

The app sends one (``frontend/lib/core/perf/field_summary.dart``) at the end of a game,
and one of the play before its tab was hidden. This keeps only:

* the keys named here, at the depth named here; anything else is dropped;
* labels made only of the closed lists' words (``vocabulary.py``): a label with any
  other word (a join code, a name, an id, anything made up) is dropped with its entry;
* numbers that are finite, 0 or more and at most an hour;
* at most ``MOST_ENTRIES`` labels per part and ``MOST_VALUES`` values per leg;
* of what the phone says about itself, the kind of phone and browser (``device``,
  derived from the browser's name for itself, which is then dropped) and a few coarse
  numbers. No graphics chip, no screen size, no full browser name: nothing that could
  tell one phone from the next.

``clean`` returns ``(summary, device)``, or None when what came is not a summary.
"""

from __future__ import annotations

import math
import re
from collections.abc import Callable
from typing import Any

from . import vocabulary

VERSION = 1
MOST_ENTRIES = 16
MOST_VALUES = 16
MOST_COLD = 8
MOST_MS = 3_600_000.0

_COMMIT = re.compile(r"^[0-9a-f]{7,40}$")

TAP_LEGS = ("heard", "screen", "left", "answer", "applied", "shown", "total")
CHANGE_LEGS = ("first", "content")
REQUEST_LEGS = ("round", "server", "connect", "outside")
ENDS = ("end_board", "hidden")
COLD_KINDS = ("boot", "db_wake")
RENDERERS = ("canvaskit", "skwasm")
ENV_NUMBERS = (
    "pixel_ratio",
    "cores",
    "memory_gb",
    "first_frame_ms",
    "main_bundle_ms",
    "engine_ms",
)


def _number(value: Any) -> float | None:
    if isinstance(value, bool) or not isinstance(value, int | float):
        return None
    if not math.isfinite(value) or value < 0 or value > MOST_MS:
        return None
    return round(float(value), 3)


def _count(value: Any) -> int | None:
    number = _number(value)
    return None if number is None else int(number)


def _values(value: Any) -> list[float]:
    if not isinstance(value, list):
        return []
    return [n for n in (_number(v) for v in value[:MOST_VALUES]) if n is not None]


def _map(raw: Any, allowed: Callable[[str], bool], entry: Any) -> dict[str, Any]:
    """A map of label to ``entry(value)``, each label in the closed vocabulary."""
    if not isinstance(raw, dict):
        return {}
    out: dict[str, Any] = {}
    for label, value in list(raw.items())[:MOST_ENTRIES]:
        if not isinstance(label, str) or not allowed(label):
            continue
        kept = entry(value)
        if kept:
            out[label] = kept
    return out


def _legs(names: tuple[str, ...]) -> Any:
    def entry(value: Any) -> dict[str, Any] | None:
        if not isinstance(value, dict):
            return None
        n = _count(value.get("n"))
        if not n:
            return None
        kept: dict[str, Any] = {"n": n}
        for name in names:
            values = _values(value.get(name))
            if values:
                kept[name] = values
        return kept

    return entry


def _frames(value: Any) -> dict[str, Any] | None:
    if not isinstance(value, dict):
        return None
    frames = _count(value.get("frames"))
    if not frames:
        return None
    kept: dict[str, Any] = {"frames": frames}
    for name in ("over_50", "over_100"):
        kept[name] = _count(value.get(name)) or 0
    for name in ("worst", "median"):
        number = _number(value.get(name))
        if number is not None:
            kept[name] = number
    return kept


def _cold(raw: Any) -> list[dict[str, Any]]:
    if not isinstance(raw, list):
        return []
    out = []
    for value in raw[:MOST_COLD]:
        if not isinstance(value, dict) or value.get("kind") not in COLD_KINDS:
            continue
        path = value.get("path")
        if not isinstance(path, str) or not vocabulary.request(path):
            continue
        kept: dict[str, Any] = {"kind": value["kind"], "path": path}
        for name in ("round", "server", "connect", "outside", "gap_s"):
            number = _number(value.get(name))
            if number is not None:
                kept[name] = number
        out.append(kept)
    return out


def _env(raw: dict[str, Any]) -> dict[str, Any]:
    env: dict[str, Any] = {}
    for name in ENV_NUMBERS:
        number = _number(raw.get(name))
        if number is not None:
            env[name] = number
    if raw.get("renderer") in RENDERERS:
        env["renderer"] = raw["renderer"]
    return env


def clean(raw: Any) -> tuple[dict[str, Any], str] | None:
    """What may be kept of ``raw`` and the kind of phone, or None."""
    if not isinstance(raw, dict) or raw.get("v") != VERSION:
        return None
    env = raw.get("env") if isinstance(raw.get("env"), dict) else {}
    socket = raw.get("socket") if isinstance(raw.get("socket"), dict) else {}
    commit = raw.get("commit")
    summary = {
        "v": VERSION,
        "commit": commit
        if isinstance(commit, str) and _COMMIT.match(commit[:40])
        else "",
        "end": raw.get("end") if raw.get("end") in ENDS else "hidden",
        "env": _env(env),
        "taps": _map(raw.get("taps"), vocabulary.tap_kind, _legs(TAP_LEGS)),
        "frames": _map(raw.get("frames"), vocabulary.screen, _frames),
        "screens": _map(
            raw.get("screens"), vocabulary.screen_change, _legs(CHANGE_LEGS)
        ),
        "requests": _map(raw.get("requests"), vocabulary.request, _legs(REQUEST_LEGS)),
        "cold": _cold(raw.get("cold")),
        "socket": {
            name: _count(socket.get(name)) or 0
            for name in ("events", "opened", "dropped")
        },
    }
    if not summary["taps"] and not summary["requests"]:
        return None
    agent = env.get("agent")
    return summary, device(agent if isinstance(agent, str) else "")


def device(agent: str) -> str:
    """The kind of phone and browser, from the browser's own name for itself."""
    a = agent.lower()
    system = next(
        (
            name
            for key, name in (
                ("android", "android"),
                ("iphone", "iphone"),
                ("ipad", "ipad"),
                ("windows", "windows"),
                ("mac os", "mac"),
                ("cros", "chromebook"),
                ("linux", "linux"),
            )
            if key in a
        ),
        "other",
    )
    browser = next(
        (
            name
            for key, name in (
                ("samsungbrowser", "samsung"),
                ("edg/", "edge"),
                ("firefox", "firefox"),
                ("fxios", "firefox"),
                ("crios", "chrome"),
                ("chrome", "chrome"),
                ("safari", "safari"),
            )
            if key in a
        ),
        "other",
    )
    return f"{system} {browser}"
