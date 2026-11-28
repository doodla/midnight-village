"""What the server counts of itself for the owner's report (``ServerCount``).

``add(word)`` is one statement: this hour's row of ``word`` (the database's clock)
made or raised by one. Only words of ``vocabulary.SERVER_COUNTS``; no ids. Rows
older than 30 days go with the next count of their word.
"""

from __future__ import annotations

from django.db import connection

from .models import ServerCount
from .vocabulary import SERVER_COUNTS

KEEP_DAYS = 30


def add(word: str) -> None:
    """Count one ``word`` for this hour."""
    if word not in SERVER_COUNTS:
        raise ValueError(f"not a server count: {word!r}")
    table = ServerCount._meta.db_table
    sql = f"""
        WITH gone AS (
          DELETE FROM {table}
          WHERE word = %s AND hour < STATEMENT_TIMESTAMP() - make_interval(days => %s)
        )
        INSERT INTO {table} (word, hour, n)
        VALUES (%s, date_trunc('hour', STATEMENT_TIMESTAMP()), 1)
        ON CONFLICT (word, hour) DO UPDATE SET n = {table}.n + 1
    """  # noqa: S608 (the table name from the model, values as parameters)
    with connection.cursor() as cursor:
        cursor.execute(sql, [word, KEEP_DAYS, word])


def totals() -> dict[str, int]:
    """Each word's count over the rows kept (the last 30 days)."""
    out: dict[str, int] = {}
    for word, n in ServerCount.objects.values_list("word", "n"):
        out[word] = out.get(word, 0) + n
    return dict(sorted(out.items()))
