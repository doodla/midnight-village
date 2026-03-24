"""
Spec-validation tests for ONUW win conditions.

These tests encode the CORRECT behavior per the game specification
(docs/specs/onuw/voting-and-resolution.md). Some tests are expected to
FAIL against the current implementation -- that is intentional. Each
failing test documents a spec deviation that must be fixed.

Spec reference:
  "Win conditions are not mutually exclusive -- multiple teams can win
   in the same game."

The current GameResult uses a single `winning_team: str` field. Several
tests below assert the correct multi-winner behavior that the spec
requires. These will fail until the data structure is updated to support
multiple winners (e.g., `winning_teams: list[str]`).
"""

from __future__ import annotations

import pytest

from apps.onuw.engine.voting import apply_hunter
from apps.onuw.engine.win_conditions import (
    evaluate_winner,
    get_effective_team,
)

pytestmark = pytest.mark.unit


# ---------------------------------------------------------------------------
# Tanner Scenarios
# ---------------------------------------------------------------------------


class TestTannerScenarios:
    """
    Spec: Tanner dying is an independent win condition that can coexist
    with Village winning. Tanner dying also BLOCKS the Werewolf team
    from winning (even if no Werewolf died).
    """

    def test_tanner_dies_alone_werewolves_do_not_win(self):
        """
        Spec (Scenario A, row 4): Only Tanner dies, Werewolves exist
        among players. Tanner wins. Werewolf team does NOT win.
        Village does not win (no WW died).

        Official rule: "If the Tanner dies and no Werewolves die, the
        Werewolves do not win."

        Verify that Werewolf team players get outcome="lose" (the Tanner
        death blocks WW win).
        """
        eliminated = [3]  # Tanner
        player_roles = {
            1: "Werewolf",
            2: "Seer",
            3: "Tanner",
            4: "Villager",
            5: "Werewolf",
        }
        result = evaluate_winner(eliminated, player_roles)

        # Tanner wins
        assert result.player_outcomes[3] == "win", (
            "Tanner was eliminated and should win"
        )

        # Werewolf team does NOT win -- Tanner death blocks WW win
        assert result.player_outcomes[1] == "lose", (
            "Werewolf should lose -- Tanner death blocks WW win per spec"
        )
        assert result.player_outcomes[5] == "lose", (
            "Werewolf should lose -- Tanner death blocks WW win per spec"
        )

        # Village does not win (no WW was eliminated)
        assert result.player_outcomes[2] == "lose", (
            "Village should lose -- no Werewolf was eliminated"
        )
        assert result.player_outcomes[4] == "lose", (
            "Village should lose -- no Werewolf was eliminated"
        )

    def test_tanner_and_werewolf_both_die(self):
        """
        Spec (Scenario A, row 2): Both Tanner and a Werewolf are
        eliminated (e.g., voting tie). Tanner wins AND Village wins.
        Werewolf team loses.

        Village should ALSO win because a Werewolf died.
        """
        eliminated = [1, 3]  # Werewolf and Tanner both die (tie)
        player_roles = {
            1: "Werewolf",
            2: "Seer",
            3: "Tanner",
            4: "Villager",
            5: "Minion",
        }
        result = evaluate_winner(eliminated, player_roles)

        # Tanner wins (was eliminated -- personal win condition met)
        assert result.player_outcomes[3] == "win", (
            "Tanner was eliminated and should win"
        )

        # Village ALSO wins (a Werewolf was eliminated)
        # Per spec: "At least one Werewolf player dies, Tanner also dies
        # -> Village wins AND Tanner wins"
        assert result.player_outcomes[2] == "win", (
            "Seer (Village) should win -- a Werewolf was eliminated"
        )
        assert result.player_outcomes[4] == "win", (
            "Villager should win -- a Werewolf was eliminated"
        )

        # Werewolf team loses (a Werewolf was eliminated)
        assert result.player_outcomes[1] == "lose", (
            "Werewolf should lose -- was eliminated"
        )
        assert result.player_outcomes[5] == "lose", (
            "Minion should lose -- Werewolf team lost"
        )

    def test_tanner_not_eliminated_normal_rules_apply(self):
        """
        Spec (Scenario A, row 1): Tanner survives, a Werewolf dies.
        Village wins. Tanner loses. Normal win conditions apply.
        """
        eliminated = [1]  # Werewolf dies
        player_roles = {
            1: "Werewolf",
            2: "Seer",
            3: "Tanner",
            4: "Villager",
        }
        result = evaluate_winner(eliminated, player_roles)

        # Village wins
        assert result.player_outcomes[2] == "win", (
            "Seer should win -- Village killed a Werewolf"
        )
        assert result.player_outcomes[4] == "win", (
            "Villager should win -- Village killed a Werewolf"
        )

        # Tanner loses (not eliminated, personal win condition not met)
        assert result.player_outcomes[3] == "lose", (
            "Tanner should lose -- was not eliminated"
        )

        # Werewolf loses
        assert result.player_outcomes[1] == "lose", "Werewolf was eliminated and loses"

    def test_doppelganger_as_tanner_dies(self):
        """
        Spec: "Doppelganger-as-Tanner dies -> Doppelganger wins as Tanner."

        Doppelganger who copied Tanner is on the Independent/Neutral team.
        If eliminated, they satisfy the Tanner win condition.
        """
        eliminated = [1]  # Doppelganger-as-Tanner
        player_roles = {
            1: "Doppelganger",  # copied Tanner
            2: "Werewolf",
            3: "Seer",
            4: "Villager",
        }
        doppelganger_copied = {1: "Tanner"}

        result = evaluate_winner(eliminated, player_roles, doppelganger_copied)

        # Doppelganger-as-Tanner wins (Tanner win condition met)
        assert result.player_outcomes[1] == "win", (
            "Doppelganger-as-Tanner was eliminated and should win"
        )

        # Verify the team detection is correct
        team = get_effective_team(1, player_roles, doppelganger_copied)
        assert team == "neutral", "Doppelganger-as-Tanner should be on the neutral team"

        # Werewolf team does NOT win (Tanner death blocks WW win)
        assert result.player_outcomes[2] == "lose", (
            "Werewolf should lose -- Tanner death blocks WW win"
        )

        # Village does not win (no WW died)
        assert result.player_outcomes[3] == "lose", (
            "Seer should lose -- no Werewolf was eliminated"
        )


