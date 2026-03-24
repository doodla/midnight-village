"""
Spec-validation tests for ONUW voting, resolution, Hunter chain, and setup validation.

These tests encode the CORRECT behavior per the official ONUW spec
(docs/specs/onuw/voting-and-resolution.md, docs/specs/onuw/overview.md).

Some tests are expected to FAIL against the current implementation because
the code has known deviations from the spec. This is intentional TDD:
the tests document what the code SHOULD do, and failing tests guide the fixes.

Known deviations tested here:
1. Min 2-vote threshold: determine_elimination does not enforce >= 2 votes.
2. Hunter chain no-recursion: apply_hunter iteratively chains through Hunters.
3. Max player count: validate_onuw_settings does not check max 10.
4. Mason pairs: validation allows 1 Mason (should require 0 or 2).
"""

import pytest

from apps.onuw.engine.roles import ROLE_REGISTRY
from apps.onuw.engine.validation import validate_onuw_settings
from apps.onuw.engine.voting import apply_hunter, count_votes, determine_elimination
from apps.onuw.engine.win_conditions import evaluate_winner

pytestmark = pytest.mark.unit


# ---------------------------------------------------------------------------
# Voting: minimum 2-vote threshold
# ---------------------------------------------------------------------------


class TestMinTwoVoteThreshold:
    """
    Spec: "The minimum vote threshold is 2. A player must receive at least 2
    votes to be eliminated."

    Current code deviation: determine_elimination returns the player with the
    most votes regardless of whether that count is >= 2.
    """

    def test_min_two_votes_required_for_elimination(self):
        """
        One player gets 1 vote, all others got 0 (timeouts/abstains).
        Spec says no one is eliminated because 1 < 2.
        """
        # 5-player game: 4 players timed out, 1 player voted for player 3.
        votes: dict[int, int | None] = {1: 3, 2: None, 3: None, 4: None, 5: None}
        vote_counts = count_votes(votes)
        # vote_counts == {3: 1}
        assert vote_counts == {3: 1}

        eliminated = determine_elimination(vote_counts)
        # Spec: player 3 has only 1 vote, below the minimum of 2 => no elimination.
        assert eliminated == [], (
            "A player with only 1 vote must NOT be eliminated. "
            "Spec requires a minimum of 2 votes for elimination."
        )

    def test_player_with_exactly_two_votes_is_eliminated(self):
        """
        One player gets 2 votes, others get 1 or 0.
        Spec says the player with 2 votes is eliminated (meets threshold).
        """
        # 5-player game: player 2 gets 2 votes, player 4 gets 1, others 0.
        votes: dict[int, int | None] = {1: 2, 2: 4, 3: 2, 4: None, 5: None}
        vote_counts = count_votes(votes)
        assert vote_counts == {2: 2, 4: 1}

        eliminated = determine_elimination(vote_counts)
        assert eliminated == [2], (
            "Player 2 has 2 votes (the most, and >= 2) so they should be eliminated."
        )

    def test_all_players_get_one_vote_no_elimination(self):
        """
        3-player game where each player gets exactly 1 vote.
        Spec says no one dies: all tied AND max votes == 1 (below threshold).
        """
        votes: dict[int, int | None] = {1: 2, 2: 3, 3: 1}
        vote_counts = count_votes(votes)
        assert vote_counts == {2: 1, 3: 1, 1: 1}

        eliminated = determine_elimination(vote_counts)
        # The existing code already returns [] for a complete tie,
        # but the reason should be the min-2 rule, not just the tie rule.
        # Either way, the result must be empty.
        assert eliminated == [], (
            "All players have 1 vote each. No one reaches the 2-vote minimum."
        )

    def test_single_vote_only_target_not_eliminated(self):
        """
        Only 1 vote cast total (all others timed out). Target has 1 vote.
        Spec: NOT eliminated because 1 < 2 minimum.

        This is the key edge case: the target has the "most" votes,
        but still should not die.
        """
        vote_counts = {5: 1}  # Only player 5 received any votes, just 1.
        eliminated = determine_elimination(vote_counts)
        assert eliminated == [], (
            "A single vote of 1 is below the 2-vote minimum. No elimination."
        )


