"""
Pure-Python win condition evaluation for ONUW.

NO Django imports allowed in this module. This is pure game logic.
"""

from __future__ import annotations

from dataclasses import dataclass

# Team classification for roles
_WEREWOLF_TEAM_ROLES = frozenset({"Werewolf", "Minion"})
_VILLAGE_TEAM_ROLES = frozenset(
    {
        "Villager",
        "Seer",
        "Robber",
        "Troublemaker",
        "Drunk",
        "Insomniac",
        "Hunter",
        "Mason",
        "Doppelganger",
    }
)
_NEUTRAL_ROLES = frozenset({"Tanner"})


@dataclass(frozen=True)
class GameResult:
    """Immutable result of evaluating win conditions."""

    winning_team: str  # "village", "werewolf", "tanner", "no_one"
    eliminated_players: list[int]
    player_outcomes: dict[int, str]  # player_id -> "win" or "lose"
    reason: str  # human-readable explanation


def get_effective_team(
    player_id: int,
    player_roles: dict[int, str],
    doppelganger_copied: dict[int, str],
) -> str:
    """
    Get a player's effective team based on their current role.

    If a player's current_role is "Doppelganger" (meaning they are the
    original Doppelganger and were never swapped away from that card),
    use their copied role for team determination.

    If someone was swapped TO a "Doppelganger" card (and is NOT the
    original Doppelganger), treat them as village team since
    Doppelganger's base team is village.
    """
    role = player_roles.get(player_id, "")

    if role == "Doppelganger":
        # This is someone holding the Doppelganger card.
        # If they are the original Doppelganger, use copied role.
        copied = doppelganger_copied.get(player_id)
        if copied is not None:
            role = copied
        else:
            # Non-original player swapped to Doppelganger card, or
            # original Doppelganger who didn't copy (shouldn't happen in
            # normal play). Treat as village.
            return "village"

    if role in _WEREWOLF_TEAM_ROLES:
        return "werewolf"
    if role in _NEUTRAL_ROLES:
        return "neutral"
    # All other roles (including unknown) default to village
    return "village"


def evaluate_winner(
    eliminated: list[int],
    player_roles: dict[int, str],
    doppelganger_copied: dict[int, str] | None = None,
) -> GameResult:
    """
    Evaluate win conditions after elimination is determined.

    Rules (evaluated in priority order):

    1. Tanner eliminated -> Tanner wins. Only the Tanner(s) get "win".
    2. Werewolf eliminated (and Tanner not) -> Village wins.
    3. No werewolf eliminated AND werewolves exist -> Werewolves win.
    4. No werewolves in game AND no one eliminated -> Village wins.
    5. No werewolves in game AND someone eliminated ->
       If Tanner eliminated: Tanner wins (same as rule 1).
       Otherwise: no_one wins (village made a mistake).
    """
    if doppelganger_copied is None:
        doppelganger_copied = {}

    # Determine teams for all players
    player_teams: dict[int, str] = {}
    for pid in player_roles:
        player_teams[pid] = get_effective_team(pid, player_roles, doppelganger_copied)

    # Check if any actual werewolf-role player exists (not just Minion)
    werewolf_role_players = [
        pid for pid, role in player_roles.items() if role == "Werewolf"
    ]
    # Also check doppelganger-as-werewolf
    for pid, copied in doppelganger_copied.items():
        if copied == "Werewolf" and pid not in werewolf_role_players:
            werewolf_role_players.append(pid)

    werewolves_in_game = len(werewolf_role_players) > 0

    # Check eliminated players' teams
    eliminated_tanners = [
        pid for pid in eliminated if player_teams.get(pid) == "neutral"
    ]
    eliminated_werewolves = [
        pid for pid in eliminated if player_roles.get(pid) == "Werewolf"
    ]
    # Also count doppelganger-as-werewolf in eliminated werewolves
    for pid in eliminated:
        if (
            player_roles.get(pid) == "Doppelganger"
            and doppelganger_copied.get(pid) == "Werewolf"
            and pid not in eliminated_werewolves
        ):
            eliminated_werewolves.append(pid)

    # Rule 1 & 5b: Tanner eliminated -> Tanner wins
    if eliminated_tanners:
        outcomes: dict[int, str] = {}
        for pid in player_roles:
            if pid in eliminated_tanners and player_teams.get(pid) == "neutral":
                outcomes[pid] = "win"
            else:
                outcomes[pid] = "lose"
        return GameResult(
            winning_team="tanner",
            eliminated_players=sorted(eliminated),
            player_outcomes=outcomes,
            reason="Tanner was eliminated and wins!",
        )

    # Rule 2: Werewolf eliminated (and Tanner not) -> Village wins
    if eliminated_werewolves:
        outcomes = {}
        for pid in player_roles:
            team = player_teams[pid]
            if team == "village":
                outcomes[pid] = "win"
            else:
                outcomes[pid] = "lose"
        return GameResult(
            winning_team="village",
            eliminated_players=sorted(eliminated),
            player_outcomes=outcomes,
            reason="A Werewolf was eliminated.",
        )

    # Rule 3: No werewolf eliminated AND werewolves exist -> Werewolves win
    if werewolves_in_game:
        outcomes = {}
        for pid in player_roles:
            team = player_teams[pid]
            if team == "werewolf":
                outcomes[pid] = "win"
            else:
                outcomes[pid] = "lose"
        return GameResult(
            winning_team="werewolf",
            eliminated_players=sorted(eliminated),
            player_outcomes=outcomes,
            reason="No Werewolf was eliminated. Werewolves win!",
        )

    # No werewolves in game
    # Rule 4: No one eliminated -> Village wins
    if not eliminated:
        outcomes = {}
        for pid in player_roles:
            team = player_teams[pid]
            if team in ("village", "neutral"):
                # In a no-werewolf game, even Tanner is considered
                # non-werewolf. But Tanner only truly "wins" by dying.
                # If no one died, Tanner doesn't win but village does.
                outcomes[pid] = "win" if team == "village" else "lose"
            else:
                outcomes[pid] = "lose"
        return GameResult(
            winning_team="village",
            eliminated_players=[],
            player_outcomes=outcomes,
            reason="No werewolves in play and no one was eliminated. Village wins!",
        )

    # Rule 5a: No werewolves in game AND someone eliminated AND not Tanner
    # -> no_one wins
    outcomes = {}
    for pid in player_roles:
        outcomes[pid] = "lose"
    return GameResult(
        winning_team="no_one",
        eliminated_players=sorted(eliminated),
        player_outcomes=outcomes,
        reason="No werewolves in play, but the village eliminated one of their own. Nobody wins.",
    )
