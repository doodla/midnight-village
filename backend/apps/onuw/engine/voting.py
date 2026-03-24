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

    # Spec: a player must receive at least 2 votes to be eliminated.
    if max_votes < 2:
        return []

    top_players = [pid for pid, count in vote_counts.items() if count == max_votes]

    return sorted(top_players)


def _is_hunter(
    pid: int,
    player_roles: dict[int, str],
    doppelganger_copied: dict[int, str] | None,
) -> bool:
    """Check if a player holds an effective Hunter role.

    A player is Hunter if:
    - Their current role card is "Hunter", OR
    - Their current role card is "Doppelganger" and they copied "Hunter".
    """
    role = player_roles.get(pid, "")
    if role == "Hunter":
        return True
    if (
        role == "Doppelganger"
        and doppelganger_copied
        and doppelganger_copied.get(pid) == "Hunter"
    ):
        return True
    return False


def apply_hunter(
    eliminated: list[int],
    player_roles: dict[int, str],
    votes: dict[int, int | None],
    doppelganger_copied: dict[int, str] | None = None,
) -> list[int]:
    """
    Apply Hunter chain-kill (no recursion).

    If any eliminated player holds the Hunter role (including
    Doppelganger-as-Hunter), add their vote target to eliminated.

    Spec: "Hunter chain kills do NOT recurse. If the Hunter kills a
    Doppelganger-as-Hunter, that second 'Hunter' does not trigger a
    further chain." Only the initially eliminated Hunters trigger kills;
    newly added targets never trigger further kills regardless of their
    role.

    Ignore None vote targets (Hunter abstained).
    Return updated elimination list (sorted, no duplicates).
    """
    result = set(eliminated)

    # Only check the INITIALLY eliminated players for Hunter role.
    # Do NOT check newly added targets (no recursion).
    for pid in eliminated:
        if _is_hunter(pid, player_roles, doppelganger_copied):
            target = votes.get(pid)
            if target is not None:
                result.add(target)

    return sorted(result)
