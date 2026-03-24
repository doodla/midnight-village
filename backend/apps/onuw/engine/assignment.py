"""
Pure-Python role assignment for ONUW games.

NO Django imports allowed in this module. This is pure game logic.
"""

from __future__ import annotations

import random


def assign_roles(
    role_counts: dict[str, int],
    player_ids: list[int],
    seed: int,
) -> tuple[dict[int, str], list[str]]:
    """
    Deterministically assign roles to players and center cards.

    Args:
        role_counts: Mapping of role name to count, e.g. {"Werewolf": 2, "Seer": 1}.
        player_ids: List of player user IDs.
        seed: Random seed for deterministic assignment.

    Returns:
        Tuple of (player_id_to_role, center_cards).
        - player_id_to_role: dict mapping each player ID to their assigned role name.
        - center_cards: list of 3 role names for the center.
    """
    rng = random.Random(seed)  # noqa: S311 — seeded for deterministic replay, not cryptographic use

    # Build the pool of all role cards
    pool: list[str] = []
    for role_name, count in sorted(role_counts.items()):
        pool.extend([role_name] * count)

    # Shuffle deterministically
    rng.shuffle(pool)

    # First N cards go to players, remaining 3 go to center
    player_id_to_role: dict[int, str] = {}
    for i, player_id in enumerate(sorted(player_ids)):
        player_id_to_role[player_id] = pool[i]

    center_cards = pool[len(player_ids) :]

    return player_id_to_role, center_cards
