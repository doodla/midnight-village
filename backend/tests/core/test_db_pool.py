"""The live server's database pool (``apps/core/pooled_postgres``, ``config/settings/vercel.py``).

Run against this run's own test database with the live settings' engine and pool
options, so what is checked is what deploys: a warm instance borrows the same
connection again (no TCP, TLS or sign-in), and connections that died while the
instance was frozen (the database closed them) cost no back-off: the next request
gets a working connection at once.
"""

from __future__ import annotations

import importlib
import sys
import time
from collections.abc import Iterator
from typing import Any

from django.db import connection
from django.db.utils import ConnectionHandler

import pytest

from apps.core.pooled_postgres.base import DatabaseWrapper

pytestmark = pytest.mark.django_db

# psycopg's pool waits 1 s before its third try at a dead connection: well over this.
NO_BACK_OFF_SECONDS = 0.5


def _live_settings(monkeypatch: pytest.MonkeyPatch) -> dict[str, Any]:
    """The live settings' database, pointed at this run's test database."""
    own = connection.settings_dict
    url = (
        f"postgres://{own['USER']}:{own['PASSWORD']}@{own['HOST'] or 'localhost'}"
        f":{own['PORT'] or 5432}/{own['NAME']}"
    )
    for key, value in {
        "SECRET_KEY": "not-a-real-secret",
        "DATABASE_URL": url,
        "REDIS_URL": "redis://localhost:6379",
        "DB_SSLMODE": "prefer",
    }.items():
        monkeypatch.setenv(key, value)
    sys.modules.pop("config.settings.vercel", None)
    live = importlib.import_module("config.settings.vercel")
    sys.modules.pop("config.settings.vercel", None)
    return live.DATABASES["default"]


@pytest.fixture
def pooled(monkeypatch: pytest.MonkeyPatch) -> Iterator[DatabaseWrapper]:
    settings_dict = ConnectionHandler(
        {"default": _live_settings(monkeypatch)}
    ).settings["default"]
    assert settings_dict["ENGINE"] == "apps.core.pooled_postgres"
    wrapper = DatabaseWrapper(settings_dict, alias="pool_under_test")
    try:
        yield wrapper
    finally:
        wrapper.close()
        wrapper.close_pool()


def _backend_pid(wrapper: DatabaseWrapper) -> int:
    with wrapper.cursor() as cursor:
        cursor.execute("SELECT pg_backend_pid()")
        (pid,) = cursor.fetchone() or (0,)
        return pid


def _a_request(wrapper: DatabaseWrapper) -> int:
    """What one request does with the database: borrow, query, give back."""
    try:
        return _backend_pid(wrapper)
    finally:
        wrapper.close()


def test_a_warm_instance_borrows_the_same_connection_again(pooled):
    first = _a_request(pooled)
    second = _a_request(pooled)
    third = _a_request(pooled)

    assert first == second == third


def test_connections_that_died_while_frozen_cost_the_next_request_no_back_off(pooled):
    # Three requests at once leave three idle connections in the pool.
    pool = pooled.pool
    pool.open()
    held = [pool.getconn() for _ in range(3)]
    pids = {conn.info.backend_pid for conn in held}
    for conn in held:
        pool.putconn(conn)
    assert len(pids) == 3

    # Frozen meanwhile: the database closes every one of them (Neon suspends).
    with connection.cursor() as cursor:
        for pid in pids:
            cursor.execute("SELECT pg_terminate_backend(%s)", [pid])

    began = time.monotonic()
    pid = _a_request(pooled)
    took = time.monotonic() - began

    assert pid not in pids
    assert took < NO_BACK_OFF_SECONDS, f"the request waited {took:.2f} s"
    # And the pool goes on serving.
    assert _a_request(pooled) not in pids


def test_one_dead_connection_among_live_ones_is_replaced_and_the_rest_kept(pooled):
    pool = pooled.pool
    pool.open()
    held = [pool.getconn() for _ in range(3)]
    pids = [conn.info.backend_pid for conn in held]
    for conn in held:
        pool.putconn(conn)
    with connection.cursor() as cursor:
        cursor.execute("SELECT pg_terminate_backend(%s)", [pids[0]])

    seen = {_a_request(pooled) for _ in range(4)}

    assert pids[0] not in seen
    assert seen & set(pids[1:])
