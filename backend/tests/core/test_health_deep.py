"""The deep health check (``/api/health/?deep=1``, ``apps/core/health.py``) and the watch's
step that reads it (``tool/deployed_check.py --deep``).

It must say ok only when the database and Redis really answer, fail fast when one
hangs, and never say more than "ok", "failed" or "not used" per part.
"""

import time

from django.test import override_settings
from django.urls import reverse

import deployed_check
import pytest

from apps.core import health

pytestmark = pytest.mark.integration

ALLOWED = {"ok", "failed", "not used"}
SECRET = "postgres://owner:hunter2@db.example.com/live"


def deep(api_client):
    return api_client.get(reverse("core:health-check") + "?deep=1")


@pytest.mark.django_db
class TestDeepHealth:
    def test_a_reachable_database_is_ok_and_the_old_shape_is_kept(self, api_client):
        response = deep(api_client)
        assert response.status_code == 200
        assert response.json() == {
            "status": "ok",
            "commit": "",
            "database": "ok",
            "redis": "not used",
        }
        assert "no-store" in response["Cache-Control"]
        plain = api_client.get(reverse("core:health-check"))
        assert plain.json() == {"status": "ok", "commit": ""}

    def test_a_database_that_fails_is_a_503_that_says_nothing_more(
        self, api_client, monkeypatch
    ):
        def broken():
            raise RuntimeError(f"could not connect to {SECRET}")

        monkeypatch.setattr(health, "database_answers", broken)
        response = deep(api_client)
        assert response.status_code == 503
        body = response.json()
        assert body["status"] == "failed"
        assert body["database"] == "failed"
        assert set(body) == {"status", "commit", "database", "redis"}
        assert "hunter2" not in response.content.decode()

    def test_a_part_that_hangs_is_failed_within_the_limit(
        self, api_client, monkeypatch
    ):
        monkeypatch.setattr(health, "TIMEOUT", 0.2)
        monkeypatch.setattr(health, "database_answers", lambda: time.sleep(3) or True)
        started = time.monotonic()
        response = deep(api_client)
        assert time.monotonic() - started < 2
        assert response.json()["database"] == "failed"

    @override_settings(
        CHANNEL_LAYERS={
            "default": {
                "BACKEND": "channels_redis.core.RedisChannelLayer",
                "CONFIG": {"hosts": ["redis://127.0.0.1:1/0"]},
            }
        }
    )
    def test_a_redis_that_does_not_answer_is_failed(self, api_client):
        response = deep(api_client)
        assert response.status_code == 503
        body = response.json()
        assert body["redis"] == "failed"
        assert body["database"] == "ok"
        assert set(body.values()) - {""} <= ALLOWED

    def test_a_redis_that_answers_is_ok(self, api_client, monkeypatch):
        monkeypatch.setattr(health, "redis_url", lambda: "redis://example.test:6379/0")
        monkeypatch.setattr(health, "redis_answers", lambda url: True)
        assert deep(api_client).json()["redis"] == "ok"


class FakeServer:
    def __init__(self, status, body):
        self.answer = (status, {}, body)

    def __call__(self, method, url, **kwargs):
        assert url.endswith("/api/health/?deep=1")
        return self.answer


class TestTheWatchReadsIt:
    def test_ok_passes(self, monkeypatch):
        body = b'{"status": "ok", "commit": "", "database": "ok", "redis": "ok"}'
        monkeypatch.setattr(deployed_check, "call", FakeServer(200, body))
        deployed_check.check_deep("https://server.test")

    def test_a_failed_part_says_which_and_where_to_look(self, monkeypatch):
        body = (
            b'{"status": "failed", "commit": "", "database": "failed", "redis": "ok"}'
        )
        monkeypatch.setattr(deployed_check, "call", FakeServer(503, body))
        with pytest.raises(deployed_check.Failed, match=r"database failed.*Neon"):
            deployed_check.check_deep("https://server.test")

    def test_a_build_that_ignores_deep_is_not_taken_for_healthy(self, monkeypatch):
        body = b'{"status": "ok", "commit": "abc"}'
        monkeypatch.setattr(deployed_check, "call", FakeServer(200, body))
        with pytest.raises(
            deployed_check.Failed, match="does not answer the deep check"
        ):
            deployed_check.check_deep("https://server.test")
