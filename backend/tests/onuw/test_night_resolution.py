"""Unit tests for ONUW night phase wave resolution engine."""

import pytest

from apps.onuw.engine.night import get_required_actions, resolve_night, resolve_wave
from apps.onuw.engine.state import GameState, NightAction

pytestmark = pytest.mark.unit


def _make_state(
    player_roles: dict[int, str] | None = None,
    center_cards: list[str] | None = None,
) -> GameState:
    """Create a GameState with sensible defaults for testing."""
    roles = player_roles or {
        1: "Werewolf",
        2: "Seer",
        3: "Robber",
        4: "Troublemaker",
        5: "Drunk",
    }
    center = center_cards or ["Villager", "Tanner", "Villager"]
    return GameState(
        player_roles=roles,
        center_cards=center,
        original_roles=dict(roles),
    )


# ── resolve_wave Tests ───────────────────────────────────────────────────────


class TestResolveWave:
    """Tests for resolve_wave."""

    def test_single_seer_peek_correct(self):
        state = _make_state()
        actions = [
            NightAction(
                player_id=2,
                role_acting_as="Seer",
                action_type="peek_player",
                targets={"player_id": 1},
            ),
        ]
        new_state, results = resolve_wave(state, actions, wave=3)
        assert len(results) == 1
        assert results[0].revealed_info["peeked_role"] == "Werewolf"
        # No state mutation from Seer
        assert new_state.player_roles == state.player_roles

    def test_robber_and_troublemaker_canonical_order(self):
        """Troublemaker sees state AFTER Robber's swap."""
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Seer",
                3: "Robber",
                4: "Troublemaker",
                5: "Villager",
            }
        )
        actions = [
            # Robber swaps with player 1 (Werewolf)
            NightAction(
                player_id=3,
                role_acting_as="Robber",
                action_type="swap_with_player",
                targets={"player_id": 1},
            ),
            # Troublemaker swaps players 1 and 2
            # After Robber: player 1 has Robber, player 3 has Werewolf
            # Troublemaker swaps 1 (now Robber) and 2 (Seer)
            NightAction(
                player_id=4,
                role_acting_as="Troublemaker",
                action_type="swap_others",
                targets={"player_ids": [1, 2]},
            ),
        ]
        new_state, results = resolve_wave(state, actions, wave=3)

        # Robber result: got Werewolf from player 1
        assert results[0].revealed_info["new_role"] == "Werewolf"

        # After Robber swap: {1: Robber, 2: Seer, 3: Werewolf, 4: Troublemaker, 5: Villager}
        # After Troublemaker swap (1, 2): {1: Seer, 2: Robber, 3: Werewolf, 4: Troublemaker, 5: Villager}
        assert new_state.player_roles[1] == "Seer"
        assert new_state.player_roles[2] == "Robber"
        assert new_state.player_roles[3] == "Werewolf"

    def test_spec_example_1_troublemaker_undoes_robber_swap(self):
        """Spec Example 1: Robber swaps Alice+Bob, Troublemaker re-swaps same pair.

        Initial: Alice(1)=Werewolf, Bob(3)=Robber, Carol(4)=Villager.
        Robber(Bob) swaps with Alice → Bob=Werewolf, Alice=Robber.
        Troublemaker(Carol) swaps Alice and Bob → back to original.
        "The Troublemaker 'undid' the Robber's swap."
        """
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Seer",
                3: "Robber",
                4: "Troublemaker",
                5: "Villager",
            }
        )
        actions = [
            # Robber(3) swaps with player 1 (Werewolf)
            NightAction(
                player_id=3,
                role_acting_as="Robber",
                action_type="swap_with_player",
                targets={"player_id": 1},
            ),
            # Troublemaker(4) swaps same pair: players 1 and 3
            NightAction(
                player_id=4,
                role_acting_as="Troublemaker",
                action_type="swap_others",
                targets={"player_ids": [1, 3]},
            ),
        ]
        new_state, results = resolve_wave(state, actions, wave=3)

        # Robber saw Werewolf when stealing from player 1
        assert results[0].revealed_info["new_role"] == "Werewolf"

        # After Robber: {1: Robber, 3: Werewolf}
        # After Troublemaker re-swaps 1↔3: {1: Werewolf, 3: Robber}
        # Back to original state for players 1 and 3
        assert new_state.player_roles[1] == "Werewolf"
        assert new_state.player_roles[3] == "Robber"
        assert new_state.player_roles[2] == "Seer"
        assert new_state.player_roles[4] == "Troublemaker"
        assert new_state.player_roles[5] == "Villager"

    def test_skip_action_is_logged(self):
        state = _make_state()
        actions = [
            NightAction(
                player_id=2,
                role_acting_as="Seer",
                action_type="skip",
                targets={},
            ),
        ]
        new_state, results = resolve_wave(state, actions, wave=3)
        assert len(results) == 1
        assert results[0].revealed_info == {}
        assert "skipped" in results[0].state_mutations[0].lower()
        # Log entry recorded
        assert len(new_state.action_log) == 1
        assert new_state.action_log[0].action_type == "skip"

    def test_empty_wave_returns_unchanged_state(self):
        state = _make_state()
        new_state, results = resolve_wave(state, [], wave=2)
        assert results == []
        assert new_state.player_roles == state.player_roles

    def test_wave_2_see_team_actions_all_processed(self):
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Werewolf",
                3: "Minion",
                4: "Mason",
                5: "Mason",
            }
        )
        actions = [
            NightAction(
                player_id=1,
                role_acting_as="Werewolf",
                action_type="see_team",
                targets={},
            ),
            NightAction(
                player_id=2,
                role_acting_as="Werewolf",
                action_type="see_team",
                targets={},
            ),
            NightAction(
                player_id=3,
                role_acting_as="Minion",
                action_type="see_team",
                targets={},
            ),
            NightAction(
                player_id=4,
                role_acting_as="Mason",
                action_type="see_team",
                targets={},
            ),
            NightAction(
                player_id=5,
                role_acting_as="Mason",
                action_type="see_team",
                targets={},
            ),
        ]
        _new_state, results = resolve_wave(state, actions, wave=2)
        assert len(results) == 5
        # Werewolves see each other
        assert results[0].revealed_info["werewolves"] == [2]
        assert results[1].revealed_info["werewolves"] == [1]
        # Minion sees werewolves
        assert sorted(results[2].revealed_info["werewolves"]) == [1, 2]
        # Masons see each other
        assert results[3].revealed_info["masons"] == [5]
        assert results[4].revealed_info["masons"] == [4]


