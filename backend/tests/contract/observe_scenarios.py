"""A phone's speed summary kept, one refused, and the report that reads them back
(``apps.observe``). Recorded after every table (``test_contract_samples.py`` calls it
last), so no earlier sample moves; no player signs in: a beacon carries no account."""

from __future__ import annotations

from ..observe.summaries import summary
from .recorder import Recording, Table

SUMMARY = "/observe/summary/"
REPORT = "/observe/report/?games=5"


def observe_samples(run: Recording) -> None:
    # No lobby: nobody sits anywhere (``run.table()`` would take a lobby code).
    t = Table(
        run.recorder, run.clock, run.layer, run.capture_on_commit, run.game_ids, ""
    )
    t.record(
        "observe/summary_kept",
        "POST",
        "",
        SUMMARY,
        summary(),
        status=204,
        about="A phone's summary of one game, sent as it ends (no account): kept, "
        "nothing answered.",
    )
    t.record(
        "observe/summary_refused",
        "POST",
        "",
        SUMMARY,
        {"v": 1},
        status=400,
        about="Something that is not a summary: nothing kept.",
    )
    t.record(
        "observe/report",
        "GET",
        "",
        REPORT,
        status=200,
        about="The last games' numbers merged: per kind of tap and device, each "
        "leg's median and 90th percentile; slowest screens; cold starts.",
    )
