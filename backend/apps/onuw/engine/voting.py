"""
Pure-Python vote counting and elimination logic for ONUW.

NO Django imports allowed in this module. This is pure game logic.
"""

from __future__ import annotations


def count_votes(votes: dict[int, int | None]) -> dict[int, int]:
    """
    Count votes. Maps player_id -> vote_count.
    Ignores None (abstains).
    """
    counts: dict[int, int] = {}
    for target in votes.values():
        if target is not None:
            counts[target] = counts.get(target, 0) + 1
    return counts


def determine_elimination(vote_counts: dict[int, int]) -> list[int]:
    """
    Determine who is eliminated.

    - Player(s) with most votes are eliminated.
    - If ALL players who received votes are tied (everyone has same count),
      no one is eliminated.
    - If a subset tie for most, all in that subset are eliminated.
    - If no votes were cast, no one is eliminated.
    """
    if not vote_counts:
        return []

    max_votes = max(vote_counts.values())
    top_players = [pid for pid, count in vote_counts.items() if count == max_votes]

    # If ALL voted-for players have the same count AND there are multiple
    # recipients, no one is eliminated (complete tie). A single player
    # receiving all votes is still eliminated.
    if len(top_players) == len(vote_counts) and len(vote_counts) > 1:
        return []

    return sorted(top_players)


def apply_hunter(
    eliminated: list[int],
    player_roles: dict[int, str],
    votes: dict[int, int | None],
) -> list[int]:
    """
    Apply Hunter chain-kill.

    If any eliminated player's current_role is "Hunter", add their vote
    target to eliminated. Handle chains: if Hunter A kills Hunter B,
    Hunter B's target is also added. Ignore None vote targets (Hunter
    abstained). Return updated elimination list (no duplicates).
    """
    result = set(eliminated)
    # Process hunters iteratively to handle chains
    queue = [pid for pid in eliminated if player_roles.get(pid) == "Hunter"]

    while queue:
        hunter_id = queue.pop(0)
        target = votes.get(hunter_id)
        if target is not None and target not in result:
            result.add(target)
            # If the newly eliminated player is also a Hunter, chain
            if player_roles.get(target) == "Hunter":
                queue.append(target)

    return sorted(result)