class TestResolveWaveCanonicalOrder:
    """Tests specifically for wave 3 canonical ordering."""

    def test_full_wave_3_canonical_order(self):
        """Seer -> Robber -> Troublemaker -> Drunk, each seeing cumulative state."""
        state = _make_state(
            player_roles={
                1: "Villager",
                2: "Seer",
                3: "Robber",
                4: "Troublemaker",
                5: "Drunk",
            },
            center_cards=["Werewolf", "Tanner", "Villager"],
        )
        actions = [
            # Drunk swaps with center 0 (should be last)
            NightAction(
                player_id=5,
                role_acting_as="Drunk",
                action_type="swap_with_center",
                targets={"center_index": 0},
            ),
            # Seer peeks player 1 (should be first)
            NightAction(
                player_id=2,
                role_acting_as="Seer",
                action_type="peek_player",
                targets={"player_id": 1},
            ),
            # Troublemaker swaps 1 and 3 (should be after Robber)
            NightAction(
                player_id=4,
                role_acting_as="Troublemaker",
                action_type="swap_others",
                targets={"player_ids": [1, 3]},
            ),
            # Robber swaps with 1 (should be after Seer)
            NightAction(
                player_id=3,
                role_acting_as="Robber",
                action_type="swap_with_player",
                targets={"player_id": 1},
            ),
        ]
        new_state, results = resolve_wave(state, actions, wave=3)

        # Results should be in canonical order: Seer, Robber, Troublemaker, Drunk
        # Seer peeks player 1 (Villager at this point)
        assert results[0].player_id == 2
        assert results[0].revealed_info["peeked_role"] == "Villager"

        # Robber swaps with player 1 -> gets Villager
        assert results[1].player_id == 3
        assert results[1].revealed_info["new_role"] == "Villager"
        # After Robber: {1: Robber, 2: Seer, 3: Villager, 4: Troublemaker, 5: Drunk}

        # Troublemaker swaps 1 and 3
        # After: {1: Villager, 2: Seer, 3: Robber, 4: Troublemaker, 5: Drunk}
        assert results[2].player_id == 4

        # Drunk swaps with center 0 (Werewolf)
        # After: {1: Villager, 2: Seer, 3: Robber, 4: Troublemaker, 5: Werewolf}
        # Center: [Drunk, Tanner, Villager]
        assert results[3].player_id == 5

        assert new_state.player_roles[1] == "Villager"
        assert new_state.player_roles[3] == "Robber"
        assert new_state.player_roles[5] == "Werewolf"
        assert new_state.center_cards[0] == "Drunk"


