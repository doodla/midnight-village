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

    def test_all_tied_no_elimination(self):
        """When ALL voted-for players have equal votes, no one is eliminated."""
        vote_counts = {1: 2, 2: 2, 3: 2}
        eliminated = determine_elimination(vote_counts)
        assert eliminated == []

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

    def test_hunter_votes_for_another_hunter_chain(self):
        """Hunter A eliminates Hunter B, Hunter B's target also eliminated."""
        eliminated = [1]
        player_roles = {1: "Hunter", 2: "Hunter", 3: "Villager", 4: "Werewolf"}
        votes: dict[int, int | None] = {1: 2, 2: 3, 3: 4, 4: 1}
        result = apply_hunter(eliminated, player_roles, votes)
        assert sorted(result) == [1, 2, 3]

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

    def test_hunter_circular_chain_terminates(self):
        """Two Hunters targeting each other don't loop infinitely."""
        eliminated = [1]
        player_roles = {1: "Hunter", 2: "Hunter", 3: "Villager"}
        votes: dict[int, int | None] = {1: 2, 2: 1, 3: 1}
        result = apply_hunter(eliminated, player_roles, votes)
        assert sorted(result) == [1, 2]
