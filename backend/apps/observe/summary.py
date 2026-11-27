"""A phone's speed summary, cut to what may be kept.

The app sends one (``frontend/lib/core/perf/field_summary.dart``) at the end of a game
or when its tab is hidden. It already holds only times, counts, kinds of screen and
control, request paths without ids and what the phone says about itself; this module
checks that again and keeps nothing else, so a mistake on the phone, or a caller
making things up, cannot put a name, a role, a code or an id in the table:

* only the keys named here, at the depth named here; anything else is dropped;
* every label (a kind of tap, a screen, a path) is short and made of the few
  characters the app's own labels use, else that entry is dropped;
* every number is finite, 0 or more and at most an hour, else it is dropped;
* lists and maps are capped, so a summary stays a few KB.

``clean`` returns None when what came is not a summary at all.
"""

from __future__ import annotations

import math
import re
from typing import Any

VERSION = 1
MOST_ENTRIES = 24
MOST_VALUES = 24
MOST_COLD = 10
MOST_MS = 3_600_000.0

# A tap kind is "talk tap main_button POST /api/onuw/games/·/ready/"; a screen
# change "talk > vote (socket phase_change)".
_LABEL = re.compile(r"^[A-Za-z0-9_ ./·>()\-]{1,120}$")
_WORD = re.compile(r"^[a-z_]{1,24}$")
_COMMIT = re.compile(r"^[0-9a-f]{7,40}$")
_SIZE = re.compile(r"^\d{1,5}x\d{1,5}$")
_PRINTABLE = re.compile(r"^[ -~]{1,240}$")

TAP_LEGS = ("heard", "screen", "left", "answer", "applied", "shown", "total")
CHANGE_LEGS = ("first", "content")
REQUEST_LEGS = ("round", "server", "connect", "outside")
ENDS = ("end_board", "hidden")
COLD_KINDS = ("boot", "db_wake")
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
    kept = [n for n in (_number(v) for v in value[:MOST_VALUES]) if n is not None]
    return kept


def _text(value: Any, pattern: re.Pattern[str], most: int) -> str | None:
    if not isinstance(value, str):
        return None
    value = value[:most]
    return value if pattern.match(value) else None


def _map(raw: Any, entry: Any) -> dict[str, Any]:
    """A map of label to ``entry(value)``, labels checked, at most MOST_ENTRIES."""
    if not isinstance(raw, dict):
        return {}
    out: dict[str, Any] = {}
    for label, value in list(raw.items())[:MOST_ENTRIES]:
        if not isinstance(label, str) or not _LABEL.match(label):
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
        path = _text(value.get("path"), _LABEL, 120)
        if path is None:
            continue
        kept: dict[str, Any] = {"kind": value["kind"], "path": path}
        for name in ("round", "server", "connect", "outside", "gap_s"):
            number = _number(value.get(name))
            if number is not None:
                kept[name] = number
        out.append(kept)
    return out


def _env(raw: Any) -> dict[str, Any]:
    if not isinstance(raw, dict):
        return {}
    env: dict[str, Any] = {}
    for name in ENV_NUMBERS:
        number = _number(raw.get(name))
        if number is not None:
            env[name] = number
    for name, pattern, most in (
        ("agent", _PRINTABLE, 240),
        ("gpu", _PRINTABLE, 120),
        ("screen", _SIZE, 11),
        ("window", _SIZE, 11),
        ("renderer", _WORD, 24),
    ):
        text = _text(raw.get(name), pattern, most)
        if text is not None:
            env[name] = text
    return env


def clean(raw: Any) -> dict[str, Any] | None:
    """What may be kept of ``raw``, or None when it is not a summary."""
    if not isinstance(raw, dict) or raw.get("v") != VERSION:
        return None
    socket = raw.get("socket") if isinstance(raw.get("socket"), dict) else {}
    summary = {
        "v": VERSION,
        "commit": _text(raw.get("commit"), _COMMIT, 40) or "",
        "end": raw.get("end") if raw.get("end") in ENDS else "hidden",
        "env": _env(raw.get("env")),
        "taps": _map(raw.get("taps"), _legs(TAP_LEGS)),
        "frames": _map(raw.get("frames"), _frames),
        "screens": _map(raw.get("screens"), _legs(CHANGE_LEGS)),
        "requests": _map(raw.get("requests"), _legs(REQUEST_LEGS)),
        "cold": _cold(raw.get("cold")),
        "socket": {
            name: _count(socket.get(name)) or 0
            for name in ("events", "opened", "dropped")
        },
    }
    if not summary["taps"] and not summary["requests"]:
        return None
    return summary


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