# ── resolve_night Tests ──────────────────────────────────────────────────────


class TestResolveNight:
    """Tests for resolve_night full night processing."""

    def test_full_5_player_game_produces_correct_final_state(self):
        """A complete night with all waves produces correct final state."""
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Seer",
                3: "Robber",
                4: "Troublemaker",
                5: "Insomniac",
            },
            center_cards=["Villager", "Drunk", "Villager"],
        )
        all_actions: dict[int, list[NightAction]] = {
            2: [
                NightAction(
                    player_id=1,
                    role_acting_as="Werewolf",
                    action_type="see_team",
                    targets={},
                ),
            ],
            3: [
                NightAction(
                    player_id=2,
                    role_acting_as="Seer",
                    action_type="peek_player",
                    targets={"player_id": 1},
                ),
                NightAction(
                    player_id=3,
                    role_acting_as="Robber",
                    action_type="swap_with_player",
                    targets={"player_id": 1},
                ),
                NightAction(
                    player_id=4,
                    role_acting_as="Troublemaker",
                    action_type="swap_others",
                    targets={"player_ids": [1, 2]},
                ),
            ],
            4: [
                NightAction(
                    player_id=5,
                    role_acting_as="Insomniac",
                    action_type="peek_player",
                    targets={},
                ),
            ],
        }
        final_state, results_by_wave = resolve_night(state, all_actions)

        # Wave 2: Werewolf is alone, sees empty list
        assert 2 in results_by_wave
        w2_results = results_by_wave[2]
        assert w2_results[0].revealed_info["werewolves"] == []

        # Wave 3 canonical order:
        # Seer peeks player 1 -> sees Werewolf (pre-swap)
        # Robber swaps with player 1 -> gets Werewolf, player 1 gets Robber
        # Troublemaker swaps 1 and 2 -> 1 gets Seer, 2 gets Robber
        assert 3 in results_by_wave
        w3_results = results_by_wave[3]
        seer_result = next(r for r in w3_results if r.player_id == 2)
        assert seer_result.revealed_info["peeked_role"] == "Werewolf"

        robber_result = next(r for r in w3_results if r.player_id == 3)
        assert robber_result.revealed_info["new_role"] == "Werewolf"

        # Final: {1: Seer, 2: Robber, 3: Werewolf, 4: Troublemaker, 5: Insomniac}
        assert final_state.player_roles[1] == "Seer"
        assert final_state.player_roles[2] == "Robber"
        assert final_state.player_roles[3] == "Werewolf"
        assert final_state.player_roles[4] == "Troublemaker"
        assert final_state.player_roles[5] == "Insomniac"

        # Wave 4: Insomniac sees their own (unchanged) role
        assert 4 in results_by_wave
        w4_results = results_by_wave[4]
        assert w4_results[0].revealed_info["current_role"] == "Insomniac"

    def test_doppelganger_copies_robber_acts_in_wave_1(self):
        """Doppelganger copies Robber, acts as Robber immediately in wave 1."""
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Werewolf",
                3: "Robber",
                4: "Villager",
                5: "Seer",
            },
            center_cards=["Tanner", "Villager", "Drunk"],
        )
        all_actions: dict[int, list[NightAction]] = {
            1: [
                # Doppelganger copies player 3 (Robber)
                NightAction(
                    player_id=1,
                    role_acting_as="Doppelganger",
                    action_type="peek_player",
                    targets={"player_id": 3},
                ),
                # Doppelganger-as-Robber swaps with player 2 (Werewolf)
                NightAction(
                    player_id=1,
                    role_acting_as="Robber",
                    action_type="swap_with_player",
                    targets={"player_id": 2},
                ),
            ],
            2: [
                NightAction(
                    player_id=2,
                    role_acting_as="Werewolf",
                    action_type="see_team",
                    targets={},
                ),
            ],
            3: [
                # Real Robber swaps with player 4 (Villager)
                NightAction(
                    player_id=3,
                    role_acting_as="Robber",
                    action_type="swap_with_player",
                    targets={"player_id": 4},
                ),
                # Seer peeks player 2
                NightAction(
                    player_id=5,
                    role_acting_as="Seer",
                    action_type="peek_player",
                    targets={"player_id": 2},
                ),
            ],
        }
        final_state, results_by_wave = resolve_night(state, all_actions)

        # Wave 1: Doppelganger copies Robber, then Doppelganger-as-Robber swaps
        assert 1 in results_by_wave
        w1_results = results_by_wave[1]
        assert len(w1_results) == 2
        assert w1_results[0].revealed_info["copied_role"] == "Robber"

        # Doppelganger-as-Robber gets Werewolf from player 2
        assert w1_results[1].player_id == 1
        assert w1_results[1].revealed_info["new_role"] == "Werewolf"

        # After Wave 1: player 1 has Werewolf, player 2 has Doppelganger

        # Wave 3 canonical order: Seer -> Robber
        # Seer peeks player 2 -> sees Doppelganger (post-Wave 1 swap)
        # Real Robber swaps with player 4 -> gets Villager

        w3_results = results_by_wave[3]

        seer_result = next(r for r in w3_results if r.player_id == 5)
        assert seer_result.revealed_info["peeked_role"] == "Doppelganger"

        robber_result = next(r for r in w3_results if r.player_id == 3)
        assert robber_result.revealed_info["new_role"] == "Villager"

        # Final state:
        # 1: Werewolf (Doppelganger-as-Robber swapped with player 2 in Wave 1)
        # 2: Doppelganger (got Doppelganger from player 1 in Wave 1)
        # 3: Villager (swapped with player 4 in Wave 3)
        # 4: Robber (got Robber from player 3 in Wave 3)
        # 5: Seer (unchanged)
        assert final_state.player_roles[1] == "Werewolf"
        assert final_state.player_roles[2] == "Doppelganger"
        assert final_state.player_roles[3] == "Villager"
        assert final_state.player_roles[4] == "Robber"
        assert final_state.player_roles[5] == "Seer"

    def test_player_who_skips_is_logged_no_error(self):
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Seer",
                3: "Robber",
                4: "Villager",
                5: "Drunk",
            }
        )
        all_actions: dict[int, list[NightAction]] = {
            2: [
                NightAction(
                    player_id=1,
                    role_acting_as="Werewolf",
                    action_type="see_team",
                    targets={},
                ),
            ],
            3: [
                # Seer skips
                NightAction(
                    player_id=2,
                    role_acting_as="Seer",
                    action_type="skip",
                    targets={},
                ),
                # Robber acts
                NightAction(
                    player_id=3,
                    role_acting_as="Robber",
                    action_type="swap_with_player",
                    targets={"player_id": 1},
                ),
                # Drunk acts
                NightAction(
                    player_id=5,
                    role_acting_as="Drunk",
                    action_type="swap_with_center",
                    targets={"center_index": 0},
                ),
            ],
        }
        _final_state, results_by_wave = resolve_night(state, all_actions)

        # Should not raise
        w3_results = results_by_wave[3]
        skip_result = next(r for r in w3_results if r.player_id == 2)
        assert skip_result.revealed_info == {}

        # Robber still works
        robber_result = next(r for r in w3_results if r.player_id == 3)
        assert robber_result.revealed_info["new_role"] == "Werewolf"

    def test_deterministic_given_same_inputs(self):
        """Same inputs always produce same outputs."""
        state = _make_state()
        all_actions: dict[int, list[NightAction]] = {
            3: [
                NightAction(
                    player_id=2,
                    role_acting_as="Seer",
                    action_type="peek_player",
                    targets={"player_id": 1},
                ),
                NightAction(
                    player_id=3,
                    role_acting_as="Robber",
                    action_type="swap_with_player",
                    targets={"player_id": 1},
                ),
                NightAction(
                    player_id=5,
                    role_acting_as="Drunk",
                    action_type="swap_with_center",
                    targets={"center_index": 0},
                ),
            ],
        }
        state1, results1 = resolve_night(state, all_actions)
        state2, results2 = resolve_night(state, all_actions)

        assert state1.player_roles == state2.player_roles
        assert state1.center_cards == state2.center_cards
        assert len(results1) == len(results2)
        for wave in results1:
            assert wave in results2
            for r1, r2 in zip(results1[wave], results2[wave], strict=True):
                assert r1.player_id == r2.player_id
                assert r1.revealed_info == r2.revealed_info

    def test_wave_ordering_1_before_2_before_3_before_4(self):
        """Log entries show waves processed in order."""
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Werewolf",
                3: "Seer",
                4: "Villager",
                5: "Insomniac",
            },
            center_cards=["Robber", "Drunk", "Villager"],
        )
        all_actions: dict[int, list[NightAction]] = {
            1: [
                NightAction(
                    player_id=1,
                    role_acting_as="Doppelganger",
                    action_type="peek_player",
                    targets={"player_id": 4},
                ),
            ],
            2: [
                NightAction(
                    player_id=2,
                    role_acting_as="Werewolf",
                    action_type="see_team",
                    targets={},
                ),
            ],
            3: [
                NightAction(
                    player_id=3,
                    role_acting_as="Seer",
                    action_type="peek_player",
                    targets={"player_id": 2},
                ),
            ],
            4: [
                NightAction(
                    player_id=5,
                    role_acting_as="Insomniac",
                    action_type="peek_player",
                    targets={},
                ),
            ],
        }
        final_state, results_by_wave = resolve_night(state, all_actions)

        # All waves should have results
        assert 1 in results_by_wave
        assert 2 in results_by_wave
        assert 3 in results_by_wave
        assert 4 in results_by_wave

        # Log entries should be in wave order
        waves = [entry.wave for entry in final_state.action_log]
        assert waves == sorted(waves)

    def test_doppelganger_copies_troublemaker_acts_in_wave_1_robber_in_wave_3(self):
        """
        Complex scenario: Doppelganger copies Troublemaker, acts immediately in wave 1.
        Robber still acts in wave 3 and sees the post-wave-1 state.
        """
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Troublemaker",
                3: "Robber",
                4: "Werewolf",
                5: "Seer",
            },
            center_cards=["Villager", "Drunk", "Villager"],
        )
        all_actions: dict[int, list[NightAction]] = {
            1: [
                NightAction(
                    player_id=1,
                    role_acting_as="Doppelganger",
                    action_type="peek_player",
                    targets={"player_id": 2},
                ),
                # Doppelganger-as-Troublemaker swaps players 3 and 5 immediately
                NightAction(
                    player_id=1,
                    role_acting_as="Troublemaker",
                    action_type="swap_others",
                    targets={"player_ids": [3, 5]},
                ),
            ],
            2: [
                NightAction(
                    player_id=4,
                    role_acting_as="Werewolf",
                    action_type="see_team",
                    targets={},
                ),
            ],
            3: [
                # Seer peeks player 4
                NightAction(
                    player_id=5,
                    role_acting_as="Seer",
                    action_type="peek_player",
                    targets={"player_id": 4},
                ),
                # Robber swaps with player 4 (Werewolf)
                NightAction(
                    player_id=3,
                    role_acting_as="Robber",
                    action_type="swap_with_player",
                    targets={"player_id": 4},
                ),
                # Real Troublemaker swaps players 4 and 5
                NightAction(
                    player_id=2,
                    role_acting_as="Troublemaker",
                    action_type="swap_others",
                    targets={"player_ids": [4, 5]},
                ),
            ],
        }
        final_state, results_by_wave = resolve_night(state, all_actions)

        # Wave 1:
        # 1. Doppelganger copies Troublemaker
        # 2. Doppelganger-as-Troublemaker swaps players 3 and 5
        #    State after wave 1: {1: Doppelganger, 2: Troublemaker, 3: Seer, 4: Werewolf, 5: Robber}
        w1_results = results_by_wave[1]
        assert len(w1_results) == 2
        assert w1_results[0].revealed_info["copied_role"] == "Troublemaker"

        # Wave 3 canonical order (post-wave-1 state):
        # Canonical: Seer -> Robber -> Troublemaker
        # 1. Seer (player 5) peeks player 4 -> Werewolf
        # 2. Robber (player 3) swaps with player 4 -> gets Werewolf, player 4 gets Seer
        #    State: {1: Doppelganger, 2: Troublemaker, 3: Werewolf, 4: Seer, 5: Robber}
        # 3. Real Troublemaker (player 2) swaps 4 and 5
        #    State: {1: Doppelganger, 2: Troublemaker, 3: Werewolf, 4: Robber, 5: Seer}

        w3_results = results_by_wave[3]

        seer_result = next(r for r in w3_results if r.player_id == 5)
        assert seer_result.revealed_info["peeked_role"] == "Werewolf"

        robber_result = next(r for r in w3_results if r.player_id == 3)
        assert robber_result.revealed_info["new_role"] == "Werewolf"

        assert final_state.player_roles[1] == "Doppelganger"
        assert final_state.player_roles[2] == "Troublemaker"
        assert final_state.player_roles[3] == "Werewolf"
        assert final_state.player_roles[4] == "Robber"
        assert final_state.player_roles[5] == "Seer"

    def test_doppelganger_followup_skipped_when_no_action_submitted(self):
        """If Doppelganger copies a role with an action but submits no follow-up, it's skipped."""
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Seer",
                3: "Werewolf",
                4: "Villager",
                5: "Robber",
            },
            center_cards=["Drunk", "Tanner", "Villager"],
        )
        all_actions: dict[int, list[NightAction]] = {
            1: [
                NightAction(
                    player_id=1,
                    role_acting_as="Doppelganger",
                    action_type="peek_player",
                    targets={"player_id": 5},
                ),
                # No follow-up from Doppelganger-as-Robber in wave 1
            ],
            2: [
                NightAction(
                    player_id=3,
                    role_acting_as="Werewolf",
                    action_type="see_team",
                    targets={},
                ),
            ],
            3: [
                NightAction(
                    player_id=2,
                    role_acting_as="Seer",
                    action_type="peek_player",
                    targets={"player_id": 3},
                ),
                NightAction(
                    player_id=5,
                    role_acting_as="Robber",
                    action_type="swap_with_player",
                    targets={"player_id": 3},
                ),
            ],
        }
        _final_state, _results_by_wave = resolve_night(state, all_actions)

        # Should not raise. Doppelganger skipped follow-up.
        # Check that a skip was logged for player 1 in wave 1
        # (Robber follow-up now happens in wave 1, not wave 3)
        w1_log_entries = [
            e for e in _final_state.action_log if e.wave == 1 and e.player_id == 1
        ]
        # Should have 2 entries: the Doppelganger peek and the skipped Robber follow-up
        assert len(w1_log_entries) == 2
        assert w1_log_entries[0].action_type == "peek_player"
        assert w1_log_entries[1].action_type == "skip"

    def test_doppelganger_copies_insomniac_sees_own_role_in_wave_4(self):
        """Doppelganger copies Insomniac, sees own role in wave 4."""
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Insomniac",
                3: "Robber",
                4: "Werewolf",
                5: "Villager",
            },
            center_cards=["Seer", "Drunk", "Villager"],
        )
        all_actions: dict[int, list[NightAction]] = {
            1: [
                NightAction(
                    player_id=1,
                    role_acting_as="Doppelganger",
                    action_type="peek_player",
                    targets={"player_id": 2},
                ),
            ],
            2: [
                NightAction(
                    player_id=4,
                    role_acting_as="Werewolf",
                    action_type="see_team",
                    targets={},
                ),
            ],
            3: [
                # Robber swaps with Doppelganger (player 1)
                NightAction(
                    player_id=3,
                    role_acting_as="Robber",
                    action_type="swap_with_player",
                    targets={"player_id": 1},
                ),
            ],
            4: [
                # Real Insomniac peeks own role
                NightAction(
                    player_id=2,
                    role_acting_as="Insomniac",
                    action_type="peek_player",
                    targets={},
                ),
                # Doppelganger-as-Insomniac peeks own role
                NightAction(
                    player_id=1,
                    role_acting_as="Insomniac",
                    action_type="peek_player",
                    targets={},
                ),
            ],
        }
        _final_state, results_by_wave = resolve_night(state, all_actions)

        # After Robber swaps with Doppelganger:
        # Player 1: Robber (was Doppelganger)
        # Player 3: Doppelganger (was Robber)
        # Doppelganger-as-Insomniac sees "Robber" (their current role after swap)
        w4_results = results_by_wave[4]
        doppel_insomniac = next(r for r in w4_results if r.player_id == 1)
        assert doppel_insomniac.revealed_info["current_role"] == "Robber"

        # Real Insomniac sees "Insomniac" (unchanged)
        real_insomniac = next(r for r in w4_results if r.player_id == 2)
        assert real_insomniac.revealed_info["current_role"] == "Insomniac"


