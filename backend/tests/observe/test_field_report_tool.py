"""`just field-report` (`tool/field_report.py`) against this server: it reads the
report the phones' summaries make and prints every part of it."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

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


def test_the_recorded_report_prints_every_part() -> None:
    sample = json.loads(SAMPLE.read_text())
    report = sample.get("body", sample)

    printed = field_report.text(report)

    assert printed.startswith("Field report: 1 games")
    assert "talk tap main_button POST /api/onuw/games/·/ready/ [android chrome] x6" in (
        printed
    )
    assert "Screens, most long frames first" in printed
    assert "end: 300, 9, 4, 240 ms" in printed
    assert "1 database waking, in 1 of 1 games" in printed
    assert "412 s after the phone's last request" in printed


def test_no_games_says_so() -> None:
    assert "no games yet" in field_report.text({"games": 0})


@pytest.mark.integration
@pytest.mark.django_db(transaction=True)
def test_it_reads_a_real_server(live_server, capsys) -> None:
    from rest_framework.test import APIClient

    APIClient().post(
        "/api/observe/summary/", json.dumps(summary()), content_type="text/plain"
    )

    assert field_report.main(["--api", live_server.url, "--games", "5"]) == 0
    assert "Field report: 1 games" in capsys.readouterr().out
    assert field_report.main(["--api", live_server.url, "--json"]) == 0
    assert json.loads(capsys.readouterr().out)["games"] == 1