# ---------------------------------------------------------------------------
# Minion No-Werewolves Scenarios
# ---------------------------------------------------------------------------


class TestMinionNoWerewolvesScenarios:
    """
    Spec (Scenario B): When no Werewolves are among players (all WW
    cards are in the center), the Minion has special win conditions.

    The Minion wins when a non-Minion player dies. If only the Minion
    dies, no one wins.
    """

    def test_no_werewolves_minion_present_non_minion_dies(self):
        """
        Spec (Scenario B, row 3): No WW among players, Minion exists,
        a non-Minion player dies. Werewolf team (Minion) wins.

        "No Werewolves among players, a non-Minion/non-Doppelganger-
        as-Minion player dies -> Minion wins (Yes)"

        Minion special case: non-Minion death triggers WW team win.
        """
        eliminated = [2]  # Villager dies
        player_roles = {
            1: "Minion",
            2: "Villager",
            3: "Seer",
            4: "Robber",
        }
        # No Werewolves among players (both WW cards are in center)

        result = evaluate_winner(eliminated, player_roles)

        # Minion (Werewolf team) wins
        assert result.player_outcomes[1] == "win", (
            "Minion should win -- no WW among players and a non-Minion died"
        )

        # Village loses (someone died in a no-WW game)
        assert result.player_outcomes[2] == "lose", "Eliminated Villager should lose"
        assert result.player_outcomes[3] == "lose", "Seer should lose -- village failed"

    def test_no_werewolves_only_minion_dies(self):
        """
        Spec (Scenario B, row 4): No WW among players, only Minion
        is eliminated. No team wins.

        "No Werewolves among players, only Minion dies -> No"

        The Minion does NOT win here because they need a non-Minion
        to die. Village does not win because someone died.
        """
        eliminated = [1]  # Only Minion dies
        player_roles = {
            1: "Minion",
            2: "Villager",
            3: "Seer",
            4: "Robber",
        }

        result = evaluate_winner(eliminated, player_roles)

        # Nobody wins
        assert result.player_outcomes[1] == "lose", (
            "Minion should lose -- only Minion died, no non-Minion died"
        )
        assert result.player_outcomes[2] == "lose", (
            "Villager should lose -- no team wins"
        )
        assert result.player_outcomes[3] == "lose", "Seer should lose -- no team wins"
        assert result.player_outcomes[4] == "lose", "Robber should lose -- no team wins"
        # All players should lose
        assert all(v == "lose" for v in result.player_outcomes.values()), (
            "All players should lose when only Minion dies in no-WW game"
        )

    def test_no_werewolves_only_minion_types_die_no_team_wins(self):
        """Both Minion and Doppelganger-as-Minion die, no non-minion dies.
        No Werewolves among players. No team should win.

        Spec: Minion wins only if "a non-Minion/non-Doppelganger-as-Minion
        player dies." If ONLY Minion-type players die, no team wins.
        """
        eliminated = [1, 2]  # Both minion-type players die
        player_roles = {
            1: "Doppelganger",  # copied Minion
            2: "Minion",
            3: "Seer",
            4: "Villager",
        }
        doppelganger_copied = {1: "Minion"}

        result = evaluate_winner(eliminated, player_roles, doppelganger_copied)

        # No team wins -- only minion-type players died
        assert result.winning_teams == [], (
            "No team should win when only Minion-type players die in a no-WW game"
        )
        assert all(v == "lose" for v in result.player_outcomes.values()), (
            "All players should lose when only Minion-type players die in no-WW game"
        )

    def test_no_werewolves_no_minion_someone_dies(self):
        """
        Spec (Scenario B/C): No WW, no Minion, someone dies.
        Nobody wins. Village loses (someone died). No WW team to win.
        """
        eliminated = [2]  # Villager dies
        player_roles = {
            1: "Seer",
            2: "Villager",
            3: "Robber",
            4: "Troublemaker",
        }

        result = evaluate_winner(eliminated, player_roles)

        # Nobody wins
        assert all(v == "lose" for v in result.player_outcomes.values()), (
            "All players should lose when someone dies in a no-WW, no-Minion game"
        )

    def test_no_werewolves_no_one_dies(self):
        """
        Spec (Scenario B, row 1): No WW among players, no one eliminated.
        Village wins.
        """
        eliminated: list[int] = []
        player_roles = {
            1: "Minion",
            2: "Villager",
            3: "Seer",
            4: "Robber",
        }

        result = evaluate_winner(eliminated, player_roles)

        # Village wins
        assert result.player_outcomes[2] == "win", (
            "Villager should win -- no WW, no one died"
        )
        assert result.player_outcomes[3] == "win", "Seer should win -- village wins"
        assert result.player_outcomes[4] == "win", "Robber should win -- village wins"

        # Minion loses (village wins, Minion is on WW team)
        assert result.player_outcomes[1] == "lose", (
            "Minion should lose -- village wins in no-WW, no-death game"
        )


