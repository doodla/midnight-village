"""Every route, as anyone without an account meets it.

Two rules, over every route the server has (a new route is checked the day it is added):

* A hostile body never makes the server fail: deep nesting, huge numbers, NaN,
  duplicate keys, a NUL character, bytes that are not UTF-8. Each answers below 500.
* Nothing a caller sends comes back to anyone without an account. Text sent to every
  route (and inside a speed summary, in every place a phone writes words) never
  appears in what any route answers without an account, nor in the owner's report:
  a route that keeps client input and serves it back openly fails here.
"""

from __future__ import annotations

import json
import re
from collections.abc import Iterator

from django.test import override_settings
from django.urls import get_resolver
from django.urls.resolvers import URLPattern, URLResolver

import pytest
from rest_framework.test import APIClient

from tests.observe.summaries import summary

pytestmark = [pytest.mark.integration, pytest.mark.django_db]

CANARY = "Zqcanary"
KEY = "owner-key-for-the-test"
FILL = {
    "str": "ABCDEF",
    "slug": "abcdef",
    "int": "1",
    "uuid": "8f14e45f-ceea-467a-9b36-5b2ba8d5b3a1",
    "path": "ABCDEF",
}
HOSTILE: list[tuple[bytes, str]] = [
    (b"[" * 16000, "application/json"),
    (b"[" * 16000, "text/plain"),
    (b'{"a": ' * 8000 + b"1" + b"}" * 8000, "application/json"),
    (b"9" * 5000, "application/json"),
    (b'{"v": 1e999, "n": NaN, "x": -Infinity}', "application/json"),
    (b'{"v": 1, "v": 2, "taps": {"a": 1, "a": 2}}', "application/json"),
    (b'{"v": 1, "s": "\\u0000\\ud800"}', "application/json"),
    (b"\xff\xfe\x00", "application/json"),
    (b"\xff\xfe\x00", "text/plain"),
]


def _routes() -> Iterator[str]:
    """Every route as a path, its parameters filled with plain values."""

    def walk(patterns: list, prefix: str) -> Iterator[str]:
        for entry in patterns:
            route = prefix + str(entry.pattern)
            if isinstance(entry, URLResolver):
                yield from walk(entry.url_patterns, route)
            elif isinstance(entry, URLPattern) and not route.startswith("admin/"):
                yield "/" + re.sub(
                    r"<(?:(\w+):)?\w+>", lambda m: FILL.get(m[1] or "str", "x"), route
                )

    yield from walk(get_resolver().url_patterns, "")


ROUTES = sorted(set(_routes()))


def test_the_scan_finds_the_routes() -> None:
    assert "/api/observe/summary/" in ROUTES
    assert "/api/auth/guest/" in ROUTES
    assert "/api/lobbies/ABCDEF/join/" in ROUTES


@pytest.mark.parametrize("route", ROUTES)
def test_a_hostile_body_never_makes_a_route_fail(route: str) -> None:
    client = APIClient()
    for body, kind in HOSTILE:
        for method in (client.post, client.patch, client.put):
            answer = method(route, body, content_type=kind)
            assert answer.status_code < 500, (route, body[:20], kind)


def _canary_bodies() -> list[tuple[str, str]]:
    planted = summary(
        commit=CANARY,
        env={"agent": CANARY, "renderer": CANARY, "gpu": CANARY},
    )
    planted["taps"][f"talk tap main_button POST /api/lobbies/{CANARY}/join/"] = {
        "n": 9,
        "screen": [1.0],
    }
    planted["taps"][f"talk tap {CANARY}"] = {"n": 9, "screen": [1.0]}
    planted["frames"][CANARY] = {"frames": 9}
    planted["screens"][f"talk > vote (socket {CANARY})"] = {"n": 9, "first": [1.0]}
    planted["requests"][f"GET /api/{CANARY}/"] = {"n": 9, "round": [1.0]}
    planted["cold"].append({"kind": "boot", "path": f"GET /api/{CANARY}/"})
    planted[CANARY] = CANARY
    words = {
        "display_name": CANARY,
        "name": CANARY,
        "code": CANARY,
        "refresh": CANARY,
        "username": CANARY,
        "password": CANARY,
        "settings": {CANARY: CANARY},
        CANARY: CANARY,
    }
    return [
        (json.dumps(planted), "text/plain"),
        (json.dumps(planted), "application/json"),
        (json.dumps(words), "application/json"),
    ]


@override_settings(FIELD_REPORT_KEY=KEY)
def test_nothing_a_caller_sends_is_served_back_without_an_account() -> None:
    client = APIClient()
    for route in ROUTES:
        for body, kind in _canary_bodies():
            for method in (client.post, client.patch, client.put):
                method(route, body, content_type=kind)

    for route in ROUTES:
        answer = client.get(route)
        assert CANARY.lower() not in answer.content.decode(errors="replace").lower(), (
            route
        )
    report = client.get("/api/observe/report/", HTTP_X_FIELD_REPORT_KEY=KEY)
    assert report.status_code == 200
    assert report.json()["summaries"] >= 1, "the planted summary was kept"
    assert CANARY.lower() not in report.content.decode().lower()
