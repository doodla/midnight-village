"""Django's PostgreSQL backend whose connection pool survives a frozen instance.

The live settings (``config/settings/vercel.py``) keep a warm instance's database
connections between requests with Django's built-in psycopg pool
(``OPTIONS["pool"]``), so a request no longer pays TCP, TLS and the sign-in. A
function instance can be frozen between requests for minutes, and the database can
close its connections meanwhile (Neon suspends an idle compute), so every connection
is checked when it is borrowed: one empty query.

Why this backend and not Django's own: when a borrowed connection fails its check,
psycopg's pool tries the next one at once, but waits 1 s before the third try, 2 s
before the fourth (its back-off). After a freeze every idle connection is dead
together, so a pool with three idle connections would stall the first tap by a
second. Here the first failed check also checks every other idle connection at once
(``ConnectionPool.check()``, psycopg's own public sweep: dead ones are dropped and
replaced in the background), so the pool's second try finds a live connection or a
new one, never the back-off.

Everything else is Django's backend unchanged (``ENGINE = "apps.core.pooled_postgres"``).
"""

from __future__ import annotations

import logging
from typing import Any

from django.core.exceptions import ImproperlyConfigured
from django.db.backends.base.base import NO_DB_ALIAS
from django.db.backends.postgresql import base as postgresql

logger = logging.getLogger(__name__)


def _checked(pool_box: dict[str, Any]) -> Any:
    """The check run on every borrowed connection (``pool_box["pool"]`` is its pool)."""
    from psycopg_pool import ConnectionPool

    def check(conn: Any) -> None:
        try:
            ConnectionPool.check_connection(conn)
        except Exception:
            pool = pool_box.get("pool")
            if pool is not None:
                logger.info("database pool: a dead connection; checking the others")
                pool.check()
            raise

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
                configure=self._configure_connection,
                check=_checked(box),
                **options,
            )
            box["pool"] = pool
            # As Django's: the first thread to set it wins.
            self._connection_pools.setdefault(self.alias, pool)
        return self._connection_pools[self.alias]
