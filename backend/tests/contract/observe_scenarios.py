"""A phone's speed summary kept, one refused, the owner's report that reads them back,
and the same report closed to anyone else (``apps.observe``). Recorded after every
table (``test_contract_samples.py`` calls it last), so no earlier sample moves; no
player signs in: a beacon carries no account."""

from __future__ import annotations

from unittest.mock import patch

from apps.observe.models import FieldSummary

from ..observe.summaries import summary
from .recorder import Recording, Table

SUMMARY = "/observe/summary/"
REPORT = "/observe/report/?last=5"


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
    # The row's hour is the database's; pinned to the recording's clock, as every
    # other time in the samples is.
    FieldSummary.objects.update(
        received_at=run.clock().replace(minute=0, second=0, microsecond=0)
    )
    t.record(
        "observe/report_closed",
        "GET",
        "",
        REPORT,
        status=404,
        about="The report asked for without the owner's key (or while none is set): "
        "as if there were no such page.",
    )
    # The owner's key itself is the test's business (tests/observe/test_views.py).
    with patch("apps.observe.views.owner_asks", return_value=True):
        t.record(
            "observe/report",
            "GET",
            "",
            REPORT,
            status=200,
            about="The owner's report of the last summaries merged: per kind of tap "
            "and device, each leg's median and 90th percentile; slowest screens; "
            "cold starts.",
        )
