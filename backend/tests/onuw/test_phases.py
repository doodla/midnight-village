"""
Unit tests for ONUW phase transition validation.

Tests the pure Python phase logic with no Django dependencies.
"""

import pytest

from apps.onuw.engine.phases import (
    ALL_PHASES,
    VALID_TRANSITIONS,
    validate_phase_transition,
)

pytestmark = pytest.mark.unit


class TestPhaseTransitionValidation:
    """Tests for validate_phase_transition()."""

    def test_lobby_to_night_is_valid(self):
        """Lobby can transition to night."""
        assert validate_phase_transition("lobby", "night") is True

    def test_night_to_discussion_is_valid(self):
        """Night can transition to discussion."""
        assert validate_phase_transition("night", "discussion") is True

    def test_discussion_to_voting_is_valid(self):
        """Discussion can transition to voting."""
        assert validate_phase_transition("discussion", "voting") is True

    def test_voting_to_results_is_valid(self):
        """Voting can transition to results."""
        assert validate_phase_transition("voting", "results") is True

    def test_lobby_to_voting_is_invalid(self):
        """Lobby cannot skip directly to voting."""
        assert validate_phase_transition("lobby", "voting") is False

    def test_lobby_to_discussion_is_invalid(self):
        """Lobby cannot skip directly to discussion."""
        assert validate_phase_transition("lobby", "discussion") is False

    def test_lobby_to_results_is_invalid(self):
        """Lobby cannot skip directly to results."""
        assert validate_phase_transition("lobby", "results") is False

    def test_results_to_night_is_invalid(self):
        """Results is terminal -- cannot go back to night."""
        assert validate_phase_transition("results", "night") is False

    def test_results_to_lobby_is_invalid(self):
        """Results is terminal -- cannot go back to lobby."""
        assert validate_phase_transition("results", "lobby") is False

    def test_results_to_discussion_is_invalid(self):
        """Results is terminal -- cannot go to discussion."""
        assert validate_phase_transition("results", "discussion") is False

    def test_results_to_voting_is_invalid(self):
        """Results is terminal -- cannot go to voting."""
        assert validate_phase_transition("results", "voting") is False

    def test_night_to_voting_is_invalid(self):
        """Night cannot skip discussion and go directly to voting."""
        assert validate_phase_transition("night", "voting") is False

    def test_voting_to_discussion_is_invalid(self):
        """Voting cannot go backwards to discussion."""
        assert validate_phase_transition("voting", "discussion") is False

    def test_discussion_to_night_is_invalid(self):
        """Discussion cannot go backwards to night."""
        assert validate_phase_transition("discussion", "night") is False

    def test_self_transition_is_invalid(self):
        """A phase cannot transition to itself."""
        for phase in ALL_PHASES:
            assert validate_phase_transition(phase, phase) is False

    def test_unknown_phase_returns_false(self):
        """An unknown source phase returns False."""
        assert validate_phase_transition("unknown", "night") is False

    def test_unknown_target_returns_false(self):
        """An unknown target phase returns False."""
        assert validate_phase_transition("lobby", "unknown") is False


class TestPhaseDefinitions:
    """Tests for the phase definitions themselves."""

    def test_all_phases_have_defined_transitions(self):
        """Every phase in ALL_PHASES has an entry in VALID_TRANSITIONS."""
        for phase in ALL_PHASES:
            assert phase in VALID_TRANSITIONS

    def test_all_phases_list_matches_transitions_keys(self):
        """ALL_PHASES matches the keys of VALID_TRANSITIONS."""
        assert set(ALL_PHASES) == set(VALID_TRANSITIONS.keys())

    def test_results_is_terminal(self):
        """Results phase has no valid transitions (terminal state)."""
        assert VALID_TRANSITIONS["results"] == []

    def test_five_phases_defined(self):
        """There are exactly 5 phases defined."""
        assert len(ALL_PHASES) == 5

    def test_phase_names(self):
        """All expected phase names are present."""
        expected = {"lobby", "night", "discussion", "voting", "results"}
        assert set(ALL_PHASES) == expected