class TestTieAtTwoOrMore:
    """
    Spec: "If there is a tie for the most votes (and the tied count is >= 2),
    all tied players die."
    """

    def test_tie_at_two_or_more_all_tied_die(self):
        """
        Two players tied at 2 votes, one at 1 vote.
        Both tied players should be eliminated.
        """
        vote_counts = {1: 2, 2: 2, 3: 1}
        eliminated = determine_elimination(vote_counts)
        assert eliminated == [1, 2], (
            "Players 1 and 2 are tied at 2 votes (>= 2 threshold). Both die."
        )

    def test_complete_tie_at_two_votes_all_die(self):
        """
        All voted-for players have exactly 2 votes.

        Per spec: "Multiple players tied for most votes (each >= 2): All tied
        players die." And edge case: "3-way tie at 2+ votes each: All three die."
        """
        vote_counts = {1: 2, 2: 2, 3: 2}
        eliminated = determine_elimination(vote_counts)
        assert eliminated == [1, 2, 3], (
            "3-way tie at 2+ votes each => all three eliminated per spec."
        )

    def test_three_way_tie_at_two_with_one_at_one_all_three_die(self):
        """
        3 players at 2 votes each, 1 player at 1 vote.
        This is NOT a complete tie (one player has fewer), so all 3 tied die.
        """
        vote_counts = {1: 2, 2: 2, 3: 2, 4: 1}
        eliminated = determine_elimination(vote_counts)
        assert eliminated == [1, 2, 3], (
            "Three players tied at 2 votes with a fourth at 1 -- "
            "the three tied players all die."
        )


# ---------------------------------------------------------------------------
# Hunter chain kills
# ---------------------------------------------------------------------------


