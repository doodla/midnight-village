"""The report over the last games: percentiles per leg, slowest screens, cold starts."""

from __future__ import annotations

from datetime import UTC, datetime
from types import SimpleNamespace

import pytest

from apps.observe import report

from .summaries import summary

pytestmark = pytest.mark.unit

TAP = "talk tap main_button POST /api/onuw/games/·/ready/"


def row(body: dict, device: str = "android chrome", minute: int = 0):
    at = datetime(2026, 11, 27, 20, minute, tzinfo=UTC)
    return SimpleNamespace(
        body=body, device=device, commit=body["commit"], received_at=at
    )


def test_the_nearest_rank_percentile() -> None:
    values = [float(v) for v in range(1, 11)]
    assert report.percentile(values, 50) == 5.0
    assert report.percentile(values, 90) == 9.0
    assert report.percentile([], 50) is None


def test_values_from_several_games_merge_by_kind_and_device() -> None:
    one = summary(seed=1)
    two = summary(seed=2)
    one["taps"][TAP]["screen"] = [10.0, 20.0, 30.0]
    two["taps"][TAP]["screen"] = [40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]

    got = report.build([row(two, minute=5), row(one), row(summary(), "iphone safari")])

    android = next(
        t for t in got["taps"] if t["kind"] == TAP and t["device"] == "android chrome"
    )
    assert android["taps"] == 12
    assert android["legs"]["screen"] == {
        "p50": 50.0,
        "p90": 90.0,
        "worst": 100.0,
        "values": 10,
    }
    assert {t["device"] for t in got["taps"] if t["kind"] == TAP} == {
        "android chrome",
        "iphone safari",
    }
    assert got["first"] < got["last"]


def test_the_screen_with_the_most_long_frames_comes_first() -> None:
    got = report.build([row(summary()), row(summary(seed=3))])

    assert [s["screen"] for s in got["screens"]] == ["end", "talk", "vote"]
    assert got["screens"][0]["over_100"] == 8
    assert got["screens"][0]["worst"] == 240.0


def test_cold_starts_are_counted_with_the_latest_ones_listed() -> None:
    warm = summary(cold=[])
    got = report.build([row(summary()), row(warm), row(summary(seed=4))])

    assert got["cold"]["db_wake"] == 2
    assert got["cold"]["boot"] == 0
    assert got["cold"]["games_with_any"] == 2
    assert got["cold"]["latest"][0]["gap_s"] == 412.0


def test_no_games_is_an_empty_report() -> None:
    got = report.build([])

    assert got["games"] == 0
    assert got["taps"] == []
    assert got["first"] is None