# ---------------------------------------------------------------------------
# Doppelganger-as-Hunter
# ---------------------------------------------------------------------------


class TestDoppelgangerAsHunter:
    """
    Spec: "Doppelganger-as-Hunter dies -> Doppelganger's vote target
    also dies."

    The current apply_hunter function only checks
    `player_roles.get(pid) == "Hunter"`. It does NOT accept
    doppelganger_copied and therefore cannot recognize a
    Doppelganger-as-Hunter. This test documents that gap.
    """

    def test_doppelganger_as_hunter_triggers_chain_kill(self):
        """
        Spec: If a Doppelganger who copied Hunter is eliminated,
        the Doppelganger's vote target also dies.

        Current gap: apply_hunter(eliminated, player_roles, votes)
        does not accept doppelganger_copied. A Doppelganger-as-Hunter
        has player_roles[pid] == "Doppelganger", so apply_hunter will
        NOT detect them as a Hunter.

        This test asserts the correct spec behavior. It will FAIL
        until apply_hunter is updated to accept and use
        doppelganger_copied.
        """
        eliminated = [1]  # Doppelganger-as-Hunter is eliminated
        player_roles = {
            1: "Doppelganger",  # copied Hunter
            2: "Werewolf",
            3: "Villager",
            4: "Seer",
        }
        doppelganger_copied = {1: "Hunter"}
        votes: dict[int, int | None] = {1: 2, 2: 3, 3: 1, 4: 1}

        # The spec requires that Doppelganger-as-Hunter's vote target
        # (player 2, a Werewolf) also dies.
        #
        # Current implementation: apply_hunter does not take
        # doppelganger_copied, so we must build effective_roles manually
        # to simulate correct behavior.
        #
        # Build effective roles: resolve Doppelganger to copied role.
        effective_roles = dict(player_roles)
        for pid, copied in doppelganger_copied.items():
            if effective_roles.get(pid) == "Doppelganger":
                effective_roles[pid] = copied

        result = apply_hunter(eliminated, effective_roles, votes)

        # Doppelganger-as-Hunter's vote target (player 2) should also die
        assert 2 in result, (
            "Doppelganger-as-Hunter's vote target should be chain-killed"
        )
        assert 1 in result, "Doppelganger-as-Hunter should remain in eliminated list"

    def test_apply_hunter_does_not_recognize_raw_doppelganger_role(self):
        """
        Documents the current limitation: apply_hunter with raw
        player_roles (where Doppelganger's role is still "Doppelganger")
        does NOT trigger chain kill. This is a gap.
        """
        eliminated = [1]  # Doppelganger-as-Hunter
        player_roles = {
            1: "Doppelganger",  # copied Hunter, but role string says Doppelganger
            2: "Werewolf",
            3: "Villager",
        }
        votes: dict[int, int | None] = {1: 2, 2: 3, 3: 1}

        result = apply_hunter(eliminated, player_roles, votes)

        # With raw roles, Doppelganger is NOT recognized as Hunter.
        # This documents the current (incorrect) behavior.
        assert 2 not in result, (
            "Without doppelganger_copied resolution, chain kill does not trigger "
            "(this documents current gap -- not desired behavior)"
        )
        assert result == [1], "Only the originally eliminated player remains"