class TestHunterChainKills:
    """
    Spec: "If a player holding the Hunter card is among the dead, the player
    the Hunter voted for is also eliminated."

    Additional spec rule: "Hunter chain kills do NOT recurse. If the Hunter
    kills a Doppelganger-as-Hunter, that second 'Hunter' does not trigger
    a further chain."
    """

    def test_hunter_kills_vote_target(self):
        """Basic Hunter chain: eliminated Hunter's vote target also dies."""
        eliminated = [1]
        player_roles = {1: "Hunter", 2: "Werewolf", 3: "Villager"}
        votes: dict[int, int | None] = {1: 2, 2: 3, 3: 1}

        result = apply_hunter(eliminated, player_roles, votes)
        assert sorted(result) == [1, 2], (
            "Hunter (player 1) died and voted for player 2. Player 2 must also die."
        )

    def test_hunter_no_chain_through_second_hunter(self):
        """
        Spec: "Hunter chain kills do NOT recurse."

        If the Hunter kills a Doppelganger-as-Hunter, the chain does NOT
        continue. Only the initially eliminated Hunter's kill applies.

        Only 1 Hunter card exists in v1; use Doppelganger-as-Hunter for the
        second Hunter-like player.
        """
        eliminated = [1]
        # Player 1 is Hunter, votes for player 2 (Doppelganger-as-Hunter).
        # Player 2 voted for player 3.
        player_roles = {
            1: "Hunter",
            2: "Doppelganger",  # copied Hunter
            3: "Villager",
            4: "Werewolf",
        }
        doppelganger_copied = {2: "Hunter"}
        votes: dict[int, int | None] = {1: 2, 2: 3, 3: 4, 4: 1}

        result = apply_hunter(eliminated, player_roles, votes, doppelganger_copied)
        # Spec: Hunter (1) kills their target (2). Stop. No recursion.
        # Player 2 is Doppelganger-as-Hunter, but the chain does NOT continue.
        assert sorted(result) == [1, 2], (
            "Hunter chain must NOT recurse. Player 1 (Hunter) kills player 2. "
            "Even though player 2 is Doppelganger-as-Hunter and voted for player 3, "
            "the chain stops. Player 3 must NOT be killed."
        )

    def test_hunter_target_already_dying_no_duplicate(self):
        """
        Hunter's target was already in the eliminated list (e.g., from a tie).
        No duplicate entry; result list stays clean.
        """
        # Both player 1 (Hunter) and player 2 died in a tie.
        # Hunter voted for player 2 who is already dying.
        eliminated = [1, 2]
        player_roles = {1: "Hunter", 2: "Werewolf", 3: "Villager"}
        votes: dict[int, int | None] = {1: 2, 2: 3, 3: 1}

        result = apply_hunter(eliminated, player_roles, votes)
        assert result == [1, 2], (
            "Hunter's target (player 2) was already dying. "
            "No duplicate and no additional kills."
        )

    def test_hunter_abstained_no_chain_kill(self):
        """
        Hunter died but their vote was None (timed out / abstained).
        No chain kill should occur.
        """
        eliminated = [1]
        player_roles = {1: "Hunter", 2: "Werewolf", 3: "Villager"}
        votes: dict[int, int | None] = {1: None, 2: 1, 3: 1}

        result = apply_hunter(eliminated, player_roles, votes)
        assert result == [1], (
            "Hunter abstained (vote is None). No chain kill triggered."
        )

    def test_hunter_not_eliminated_no_chain(self):
        """Hunter is alive -- their ability does not trigger."""
        eliminated = [2]  # Non-Hunter player eliminated
        player_roles = {1: "Hunter", 2: "Werewolf", 3: "Villager"}
        votes: dict[int, int | None] = {1: 2, 2: 3, 3: 2}

        result = apply_hunter(eliminated, player_roles, votes)
        assert result == [2], "Hunter is alive. No chain kill."

    def test_hunter_circular_reference_terminates(self):
        """
        Hunter and Doppelganger-as-Hunter vote for each other. Hunter dies
        from voting. Per no-recursion spec, only the first Hunter's target
        dies. The Doppelganger-as-Hunter (killed by chain) does NOT trigger
        further chain.

        Only 1 Hunter card exists in v1; use Doppelganger-as-Hunter for the
        second Hunter-like player.
        """
        eliminated = [1]
        player_roles = {1: "Hunter", 2: "Doppelganger", 3: "Villager"}
        doppelganger_copied = {2: "Hunter"}
        votes: dict[int, int | None] = {1: 2, 2: 1, 3: 1}

        result = apply_hunter(eliminated, player_roles, votes, doppelganger_copied)
        # Per strict no-recursion: Hunter 1 kills Doppelganger-as-Hunter 2. Stop.
        # Player 2's death does NOT trigger a chain back to player 1.
        assert sorted(result) == [1, 2], (
            "Hunter 1 kills Doppelganger-as-Hunter 2. Chain does not recurse "
            "(player 2 does not trigger further)."
        )


# ---------------------------------------------------------------------------
# Setup validation
# ---------------------------------------------------------------------------


