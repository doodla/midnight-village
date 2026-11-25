"""The live server's database pool (``apps/core/pooled_postgres``, ``config/settings/vercel.py``).

Run against this run's own test database with the live settings' engine and pool
options, so what is checked is what deploys: a warm instance lends the same
connection again (no TCP, TLS or sign-in), and connections that died while the
instance was frozen cost the next request one new connection, never a wait on each
dead one: neither when the database reset them nor when their path went silent
(``Proxy`` below drops a connection's packets on the floor, as a vanished network
path does).
"""

from __future__ import annotations

import importlib
import logging
import socket
import sys
import threading
import time
from collections.abc import Iterator
from typing import Any

from django.db import connection
from django.db.utils import ConnectionHandler

import psycopg
import pytest
from psycopg_pool import ConnectionPool

from apps.core import server_timing
from apps.core.pooled_postgres import base
from apps.core.pooled_postgres.base import DatabaseWrapper

pytestmark = pytest.mark.django_db

# psycopg's pool waits 1 s before its third try at a dead connection: well over this.
NO_BACK_OFF_SECONDS = 0.5
# A silent connection that is probed anyway is cut after this, so a regression
# fails on time instead of hanging the run.
SILENT_FOR = 5.0


def _live_settings(
    monkeypatch: pytest.MonkeyPatch, host: str | None = None, port: int | None = None
) -> dict[str, Any]:
    """The live settings' database, pointed at this run's test database."""
    own = connection.settings_dict
    url = (
        f"postgres://{own['USER']}:{own['PASSWORD']}"
        f"@{host or own['HOST'] or 'localhost'}:{port or own['PORT'] or 5432}"
        f"/{own['NAME']}"
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


def _wrapper(settings: dict[str, Any], alias: str) -> Iterator[DatabaseWrapper]:
    settings_dict = ConnectionHandler({"default": settings}).settings["default"]
    assert settings_dict["ENGINE"] == "apps.core.pooled_postgres"
    # Named, so the replacements a drain opens in the background (still opening as
    # the pool closes) can be ended before the run drops its database.
    settings_dict["OPTIONS"]["application_name"] = alias
    wrapper = DatabaseWrapper(settings_dict, alias=alias)
    try:
        yield wrapper
    finally:
        wrapper.close()
        wrapper.close_pool()
        time.sleep(0.2)
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT pg_terminate_backend(pid) FROM pg_stat_activity"
                " WHERE application_name = %s",
                [alias],
            )


@pytest.fixture
def pooled(monkeypatch: pytest.MonkeyPatch) -> Iterator[DatabaseWrapper]:
    yield from _wrapper(_live_settings(monkeypatch), "pool_under_test")


class Proxy:
    """A TCP relay to the database whose connections can be made silent: whatever
    then reaches it is swallowed and nothing comes back."""

    def __init__(self, upstream: tuple[str, int]) -> None:
        self.upstream = upstream
        self.server = socket.create_server(("127.0.0.1", 0))
        self.port = self.server.getsockname()[1]
        self.pairs: list[dict[str, Any]] = []
        # Seconds before a new connection reaches the database (a database that
        # scaled to zero wakes first).
        self.wake = 0.0
        threading.Thread(target=self._accept, daemon=True).start()

    def _accept(self) -> None:
        while True:
            try:
                client, _ = self.server.accept()
            except OSError:
                return
            time.sleep(self.wake)
            up = socket.create_connection(self.upstream)
            pair = {"client": client, "up": up, "silent": False}
            self.pairs.append(pair)
            for src, dst in ((client, up), (up, client)):
                threading.Thread(
                    target=self._pump, args=(pair, src, dst), daemon=True
                ).start()

    def _pump(self, pair: dict[str, Any], src: socket.socket, dst: socket.socket):
        try:
            while data := src.recv(65536):
                if pair["silent"]:
                    if src is pair["client"]:
                        cut = threading.Timer(SILENT_FOR, self._cut, [pair])
                        cut.daemon = True
                        cut.start()
                    continue
                dst.sendall(data)
        except OSError:
            pass
        if not pair["silent"]:
            self._cut(pair)

    @staticmethod
    def _cut(pair: dict[str, Any]) -> None:
        for end in (pair["client"], pair["up"]):
            try:
                end.close()
            except OSError:
                pass

    def silence_all(self) -> None:
        for pair in self.pairs:
            pair["silent"] = True

    def close(self) -> None:
        self.server.close()
        for pair in self.pairs:
            self._cut(pair)


@pytest.fixture
def proxy() -> Iterator[Proxy]:
    own = connection.settings_dict
    relay = Proxy((own["HOST"] or "localhost", int(own["PORT"] or 5432)))
    try:
        yield relay
    finally:
        relay.close()