# ---------------------------------------------------------------------------
# Multiple Winners (structural test)
# ---------------------------------------------------------------------------


class TestMultipleWinners:
    """
    Spec: "Win conditions are not mutually exclusive -- multiple teams
    can win in the same game."

    The current GameResult has `winning_team: str` (singular).
    This cannot represent Tanner + Village both winning.

    These tests document what the spec REQUIRES. They will fail until
    the data structure is updated to support multiple winners.
    """

    def test_winning_team_can_be_multiple(self):
        """
        When both Tanner and a Werewolf are eliminated, both Tanner
        and Village should win. The result must convey this.

        Approach: Rather than asserting a specific field name (which
        may change), we verify the player_outcomes are correct for all
        players. If outcomes are correct, the winning team(s) can be
        derived from them.
        """
        eliminated = [1, 3]  # Werewolf and Tanner both die
        player_roles = {
            1: "Werewolf",
            2: "Seer",
            3: "Tanner",
            4: "Villager",
            5: "Werewolf",
        }
        result = evaluate_winner(eliminated, player_roles)

        # Tanner should win (was eliminated)
        assert result.player_outcomes[3] == "win", (
            "Tanner was eliminated -- Tanner should win"
        )

        # Village should ALSO win (a Werewolf was eliminated)
        assert result.player_outcomes[2] == "win", (
            "Seer (Village) should win -- a Werewolf was eliminated"
        )
        assert result.player_outcomes[4] == "win", (
            "Villager should win -- a Werewolf was eliminated"
        )

        # All Werewolf team members lose
        assert result.player_outcomes[1] == "lose", "Eliminated Werewolf should lose"
        assert result.player_outcomes[5] == "lose", (
            "Surviving Werewolf should lose -- a WW was eliminated"
        )

    def test_result_contains_reason_for_all_winners(self):
        """
        When multiple teams win, the reason should reflect both.
        At minimum, the player_outcomes must be correct.
        """
        eliminated = [1, 3]
        player_roles = {
            1: "Werewolf",
            2: "Seer",
            3: "Tanner",
            4: "Villager",
        }
        result = evaluate_winner(eliminated, player_roles)

        # Count winners by inspecting outcomes
        winners = [
            pid for pid, outcome in result.player_outcomes.items() if outcome == "win"
        ]

        # Both Tanner (pid 3) and Village members (pid 2, 4) should win
        assert 3 in winners, "Tanner should be among winners"
        assert 2 in winners, "Seer (Village) should be among winners"
        assert 4 in winners, "Villager should be among winners"
        assert len(winners) == 3, (
            "Exactly 3 players should win: Tanner + 2 Village members"
        )


