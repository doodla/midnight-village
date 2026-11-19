"""
How many people are at tables right now, from live socket rows.

Counts come from the sockets players hold open (a row per socket, kept fresh by a
heartbeat, see ``apps.core.presence``), on the database clock: nothing is kept in
a process, so any instance gives the same answer. Core knows its own lobby sockets;
a game app registers a source for its game sockets (``register_online_source``),
so core imports no game app.

A person on the home screen holds no socket and is not counted: the honest label
is "players at tables".
"""

from __future__ import annotations

from collections.abc import Callable, Iterable
from typing import Any

from apps.core import presence

# A source returns (user id, lobby id) for each fresh socket it knows about.
OnlineSource = Callable[[], Iterable[tuple[int, int]]]

_sources: list[OnlineSource] = []


def register_online_source(source: OnlineSource) -> None:
    """Add a game app's fresh sockets to the count (once per source)."""
    if source not in _sources:
        _sources.append(source)


def _lobby_sockets() -> Iterable[tuple[int, int]]:
    return presence.fresh_rows().values_list("user_id", "lobby_id")


def online_counts() -> dict[str, int]:
    """``{"players": distinct users, "tables": distinct lobbies}`` with a fresh socket."""
    pairs: set[tuple[Any, Any]] = set()
    for source in (_lobby_sockets, *_sources):
        pairs.update(source())
    return {
        "players": len({user_id for user_id, _ in pairs}),
        "tables": len({lobby_id for _, lobby_id in pairs}),
    }