class TestSetupValidationMaxPlayers:
    """
    Spec: "Player count: 3-10 players."

    Current code deviation: checks min 3 but not max 10.
    """

    def test_max_ten_players(self):
        """11 players should produce a validation error."""
        # 11 players need 14 cards. Build a valid-ish role set for 14 cards.
        config = {
            "roles": {
                "Werewolf": 2,
                "Villager": 3,
                "Seer": 1,
                "Robber": 1,
                "Troublemaker": 1,
                "Drunk": 1,
                "Insomniac": 1,
                "Minion": 1,
                "Tanner": 1,
                "Hunter": 1,
                "Mason": 0,
            }
        }
        # Total = 2+3+1+1+1+1+1+1+1+1+0 = 13, need 14 for 11 players.
        # Doesn't matter -- the max-player check should fire first or alongside.
        errors = validate_onuw_settings(config, 11)
        assert any(
            "10" in e or "maximum" in e.lower() or "at most" in e.lower()
            for e in errors
        ), f"11 players should produce a max-player error. Got errors: {errors}"

    def test_ten_players_valid_count(self):
        """10 players is at the boundary and should NOT produce a player count error."""
        # 10 players + 3 center = 13 cards.
        config = {
            "roles": {
                "Werewolf": 2,
                "Villager": 3,
                "Seer": 1,
                "Robber": 1,
                "Troublemaker": 1,
                "Drunk": 1,
                "Insomniac": 1,
                "Minion": 1,
                "Tanner": 1,
                "Hunter": 1,
            }
        }
        # Total = 2+3+1+1+1+1+1+1+1+1 = 13. Exactly 10+3. Valid.
        errors = validate_onuw_settings(config, 10)
        # Should have no player-count-related errors.
        player_count_errors = [
            e
            for e in errors
            if "player" in e.lower()
            and (
                "at least" in e.lower()
                or "at most" in e.lower()
                or "maximum" in e.lower()
            )
        ]
        assert player_count_errors == [], (
            f"10 players should be valid. Got player count errors: {player_count_errors}"
        )

    def test_player_count_three_minimum(self):
        """2 players should produce a validation error (existing behavior, confirm)."""
        config = {
            "roles": {
                "Werewolf": 2,
                "Seer": 1,
                "Robber": 1,
                "Villager": 1,
            }
        }
        errors = validate_onuw_settings(config, 2)
        assert any("3" in e and "player" in e.lower() for e in errors), (
            f"2 players should produce a min-player error. Got errors: {errors}"
        )


class TestMasonPairValidation:
    """
    Spec: "Masons: Must be used in pairs -- cannot include just 1 Mason card."
    Mason count must be 0 or 2.

    Current code deviation: ROLE_REGISTRY has Mason min_count=0, so
    validate_onuw_settings allows 1 Mason without error.
    """

    def test_mason_must_be_pair_or_zero(self):
        """1 Mason in settings should produce a validation error."""
        config = {
            "roles": {
                "Werewolf": 2,
                "Seer": 1,
                "Robber": 1,
                "Mason": 1,
                "Villager": 1,
                "Troublemaker": 1,
                "Drunk": 1,
            }
        }
        errors = validate_onuw_settings(config, 5)
        assert any("mason" in e.lower() or "pair" in e.lower() for e in errors), (
            f"1 Mason should be rejected (must be 0 or 2). Got errors: {errors}"
        )

    def test_mason_pair_valid(self):
        """2 Masons in settings is valid."""
        config = {
            "roles": {
                "Werewolf": 2,
                "Seer": 1,
                "Mason": 2,
                "Villager": 1,
                "Troublemaker": 1,
                "Drunk": 1,
            }
        }
        errors = validate_onuw_settings(config, 5)
        mason_errors = [
            e for e in errors if "mason" in e.lower() or "pair" in e.lower()
        ]
        assert mason_errors == [], (
            f"2 Masons should be valid. Got Mason-related errors: {mason_errors}"
        )

    def test_zero_masons_valid(self):
        """0 Masons (not included) is valid."""
        config = {
            "roles": {
                "Werewolf": 2,
                "Seer": 1,
                "Robber": 1,
                "Villager": 1,
                "Drunk": 1,
                "Insomniac": 1,
                "Troublemaker": 1,
            }
        }
        errors = validate_onuw_settings(config, 5)
        mason_errors = [
            e for e in errors if "mason" in e.lower() or "pair" in e.lower()
        ]
        assert mason_errors == [], (
            f"0 Masons should be valid. Got Mason-related errors: {mason_errors}"
        )

    def test_zero_masons_explicit_valid(self):
        """Mason: 0 explicitly set should also be valid."""
        config = {
            "roles": {
                "Werewolf": 2,
                "Seer": 1,
                "Robber": 1,
                "Mason": 0,
                "Villager": 1,
                "Drunk": 1,
                "Insomniac": 1,
                "Troublemaker": 1,
            }
        }
        errors = validate_onuw_settings(config, 5)
        mason_errors = [
            e for e in errors if "mason" in e.lower() or "pair" in e.lower()
        ]
        assert mason_errors == [], (
            f"Mason: 0 should be valid. Got Mason-related errors: {mason_errors}"
        )


