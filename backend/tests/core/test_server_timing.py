"""Every answer carries ``Server-Timing``: what it cost the server, by part."""

from django.db import connection
from django.http import HttpResponse
from django.test import RequestFactory
from django.test.utils import CaptureQueriesContext

import pytest
from rest_framework.test import APIClient

from apps.core import server_timing
from apps.core.models import User

pytestmark = pytest.mark.django_db

NAMES = ["Ana", "Ben", "Cleo", "Dev"]


def parts(header: str) -> dict[str, tuple[float, str | None]]:
    """``{"db": (ms, "count"), ...}`` from a Server-Timing header."""
    out = {}
    for entry in header.split(", "):
        name, *params = entry.split(";")
        values = dict(p.split("=", 1) for p in params)
        out[name] = (float(values["dur"]), values.get("desc", "").strip('"') or None)
    return out


def test_the_header_counts_each_part_the_request_used() -> None:
    def view(request):
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
        server_timing.note("sockets", 0.002)
        server_timing.note("sockets", 0.003)
        return HttpResponse("ok")

    middleware = server_timing.ServerTimingMiddleware(view)
    response = middleware(RequestFactory().get("/"))

    got = parts(response["Server-Timing"])
    assert got["db"][1] == "1"
    assert got["sockets"] == (5.0, "2")
    assert got["queue"] == (0.0, "0")
    assert got["total"][0] > 0
    assert set(got) == {"connect", "db", "sockets", "queue", "total"}


def test_a_note_outside_a_request_is_dropped() -> None:
    server_timing.note("queue", 1.0)  # nothing to add it to: no error, no effect

    response = server_timing.ServerTimingMiddleware(lambda r: HttpResponse())(
        RequestFactory().get("/")
    )

    assert parts(response["Server-Timing"])["queue"] == (0.0, "0")


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
    got = parts(response["Server-Timing"])
    assert got["db"][1] == str(len(queries.captured_queries))
    assert User.objects.filter(display_name__in=NAMES).count() == 4
