"""The phones' numbers over the last games, merged: what ``just field-report`` prints and
the owner's status page is built from (``GET /api/observe/report/``).

Every summary holds, per kind of tap and per leg, up to 24 of that game's values spread
over its range (``field_summary.dart``); merging them across games gives the median
and the 90th percentile of each leg without keeping every tap.
"""

from __future__ import annotations

import math
from collections import defaultdict
from collections.abc import Iterable
from typing import Any

from apps.core.wire import wire_time

from .summary import CHANGE_LEGS, REQUEST_LEGS, TAP_LEGS

MOST_ROWS = 30
MOST_LATEST_COLD = 10


def percentile(values: list[float], p: float) -> float | None:
    """The nearest-rank ``p``th percentile (None for none)."""
    if not values:
        return None
    ordered = sorted(values)
    return ordered[max(0, math.ceil(p / 100 * len(ordered)) - 1)]


def spread(values: list[float]) -> dict[str, Any] | None:
    if not values:
        return None
    return {
        "p50": percentile(values, 50),
        "p90": percentile(values, 90),
        "worst": max(values),
        "values": len(values),
    }


def _legs(merged: dict[str, list[float]], names: Iterable[str]) -> dict[str, Any]:
    return {name: s for name in names if (s := spread(merged.get(name, [])))}


def build(rows: Iterable[Any]) -> dict[str, Any]:
    """``rows``: ``FieldSummary`` rows, newest first."""
    rows = list(rows)
    commits: dict[str, int] = defaultdict(int)
    devices: dict[str, int] = defaultdict(int)
    taps: dict[tuple[str, str], dict[str, Any]] = {}
    frames: dict[str, dict[str, float]] = {}
    changes: dict[str, dict[str, Any]] = {}
    requests: dict[str, dict[str, Any]] = {}
    cold_counts = {"boot": 0, "db_wake": 0, "games_with_any": 0}
    cold_latest: list[dict[str, Any]] = []

    def merge(
        into: dict[str, Any], entry: dict[str, Any], names: Iterable[str]
    ) -> None:
        into["n"] = into.get("n", 0) + entry.get("n", 0)
        for name in names:
            into.setdefault(name, []).extend(entry.get(name, []))

    for row in rows:
        body = row.body
        commits[row.commit[:7] or "?"] += 1
        devices[row.device or "?"] += 1
        for kind, entry in body.get("taps", {}).items():
            merge(taps.setdefault((kind, row.device), {}), entry, TAP_LEGS)
        for screen, entry in body.get("frames", {}).items():
            into = frames.setdefault(
                screen, {"frames": 0, "over_50": 0, "over_100": 0, "worst": 0.0}
            )
            for name in ("frames", "over_50", "over_100"):
                into[name] += entry.get(name, 0)
            into["worst"] = max(into["worst"], entry.get("worst", 0.0))
        for change, entry in body.get("screens", {}).items():
            merge(changes.setdefault(change, {}), entry, CHANGE_LEGS)
        for path, entry in body.get("requests", {}).items():
            merge(requests.setdefault(path, {}), entry, REQUEST_LEGS)
        seen = body.get("cold", [])
        cold_counts["games_with_any"] += 1 if seen else 0
        for one in seen:
            cold_counts[one["kind"]] += 1
            if len(cold_latest) < MOST_LATEST_COLD:
                cold_latest.append(
                    {
                        "received_at": wire_time(row.received_at),
                        "device": row.device,
                        **one,
                    }
                )

    tap_rows = [
        {"kind": kind, "device": dev, "taps": e["n"], "legs": _legs(e, TAP_LEGS)}
        for (kind, dev), e in taps.items()
    ]
    tap_rows.sort(key=lambda r: (-r["taps"], r["kind"], r["device"]))
    screen_rows = [
        {
            "screen": screen,
            **f,
            "share_over_50": round(f["over_50"] / f["frames"], 3) if f["frames"] else 0,
        }
        for screen, f in frames.items()
    ]
    screen_rows.sort(key=lambda r: (-r["over_100"], -r["over_50"], r["screen"]))
    change_rows = [
        {"change": change, "n": e["n"], **_legs(e, CHANGE_LEGS)}
        for change, e in changes.items()
    ]
    change_rows.sort(key=lambda r: -((r.get("content") or {}).get("p90") or 0))
    request_rows = [
        {"path": path, "n": e["n"], **_legs(e, REQUEST_LEGS)}
        for path, e in requests.items()
    ]
    request_rows.sort(key=lambda r: (-r["n"], r["path"]))
    return {
        "games": len(rows),
        "first": wire_time(rows[-1].received_at) if rows else None,
        "last": wire_time(rows[0].received_at) if rows else None,
        "commits": dict(sorted(commits.items(), key=lambda kv: -kv[1])),
        "devices": dict(sorted(devices.items(), key=lambda kv: -kv[1])),
        "taps": tap_rows[:MOST_ROWS],
        "screens": screen_rows[:MOST_ROWS],
        "changes": change_rows[:MOST_ROWS],
        "requests": request_rows[:MOST_ROWS],
        "cold": {**cold_counts, "latest": cold_latest},
    }
