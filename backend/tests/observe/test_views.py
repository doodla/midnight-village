"""The summaries come in as a beacon sends them, and the report reads them back.

``navigator.sendBeacon`` sends ``text/plain`` with no account; the view keeps one row
per summary, refuses what is too large or not a summary, limits each address, and
clears what is older than 30 days or beyond the newest rows kept.
"""

from __future__ import annotations

import json
from datetime import timedelta

from django.core.cache import cache
from django.urls import reverse
from django.utils import timezone

import pytest
from rest_framework.test import APIClient
from rest_framework.throttling import SimpleRateThrottle

from apps.observe import views
from apps.observe.models import FieldSummary
from config.settings import base

from .summaries import summary

pytestmark = [pytest.mark.integration, pytest.mark.django_db]

SUMMARY = "observe:summary"
REPORT = "observe:report"


def beacon(body: object, address: str = "203.0.113.7") -> int:
    """POST as a beacon does: text/plain, no account."""
    text = body if isinstance(body, str | bytes) else json.dumps(body)
    return (
        APIClient()
        .post(reverse(SUMMARY), text, content_type="text/plain", REMOTE_ADDR=address)
        .status_code
    )


def test_a_summary_sent_as_a_beacon_is_kept_with_the_phone_it_came_from() -> None:
    assert beacon(summary()) == 204

    row = FieldSummary.objects.get()
    assert row.device == "android chrome"
    assert row.commit == "faf62a1c0ffee"
    assert row.body["taps"]


def test_a_signed_in_phone_sends_no_account_and_the_row_names_none() -> None:
    """The row has no user, table or game column at all."""
    names = {f.name for f in FieldSummary._meta.get_fields()}
    assert names == {"id", "received_at", "commit", "device", "body"}


@pytest.mark.parametrize("body", ["not json", "[]", {"v": 1}, b"\xff\xfe"])
def test_what_is_not_a_summary_is_refused_and_nothing_is_kept(body: object) -> None:
    assert beacon(body) == 400
    assert not FieldSummary.objects.exists()


def test_a_summary_larger_than_the_cap_is_refused() -> None:
    big = summary(env={"agent": "x" * (views.MOST_BYTES + 1)})

    assert beacon(big) == 413
    assert not FieldSummary.objects.exists()


def test_summaries_older_than_30_days_are_cleared_as_new_ones_arrive() -> None:
    old = FieldSummary.objects.create(body=summary())
    FieldSummary.objects.filter(id=old.id).update(
        received_at=timezone.now() - timedelta(days=31)
    )
    recent = FieldSummary.objects.create(body=summary())

    assert beacon(summary()) == 204

    assert not FieldSummary.objects.filter(id=old.id).exists()
    assert FieldSummary.objects.filter(id=recent.id).exists()


def test_only_the_newest_rows_are_kept(monkeypatch) -> None:
    monkeypatch.setattr(views, "KEEP_ROWS", 3)
    for seed in range(4):
        assert beacon(summary(seed=seed)) == 204

    assert FieldSummary.objects.count() == 3


def test_one_address_is_limited_and_a_room_of_tables_is_not(monkeypatch) -> None:
    """Ten phones, each sending at the end of six games and twice when hidden:
    480 from one address in an evening pass; the next ones in that hour do not."""
    rates = dict(base.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"])
    monkeypatch.setattr(SimpleRateThrottle, "THROTTLE_RATES", rates)
    monkeypatch.setattr(views, "KEEP_ROWS", 10)
    cache.clear()
    try:
        assert {beacon(summary()) for _ in range(480)} == {204}
        for _ in range(120):
            beacon(summary())
        assert beacon(summary()) == 429
        assert beacon(summary(), address="198.51.100.2") == 204
    finally:
        cache.clear()


def test_the_report_merges_the_last_games() -> None:
    for seed in range(3):
        assert beacon(summary(seed=seed)) == 204

    got = APIClient().get(reverse(REPORT), {"games": 2})

    assert got.status_code == 200
    report = got.json()
    assert report["games"] == 2
    assert report["devices"] == {"android chrome": 2}
    tap = report["taps"][0]
    assert tap["kind"].startswith("talk tap main_button POST")
    assert tap["taps"] == 12
    assert set(tap["legs"]) >= {"screen", "answer", "total"}
    assert report["cold"]["db_wake"] == 2


def test_a_report_asked_for_a_number_that_is_not_one_is_refused() -> None:
    assert APIClient().get(reverse(REPORT), {"games": "all"}).status_code == 400
