"""How long the live server takes, per kind of request: the latency leg of the
check after each merge (tool/deployed_check.py records into it while the socket
leg plays).

It REPORTS, it never fails the check: the runner's network is noisy, and there
is no budget until there is a week of numbers to set one from. Two merges are
compared by reading two runs' tables (the job summary) or their JSON (the run's
artifact).

Per kind of request it keeps: the time on the caller's clock (the first one
apart, since it may meet a cold server; then the median and the worst), and
what the server says of itself in its `Server-Timing` header
(backend/apps/core/server_timing.py): `connect`, the time it took to get its
database connection when it made one, and `total`, its own time rounded to
50 ms. And how long after a request was SENT the other guests' sockets had its
event.

The requests go over a connection that is kept open, as a phone's do: a new
TLS handshake on every request would be most of each number.

Only the standard library.
"""

import http.client
import json
import os
import re
import statistics
import time
import urllib.parse

PART = re.compile(r"([A-Za-z_]+)\s*;\s*dur=([0-9.]+)")


def parts(header: str | None) -> dict[str, float]:
    """`connect;dur=26.2, total;dur=50` as {"connect": 26.2, "total": 50.0}."""
    return {name: float(ms) for name, ms in PART.findall(header or "")}


class KeptOpen:
    """Requests over connections that stay open, one per caller (`who`)."""

    def __init__(self, api: str, timeout: float = 30.0):
        split = urllib.parse.urlsplit(api)
        self._secure = split.scheme == "https"
        self._host = split.netloc
        self._timeout = timeout
        self._open: dict[str, http.client.HTTPConnection] = {}

    def _connection(self, who: str) -> tuple[http.client.HTTPConnection, bool]:
        if who in self._open:
            return self._open[who], False
        kind = (
            http.client.HTTPSConnection if self._secure else http.client.HTTPConnection
        )
        self._open[who] = kind(self._host, timeout=self._timeout)
        return self._open[who], True

    def request(self, who, method, path, body=None, headers=None):
        """(status, headers, bytes, seconds, whether a connection was opened for it).
        A connection the server closed meanwhile is opened again, once."""
        data = json.dumps(body).encode() if body is not None else None
        for attempt in (1, 2):
            connection, new = self._connection(who)
            began = time.perf_counter()
            try:
                connection.request(method, path, body=data, headers=headers or {})
                answer = connection.getresponse()
                raw = answer.read()
            except (http.client.HTTPException, OSError):
                self.close(who)
                if new or attempt == 2:
                    raise
                continue
            return (
                answer.status,
                answer.headers,
                raw,
                time.perf_counter() - began,
                new,
            )
        raise AssertionError("unreachable")

    def close(self, who: str | None = None) -> None:
        for name in [who] if who else list(self._open):
            connection = self._open.pop(name, None)
            if connection is not None:
                try:
                    connection.close()
                except OSError:
                    pass


def ms(seconds: float) -> int:
    return round(seconds * 1000)


class Timings:
    def __init__(self):
        self.requests: dict[str, list[dict]] = {}
        self.heard: dict[str, list[float]] = {}

    def add(self, kind: str, seconds: float, header: str | None, new: bool) -> None:
        said = parts(header)
        self.requests.setdefault(kind, []).append(
            {
                "ms": ms(seconds),
                "new_connection": new,
                "connect": said.get("connect"),
                "total": said.get("total"),
            }
        )

    def add_heard(self, event: str, seconds: float) -> None:
        self.heard.setdefault(event, []).append(seconds)

    def rows(self) -> list[dict]:
        """One row per kind, in the order first met."""
        out = []
        for kind, made in self.requests.items():
            # a request that also opened its connection paid a handshake: kept apart
            kept = [one["ms"] for one in made if not one["new_connection"]]
            opened = [one["ms"] for one in made if one["new_connection"]]
            connects = [one["connect"] for one in made if one["connect"] is not None]
            totals = [one["total"] for one in made if one["total"] is not None]
            out.append(
                {
                    "kind": kind,
                    "count": len(made),
                    "first_ms": made[0]["ms"],
                    "median_ms": round(statistics.median(kept)) if kept else None,
                    "worst_ms": max(kept) if kept else None,
                    "with_handshake_ms": max(opened) if opened else None,
                    "connects": len(connects),
                    "connect_median": round(statistics.median(connects), 1)
                    if connects
                    else None,
                    "connect_worst": max(connects) if connects else None,
                    "server_total_median": round(statistics.median(totals))
                    if totals
                    else None,
                    "server_total_worst": round(max(totals)) if totals else None,
                }
            )
        return out

    def as_json(self, **about) -> str:
        return json.dumps(
            {
                **about,
                "rows": self.rows(),
                "heard_ms": {
                    event: [ms(s) for s in waits] for event, waits in self.heard.items()
                },
                "requests": self.requests,
            },
            indent=1,
        )

    def table(self) -> str:
        """The rows as a Markdown table (the job summary), times in ms."""

        def cell(value):
            return "" if value is None else str(value)

        lines = [
            "| request | n | first | median | worst | with a handshake | server total (median / worst) | server connect (median / worst, of n) |",
            "|---|---|---|---|---|---|---|---|",
        ]
        for row in self.rows():
            total = (
                f"{row['server_total_median']} / {row['server_total_worst']}"
                if row["server_total_median"] is not None
                else "no header"
            )
            connect = (
                f"{row['connect_median']} / {row['connect_worst']} of {row['connects']}"
                if row["connects"]
                else "none made"
            )
            lines.append(
                f"| {row['kind']} | {row['count']} | {row['first_ms']} | {cell(row['median_ms'])} "
                f"| {cell(row['worst_ms'])} | {cell(row['with_handshake_ms'])} | {total} | {connect} |"
            )
        lines.append("")
        lines.append(
            "Milliseconds. first, median, worst: on the caller's clock over a connection kept open "
            "(median and worst leave out a request that opened its connection: that one is under "
            '"with a handshake"). server: its own `Server-Timing` header.'
        )
        if self.heard:
            lines.append("")
            lines.append(
                "| event on the other guests' sockets | ms after its request was sent |"
            )
            lines.append("|---|---|")
            for event, waits in self.heard.items():
                lines.append(
                    f"| {event} | {', '.join(str(ms(s)) for s in waits)} (at most: listening starts when the answer is back) |"
                )
        return "\n".join(lines)

    def report(self, to: str, **about) -> None:
        """The table on stdout and in the job's summary, the JSON in the file `to`."""
        table = self.table()
        print("\n" + table)
        with open(to, "w") as out:
            out.write(self.as_json(**about))
        summary = os.environ.get("GITHUB_STEP_SUMMARY")
        if summary:
            named = about.get("commit") or "no commit named"
            with open(summary, "a") as out:
                out.write(f"## How long the live server took ({named})\n\n{table}\n")