@pytest.fixture
def proxied(monkeypatch: pytest.MonkeyPatch, proxy: Proxy) -> Iterator[DatabaseWrapper]:
    settings = _live_settings(monkeypatch, host="127.0.0.1", port=proxy.port)
    yield from _wrapper(settings, "pool_through_proxy")


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


def _idle(wrapper: DatabaseWrapper, count: int) -> set[int]:
    """``count`` requests at once leave ``count`` idle connections: their pids."""
    pool = wrapper.pool
    pool.open()
    held = [pool.getconn() for _ in range(count)]
    pids = {conn.info.backend_pid for conn in held}
    for conn in held:
        base.note_idle(conn)
        pool.putconn(conn)
    assert len(pids) == count
    return pids


def _timed(wrapper: DatabaseWrapper) -> tuple[int, float]:
    began = time.monotonic()
    pid = _a_request(wrapper)
    return pid, time.monotonic() - began


def test_a_warm_instance_borrows_the_same_connection_again(pooled):
    first = _a_request(pooled)
    second = _a_request(pooled)
    third = _a_request(pooled)

    assert first == second == third


def test_the_header_says_connect_only_when_a_connection_was_opened(pooled):
    # What `Server-Timing` shows live: the first request on an instance opens a
    # connection (`connect`), the next ones borrow it again (no `connect`).
    server_timing.install()

    def connect_part() -> list[float] | None:
        server_timing._current.parts = {}
        try:
            _a_request(pooled)
            return server_timing._current.parts.get("connect")
        finally:
            server_timing._current.parts = None

    first, second, third = connect_part(), connect_part(), connect_part()

    assert first is not None and first[0] == 1
    assert second is None
    assert third is None


def test_connections_the_database_closed_while_frozen_cost_no_back_off(pooled):
    pids = _idle(pooled, 3)
    # Frozen meanwhile: the database closes every one of them (Neon suspends).
    with connection.cursor() as cursor:
        for pid in pids:
            cursor.execute("SELECT pg_terminate_backend(%s)", [pid])

    pid, took = _timed(pooled)

    assert pid not in pids
    assert took < NO_BACK_OFF_SECONDS, f"the request waited {took:.2f} s"
    assert _a_request(pooled) not in pids  # and the pool goes on serving


def test_a_thaw_never_waits_on_silent_dead_connections(proxied, proxy, monkeypatch):
    pids = _idle(proxied, 3)
    # Frozen two minutes; meanwhile the connections' path vanished: no reply, no
    # reset. A connection unused that long is not probed at all.
    proxy.silence_all()
    later = time.time() + 120
    monkeypatch.setattr(base, "_wall_clock", lambda: later)

    pid, took = _timed(proxied)

    assert pid not in pids
    assert took < NO_BACK_OFF_SECONDS, f"the request waited {took:.2f} s"


def test_the_first_tap_after_a_quiet_spell_waits_for_the_database_to_wake(
    proxied, proxy, monkeypatch
):
    # Ten quiet minutes: the instance's connections are stale and the database
    # scaled to zero, so the one new connection waits for it to wake (2 s here).
    pids = _idle(proxied, 3)
    proxy.silence_all()
    proxy.wake = 2.0
    later = time.time() + 600
    monkeypatch.setattr(base, "_wall_clock", lambda: later)

    pid, took = _timed(proxied)

    assert pid not in pids
    assert 2.0 <= took < 2.0 + NO_BACK_OFF_SECONDS, f"the request took {took:.2f} s"


def test_a_silent_dead_connection_costs_a_request_one_probe_at_most(
    pooled, monkeypatch
):
    # Frozen only seconds, so the connections are probed: each probe of a dead
    # one hangs until the network gives up (`tcp_user_timeout` live), here 1 s.
    pids = _idle(pooled, 3)
    probes: list[int] = []
    probe = ConnectionPool.check_connection

    def silent(conn: Any) -> None:
        if conn.info.backend_pid in pids:
            probes.append(conn.info.backend_pid)
            time.sleep(1.0)
            raise psycopg.OperationalError("no answer")
        probe(conn)

    monkeypatch.setattr(ConnectionPool, "check_connection", staticmethod(silent))

    pid, took = _timed(pooled)

    assert pid not in pids
    assert len(probes) == 1
    assert took < 1.0 + NO_BACK_OFF_SECONDS, f"the request waited {took:.2f} s"


def test_a_slow_wait_for_a_connection_is_logged(pooled, monkeypatch, caplog):
    _a_request(pooled)
    probe = ConnectionPool.check_connection

    def slow(conn: Any) -> None:
        time.sleep(base.SLOW_BORROW_SECONDS + 0.1)
        probe(conn)

    monkeypatch.setattr(ConnectionPool, "check_connection", staticmethod(slow))

    with caplog.at_level(logging.WARNING, logger="apps.core.pooled_postgres.base"):
        _a_request(pooled)

    assert "getting a connection took" in caplog.text
