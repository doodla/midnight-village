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

    winning_teams: list[str]  # e.g. ["village"], ["tanner", "village"], []
    eliminated_players: list[int]
    player_outcomes: dict[int, str]  # player_id -> "win" or "lose"
    reason: str  # human-readable explanation


def _get_card_copied_role(doppelganger_copied: dict[int, str]) -> str | None:
    """Get the role that the Doppelganger card copied.

    The copied role is a property of the CARD, not the player who
    originally held it. There is at most one Doppelganger card in
    any ONUW game, so the dict has at most one entry.

    Returns None if no Doppelganger copy occurred (card was in the
    center or never dealt).
    """
    if not doppelganger_copied:
        return None
    return next(iter(doppelganger_copied.values()))


def get_effective_team(
    player_id: int,
    player_roles: dict[int, str],
    doppelganger_copied: dict[int, str],
) -> str:
    """
    Get a player's effective team based on their current role.

    The copied role is a property of the Doppelganger CARD. Any player
    currently holding that card inherits the copied role's team — whether
    they are the original Doppelganger or received the card via swap.
    """
    role = player_roles.get(player_id, "")

    if role == "Doppelganger":
        # This player holds the Doppelganger card. The card's copied
        # role determines team, regardless of who originally copied.
        copied = _get_card_copied_role(doppelganger_copied)
        if copied is not None:
            role = copied
        else:
            # Doppelganger card with no copy (e.g. swapped in from center
            # where no Doppelganger was dealt). Base team is village.
            return "village"

    if role in _WEREWOLF_TEAM_ROLES:
        return "werewolf"
    if role in _NEUTRAL_ROLES:
        return "neutral"
    # All other roles (including unknown) default to village
    return "village"


def _get_effective_role(
    player_id: int,
    player_roles: dict[int, str],
    doppelganger_copied: dict[int, str],
) -> str:
    """
    Get a player's effective role, resolving Doppelganger to the card's copied role.

    The copied role is a property of the Doppelganger CARD. Any player
    currently holding that card inherits the copied role.
    """
    role = player_roles.get(player_id, "")
    if role == "Doppelganger":
        copied = _get_card_copied_role(doppelganger_copied)
        if copied is not None:
            return copied
    return role


def _is_effective_minion(
    player_id: int,
    player_roles: dict[int, str],
    doppelganger_copied: dict[int, str],
) -> bool:
    """Check if a player is effectively a Minion (including Doppelganger-as-Minion)."""
    return _get_effective_role(player_id, player_roles, doppelganger_copied) == "Minion"


