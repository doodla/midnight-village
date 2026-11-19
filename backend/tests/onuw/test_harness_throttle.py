"""
B4 — confirm the harness guest-throttle relief holds for a full nine-scenario run.

A nine-scenario harness run spins ~9 tables, each up to 10 guests (~90 guest
creations) plus many authenticated calls. The dev "anon" rate is 1000/minute;
the harness raises it to 1,000,000/minute. The guest view hardcodes
``throttle_classes=[AnonRateThrottle]`` (scope "anon"), so raising the rate is
the lever — not clearing DEFAULT_THROTTLE_CLASSES.

DRF caveat: ``SimpleRateThrottle.THROTTLE_RATES`` is bound to
``api_settings.DEFAULT_THROTTLE_RATES`` as a CLASS attribute at import time, so
``@override_settings(REST_FRAMEWORK=...)`` does NOT change the effective rate for
an already-imported throttle. We therefore set the rate the way the harness
settings module does — by replacing the rates dict the throttle reads — via
monkeypatch, so these tests exercise the real rate the throttle enforces rather
than a value DRF silently ignores.
"""

from __future__ import annotations

from django.urls import reverse

import pytest
from rest_framework import status
from rest_framework.throttling import AnonRateThrottle, SimpleRateThrottle

pytestmark = pytest.mark.integration


def _set_anon_rate(monkeypatch, rate: str) -> None:
    """Set the effective "anon" throttle rate the guest endpoint enforces.

    Patches the class-level THROTTLE_RATES dict (what SimpleRateThrottle.get_rate
    reads) and clears the rate cache so a fresh throttle instance recomputes.
    """
    monkeypatch.setattr(
        SimpleRateThrottle,
        "THROTTLE_RATES",
        {"anon": rate, "user": rate},
        raising=False,
    )
    AnonRateThrottle().cache.clear()


def test_harness_settings_raise_anon_and_user_rates():
    """The harness settings module pins anon/user rates to 1,000,000/minute."""
    import importlib

    harness = importlib.import_module("config.settings.harness")
    rates = harness.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"]
    assert rates["anon"] == "1000000/minute"
    assert rates["user"] == "1000000/minute"


def test_guest_throttle_is_actually_active_on_this_endpoint(
    monkeypatch, api_client, db
):
    """Sanity: with a low rate the guest endpoint DOES 429.

    Proves the throttle is live on this endpoint, so raising the rate is the
    real lever. Without this, the volume test below could pass for the wrong
    reason (throttle silently disabled).
    """
    _set_anon_rate(monkeypatch, "5/minute")
    url = reverse("core:guest-create")
    statuses = [api_client.post(url, {}, format="json").status_code for _ in range(7)]
    assert status.HTTP_429_TOO_MANY_REQUESTS in statuses


def test_full_nine_scenario_guest_volume_does_not_throttle(monkeypatch, api_client, db):
    """A full run's guest volume (9 tables x 10 guests) creates with no 429.

    AnonRateThrottle buckets by client IP; the test client presents a single IP,
    so all 90 share one bucket — the worst case. Under the harness rate this
    must never 429.
    """
    _set_anon_rate(monkeypatch, "1000000/minute")
    url = reverse("core:guest-create")
    for i in range(9 * 10):
        resp = api_client.post(url, {}, format="json")
        assert resp.status_code == status.HTTP_201_CREATED, (
            f"guest #{i} unexpectedly returned {resp.status_code}"
        )
