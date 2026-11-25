"""``just server-timing``: print what each request costs the server, at 3, 6 and 10
seats (the table ``tap_costs.play`` measures). Skipped unless ``SERVER_TIMING`` is
set, so the suite never prints it; the guard on the counts is
``test_tap_query_budget.py``.

``SERVER_TIMING=sql`` also prints every query of the costliest request of each kind
at ten seats.
"""

from __future__ import annotations

import os
import sys
from typing import Any

import pytest

from tests.contract.recorder import recording

from .tap_costs import SIZES, Cost, play, worst

pytestmark = [pytest.mark.django_db, pytest.mark.uses_timers]

WANTED = os.environ.get("SERVER_TIMING", "")


def _say(line: str = "") -> None:
    sys.stdout.write(line + "\n")


def _row(label: str, by_size: dict[int, Cost | None]) -> str:
    def cell(cost: Cost | None, value: str) -> str:
        return "-" if cost is None else str(getattr(cost, value))

    big = by_size[SIZES[-1]] or next(c for c in by_size.values() if c is not None)
    counts = " ".join(f"{cell(by_size[n], 'queries'):>3}" for n in SIZES)
    sends = " ".join(f"{cell(by_size[n], 'sends'):>2}" for n in SIZES)
    return (
        f"{label[:66]:<66} {counts} {big.locks:>3} {big.lock_span:>4} "
        f"{big.writes:>3}  {sends} {big.redis_trips:>3} {big.publishes:>3} "
        f"{big.ms:>7.1f} {big.sql_ms:>6.1f}"
    )


HEAD = "queries 3/6/10  lk span  wr  sends 3/6/10 rds pub  ms@10 sql ms"


@pytest.mark.skipif(not WANTED, reason="set SERVER_TIMING=1 (just server-timing)")
def test_print_what_each_request_costs(django_capture_on_commit_callbacks: Any) -> None:
    by_size: dict[int, dict[str, Cost]] = {}
    with recording(django_capture_on_commit_callbacks) as run:
        for players in SIZES:
            by_size[players] = worst(play(run, players))
    labels = list(by_size[SIZES[-1]])
    _say()
    _say(f"{'request [stage]':<66} {HEAD}")
    for label in labels:
        _say(_row(label, {n: by_size[n].get(label) for n in SIZES}))
    _say(
        "\ncolumns: database round trips at 3 / 6 / 10 seats (the costliest request "
        "of that kind in the game); at 10 seats: row locks taken, round trips the "
        "first lock is held for, writes; socket messages handed to the channel "
        "layer at 3 / 6 / 10 seats (on the live server each is 4 Redis round trips "
        "before the answer leaves); timer messages published (a Vercel Queue send "
        "each, also before the answer); time here, against local Postgres, and its "
        "SQL part. Requests sign in with a real access token, as the app's do."
    )
    if WANTED == "sql":
        for label, cost in by_size[SIZES[-1]].items():
            _say(f"\n== {label}: {cost.queries} queries")
            for query in cost.sql:
                _say(f"   {query[:220]}")