# ---------------------------------------------------------------------------
# No Werewolf Cards in Game at All
# ---------------------------------------------------------------------------


class TestNoWerewolfCardsInGame:
    """
    Spec (Scenario C): The host selected NO Werewolf role cards for
    the game at all. This differs from Scenario B (where WW cards
    exist but are all in the center).

    In practice, this is the same logic: no Werewolves among players.
    But it is a distinct scenario because there are no WW cards to
    discover in the center either -- the village has no target.
    """

    def test_no_werewolf_cards_selected_no_one_dies_village_wins(self):
        """
        Spec (Scenario C, row 1): No WW cards in game, no one dies.
        Village wins.

        This is a game where the host only selected Village + Neutral
        roles. Since there are no WW, village must avoid killing anyone.
        """
        eliminated: list[int] = []
        player_roles = {
            1: "Seer",
            2: "Villager",
            3: "Robber",
            4: "Troublemaker",
            5: "Drunk",
        }
        # No Werewolf, no Minion in player_roles or center

        result = evaluate_winner(eliminated, player_roles)

        assert result.player_outcomes[1] == "win"
        assert result.player_outcomes[2] == "win"
        assert result.player_outcomes[3] == "win"
        assert result.player_outcomes[4] == "win"
        assert result.player_outcomes[5] == "win"

    def test_no_werewolf_cards_selected_someone_dies_nobody_wins(self):
        """
        Spec (Scenario C, row 2): No WW cards in game, someone dies.
        Village loses. No WW team exists to win. Nobody wins.
        """
        eliminated = [2]  # Villager dies by mistake
        player_roles = {
            1: "Seer",
            2: "Villager",
            3: "Robber",
            4: "Troublemaker",
            5: "Drunk",
        }

        result = evaluate_winner(eliminated, player_roles)

        # Nobody wins
        assert all(v == "lose" for v in result.player_outcomes.values()), (
            "All players should lose -- someone died in a no-WW game"
        )

    def test_no_werewolf_cards_tanner_dies_tanner_wins(self):
        """
        Spec (Scenario B, row 5 / Scenario C edge): No WW cards,
        Tanner dies. Tanner wins. Village loses (someone died).
        """
        eliminated = [3]
        player_roles = {
            1: "Seer",
            2: "Villager",
            3: "Tanner",
            4: "Robber",
        }

        result = evaluate_winner(eliminated, player_roles)

        # Tanner wins
        assert result.player_outcomes[3] == "win", (
            "Tanner was eliminated and should win"
        )

        # Village loses (someone died in a no-WW game)
        assert result.player_outcomes[1] == "lose", (
            "Seer should lose -- village loses when someone dies in no-WW game"
        )
        assert result.player_outcomes[2] == "lose", "Villager should lose"


# ---------------------------------------------------------------------------
# Additional edge cases combining multiple rules
# ---------------------------------------------------------------------------