class TestCardCountValidation:
    """Card count must equal player_count + 3."""

    def test_card_count_equals_players_plus_three(self):
        """Wrong total card count should produce an error."""
        config = {
            "roles": {
                "Werewolf": 2,
                "Seer": 1,
            }
        }
        # 5 players need 8 cards total. 2+1=3, which is wrong.
        errors = validate_onuw_settings(config, 5)
        assert any("total" in e.lower() or "count" in e.lower() for e in errors), (
            f"Total cards (3) != 5+3=8. Should produce an error. Got: {errors}"
        )

    def test_correct_card_count_no_error(self):
        """Correct total card count should not produce a count error."""
        config = {
            "roles": {
                "Werewolf": 2,
                "Seer": 1,
                "Robber": 1,
                "Villager": 1,
                "Drunk": 1,
                "Insomniac": 1,
                "Troublemaker": 1,
            }
        }
        # 5 players, 8 cards total. 2+1+1+1+1+1+1 = 8. Correct.
        errors = validate_onuw_settings(config, 5)
        count_errors = [
            e for e in errors if "total" in e.lower() and "count" in e.lower()
        ]
        assert count_errors == [], (
            f"Card count is correct (8 = 5+3). Should have no count errors. Got: {count_errors}"
        )


# ---------------------------------------------------------------------------
# Role registry: Mason definition
# ---------------------------------------------------------------------------


class TestMasonRoleRegistryDefinition:
    """Verify the Mason role definition supports pair-or-zero enforcement."""

    def test_mason_in_registry(self):
        """Mason must exist in the role registry."""
        assert "Mason" in ROLE_REGISTRY

    def test_mason_max_count_is_two(self):
        """Mason max_count should be 2."""
        mason = ROLE_REGISTRY["Mason"]
        assert mason.max_count == 2

    def test_mason_min_count(self):
        """
        Mason min_count should be 0 (zero Masons is fine).
        The pair constraint (no single Mason) must be enforced separately
        in validation, not just via min_count.
        """
        mason = ROLE_REGISTRY["Mason"]
        assert mason.min_count == 0


# ---------------------------------------------------------------------------
# Integration: full vote-to-elimination pipeline with min-2 rule
# ---------------------------------------------------------------------------


class TestVoteToEliminationPipeline:
    """
    End-to-end tests combining count_votes, determine_elimination, and
    apply_hunter to verify the full pipeline respects spec rules.
    """

    def test_full_pipeline_normal_elimination(self):
        """
        5-player game. Player 3 gets 3 votes. Should be eliminated.
        """
        votes: dict[int, int | None] = {1: 3, 2: 3, 3: 1, 4: 3, 5: 1}
        player_roles = {
            1: "Seer",
            2: "Villager",
            3: "Werewolf",
            4: "Robber",
            5: "Villager",
        }

        vote_counts = count_votes(votes)
        eliminated = determine_elimination(vote_counts)
        final = apply_hunter(eliminated, player_roles, votes)

        assert final == [3]

    def test_full_pipeline_one_vote_no_elimination(self):
        """
        5-player game. 4 players abstain, 1 votes. No elimination (min 2).
        """
        votes: dict[int, int | None] = {1: 3, 2: None, 3: None, 4: None, 5: None}
        player_roles = {
            1: "Seer",
            2: "Villager",
            3: "Werewolf",
            4: "Robber",
            5: "Villager",
        }

        vote_counts = count_votes(votes)
        eliminated = determine_elimination(vote_counts)
        final = apply_hunter(eliminated, player_roles, votes)

        assert final == [], (
            "Only 1 vote cast. Player 3 has 1 vote, below the 2-vote minimum. "
            "No one should be eliminated."
        )

    def test_full_pipeline_hunter_kills_werewolf_village_wins(self):
        """
        Hunter is eliminated, chain kills a Werewolf.
        Full pipeline should show both eliminated.
        """
        # Players 2-5 vote for player 1 (the Hunter). Hunter votes for player 3.
        votes: dict[int, int | None] = {1: 3, 2: 1, 3: 1, 4: 1, 5: 1}
        player_roles = {
            1: "Hunter",
            2: "Villager",
            3: "Werewolf",
            4: "Seer",
            5: "Robber",
        }

        # Player 1 gets 4 votes, player 3 gets 1 vote.
        vote_counts = count_votes(votes)
        eliminated = determine_elimination(vote_counts)
        assert eliminated == [1]

        final = apply_hunter(eliminated, player_roles, votes)
        # Hunter (1) voted for player 3 (Werewolf). Chain kill adds player 3.
        assert sorted(final) == [1, 3]


