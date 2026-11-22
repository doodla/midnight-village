"""
What a practice player picks: one legal random choice, from the same data a phone
reads.

A practice player answers the prompt ``GET /me/`` would show it
(``engine.choose.build_choose_prompt``): one of the prompt's ``shapes`` chosen
uniformly, then that many distinct cards of that kind uniformly from the prompt's
board. The server reads the picks exactly as it reads a phone's
(``engine.choose.interpret_choice``), so a practice player can do nothing a person
could not. With nothing to choose (``chooses_left`` 0, or no shape that names
cards) the picks are empty: "You"-or-nothing, which reads as nothing for every
role. Its vote is one of the prompt's targets, uniformly.

Every draw comes from a ``random.Random`` seeded from the game's seed, a label for
the step and the player's seat (``practice_rng``), so a replay of the same game,
even with other accounts in the same seats, makes the same choices.

NO Django imports allowed in this module. This is pure game logic.
"""

from __future__ import annotations

import random
from collections.abc import Sequence
from typing import Any


def practice_rng(game_seed: int, label: str, seat: int) -> random.Random:
    """The seeded draw for one practice player's step (``label``: the stage and
    how many chooses it has sent, or ``vote``; ``seat``: where it sits)."""
    return random.Random(f"{game_seed}:practice:{label}:{seat}")  # noqa: S311 (seeded, not secret)


def practice_picks(prompt: dict[str, Any], rng: random.Random) -> list[dict[str, int]]:
    """The picks a practice player sends for ``prompt`` (a ``choose`` prompt)."""
    if prompt.get("chooses_left", 0) <= 0:
        return []
    board = prompt.get("valid_targets") or {}
    players = list(board.get("player_ids") or [])
    centre = list(board.get("center_indices") or [])
    shapes = [
        shape
        for shape in prompt.get("shapes") or []
        if _fits(shape, len(players), len(centre))
    ]
    if not shapes:
        return []
    shape = rng.choice(shapes)
    if "players" in shape:
        return [{"player_id": pid} for pid in rng.sample(players, shape["players"])]
    return [{"center_index": i} for i in rng.sample(centre, shape["center"])]


def _fits(shape: dict[str, int], players: int, centre: int) -> bool:
    """A shape that names cards the board holds enough of (``{"any": 1}`` names
    none: it is the shape of a phone with nothing to choose)."""
    if "players" in shape:
        return 0 < shape["players"] <= players
    if "center" in shape:
        return 0 < shape["center"] <= centre
    return False


def practice_vote(targets: Sequence[int], rng: random.Random) -> int | None:
    """Whom a practice player votes for: one of ``targets`` (every other player),
    uniformly; None when there is nobody."""
    return rng.choice(list(targets)) if targets else None
