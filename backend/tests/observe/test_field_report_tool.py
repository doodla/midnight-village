"""`just field-report` (`tool/field_report.py`) against this server: it sends the
owner's key from its own environment, prints every part of the report, and says the
report is closed when it has no key or the wrong one."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

from django.test import override_settings

import pytest

from .summaries import summary

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location(
    "field_report", ROOT / "tool" / "field_report.py"
)
assert spec and spec.loader
field_report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(field_report)

SAMPLE = ROOT / "contract_samples" / "http" / "observe" / "report.json"
KEY = "the-owners-key"


def test_the_recorded_report_prints_every_part() -> None:
    sample = json.loads(SAMPLE.read_text())
    report = sample.get("body", sample)

    printed = field_report.text(report)

    assert printed.startswith("Field report: 1 summaries (1 at a game's end")
    assert "talk tap main_button POST /api/onuw/games/·/ready/ [android chrome] x6" in (
        printed
    )
    assert "Screens, most long frames first" in printed
    assert "end: 300, 9, 4, 240 ms" in printed
    assert "1 database waking, in 1 of 1 summaries" in printed
    assert "412 s after the phone's last request" in printed


def test_no_summaries_says_so() -> None:
    assert "no summaries yet" in field_report.text({"summaries": 0})


@pytest.mark.integration
@pytest.mark.django_db(transaction=True)
@override_settings(FIELD_REPORT_KEY=KEY)
def test_it_reads_a_real_server_with_the_owners_key(
    live_server, capsys, monkeypatch
) -> None:
    from rest_framework.test import APIClient

    APIClient().post(
        "/api/observe/summary/", json.dumps(summary()), content_type="text/plain"
    )

    monkeypatch.setenv("FIELD_REPORT_KEY", KEY)
    assert field_report.main(["--api", live_server.url, "--last", "5"]) == 0
    assert "Field report: 1 summaries" in capsys.readouterr().out
    assert field_report.main(["--api", live_server.url, "--json"]) == 0
    assert json.loads(capsys.readouterr().out)["summaries"] == 1

    monkeypatch.setenv("FIELD_REPORT_KEY", "a-guess")
    assert field_report.main(["--api", live_server.url]) == 2
    assert "the report is closed" in capsys.readouterr().err
    monkeypatch.delenv("FIELD_REPORT_KEY")
    assert field_report.main(["--api", live_server.url]) == 2
