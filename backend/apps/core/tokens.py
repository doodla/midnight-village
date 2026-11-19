"""
Player tokens: the small picture that stands for a player at the table.

A token is public table identity, never tied to a role. Each lobby hands them
out in an order that depends only on its code (so the same code and join order
always give the same tokens); a new member takes the first one nobody in the
lobby holds. The caller holds the Lobby row lock (see
``apps.core.lobbies.add_member``), so two joins never take the same token.
"""

from __future__ import annotations

import random
from collections.abc import Collection
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from apps.core.models import Lobby

TOKENS: tuple[str, ...] = (
    "crow",
    "key",
    "moth",
    "bell",
    "thorn",
    "antler",
    "hare",
    "lantern",
    "spindle",
    "scythe",
)

MAX_TABLE_SIZE = len(TOKENS)


def token_order(code: str) -> list[str]:
    """Every token, in the order this lobby code hands them out."""
    rng = random.Random(f"{code}:tokens")  # noqa: S311 (seeded for replay, not secret)
    return rng.sample(TOKENS, MAX_TABLE_SIZE)


def first_free_token(code: str, taken: Collection[str]) -> str | None:
    """The first token in the lobby's order not in ``taken`` (None = all are used)."""
    return next((t for t in token_order(code) if t not in taken), None)


def assign_token(lobby: Lobby) -> str | None:
    """The token the next member of ``lobby`` gets (None when every token is held).

    Call with the Lobby row locked.
    """
    taken = set(lobby.players.values_list("token", flat=True))  # type: ignore[attr-defined]
    return first_free_token(lobby.code, taken)