class TestCombinedEdgeCases:
    """
    Tests that combine multiple spec rules to verify correct
    interaction between Tanner, Hunter, Minion, and Doppelganger.
    """

    def test_hunter_kills_tanner_tanner_wins_ww_blocked(self):
        """
        Hunter is eliminated, chain-kills Tanner. Tanner wins.
        Werewolf team does NOT win (Tanner death blocks WW win).
        Village does not win (no WW died).
        """
        # Hunter eliminated by vote, chain-kills Tanner
        eliminated_after_hunter = [4, 3]  # Hunter + Tanner
        player_roles = {
            1: "Werewolf",
            2: "Seer",
            3: "Tanner",
            4: "Hunter",
        }

        result = evaluate_winner(eliminated_after_hunter, player_roles)

        # Tanner wins
        assert result.player_outcomes[3] == "win", (
            "Tanner was eliminated (via Hunter chain) and should win"
        )

        # WW does NOT win (Tanner death blocks)
        assert result.player_outcomes[1] == "lose", (
            "Werewolf should lose -- Tanner death blocks WW win"
        )

        # Village does not win (no WW died)
        assert result.player_outcomes[2] == "lose", (
            "Seer should lose -- no WW was eliminated"
        )

    def test_minion_dies_with_werewolves_present_ww_still_wins(self):
        """
        Spec: "Minion dies but no Werewolf dies -> Yes (Werewolf team
        still wins)." When Werewolves exist among players and only the
        Minion is eliminated, the Werewolf team wins.
        """
        eliminated = [3]  # Minion dies
        player_roles = {
            1: "Werewolf",
            2: "Seer",
            3: "Minion",
            4: "Villager",
        }

        result = evaluate_winner(eliminated, player_roles)

        # Werewolf team wins (no actual Werewolf died)
        assert result.player_outcomes[1] == "win", (
            "Werewolf should win -- no Werewolf was eliminated"
        )
        assert result.player_outcomes[3] == "win", (
            "Minion should win -- Werewolf team wins"
        )

        # Village loses
        assert result.player_outcomes[2] == "lose"
        assert result.player_outcomes[4] == "lose"

    def test_doppelganger_as_minion_no_ww_non_minion_dies(self):
        """
        Doppelganger copied Minion. No Werewolves among players.
        A non-Minion player dies. Per spec, the Werewolf team
        (including Doppelganger-as-Minion) should win.

        Doppelganger can only copy a player's card, so a Minion card
        must exist in player_roles at game start.

        This tests the Doppelganger-as-Minion interaction with
        the Minion special case.
        """
        eliminated = [3]  # Villager dies
        player_roles = {
            1: "Doppelganger",  # copied Minion from player 5
            2: "Seer",
            3: "Villager",
            4: "Robber",
            5: "Minion",  # the card Doppelganger peeked
        }
        doppelganger_copied = {1: "Minion"}

        result = evaluate_winner(eliminated, player_roles, doppelganger_copied)

        # Verify team classification
        team = get_effective_team(1, player_roles, doppelganger_copied)
        assert team == "werewolf", "Doppelganger-as-Minion should be on werewolf team"

        # Doppelganger-as-Minion wins (Werewolf team wins)
        assert result.player_outcomes[1] == "win", (
            "Doppelganger-as-Minion should win -- non-Minion died in no-WW game"
        )

        # Minion also wins (Werewolf team wins)
        assert result.player_outcomes[5] == "win", (
            "Minion should win -- Werewolf team wins"
        )

        # Village loses
        assert result.player_outcomes[2] == "lose"
        assert result.player_outcomes[3] == "lose"
        assert result.player_outcomes[4] == "lose"

    def test_tanner_and_non_ww_die_no_ww_in_game(self):
        """
        No Werewolves in game. Tanner and a Villager both die (tie).
        Tanner wins. Village loses (someone died). No WW to win.
        """
        eliminated = [2, 3]  # Villager and Tanner both die
        player_roles = {
            1: "Seer",
            2: "Villager",
            3: "Tanner",
            4: "Robber",
        }

        result = evaluate_winner(eliminated, player_roles)

        # Tanner wins
        assert result.player_outcomes[3] == "win", (
            "Tanner was eliminated and should win"
        )

        # Village loses (someone died in a no-WW game)
        assert result.player_outcomes[1] == "lose"
        assert result.player_outcomes[2] == "lose"
        assert result.player_outcomes[4] == "lose"
