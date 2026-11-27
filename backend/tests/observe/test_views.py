"""The summaries come in as a beacon sends them; only the owner reads the report.

``navigator.sendBeacon`` sends ``text/plain`` with no account; the view keeps one row
per summary, refuses what is too large or not a summary, limits each address, and
clears what is older than 30 days or beyond the newest rows kept. The report answers
404 to anyone without the owner's key, and to everyone while no key is set.
"""

from __future__ import annotations

import json
from datetime import timedelta

from django.core.cache import cache
from django.db.models.functions import Now
from django.test import override_settings
from django.urls import reverse

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
KEY = "the-owners-key"


def beacon(body: object, address: str = "203.0.113.7") -> int:
    """POST as a beacon does: text/plain, no account."""
    text = body if isinstance(body, str | bytes) else json.dumps(body)
    return (
        APIClient()
        .post(reverse(SUMMARY), text, content_type="text/plain", REMOTE_ADDR=address)
        .status_code
    )


def read_report(key: str | None = KEY, address: str = "192.0.2.1", **params: object):
    headers = {} if key is None else {"HTTP_X_FIELD_REPORT_KEY": key}
    return APIClient().get(reverse(REPORT), params, REMOTE_ADDR=address, **headers)


def test_a_summary_sent_as_a_beacon_is_kept_with_the_kind_of_phone_only() -> None:
    assert beacon(summary()) == 204

    row = FieldSummary.objects.get()
    assert row.device == "android chrome"
    assert row.commit == "faf62a1c0ffee"
    assert row.body["taps"]
    assert "agent" not in row.body["env"]


def test_a_row_says_the_hour_it_came_in_no_finer() -> None:
    assert beacon(summary()) == 204

    at = FieldSummary.objects.get().received_at
    assert (at.minute, at.second, at.microsecond) == (0, 0, 0)


def test_a_signed_in_phone_sends_no_account_and_the_row_names_none() -> None:
    """The row has no user, table or game column at all."""
    names = {f.name for f in FieldSummary._meta.get_fields()}
    assert names == {"id", "received_at", "commit", "device", "body"}


@pytest.mark.parametrize("body", ["not json", "[]", {"v": 1}, b"\xff\xfe", b"[" * 8000])
def test_what_is_not_a_summary_is_refused_and_nothing_is_kept(body: object) -> None:
    assert beacon(body) == 400
    assert not FieldSummary.objects.exists()


def test_a_summary_larger_than_the_cap_is_refused() -> None:
    big = summary(env={"agent": "x" * (views.MOST_BYTES + 1)})

    assert beacon(big) == 413
    assert not FieldSummary.objects.exists()


def test_old_rows_and_rows_beyond_the_newest_go_in_one_clean_up(monkeypatch) -> None:
    """Aged by the database's own clock."""
    monkeypatch.setattr(views, "KEEP_ROWS", 3)
    old = FieldSummary.objects.create(body=summary())
    FieldSummary.objects.filter(id=old.id).update(
        received_at=Now() - timedelta(days=31)
    )
    for seed in range(4):
        assert beacon(summary(seed=seed)) == 204

    assert not FieldSummary.objects.filter(id=old.id).exists()
    assert FieldSummary.objects.count() == 3


def test_one_address_is_limited_and_a_room_of_tables_is_not(monkeypatch) -> None:
    """Ten phones, each sending at the end of six games and twice when hidden:
    480 from one address in an evening pass; the next ones in that hour do not.
    The owner reading the report from the same address takes nothing from them."""
    rates = dict(base.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"])
    monkeypatch.setattr(SimpleRateThrottle, "THROTTLE_RATES", rates)
    monkeypatch.setattr(views, "KEEP_ROWS", 10)
    cache.clear()
    try:
        with override_settings(FIELD_REPORT_KEY=KEY):
            for _ in range(30):
                assert read_report(address="203.0.113.7").status_code == 200
        assert {beacon(summary()) for _ in range(480)} == {204}
        for _ in range(120):
            beacon(summary())
        assert beacon(summary()) == 429
        assert beacon(summary(), address="198.51.100.2") == 204
    finally:
        cache.clear()


@pytest.mark.parametrize("key", [None, "", "a-guess", KEY + "x"])
def test_the_report_is_not_there_for_anyone_without_the_owners_key(key) -> None:
    assert beacon(summary()) == 204

    with override_settings(FIELD_REPORT_KEY=KEY):
        answer = read_report(key)

    assert answer.status_code == 404
    assert "taps" not in answer.content.decode()


def test_with_no_key_set_the_report_is_closed_to_everyone() -> None:
    assert beacon(summary()) == 204

    with override_settings(FIELD_REPORT_KEY=""):
        assert read_report("").status_code == 404
        assert read_report(KEY).status_code == 404


@override_settings(FIELD_REPORT_KEY=KEY)
def test_the_owners_report_merges_the_last_summaries_and_counts_them_as_such() -> None:
    for seed in range(3):
        assert beacon(summary(seed=seed)) == 204
    assert beacon(summary(end="hidden")) == 204

    got = read_report(last=3)

    assert got.status_code == 200
    report = got.json()
    assert report["summaries"] == 3
    assert report["at_game_end"] == 2
    assert report["devices"] == {"android chrome": 3}
    tap = report["taps"][0]
    assert tap["kind"].startswith("talk tap main_button POST")
    assert tap["taps"] == 18
    assert set(tap["legs"]) >= {"screen", "answer", "total"}
    assert report["cold"]["db_wake"] == 3


@override_settings(FIELD_REPORT_KEY=KEY)
def test_a_report_asked_for_a_number_that_is_not_one_is_refused() -> None:
    assert read_report(last="all").status_code == 400
