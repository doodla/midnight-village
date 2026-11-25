"""Django's PostgreSQL backend whose connection pool survives a frozen instance.

The live settings (``config/settings/vercel.py``) keep a warm instance's database
connections between requests with Django's built-in psycopg pool
(``OPTIONS["pool"]``), so a request no longer pays TCP, TLS and the sign-in.

A function instance can be frozen between requests for minutes, and meanwhile the
database can close its connections (Neon suspends an idle compute) or their network
path can vanish without a word. So a request trusts a lent connection only after
this check (``_checked``), which talks to the database at most once:

* a connection unused for over ``STALE_AFTER_SECONDS`` (wall clock, which a frozen
  instance's clock catches up on) is not probed: after a thaw it is probably dead,
  and a dead path can hold a probe for seconds;
* otherwise one empty query; a dead path fails it within ``tcp_user_timeout``.

Either failure closes that connection and drains the pool: every idle connection
is closed locally, without talking to it (they died together), and replaced in the
background. psycopg then tries again at once and the request gets a new connection,
so a thaw costs one connect. (psycopg's own way, without this, went through the dead
ones one at a time with a 1 s, then 2 s back-off; its ``check()`` probes them one by
one in the request.) ``tests/core/test_db_pool.py`` holds both paths, with dead
connections that reset and ones that stay silent.

Getting a connection that takes over ``SLOW_BORROW_SECONDS`` is logged as a warning:
a lent connection puts no ``connect`` in ``Server-Timing``, so a wait for the pool
would not show there.

Everything else is Django's backend unchanged (``ENGINE = "apps.core.pooled_postgres"``).
"""

from __future__ import annotations

import logging
import time
from typing import Any

from django.core.exceptions import ImproperlyConfigured
from django.db.backends.base.base import NO_DB_ALIAS
from django.db.backends.postgresql import base as postgresql

logger = logging.getLogger(__name__)

STALE_AFTER_SECONDS = 60
SLOW_BORROW_SECONDS = 1.0

# Set on a connection the pool has just opened; taken off when it is first lent.
NEW = "_opened_for_the_pool"
# When Django last gave the connection back (wall clock); taken off when lent.
IDLE_SINCE = "_idle_since_for_the_pool"


class UntrustedConnectionError(Exception):
    """A lent connection that failed its check (psycopg then tries another)."""


def _wall_clock() -> float:
    return time.time()


def note_idle(connection: Any) -> None:
    setattr(connection, IDLE_SINCE, _wall_clock())


def _checked(pool_box: dict[str, Any]) -> Any:
    """The check run on every lent connection (``pool_box["pool"]`` is its pool)."""
    from psycopg_pool import ConnectionPool

    def check(conn: Any) -> None:
        idle_since = vars(conn).pop(IDLE_SINCE, None)
        if idle_since is not None and _wall_clock() - idle_since > STALE_AFTER_SECONDS:
            why = "unused for over a minute"
        else:
            try:
                ConnectionPool.check_connection(conn)
                return
            except Exception:
                why = "dead"
        logger.info("database pool: a lent connection was %s; draining", why)
        conn.close()  # local: a dead path is never waited on
        pool = pool_box.get("pool")
        if pool is not None:
            pool.drain()
        raise UntrustedConnectionError(why)

    return check


class DatabaseWrapper(postgresql.DatabaseWrapper):
    @property
    def pool(self) -> Any:
        pool_options = self.settings_dict["OPTIONS"].get("pool")
        if self.alias == NO_DB_ALIAS or not pool_options:
            return None
        if self.alias not in self._connection_pools:
            if self.settings_dict.get("CONN_MAX_AGE", 0) != 0:
                raise ImproperlyConfigured(
                    "Pooling doesn't support persistent connections."
                )
            from psycopg_pool import ConnectionPool

            options: dict[str, Any] = {} if pool_options is True else dict(pool_options)
            params: Any = self.get_connection_params()
            connect_kwargs: dict[str, Any] = dict(params)
            # Django sets autocommit itself later on, as in its own backend.
            connect_kwargs["autocommit"] = True
            box: dict[str, Any] = {}
            pool = ConnectionPool(
                kwargs=connect_kwargs,
                open=False,  # opened by the first request that needs it
                configure=self._configure_new,
                check=_checked(box),
                **options,
            )
            box["pool"] = pool
            # As Django's: the first thread to set it wins.
            self._connection_pools.setdefault(self.alias, pool)
        return self._connection_pools[self.alias]

    # Whether this request's connection was lent again by the pool (no TCP, TLS or
    # sign-in): the Server-Timing header then has no ``connect`` part.
    reused_connection = False

    def _configure_new(self, connection: Any) -> None:
        """The pool's ``configure``: runs once per connection it opens."""
        self._configure_connection(connection)
        setattr(connection, NEW, True)

    def get_new_connection(self, conn_params: Any) -> Any:
        self.reused_connection = False
        began = time.monotonic()
        connection = super().get_new_connection(conn_params)
        if self.pool is not None:
            self.reused_connection = not vars(connection).pop(NEW, False)
            took = time.monotonic() - began
            if took > SLOW_BORROW_SECONDS:
                logger.warning(
                    "database pool: getting a connection took %.1f s (%s)",
                    took,
                    "lent again" if self.reused_connection else "opened",
                )
        return connection

    def _close(self) -> None:
        if self.connection is not None and self.pool is not None:
            note_idle(self.connection)
        super()._close()
