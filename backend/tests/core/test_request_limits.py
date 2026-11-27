"""
Request limits never touch a table, and cannot be dodged with a made-up address.

The limits count per client address (``apps/core/throttles.py``). Friends at a table
share one address, so the allowances are tested with whole tables on ONE address.

DRF binds ``THROTTLE_RATES`` to the settings at import, so a test sets the rates the
throttle reads (the real ones from ``config.settings.base``) rather than overriding
settings, which DRF would ignore.
"""

from __future__ import annotations

import importlib

from django.core.cache import cache
from django.urls import get_resolver, reverse

import pytest
from rest_framework import status
from rest_framework.test import APIClient
from rest_framework.throttling import SimpleRateThrottle

from apps.core.throttles import client_address
from config.settings import base

pytestmark = pytest.mark.integration

REAL_RATES = dict(base.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"])
SIGN_UP = "core:guest-create"
WIFI = "203.0.113.7"  # one table's shared address


@pytest.fixture
def real_limits(monkeypatch):
    """The limits as production has them, counting from zero."""
    monkeypatch.setattr(SimpleRateThrottle, "THROTTLE_RATES", dict(REAL_RATES))
    cache.clear()
    yield
    cache.clear()


def sign_up(address: str = WIFI, **headers: str) -> int:
    return (
        APIClient()
        .post(reverse(SIGN_UP), {}, format="json", REMOTE_ADDR=address, **headers)
        .status_code
    )


def test_a_table_of_ten_on_one_address_all_sign_in_and_retry(real_limits, db):
    """Ten friends, each tapping twice: twenty sign-ups from one address."""
    assert [sign_up() for _ in range(20)] == [status.HTTP_201_CREATED] * 20


def test_a_second_table_sits_down_in_the_same_minute(real_limits, db):
    """Two tables of ten on one network, every phone retrying once: forty."""
    assert [sign_up() for _ in range(40)] == [status.HTTP_201_CREATED] * 40


def test_past_the_allowance_one_address_is_refused_and_another_is_not(real_limits, db):
    allowance = int(REAL_RATES["sign_up"].split("/")[0])
    assert all(sign_up() == status.HTTP_201_CREATED for _ in range(allowance))
    assert sign_up() == status.HTTP_429_TOO_MANY_REQUESTS
    assert sign_up("198.51.100.9") == status.HTTP_201_CREATED


def test_a_made_up_forwarded_address_buys_no_fresh_allowance(real_limits, db):
    allowance = int(REAL_RATES["sign_up"].split("/")[0])
    for i in range(allowance):
        assert sign_up(HTTP_X_FORWARDED_FOR=f"10.0.0.{i}") == status.HTTP_201_CREATED
    assert sign_up(HTTP_X_FORWARDED_FOR="10.9.9.9") == status.HTTP_429_TOO_MANY_REQUESTS


def test_on_the_platform_the_vouched_header_is_the_address(real_limits, db, settings):
    """Behind Vercel every request arrives from the platform's own address: the
    header it writes tells the phones apart."""
    settings.CLIENT_ADDRESS_HEADER = "HTTP_X_VERCEL_FORWARDED_FOR"
    allowance = int(REAL_RATES["sign_up"].split("/")[0])
    edge = "10.1.1.1"
    for _ in range(allowance):
        assert (
            sign_up(edge, HTTP_X_VERCEL_FORWARDED_FOR=WIFI) == status.HTTP_201_CREATED
        )
    assert (
        sign_up(edge, HTTP_X_VERCEL_FORWARDED_FOR=WIFI)
        == status.HTTP_429_TOO_MANY_REQUESTS
    )
    # another network, through the same edge, has its own allowance
    assert (
        sign_up(edge, HTTP_X_VERCEL_FORWARDED_FOR="198.51.100.9")
        == status.HTTP_201_CREATED
    )


def test_elsewhere_the_address_is_the_connections():
    assert base.CLIENT_ADDRESS_HEADER is None


@pytest.mark.parametrize(
    "made_up",
    ["10.0.0.1, 203.0.113.7", "203.0.113.7,10.0.0.1", "not an address", ""],
)
def test_a_vouched_header_that_is_not_one_address_shares_one_allowance(
    rf, settings, made_up
):
    """Only a caller adding headers of their own can produce these: they all land
    in one bucket, never a fresh one each."""
    settings.CLIENT_ADDRESS_HEADER = "HTTP_X_VERCEL_FORWARDED_FOR"
    request = rf.get("/", HTTP_X_VERCEL_FORWARDED_FOR=made_up)
    assert client_address(request) == "unverified"


def test_a_missing_vouched_header_is_logged_and_the_connection_counts(
    rf, settings, caplog
):
    settings.CLIENT_ADDRESS_HEADER = "HTTP_X_VERCEL_FORWARDED_FOR"
    with caplog.at_level("WARNING", logger="apps.core.throttles"):
        assert client_address(rf.get("/", REMOTE_ADDR="198.51.100.9")) == "198.51.100.9"
    assert "HTTP_X_VERCEL_FORWARDED_FOR" in caplog.text


def test_one_ipv6_network_is_one_caller(rf):
    here = client_address(rf.get("/", REMOTE_ADDR="2001:db8:1:2:aaaa::1"))
    same_house = client_address(rf.get("/", REMOTE_ADDR="2001:db8:1:2:bbbb::9"))
    next_door = client_address(rf.get("/", REMOTE_ADDR="2001:db8:1:3::1"))
    assert here == same_house != next_door
    assert client_address(rf.get("/", REMOTE_ADDR="::ffff:203.0.113.7")) == WIFI


def test_the_stats_number_allows_a_roomful_of_phones_polling(real_limits, db):
    """Thirty phones on one address, each asking every fifteen seconds: 120 a minute."""
    url = reverse("core:online-stats")
    answers = {APIClient().get(url, REMOTE_ADDR=WIFI).status_code for _ in range(120)}
    assert answers == {status.HTTP_200_OK}


def test_requests_inside_a_game_carry_no_limit():
    """Only sign-up, the stats number and the phones' speed summaries (a beacon sent
    after the play, ``apps/observe``) are limited: nothing a table does in play.
    Every route the server has is looked at, so a new limited view fails here."""
    assert "DEFAULT_THROTTLE_CLASSES" not in base.REST_FRAMEWORK

    def routes(patterns):
        for entry in patterns:
            if hasattr(entry, "url_patterns"):
                yield from routes(entry.url_patterns)
            else:
                yield entry.callback

    limited = set()
    for callback in routes(get_resolver().url_patterns):
        view = getattr(callback, "cls", None) or getattr(callback, "view_class", None)
        if view is not None and getattr(view, "throttle_classes", None):
            limited.add(view.__name__)
    assert limited == {
        "GuestCreateView",
        "OnlineStatsView",
        "SummaryView",
        "ReportView",
    }


def test_the_harness_lifts_the_sign_up_limit_for_its_ninety_guests():
    harness = importlib.import_module("config.settings.harness")
    rates = harness.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"]
    assert int(rates["sign_up"].split("/")[0]) >= 1_000_000
