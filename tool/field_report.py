#!/usr/bin/env python3
"""What real phones measured in real games: `just field-report`.

The live app's quiet recorder sends one summary per game (or when a tab is hidden)
to the server (`frontend/lib/core/perf/field_summary.dart`, kept by
`backend/apps/observe/`). This reads the server's merged report of the last games,
`GET /api/observe/report/?games=N` (no account: it holds only times and counts), and
prints it:

* per kind of tap and device, each leg's median and 90th percentile, in ms
  (screen: finger to the first frame; left: finger to the request leaving; answer:
  its round trip; applied: the answer in to the app having used it; shown: to the
  frame after; total: finger to the last of these);
* the screens with the most long frames;
* the slowest screen changes;
* each request's round trip, the server's own time and the time outside it;
* cold starts seen in play (`boot`: a request far slower outside the server than the
  game's others, an instance starting; `db_wake`: its database connection was,
  Neon waking), with how long the phone had asked nothing before.

usage: tool/field_report.py [--games N] [--api ORIGIN] [--json]

`--json` prints the report as the server sent it (what a status page is built from).
Only the standard library.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.request
from typing import Any

LIVE_API = "https://midnight-village-anthelion.vercel.app"
LEGS = ("screen", "left", "answer", "applied", "shown", "total")


def fetch(api: str, games: int) -> dict[str, Any]:
    url = f"{api.rstrip('/')}/api/observe/report/?games={games}"
    request = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=30) as answer:  # noqa: S310
        return json.load(answer)


def _ms(value: float | None) -> str:
    return "-" if value is None else f"{round(value)}"


def _spread(leg: dict[str, Any] | None) -> str:
    if not leg:
        return "-"
    return f"{_ms(leg.get('p50'))}/{_ms(leg.get('p90'))}"


def _counts(counts: dict[str, int]) -> str:
    return ", ".join(f"{name} x{n}" for name, n in counts.items()) or "-"


def text(report: dict[str, Any]) -> str:
    out: list[str] = []
    games = report.get("games", 0)
    if not games:
        return "Field report: no games yet (the live app sends one per game)."
    out.append(
        f"Field report: {games} games, {report['first'][:16]} to "
        f"{report['last'][:16]} (UTC)"
    )
    out.append(f"  builds: {_counts(report['commits'])}")
    out.append(f"  phones: {_counts(report['devices'])}")
    out.append("")
    out.append("Taps, ms median/90th: " + " ".join(LEGS))
    for tap in report["taps"]:
        legs = " ".join(_spread(tap["legs"].get(leg)) for leg in LEGS)
        out.append(f"  {tap['kind']} [{tap['device']}] x{tap['taps']}: {legs}")
    out.append("")
    out.append(
        "Screens, most long frames first: frames, over 50 ms, over 100 ms, worst"
    )
    for s in report["screens"][:10]:
        out.append(
            f"  {s['screen']}: {s['frames']}, {s['over_50']}, {s['over_100']}, "
            f"{_ms(s['worst'])} ms"
        )
    out.append("")
    out.append(
        "Screen changes, slowest first: ms median/90th to first frame, to content"
    )
    for c in report["changes"][:10]:
        out.append(
            f"  {c['change']} x{c['n']}: {_spread(c.get('first'))} "
            f"{_spread(c.get('content'))}"
        )
    out.append("")
    out.append(
        "Requests, ms median/90th: round trip, server's own (Server-Timing total), "
        "outside the server, database connect"
    )
    for r in report["requests"][:12]:
        out.append(
            f"  {r['path']} x{r['n']}: {_spread(r.get('round'))} "
            f"{_spread(r.get('server'))} {_spread(r.get('outside'))} "
            f"{_spread(r.get('connect'))}"
        )
    cold = report["cold"]
    out.append("")
    out.append(
        f"Cold starts seen: {cold['boot']} server starting, {cold['db_wake']} "
        f"database waking, in {cold['games_with_any']} of {games} games"
    )
    for one in cold["latest"]:
        gap = one.get("gap_s")
        quiet = (
            "" if gap is None else f", {round(gap)} s after the phone's last request"
        )
        out.append(
            f"  {one['received_at'][:16]} {one['device']} {one['kind']}: "
            f"{one['path']}, round trip {_ms(one.get('round'))} ms, server "
            f"{_ms(one.get('server'))} ms, connect {_ms(one.get('connect'))} ms{quiet}"
        )
    return "\n".join(out)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--games", type=int, default=30, help="the last N games (30)")
    parser.add_argument("--api", default=LIVE_API, help="the server's origin")
    parser.add_argument("--json", action="store_true", help="the report as JSON")
    args = parser.parse_args(argv)
    try:
        report = fetch(args.api, args.games)
    except OSError as error:
        print(f"field-report: could not read {args.api}: {error}", file=sys.stderr)
        return 2
    print(json.dumps(report, indent=2) if args.json else text(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