# ── get_required_actions Tests ───────────────────────────────────────────────


class TestGetRequiredActions:
    """Tests for get_required_actions."""

    def test_wave_2_returns_werewolf_minion_mason(self):
        state = _make_state(
            player_roles={
                1: "Werewolf",
                2: "Minion",
                3: "Mason",
                4: "Villager",
                5: "Seer",
            }
        )
        prompts = get_required_actions(state, wave=2)
        player_ids = {p["player_id"] for p in prompts}
        assert player_ids == {1, 2, 3}

    def test_wave_3_returns_seer_robber_troublemaker_drunk(self):
        state = _make_state()
        prompts = get_required_actions(state, wave=3)
        player_ids = {p["player_id"] for p in prompts}
        assert player_ids == {2, 3, 4, 5}  # Seer, Robber, Troublemaker, Drunk

    def test_wave_with_no_roles_returns_empty(self):
        state = _make_state(player_roles={1: "Villager", 2: "Villager", 3: "Villager"})
        prompts = get_required_actions(state, wave=2)
        assert prompts == []

    def test_doppelganger_followup_included(self):
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Seer",
                3: "Robber",
                4: "Villager",
                5: "Werewolf",
            }
        )
        # Doppelganger-as-Seer follow-up now happens in wave 1
        prompts = get_required_actions(
            state,
            wave=1,
            doppelganger_info={1: "Seer"},
        )
        # Should include player 1 (Doppelganger acts in wave 1) and
        # Doppelganger-as-Seer follow-up also in wave 1
        player_ids = {p["player_id"] for p in prompts}
        assert 1 in player_ids

        # Wave 3 should NOT include Doppelganger-as-Seer follow-up
        w3_prompts = get_required_actions(
            state,
            wave=3,
            doppelganger_info={1: "Seer"},
        )
        w3_player_ids = {p["player_id"] for p in w3_prompts}
        assert 1 not in w3_player_ids
        # Real Seer and Robber still act in wave 3
        assert 2 in w3_player_ids
        assert 3 in w3_player_ids

    def test_prompt_includes_valid_targets(self):
        state = _make_state()
        prompts = get_required_actions(state, wave=3)
        seer_prompt = next(p for p in prompts if p["player_id"] == 2)
        assert "player_ids" in seer_prompt["valid_targets"]
        assert "center_indices" in seer_prompt["valid_targets"]
        # Seer cannot target self
        assert 2 not in seer_prompt["valid_targets"]["player_ids"]