# ---------------------------------------------------------------------------
# Complete Resolution Example from spec
# ---------------------------------------------------------------------------


class TestCompleteResolutionExample:
    """Spec: Complete Resolution Example from voting-and-resolution.md."""

    def test_complete_resolution_example_from_spec(self):
        """
        Setup: Alice(1)=Werewolf, Bob(2)=Seer, Carol(3)=Robber, Dave(4)=Villager, Eve(5)=Hunter
        Center: [Werewolf, Minion, Tanner]

        Night:
        1. Bob (Seer) peeks Alice -> sees Werewolf
        2. Carol (Robber) swaps with Alice -> Carol=Werewolf, Alice=Robber
        3. Eve (Hunter) does not wake

        Final Roles: Alice=Robber, Bob=Seer, Carol=Werewolf, Dave=Villager, Eve=Hunter

        Voting: Alice->Carol, Bob->Alice, Carol->Bob, Dave->Alice, Eve->Alice
        Alice gets 3 votes, eliminated.

        Alice holds Robber (village), not Hunter -- no chain.
        Carol (Werewolf) is alive. Werewolf team wins.
        """
        # Final roles after all night swaps
        player_roles = {
            1: "Robber",  # Alice (was Werewolf, Robber stole it)
            2: "Seer",  # Bob
            3: "Werewolf",  # Carol (was Robber, now holds Werewolf)
            4: "Villager",  # Dave
            5: "Hunter",  # Eve
        }

        # Votes: Alice(1)->Carol(3), Bob(2)->Alice(1), Carol(3)->Bob(2),
        #        Dave(4)->Alice(1), Eve(5)->Alice(1)
        votes: dict[int, int | None] = {1: 3, 2: 1, 3: 2, 4: 1, 5: 1}

        # Step 1: Tally votes
        vote_counts = count_votes(votes)
        assert vote_counts[1] == 3, "Alice should have 3 votes"
        assert vote_counts[3] == 1, "Carol should have 1 vote"
        assert vote_counts[2] == 1, "Bob should have 1 vote"

        # Step 2: Determine elimination
        eliminated = determine_elimination(vote_counts)
        assert eliminated == [1], (
            "Alice (player 1) should be the sole elimination with 3 votes"
        )

        # Step 3: Apply Hunter -- Alice holds Robber, not Hunter. No chain.
        final_eliminated = apply_hunter(eliminated, player_roles, votes)
        assert final_eliminated == [1], (
            "Alice holds Robber, not Hunter. No Hunter chain should trigger."
        )

        # Step 4: Evaluate winner
        result = evaluate_winner(final_eliminated, player_roles)
        assert "werewolf" in result.winning_teams, (
            "Carol (player 3) holds Werewolf and is alive. Werewolf team wins."
        )
        assert "village" not in result.winning_teams, (
            "No Werewolf was eliminated. Village should not win."
        )
        assert "tanner" not in result.winning_teams, (
            "No Tanner in play among players. Tanner should not win."
        )
