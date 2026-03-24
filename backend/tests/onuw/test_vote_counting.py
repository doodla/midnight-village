"""
Unit tests for ONUW vote counting and elimination logic.

Tests the pure-Python voting engine (no Django dependencies).
"""

import pytest

from apps.onuw.engine.voting import apply_hunter, count_votes, determine_elimination

pytestmark = pytest.mark.unit


class TestCountVotes:
    """Tests for count_votes function."""

    def test_simple_majority(self):
        """Player with most votes gets the highest count."""
        votes: dict[int, int | None] = {1: 3, 2: 3, 3: 1, 4: 3, 5: 3}
        counts = count_votes(votes)
        assert counts == {3: 4, 1: 1}

    def test_all_votes_for_one_player(self):
        """All players vote for the same target."""
        votes: dict[int, int | None] = {1: 2, 2: 2, 3: 2}
        counts = count_votes(votes)
        assert counts == {2: 3}

    def test_abstains_ignored(self):
        """None votes (abstains) are not counted."""
        votes: dict[int, int | None] = {1: 3, 2: None, 3: 1, 4: None}
        counts = count_votes(votes)
        assert counts == {3: 1, 1: 1}

    def test_all_abstain(self):
        """If everyone abstains, no counts returned."""
        votes: dict[int, int | None] = {1: None, 2: None, 3: None}
        counts = count_votes(votes)
        assert counts == {}

    def test_empty_votes(self):
        """Empty vote dict returns empty counts."""
        counts = count_votes({})
        assert counts == {}

    def test_split_votes(self):
        """Votes evenly split among targets."""
        votes: dict[int, int | None] = {1: 2, 2: 3, 3: 4, 4: 1}
        counts = count_votes(votes)
        assert counts == {2: 1, 3: 1, 4: 1, 1: 1}


class TestDetermineElimination:
    """Tests for determine_elimination function."""

    def test_simple_majority(self):
        """Player with clear majority is eliminated."""
        vote_counts = {1: 3, 2: 1, 3: 1}
        eliminated = determine_elimination(vote_counts)
        assert eliminated == [1]

    def test_tie_for_most_both_eliminated(self):
        """When a subset tie for most votes, all in that subset are eliminated."""
        vote_counts = {1: 2, 2: 2, 3: 1}
        eliminated = determine_elimination(vote_counts)
        assert eliminated == [1, 2]

    def test_all_tied_at_two_or_more_all_die(self):
        """When ALL voted-for players tie at 2+ votes, all are eliminated.

        Per spec: "Multiple players tied for most votes (each >= 2): All tied players die."
        The spec explicitly says a 3-way tie at 2+ → all three die.
        """
        vote_counts = {1: 2, 2: 2, 3: 2}
        eliminated = determine_elimination(vote_counts)
        assert eliminated == [1, 2, 3]

    def test_all_votes_for_one_player(self):
        """Single player with all votes is eliminated (no tie)."""
        vote_counts = {1: 5}
        # Only one player received votes -- they are eliminated.
        # The "all tied" rule only applies when 2+ players are tied.
        eliminated = determine_elimination(vote_counts)
        assert eliminated == [1]

    def test_two_players_one_more_votes(self):
        """Two players received votes, one has more."""
        vote_counts = {1: 3, 2: 2}
        eliminated = determine_elimination(vote_counts)
        assert eliminated == [1]

    def test_all_players_get_one_vote_each_no_elimination(self):
        """Spec: 'No player has more than 1 vote -> no one dies.'

        5-player game where each player receives exactly 1 vote.
        """
        vote_counts = {1: 1, 2: 1, 3: 1, 4: 1, 5: 1}
        eliminated = determine_elimination(vote_counts)
        assert eliminated == []

    def test_empty_counts(self):
        """No votes cast -> no elimination."""
        eliminated = determine_elimination({})
        assert eliminated == []

    def test_three_way_partial_tie(self):
        """Three tied for most, one with fewer -> three eliminated."""
        vote_counts = {1: 2, 2: 2, 3: 2, 4: 1}
        eliminated = determine_elimination(vote_counts)
        assert eliminated == [1, 2, 3]