def evaluate_winner(
    eliminated: list[int],
    player_roles: dict[int, str],
    doppelganger_copied: dict[int, str] | None = None,
) -> GameResult:
    """
    Evaluate win conditions after elimination is determined.

    Win conditions are NOT mutually exclusive. Multiple teams can win.

    Algorithm:
    1. Determine effective roles (resolve Doppelganger)
    2. Identify werewolf_players, tanner_players, minion_players
    3. Tanner win (independent): if any Tanner is eliminated, "tanner" wins
    4. Village vs Werewolf:
       a. If werewolf_players exist:
          - If any werewolf died -> "village" wins
          - If no werewolf died AND tanner did NOT die -> "werewolf" wins
          - If no werewolf died AND tanner died -> werewolves do NOT win
       b. If no werewolf_players exist:
          - If no one died -> "village" wins
          - If Minion exists and a non-Minion/non-Doppelganger-as-Minion died
            -> "werewolf" wins
          - If only Minion died -> no team wins
          - Otherwise (no Minion, someone died) -> no one wins
    5. Build player_outcomes based on winning_teams
    """
    if doppelganger_copied is None:
        doppelganger_copied = {}

    # Determine teams for all players
    player_teams: dict[int, str] = {}
    for pid in player_roles:
        player_teams[pid] = get_effective_team(pid, player_roles, doppelganger_copied)

    # Identify werewolf-role players using effective role resolution.
    # This correctly handles: real Werewolf cards, Doppelganger card
    # that copied Werewolf (regardless of who now holds it), and
    # ignores the original Doppelganger if their card was swapped away.
    werewolf_role_players = [
        pid
        for pid in player_roles
        if _get_effective_role(pid, player_roles, doppelganger_copied) == "Werewolf"
    ]

    werewolves_in_game = len(werewolf_role_players) > 0

    # Identify minion players (Minion or Doppelganger-as-Minion)
    minion_players = [
        pid
        for pid in player_roles
        if _is_effective_minion(pid, player_roles, doppelganger_copied)
    ]

    # Check eliminated players' effective roles
    eliminated_tanners = [
        pid for pid in eliminated if player_teams.get(pid) == "neutral"
    ]
    eliminated_werewolves = [
        pid
        for pid in eliminated
        if _get_effective_role(pid, player_roles, doppelganger_copied) == "Werewolf"
    ]

    # --- Evaluate winning teams (non-mutually-exclusive) ---
    winning_teams: list[str] = []
    reasons: list[str] = []

    # Step 3: Tanner win (independent check)
    tanner_wins = len(eliminated_tanners) > 0
    if tanner_wins:
        winning_teams.append("tanner")
        reasons.append("Tanner was eliminated and wins!")

    # Step 4: Village vs Werewolf
    if werewolves_in_game:
        # 4a: Werewolves exist among players
        if eliminated_werewolves:
            # A werewolf died -> village wins
            winning_teams.append("village")
            reasons.append("A Werewolf was eliminated.")
        elif not tanner_wins:
            # No werewolf died AND tanner did NOT die -> werewolves win
            winning_teams.append("werewolf")
            reasons.append("No Werewolf was eliminated. Werewolves win!")
        # else: no werewolf died AND tanner died -> WW blocked, no WW win
    else:
        # 4b: No werewolves among players
        if not eliminated:
            # No one died -> village wins
            winning_teams.append("village")
            reasons.append(
                "No werewolves in play and no one was eliminated. Village wins!"
            )
        elif minion_players:
            # Minion exists -- check who died
            # Check if any non-Minion player died
            eliminated_non_minion = [
                pid
                for pid in eliminated
                if not _is_effective_minion(pid, player_roles, doppelganger_copied)
                and player_teams.get(pid) != "neutral"  # Tanner is handled separately
            ]
            eliminated_only_minions = all(
                _is_effective_minion(pid, player_roles, doppelganger_copied)
                for pid in eliminated
                if player_teams.get(pid) != "neutral"
            )

            if eliminated_non_minion:
                # A non-Minion/non-Tanner died -> werewolf team wins
                winning_teams.append("werewolf")
                reasons.append(
                    "No werewolves in play, but a non-Minion player was eliminated. "
                    "Minion wins for the Werewolf team!"
                )
            elif eliminated_only_minions and not tanner_wins:
                # Only Minion(s) died, no Tanner died -> no team wins
                pass  # No team added
            # If tanner_wins and only Minions died among non-Tanners,
            # no additional team wins beyond Tanner
        else:
            # No Minion, no Werewolves, someone died
            if not tanner_wins:
                # No Tanner died either -> nobody wins
                pass  # No team added

    # Build reason string
    reason = (
        " ".join(reasons)
        if reasons
        else (
            "No werewolves in play, but the village eliminated one of their own. Nobody wins."
        )
    )

    # Step 5: Build player outcomes
    outcomes: dict[int, str] = {}
    for pid in player_roles:
        team = player_teams[pid]
        won = False

        if "village" in winning_teams and team == "village":
            won = True
        elif "werewolf" in winning_teams and team == "werewolf":
            won = True
        elif (
            "tanner" in winning_teams
            and team == "neutral"
            and pid in eliminated_tanners
        ):
            # Tanner only wins if actually eliminated
            won = True

        outcomes[pid] = "win" if won else "lose"

    return GameResult(
        winning_teams=winning_teams,
        eliminated_players=sorted(eliminated),
        player_outcomes=outcomes,
        reason=reason,
    )
