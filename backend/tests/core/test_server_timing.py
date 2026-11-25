"""Every answer carries ``Server-Timing``: live, only the connection time and a
rounded total; with ``SERVER_TIMING_DETAIL`` (development, tests) its parts too."""

from django.db import connection
from django.http import HttpResponse
from django.test import RequestFactory, override_settings
from django.test.utils import CaptureQueriesContext

import pytest
from rest_framework.test import APIClient

from apps.core import server_timing

NAMES = ["Ana", "Ben", "Cleo", "Dev"]


def parts(header: str) -> dict[str, tuple[float, str | None]]:
    """``{"db": (ms, "count"), ...}`` from a Server-Timing header."""
    out = {}
    for entry in header.split(", "):
        name, *params = entry.split(";")
        values = dict(p.split("=", 1) for p in params)
        out[name] = (float(values["dur"]), values.get("desc", "").strip('"') or None)
    return out


def _view_with_one_query_and_two_sends(request):
    with connection.cursor() as cursor:
        cursor.execute("SELECT 1")
    server_timing.note("sockets", 0.002)
    server_timing.note("sockets", 0.003)
    return HttpResponse("ok")


def _answer(view, **settings) -> dict[str, tuple[float, str | None]]:
    with override_settings(**settings):
        response = server_timing.ServerTimingMiddleware(view)(RequestFactory().get("/"))
    return parts(response["Server-Timing"])


@pytest.mark.django_db
def test_with_detail_the_header_counts_each_part_the_request_used() -> None:
    got = _answer(_view_with_one_query_and_two_sends, SERVER_TIMING_DETAIL=True)

    assert got["db"][1] == "1"
    assert got["sockets"] == (5.0, "2")
    assert got["queue"] == (0.0, "0")
    assert got["total"][0] > 0
    # The test's connection was open already: no connect was made, none is told.
    assert set(got) == {"db", "sockets", "queue", "total"}


@pytest.mark.django_db
def test_live_the_header_has_no_counts_and_a_total_rounded_to_50_ms() -> None:
    got = _answer(_view_with_one_query_and_two_sends, SERVER_TIMING_DETAIL=False)

    assert set(got) == {"total"}
    assert got["total"][1] is None
    assert got["total"][0] % server_timing.TOTAL_STEP_MS == 0


@pytest.mark.django_db(transaction=True)
def test_a_request_that_opens_its_connection_is_told_how_long_it_took() -> None:
    connection.close()

    got = _answer(_view_with_one_query_and_two_sends, SERVER_TIMING_DETAIL=False)

    assert set(got) == {"connect", "total"}
    assert got["connect"][0] >= 0
    assert got["connect"][1] is None


def test_a_health_check_opens_no_database_connection() -> None:
    # No database access is allowed in this test: opening one would raise.
    response = APIClient().get("/api/health/")

    assert response.status_code == 200
    assert "connect" not in parts(response.headers["Server-Timing"])


def test_a_note_outside_a_request_is_dropped() -> None:
    server_timing.note("queue", 1.0)  # nothing to add it to: no error, no effect

    got = _answer(lambda r: HttpResponse(), SERVER_TIMING_DETAIL=True)

    assert got["queue"] == (0.0, "0")


@pytest.mark.django_db
def test_a_lobby_read_at_a_four_player_table_names_its_round_trips() -> None:
    clients = {}
    for name in NAMES:
        body = APIClient().post("/api/auth/guest/", {"display_name": name}).json()
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {body['access']}")
        clients[name] = client
    code = clients["Ana"].post("/api/lobbies/", {"game_type": "onuw"}).json()["code"]
    for name in NAMES[1:]:
        assert clients[name].post(f"/api/lobbies/{code}/join/").status_code == 200

    with CaptureQueriesContext(connection) as queries:
        response = clients["Dev"].get(f"/api/lobbies/{code}/")

    assert response.status_code == 200
    assert len(response.json()["players"]) == 4
    got = parts(response.headers["Server-Timing"])
    assert got["db"][1] == str(len(queries.captured_queries))