class TestApplyHunter:
    """Tests for apply_hunter function."""

    def test_hunter_chain_kill(self):
        """Eliminated Hunter's vote target is also eliminated."""
        eliminated = [1]
        player_roles = {1: "Hunter", 2: "Werewolf", 3: "Villager"}
        votes: dict[int, int | None] = {1: 2, 2: 1, 3: 1}
        result = apply_hunter(eliminated, player_roles, votes)
        assert 2 in result
        assert 1 in result

    def test_hunter_kills_target_but_chain_does_not_recurse(self):
        """Hunter kills Doppelganger-as-Hunter, but chain does NOT recurse.

        Per spec: "Hunter chain kills do NOT recurse."
        Only 1 Hunter card exists in v1; use Doppelganger-as-Hunter for the
        second Hunter-like player.
        """
        eliminated = [1]
        player_roles = {1: "Hunter", 2: "Doppelganger", 3: "Villager", 4: "Werewolf"}
        doppelganger_copied = {2: "Hunter"}
        votes: dict[int, int | None] = {1: 2, 2: 3, 3: 4, 4: 1}
        result = apply_hunter(eliminated, player_roles, votes, doppelganger_copied)
        assert sorted(result) == [1, 2]

    def test_hunter_abstained_no_chain(self):
        """Eliminated Hunter with None vote target does not chain."""
        eliminated = [1]
        player_roles = {1: "Hunter", 2: "Werewolf", 3: "Villager"}
        votes: dict[int, int | None] = {1: None, 2: 1, 3: 1}
        result = apply_hunter(eliminated, player_roles, votes)
        assert result == [1]

    def test_no_hunter_in_eliminated(self):
        """No Hunter in eliminated list -> no chain."""
        eliminated = [2]
        player_roles = {1: "Hunter", 2: "Werewolf", 3: "Villager"}
        votes: dict[int, int | None] = {1: 2, 2: 3, 3: 2}
        result = apply_hunter(eliminated, player_roles, votes)
        assert result == [2]

    def test_hunter_target_already_eliminated(self):
        """Hunter's target is already in eliminated -> no duplicate."""
        eliminated = [1, 2]
        player_roles = {1: "Hunter", 2: "Werewolf", 3: "Villager"}
        votes: dict[int, int | None] = {1: 2, 2: 3, 3: 1}
        result = apply_hunter(eliminated, player_roles, votes)
        assert result == [1, 2]

    def test_empty_eliminated(self):
        """Empty eliminated list -> empty result."""
        player_roles = {1: "Hunter", 2: "Werewolf"}
        votes: dict[int, int | None] = {1: 2, 2: 1}
        result = apply_hunter([], player_roles, votes)
        assert result == []

    def test_hunter_dies_in_tie_chain_still_fires(self):
        """Spec: 'If the Hunter dies in a tie, the ability still triggers.'

        Two players tied at 2 votes each -> both eliminated.
        Player 1 is Hunter and voted for player 3 -> chain kills player 3.
        """
        # Two players tied at 2 votes each -> both eliminated
        vote_counts = {1: 2, 2: 2}
        eliminated = determine_elimination(vote_counts)
        assert sorted(eliminated) == [1, 2]

        # Player 1 is Hunter, voted for player 3
        player_roles = {1: "Hunter", 2: "Werewolf", 3: "Villager", 4: "Seer"}
        votes: dict[int, int | None] = {1: 3, 2: 1, 3: 2, 4: 2}
        result = apply_hunter(eliminated, player_roles, votes)
        assert 3 in result  # Hunter's target also dies
        assert sorted(result) == [1, 2, 3]

    def test_hunter_circular_chain_terminates(self):
        """Hunter kills Doppelganger-as-Hunter; chain does not recurse back.

        Only 1 Hunter card exists in v1; use Doppelganger-as-Hunter for the
        second Hunter-like player.
        """
        eliminated = [1]
        player_roles = {1: "Hunter", 2: "Doppelganger", 3: "Villager"}
        doppelganger_copied = {2: "Hunter"}
        votes: dict[int, int | None] = {1: 2, 2: 3, 3: 1}
        result = apply_hunter(eliminated, player_roles, votes, doppelganger_copied)
        assert sorted(result) == [1, 2]

    def test_swapped_hunter_card_new_holder_triggers_chain(self):
        """Spec: Hunter ability belongs to the card position, not the original player.

        If Robber steals the Hunter card, the Robber now holds Hunter.
        If the Robber (now Hunter) is eliminated, THEIR vote target dies.
        The original Hunter player (now Robber) does NOT trigger the chain.
        """
        # After night: player 1 holds Robber (was original Hunter),
        # player 2 holds Hunter (was original Robber who stole it)
        eliminated = [2]  # Player 2 (now Hunter) eliminated
        player_roles = {1: "Robber", 2: "Hunter", 3: "Werewolf", 4: "Villager"}
        votes: dict[int, int | None] = {1: 3, 2: 3, 3: 1, 4: 1}

        result = apply_hunter(eliminated, player_roles, votes)
        # Player 2's vote target (player 3) should also die
        assert 3 in result
        # Player 1 (original Hunter, now Robber) does NOT trigger chain
        assert sorted(result) == [2, 3]

    def test_doppelganger_as_hunter_robbed_loses_passive(self):
        """Spec: Doppelganger-as-Hunter gets robbed, now holds Robber card.

        The passive Hunter ability requires player_roles == "Doppelganger"
        for doppelganger_copied lookup. Since the Doppelganger was robbed
        and now holds "Robber", they no longer qualify. No chain kill.
        """
        # After night: DG (player 1) copied Hunter, then Robber stole DG's card.
        # Player 1 now holds "Robber", player 2 holds "Doppelganger".
        eliminated = [1]
        player_roles = {1: "Robber", 2: "Doppelganger", 3: "Werewolf", 4: "Villager"}
        doppelganger_copied = {1: "Hunter"}  # DG copied Hunter, but card is now Robber
        votes: dict[int, int | None] = {1: 3, 2: 1, 3: 4, 4: 1}

        result = apply_hunter(eliminated, player_roles, votes, doppelganger_copied)
        # Player 1 holds Robber card — NOT recognized as Hunter
        assert sorted(result) == [1], (
            "Doppelganger who was robbed no longer holds Doppelganger card, "
            "so Hunter passive does not apply"
        )
