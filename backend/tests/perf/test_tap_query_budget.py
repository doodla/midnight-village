"""A tap costs the server the same at three seats as at ten, and no more than it did.

Every database query is a round trip to the database before the answer leaves, and
on the live server so is every socket message (Redis) and timer message (the queue).
So the cost of a tap is counted, not timed: ``tap_costs.play`` plays one whole game
the way the app does (seeded deal, frozen clock) at 3, 6 and 10 seats and measures
every request, timer and socket opening. Two rules:

1. **Nothing grows with the table.** A kind of request (its method, path and stage,
   and whether it closed the stage) makes the same number of round trips, holds its
   row lock as long, and sends as many messages at ten seats as at three. One query
   per player (an account read per member, say) fails here, whatever the budget.
2. **Nothing grows quietly.** At ten seats each kind of request costs exactly what
   ``tap_budget.json`` says, and none more than ``CEILING`` round trips. A change
   that adds a query fails with what grew; a change that removes one fails too, so
   the gain is written down and cannot be lost again unseen. Re-record with
   ``just tap-budget`` and review the diff, as with the contract samples.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any

import pytest

from tests.contract.recorder import recording

from .tap_costs import SIZES, Cost, play, worst

pytestmark = [pytest.mark.django_db, pytest.mark.uses_timers]

BUDGET_FILE = Path(__file__).with_name("tap_budget.json")
# No request, timer or socket opening makes more database round trips than this at
# a full table (the costliest today, a game socket opening and the night's close,
# are in the high thirties). Raising it is a decision, not a re-record.
CEILING = 40
MEASURES = ("queries", "lock_span", "sends", "publishes")
RERECORD = "Re-record with `just tap-budget` and review the diff of tap_budget.json."


def _played(capture: Any) -> dict[int, dict[str, Cost]]:
    with recording(capture) as run:
        return {players: worst(play(run, players)) for players in SIZES}


def _measures(cost: Cost) -> dict[str, int]:
    return {name: getattr(cost, name) for name in MEASURES}


def test_no_request_costs_more_at_ten_seats_than_at_three(
    django_capture_on_commit_callbacks: Any,
) -> None:
    by_size = _played(django_capture_on_commit_callbacks)
    grows = []
    for label in by_size[SIZES[-1]]:
        seen = {n: by_size[n][label] for n in SIZES if label in by_size[n]}
        assert len(seen) == len(SIZES), f"{label} is not made at every table size"
        for name in MEASURES:
            values = {n: getattr(cost, name) for n, cost in seen.items()}
            if len(set(values.values())) > 1:
                grows.append(f"{label}: {name} by seats {values}")
    assert not grows, (
        "A request costs more round trips at a bigger table (a query per player?):\n"
        + "\n".join(grows)
    )


def test_every_request_costs_what_its_budget_says(
    django_capture_on_commit_callbacks: Any,
) -> None:
    at_ten = _played(django_capture_on_commit_callbacks)[SIZES[-1]]
    measured = {label: _measures(at_ten[label]) for label in sorted(at_ten)}
    over = [
        f"{label}: {m['queries']} round trips"
        for label, m in measured.items()
        if m["queries"] > CEILING
    ]
    assert not over, f"Over the ceiling of {CEILING} round trips:\n" + "\n".join(over)

    if os.environ.get("UPDATE_TAP_BUDGET"):
        BUDGET_FILE.write_text(
            json.dumps(
                {
                    "about": (
                        "What each request, timer and socket opening costs the "
                        f"server at {SIZES[-1]} seats (tests/perf/"
                        "test_tap_query_budget.py). Do not edit: run `just "
                        "tap-budget` and review the diff."
                    ),
                    "requests": measured,
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )
        return

    budget = json.loads(BUDGET_FILE.read_text(encoding="utf-8"))["requests"]
    problems = []
    for label in sorted(budget.keys() | measured.keys()):
        if label not in measured:
            problems.append(f"{label}: no longer made")
        elif label not in budget:
            problems.append(f"{label}: new, {measured[label]}")
        else:
            for name in MEASURES:
                had, has = budget[label][name], measured[label][name]
                if has != had:
                    word = "GREW" if has > had else "shrank (write the gain down)"
                    problems.append(f"{label}: {name} {word}: {had} -> {has}")
    assert not problems, (
        "What a request costs the server changed:\n"
        + "\n".join(problems)
        + f"\n{RERECORD}"
    )
