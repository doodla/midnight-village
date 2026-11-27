"""The game's socket group names: the one place they are spelled.

A game socket joins both (``GameConsumer``); the stage sends and the own views
address them through these, and so does the contract recorder, so a group cannot
be named one way where it is joined and another where it is sent to.
"""

from __future__ import annotations

from typing import Any


def game_group(game_id: Any) -> str:
    """The whole table's group: every socket of the game."""
    return f"game_{game_id}"


def player_group(game_id: Any, user_id: int) -> str:
    """One player's own sockets of the game (their own view, nothing else)."""
    return f"game_{game_id}_player_{user_id}"
