#!/usr/bin/env python3
"""What real phones measured in real play: `just field-report`.

The live app's quiet recorder sends a summary at the end of each game, and one of the
play before its tab is hidden (`frontend/lib/core/perf/field_summary.dart`, kept by
`backend/apps/observe/`). This reads the server's merged report of the last summaries,
`GET /api/observe/report/?last=N`, which is the owner's only: it is sent the key in
this machine's `FIELD_REPORT_KEY` environment variable (the server must have the same
one; without one there, the report answers 404 to everyone). It prints:

* per kind of tap and device, each leg's median and 90th percentile, in ms
  (screen: finger to the first frame; left: finger to the request leaving; answer:
  its round trip; applied: the answer in to the app having used it; shown: to the
  frame after; total: finger to the last of these);
* the screens with the most long frames;
* the slowest screen changes;
* each request's round trip, the server's own time and the time outside it;
* cold starts seen in play (`boot`: a request far slower outside the server than the
  summary's others, an instance starting; `db_wake`: its database connection was,
  Neon waking), with how long the phone had asked nothing before.

usage: FIELD_REPORT_KEY=... tool/field_report.py [--last N] [--api ORIGIN] [--json]

`--json` prints the report as the server sent it.
Only the standard library.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from typing import Any

LIVE_API = "https://midnight-village-anthelion.vercel.app"
LEGS = ("screen", "left", "answer", "applied", "shown", "total")
KEY_HEADER = "X-Field-Report-Key"
CLOSED = (
    "field-report: the report is closed. Set FIELD_REPORT_KEY here to the key the "
    "server has (its own FIELD_REPORT_KEY environment variable); while the server has "
    "none, the report is closed to everyone and the summaries are still kept."
)


def fetch(api: str, last: int, key: str) -> dict[str, Any]:
    url = f"{api.rstrip('/')}/api/observe/report/?last={last}"
    request = urllib.request.Request(
        url, headers={"Accept": "application/json", KEY_HEADER: key}
    )
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
    rows = report.get("summaries", 0)
    if not rows:
        return "Field report: no summaries yet (the live app sends one per game)."
    out.append(
        f"Field report: {rows} summaries ({report['at_game_end']} at a game's end, the "
        f"rest the play before a tab was hidden), {report['first'][:13]}h to "
        f"{report['last'][:13]}h (UTC)"
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
        f"database waking, in {cold['summaries_with_any']} of {rows} summaries"
    )
    for one in cold["latest"]:
        gap = one.get("gap_s")
        quiet = (
            "" if gap is None else f", {round(gap)} s after the phone's last request"
        )
        out.append(
            f"  {one['received_at'][:13]}h {one['device']} {one['kind']}: "
            f"{one['path']}, round trip {_ms(one.get('round'))} ms, server "
            f"{_ms(one.get('server'))} ms, connect {_ms(one.get('connect'))} ms{quiet}"
        )
    return "\n".join(out)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--last", type=int, default=30, help="the last N summaries (30, at most 60)"
    )
    parser.add_argument("--api", default=LIVE_API, help="the server's origin")
    parser.add_argument("--json", action="store_true", help="the report as JSON")
    args = parser.parse_args(argv)
    key = os.environ.get("FIELD_REPORT_KEY", "")
    if not key:
        print(CLOSED, file=sys.stderr)
        return 2
    try:
        report = fetch(args.api, args.last, key)
    except urllib.error.HTTPError as error:
        print(
            CLOSED if error.code == 404 else f"field-report: answered {error.code}",
            file=sys.stderr,
        )
        return 2
    except OSError as error:
        print(f"field-report: could not read {args.api}: {error}", file=sys.stderr)
        return 2
    print(json.dumps(report, indent=2) if args.json else text(report))
    return 0


if __name__ == "__main__":
    sys.exit(main())
