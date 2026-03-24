"""
Spec-validation tests for Doppelganger timing in ONUW night phase.

Per the official ONUW rules, Doppelganger follow-up actions for Wave 3 roles
(Seer, Robber, Troublemaker, Drunk) should execute IMMEDIATELY in Wave 1,
right after the Doppelganger copies the role. This means:

  - Doppelganger-as-Seer peeks BEFORE any Wave 2 or Wave 3 actions occur,
    so the Doppelganger sees the ORIGINAL game state.
  - Doppelganger-as-Robber/Troublemaker/Drunk swaps happen in Wave 1,
    BEFORE werewolves wake, before real Seer/Robber/etc act.
  - Wave 2 follow-ups (Werewolf, Mason, Minion) remain in Wave 2.
  - Wave 4 follow-ups (Insomniac) remain in Wave 4.

The current engine defers Wave 3 follow-ups to Wave 3 (with Doppelganger
sorted before the real role). These tests encode the CORRECT spec behavior
and are expected to fail against the current implementation -- this is TDD.
"""

import pytest

from apps.onuw.engine.night import resolve_night
from apps.onuw.engine.state import GameState, NightAction

pytestmark = pytest.mark.unit


# ── Helpers ──────────────────────────────────────────────────────────────────


def _make_state(
    player_roles: dict[int, str],
    center_cards: list[str] | None = None,
) -> GameState:
    """Create a GameState with given roles and sensible center card defaults."""
    center = center_cards or ["Villager", "Tanner", "Villager"]
    return GameState(
        player_roles=player_roles,
        center_cards=center,
        original_roles=dict(player_roles),
    )


# ── Test 1: Doppelganger-as-Seer acts in Wave 1, sees original state ────────


class TestDoppelgangerAsSeerWave1:
    """Spec: Doppelganger copies Seer, immediately peeks in Wave 1.

    The peek should see the ORIGINAL game state because no Wave 2 or
    Wave 3 actions have occurred yet.
    """

    def test_doppelganger_as_seer_peeks_in_wave_1_sees_original_state(self):
        """Doppelganger copies Seer, peeks player in Wave 1 before any other wave."""
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Seer",
                3: "Robber",
                4: "Werewolf",
                5: "Villager",
            },
        )

        # Spec behavior: Doppelganger copy AND follow-up both go in wave 1.
        # The Doppelganger peeks player 4, then immediately acts as Seer
        # to peek player 3 -- all within wave 1, before anything else.
        all_actions: dict[int, list[NightAction]] = {
            1: [
                # Doppelganger copies player 2 (Seer)
                NightAction(
                    player_id=1,
                    role_acting_as="Doppelganger",
                    action_type="peek_player",
                    targets={"player_id": 2},
                ),
                # Doppelganger-as-Seer immediately peeks player 4
                NightAction(
                    player_id=1,
                    role_acting_as="Seer",
                    action_type="peek_player",
                    targets={"player_id": 4},
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
                # Real Seer peeks player 3
                NightAction(
                    player_id=2,
                    role_acting_as="Seer",
                    action_type="peek_player",
                    targets={"player_id": 3},
                ),
                # Robber swaps with player 4
                NightAction(
                    player_id=3,
                    role_acting_as="Robber",
                    action_type="swap_with_player",
                    targets={"player_id": 4},
                ),
            ],
        }

        _final_state, results_by_wave = resolve_night(state, all_actions)

        # The Doppelganger-as-Seer result must be in Wave 1 results
        assert 1 in results_by_wave, "Wave 1 should have results"
        w1_results = results_by_wave[1]

        # There should be two results in wave 1: the copy and the follow-up peek
        assert len(w1_results) == 2, (
            "Wave 1 should contain both the Doppelganger copy action "
            "and the Doppelganger-as-Seer follow-up peek"
        )

        # First result: Doppelganger copies Seer
        assert w1_results[0].player_id == 1
        assert w1_results[0].revealed_info["copied_role"] == "Seer"

        # Second result: Doppelganger-as-Seer peeks player 4 and sees
        # the ORIGINAL role (Werewolf), because no swaps have happened yet
        doppel_seer_result = w1_results[1]
        assert doppel_seer_result.player_id == 1
        assert doppel_seer_result.revealed_info["peeked_role"] == "Werewolf"

        # The Doppelganger-as-Seer action should NOT appear in Wave 3 results
        if 3 in results_by_wave:
            w3_player_ids_and_roles = [
                (r.player_id, r.revealed_info) for r in results_by_wave[3]
            ]
            # Player 1 should not have any results in wave 3
            assert all(pid != 1 for pid, _ in w3_player_ids_and_roles), (
                "Doppelganger-as-Seer should NOT appear in Wave 3"
            )


# ── Test 2: Doppelganger-as-Robber swaps in Wave 1 ──────────────────────────


class TestDoppelgangerAsRobberWave1:
    """Spec: Doppelganger copies Robber, immediately swaps in Wave 1.

    When the real Robber acts in Wave 3, it should see the post-Doppelganger
    state (the swap already happened).
    """

    def test_doppelganger_as_robber_swaps_in_wave_1(self):
        """Doppelganger-as-Robber swap occurs before any Wave 2/3 actions."""
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Robber",
                3: "Werewolf",
                4: "Seer",
                5: "Villager",
            },
        )

        all_actions: dict[int, list[NightAction]] = {
            1: [
                # Doppelganger copies player 2 (Robber)
                NightAction(
                    player_id=1,
                    role_acting_as="Doppelganger",
                    action_type="peek_player",
                    targets={"player_id": 2},
                ),
                # Doppelganger-as-Robber immediately swaps with player 3 (Werewolf)
                NightAction(
                    player_id=1,
                    role_acting_as="Robber",
                    action_type="swap_with_player",
                    targets={"player_id": 3},
                ),
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
                # Real Robber swaps with player 5 (Villager)
                NightAction(
                    player_id=2,
                    role_acting_as="Robber",
                    action_type="swap_with_player",
                    targets={"player_id": 5},
                ),
                # Seer peeks player 1
                NightAction(
                    player_id=4,
                    role_acting_as="Seer",
                    action_type="peek_player",
                    targets={"player_id": 1},
                ),
            ],
        }

        final_state, results_by_wave = resolve_night(state, all_actions)

        # Wave 1: Doppelganger copies Robber, then swaps with player 3
        assert 1 in results_by_wave
        w1_results = results_by_wave[1]
        assert len(w1_results) == 2

        # Doppelganger-as-Robber gets Werewolf from player 3
        doppel_robber_result = w1_results[1]
        assert doppel_robber_result.player_id == 1
        assert doppel_robber_result.revealed_info["new_role"] == "Werewolf"

        # After Wave 1 swap: player 1 has Werewolf, player 3 has Doppelganger
        # Wave 3: Real Robber swaps with player 5 (Villager)
        #   -> player 2 gets Villager, player 5 gets Robber
        # Seer peeks player 1 -> should see Werewolf (swapped in Wave 1)

        w3_results = results_by_wave[3]
        robber_result = next(r for r in w3_results if r.player_id == 2)
        assert robber_result.revealed_info["new_role"] == "Villager"

        seer_result = next(r for r in w3_results if r.player_id == 4)
        assert seer_result.revealed_info["peeked_role"] == "Werewolf"

        # Final state:
        # Player 1: Werewolf (Doppelganger swapped with player 3 in Wave 1)
        # Player 2: Villager (Robber swapped with player 5 in Wave 3)
        # Player 3: Doppelganger (got Doppelganger from player 1 in Wave 1)
        # Player 4: Seer (unchanged)
        # Player 5: Robber (got Robber from player 2 in Wave 3)
        assert final_state.player_roles[1] == "Werewolf"
        assert final_state.player_roles[2] == "Villager"
        assert final_state.player_roles[3] == "Doppelganger"
        assert final_state.player_roles[4] == "Seer"
        assert final_state.player_roles[5] == "Robber"


# ── Test 3: Doppelganger-as-Troublemaker swaps in Wave 1 ────────────────────


class TestDoppelgangerAsTroublemakerWave1:
    """Spec: Doppelganger copies Troublemaker, swaps two others in Wave 1."""

    def test_doppelganger_as_troublemaker_swaps_in_wave_1(self):
        """Doppelganger-as-Troublemaker swap happens before any other role acts."""
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Troublemaker",
                3: "Werewolf",
                4: "Seer",
                5: "Villager",
            },
        )

        all_actions: dict[int, list[NightAction]] = {
            1: [
                # Doppelganger copies player 2 (Troublemaker)
                NightAction(
                    player_id=1,
                    role_acting_as="Doppelganger",
                    action_type="peek_player",
                    targets={"player_id": 2},
                ),
                # Doppelganger-as-Troublemaker swaps players 3 and 5
                NightAction(
                    player_id=1,
                    role_acting_as="Troublemaker",
                    action_type="swap_others",
                    targets={"player_ids": [3, 5]},
                ),
            ],
            2: [
                # Werewolf wakes -- but player 3 is no longer Werewolf
                # (swapped with player 5 in Wave 1). Player 3 now has Villager,
                # player 5 now has Werewolf.
                # However, the Werewolf see_team uses current role to find
                # teammates. Since player 3 STILL has role "Werewolf" assigned
                # at game start but was swapped... let's trace carefully.
                # After Wave 1: player 3=Villager, player 5=Werewolf
                # So player 5 submits see_team as Werewolf? No -- player 3
                # submitted this action already. The action is pre-submitted.
                NightAction(
                    player_id=3,
                    role_acting_as="Werewolf",
                    action_type="see_team",
                    targets={},
                ),
            ],
            3: [
                # Seer peeks player 3 -- should see Villager (swapped in Wave 1)
                NightAction(
                    player_id=4,
                    role_acting_as="Seer",
                    action_type="peek_player",
                    targets={"player_id": 3},
                ),
            ],
        }

        final_state, results_by_wave = resolve_night(state, all_actions)

        # Wave 1 should contain both the copy and the Troublemaker swap
        assert 1 in results_by_wave
        w1_results = results_by_wave[1]
        assert len(w1_results) == 2

        # After Wave 1: player 3 has Villager, player 5 has Werewolf
        # Seer peeks player 3 in Wave 3 -> sees Villager (post-Wave 1 swap)
        w3_results = results_by_wave[3]
        seer_result = next(r for r in w3_results if r.player_id == 4)
        assert seer_result.revealed_info["peeked_role"] == "Villager"

        # Final roles after all waves
        assert final_state.player_roles[3] == "Villager"
        assert final_state.player_roles[5] == "Werewolf"


# ── Test 4: Doppelganger-as-Drunk swaps in Wave 1 ───────────────────────────


class TestDoppelgangerAsDrunkWave1:
    """Spec: Doppelganger copies Drunk, swaps with center card in Wave 1."""

    def test_doppelganger_as_drunk_swaps_with_center_in_wave_1(self):
        """Doppelganger-as-Drunk center swap happens before any other role acts."""
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Drunk",
                3: "Seer",
                4: "Werewolf",
                5: "Villager",
            },
            center_cards=["Hunter", "Tanner", "Villager"],
        )

        all_actions: dict[int, list[NightAction]] = {
            1: [
                # Doppelganger copies player 2 (Drunk)
                NightAction(
                    player_id=1,
                    role_acting_as="Doppelganger",
                    action_type="peek_player",
                    targets={"player_id": 2},
                ),
                # Doppelganger-as-Drunk swaps with center card 0 (Hunter)
                NightAction(
                    player_id=1,
                    role_acting_as="Drunk",
                    action_type="swap_with_center",
                    targets={"center_index": 0},
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
                # Seer peeks center cards -- should see Doppelganger at index 0
                # (swapped in Wave 1) and Tanner at index 1 (unchanged)
                NightAction(
                    player_id=3,
                    role_acting_as="Seer",
                    action_type="peek_center",
                    targets={"center_indices": [0, 1]},
                ),
                # Real Drunk swaps with center card 2 (Villager)
                NightAction(
                    player_id=2,
                    role_acting_as="Drunk",
                    action_type="swap_with_center",
                    targets={"center_index": 2},
                ),
            ],
        }

        final_state, results_by_wave = resolve_night(state, all_actions)

        # Wave 1: Doppelganger copies Drunk, then swaps with center 0
        assert 1 in results_by_wave
        w1_results = results_by_wave[1]
        assert len(w1_results) == 2

        # After Wave 1: player 1 has Hunter (from center), center 0 has Doppelganger
        # Wave 3 Seer peeks center 0 -> should see Doppelganger (placed in Wave 1)
        w3_results = results_by_wave[3]
        seer_result = next(r for r in w3_results if r.player_id == 3)
        peeked_center = seer_result.revealed_info["peeked_center"]
        center_0_peek = next(p for p in peeked_center if p["index"] == 0)
        assert center_0_peek["role"] == "Doppelganger", (
            "Seer should see Doppelganger at center 0 (swapped in Wave 1)"
        )

        # Final state
        assert final_state.player_roles[1] == "Hunter"
        assert final_state.center_cards[0] == "Doppelganger"
        # Real Drunk swapped with center 2 (Villager)
        assert final_state.player_roles[2] == "Villager"
        assert final_state.center_cards[2] == "Drunk"


# ── Test 5: Doppelganger-as-Seer peeks, then real Robber swaps that player ──


class TestDoppelgangerAsSeerThenRobberSwaps:
    """Spec: Doppelganger-as-Seer sees original state; later swaps don't retroactively change it."""

    def test_doppelganger_as_seer_sees_original_then_robber_swaps_target(self):
        """
        Doppelganger-as-Seer peeks player 3 in Wave 1, sees Robber (original).
        Then real Robber swaps with player 3 in Wave 3.
        Doppelganger's peek result should still reflect the original role.
        """
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Seer",
                3: "Robber",
                4: "Werewolf",
                5: "Villager",
            },
        )

        all_actions: dict[int, list[NightAction]] = {
            1: [
                # Doppelganger copies player 2 (Seer)
                NightAction(
                    player_id=1,
                    role_acting_as="Doppelganger",
                    action_type="peek_player",
                    targets={"player_id": 2},
                ),
                # Doppelganger-as-Seer peeks player 4 (Werewolf)
                NightAction(
                    player_id=1,
                    role_acting_as="Seer",
                    action_type="peek_player",
                    targets={"player_id": 4},
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
                # Real Seer peeks player 4
                NightAction(
                    player_id=2,
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
            ],
        }

        _final_state, results_by_wave = resolve_night(state, all_actions)

        # Doppelganger-as-Seer peeked player 4 in Wave 1 -> sees Werewolf
        w1_results = results_by_wave[1]
        doppel_seer_result = w1_results[1]
        assert doppel_seer_result.player_id == 1
        assert doppel_seer_result.revealed_info["peeked_role"] == "Werewolf"

        # Real Seer peeks player 4 in Wave 3 (before Robber, per canonical order)
        # -> still sees Werewolf at this point
        w3_results = results_by_wave[3]
        real_seer_result = next(r for r in w3_results if r.player_id == 2)
        assert real_seer_result.revealed_info["peeked_role"] == "Werewolf"

        # Robber swaps with player 4 -> player 3 gets Werewolf, player 4 gets Robber
        robber_result = next(r for r in w3_results if r.player_id == 3)
        assert robber_result.revealed_info["new_role"] == "Werewolf"

        # Final: player 4 is now Robber, but both Seers saw Werewolf as expected
        assert _final_state.player_roles[3] == "Werewolf"
        assert _final_state.player_roles[4] == "Robber"


# ── Test 6: Doppelganger-as-Robber steals, then real Robber steals from Doppelganger ─


class TestDoppelgangerRobberChain:
    """Spec: Chain of Robber swaps starting in Wave 1."""

    def test_doppelganger_as_robber_then_real_robber_steals_from_doppelganger(self):
        """
        Wave 1: Doppelganger-as-Robber steals from player 3 (Werewolf).
          -> Player 1 gets Werewolf, player 3 gets Doppelganger.
        Wave 3: Real Robber steals from player 1 (now Werewolf).
          -> Player 2 gets Werewolf, player 1 gets Robber.

        The real Robber should see the post-Wave-1 state, getting Werewolf
        from player 1 (who stole it in Wave 1).
        """
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Robber",
                3: "Werewolf",
                4: "Villager",
                5: "Seer",
            },
        )

        all_actions: dict[int, list[NightAction]] = {
            1: [
                # Doppelganger copies player 2 (Robber)
                NightAction(
                    player_id=1,
                    role_acting_as="Doppelganger",
                    action_type="peek_player",
                    targets={"player_id": 2},
                ),
                # Doppelganger-as-Robber steals from player 3 (Werewolf)
                NightAction(
                    player_id=1,
                    role_acting_as="Robber",
                    action_type="swap_with_player",
                    targets={"player_id": 3},
                ),
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
                # Real Robber steals from player 1 (who now has Werewolf after Wave 1)
                NightAction(
                    player_id=2,
                    role_acting_as="Robber",
                    action_type="swap_with_player",
                    targets={"player_id": 1},
                ),
                # Seer peeks player 3
                NightAction(
                    player_id=5,
                    role_acting_as="Seer",
                    action_type="peek_player",
                    targets={"player_id": 3},
                ),
            ],
        }

        final_state, results_by_wave = resolve_night(state, all_actions)

        # Wave 1: Doppelganger-as-Robber steals Werewolf from player 3
        w1_results = results_by_wave[1]
        doppel_robber_result = w1_results[1]
        assert doppel_robber_result.player_id == 1
        assert doppel_robber_result.revealed_info["new_role"] == "Werewolf"

        # After Wave 1:
        #   Player 1: Werewolf, Player 3: Doppelganger

        # Wave 3 (canonical: Seer -> Robber):
        # Seer peeks player 3 -> sees Doppelganger (post-Wave 1)
        w3_results = results_by_wave[3]
        seer_result = next(r for r in w3_results if r.player_id == 5)
        assert seer_result.revealed_info["peeked_role"] == "Doppelganger"

        # Real Robber steals from player 1 -> gets Werewolf
        robber_result = next(r for r in w3_results if r.player_id == 2)
        assert robber_result.revealed_info["new_role"] == "Werewolf"

        # Final state:
        # Player 1: Robber (swapped away Werewolf to player 2 in Wave 3)
        # Player 2: Werewolf (stole from player 1 in Wave 3)
        # Player 3: Doppelganger (got it from player 1 in Wave 1)
        # Player 4: Villager (unchanged)
        # Player 5: Seer (unchanged)
        assert final_state.player_roles[1] == "Robber"
        assert final_state.player_roles[2] == "Werewolf"
        assert final_state.player_roles[3] == "Doppelganger"
        assert final_state.player_roles[4] == "Villager"
        assert final_state.player_roles[5] == "Seer"


# ── Test 7: Doppelganger Wave 2 follow-ups unchanged ────────────────────────


class TestDoppelgangerWave2FollowupsUnchanged:
    """Spec: Doppelganger-as-Werewolf and Doppelganger-as-Mason still act in Wave 2.

    Only Wave 3 follow-ups move to Wave 1. Wave 2 follow-ups are NOT affected.
    """

    def test_doppelganger_as_werewolf_acts_in_wave_2(self):
        """Doppelganger copies Werewolf, sees other werewolves in Wave 2."""
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Werewolf",
                3: "Seer",
                4: "Villager",
                5: "Villager",
            },
        )

        all_actions: dict[int, list[NightAction]] = {
            1: [
                # Doppelganger copies player 2 (Werewolf)
                NightAction(
                    player_id=1,
                    role_acting_as="Doppelganger",
                    action_type="peek_player",
                    targets={"player_id": 2},
                ),
            ],
            2: [
                # Real Werewolf sees team
                NightAction(
                    player_id=2,
                    role_acting_as="Werewolf",
                    action_type="see_team",
                    targets={},
                ),
                # Doppelganger-as-Werewolf sees team
                NightAction(
                    player_id=1,
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
        }

        _final_state, results_by_wave = resolve_night(state, all_actions)

        # Doppelganger-as-Werewolf should be in Wave 2, NOT Wave 1
        assert 2 in results_by_wave
        w2_results = results_by_wave[2]

        # Both the real Werewolf and Doppelganger-as-Werewolf should have results
        w2_player_ids = [r.player_id for r in w2_results]
        assert 1 in w2_player_ids, "Doppelganger-as-Werewolf should act in Wave 2"
        assert 2 in w2_player_ids, "Real Werewolf should act in Wave 2"

        # Wave 1 should only have the Doppelganger copy, NOT the Werewolf see_team
        w1_results = results_by_wave.get(1, [])
        assert len(w1_results) == 1, (
            "Wave 1 should only have the Doppelganger copy action"
        )
        assert w1_results[0].revealed_info.get("copied_role") == "Werewolf"

    def test_doppelganger_as_mason_acts_in_wave_2(self):
        """Doppelganger copies Mason, sees other Masons in Wave 2."""
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Mason",
                3: "Mason",
                4: "Werewolf",
                5: "Villager",
            },
        )

        all_actions: dict[int, list[NightAction]] = {
            1: [
                # Doppelganger copies player 2 (Mason)
                NightAction(
                    player_id=1,
                    role_acting_as="Doppelganger",
                    action_type="peek_player",
                    targets={"player_id": 2},
                ),
            ],
            2: [
                # Both real Masons see team
                NightAction(
                    player_id=2,
                    role_acting_as="Mason",
                    action_type="see_team",
                    targets={},
                ),
                NightAction(
                    player_id=3,
                    role_acting_as="Mason",
                    action_type="see_team",
                    targets={},
                ),
                # Doppelganger-as-Mason sees team
                NightAction(
                    player_id=1,
                    role_acting_as="Mason",
                    action_type="see_team",
                    targets={},
                ),
                # Werewolf sees team
                NightAction(
                    player_id=4,
                    role_acting_as="Werewolf",
                    action_type="see_team",
                    targets={},
                ),
            ],
        }

        _final_state, results_by_wave = resolve_night(state, all_actions)

        # Doppelganger-as-Mason should be in Wave 2
        assert 2 in results_by_wave
        w2_results = results_by_wave[2]
        w2_player_ids = [r.player_id for r in w2_results]
        assert 1 in w2_player_ids, "Doppelganger-as-Mason should act in Wave 2"

        # Doppelganger-as-Mason sees the other Masons
        doppel_mason_result = next(r for r in w2_results if r.player_id == 1)
        assert sorted(doppel_mason_result.revealed_info["masons"]) == [2, 3]


# ── Test 8: Doppelganger-as-Insomniac still acts in Wave 4 ──────────────────


class TestDoppelgangerAsInsomniacWave4:
    """Spec: Doppelganger-as-Insomniac always acts in Wave 4, unaffected by timing fix."""

    def test_doppelganger_as_insomniac_acts_in_wave_4_not_wave_1(self):
        """Doppelganger copies Insomniac, sees final role in Wave 4 after all swaps."""
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Insomniac",
                3: "Robber",
                4: "Werewolf",
                5: "Villager",
            },
        )

        all_actions: dict[int, list[NightAction]] = {
            1: [
                # Doppelganger copies player 2 (Insomniac)
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
                # Robber swaps with player 1 (Doppelganger)
                NightAction(
                    player_id=3,
                    role_acting_as="Robber",
                    action_type="swap_with_player",
                    targets={"player_id": 1},
                ),
            ],
            4: [
                # Real Insomniac sees own role in Wave 4
                NightAction(
                    player_id=2,
                    role_acting_as="Insomniac",
                    action_type="peek_player",
                    targets={},
                ),
                # Doppelganger-as-Insomniac sees own role in Wave 4
                NightAction(
                    player_id=1,
                    role_acting_as="Insomniac",
                    action_type="peek_player",
                    targets={},
                ),
            ],
        }

        _final_state, results_by_wave = resolve_night(state, all_actions)

        # Wave 1 should only have the Doppelganger copy
        w1_results = results_by_wave.get(1, [])
        assert len(w1_results) == 1
        assert w1_results[0].revealed_info.get("copied_role") == "Insomniac"

        # Wave 4 should have both Insomniac results
        assert 4 in results_by_wave
        w4_results = results_by_wave[4]
        w4_player_ids = [r.player_id for r in w4_results]
        assert 1 in w4_player_ids, "Doppelganger-as-Insomniac should act in Wave 4"
        assert 2 in w4_player_ids, "Real Insomniac should act in Wave 4"

        # After Robber swapped with Doppelganger in Wave 3:
        #   Player 1: Robber (was Doppelganger), Player 3: Doppelganger (was Robber)
        # Doppelganger-as-Insomniac sees "Robber" (their final role)
        doppel_insomniac = next(r for r in w4_results if r.player_id == 1)
        assert doppel_insomniac.revealed_info["current_role"] == "Robber"


# ── Test 9: Doppelganger teammate visibility in Wave 2 ──────────────────────


class TestDoppelgangerTeamVisibility:
    """Spec: Doppelganger-as-Werewolf/Mason is visible to real teammates in Wave 2.

    Per doppelganger.md: "All Werewolves (including Doppelganger-as-Werewolf)
    open eyes and see each other." Same for Masons.
    """

    def test_real_werewolf_sees_doppelganger_as_werewolf(self):
        """Real Werewolf should see Doppelganger-as-Werewolf as a teammate."""
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Werewolf",
                3: "Seer",
                4: "Villager",
                5: "Villager",
            },
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
                    player_id=2,
                    role_acting_as="Werewolf",
                    action_type="see_team",
                    targets={},
                ),
                NightAction(
                    player_id=1,
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
                    targets={"player_id": 4},
                ),
            ],
        }

        _final_state, results_by_wave = resolve_night(state, all_actions)

        w2_results = results_by_wave[2]

        # Real Werewolf (player 2) should see Doppelganger (player 1) as teammate
        real_ww_result = next(r for r in w2_results if r.player_id == 2)
        assert 1 in real_ww_result.revealed_info["werewolves"], (
            "Real Werewolf should see Doppelganger-as-Werewolf as teammate"
        )

        # Doppelganger-as-Werewolf (player 1) should see real Werewolf (player 2)
        doppel_ww_result = next(r for r in w2_results if r.player_id == 1)
        assert 2 in doppel_ww_result.revealed_info["werewolves"], (
            "Doppelganger-as-Werewolf should see real Werewolf as teammate"
        )

    def test_real_mason_sees_doppelganger_as_mason(self):
        """Real Mason should see Doppelganger-as-Mason as a teammate."""
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Mason",
                3: "Mason",
                4: "Werewolf",
                5: "Villager",
            },
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
                    player_id=2,
                    role_acting_as="Mason",
                    action_type="see_team",
                    targets={},
                ),
                NightAction(
                    player_id=3,
                    role_acting_as="Mason",
                    action_type="see_team",
                    targets={},
                ),
                NightAction(
                    player_id=1,
                    role_acting_as="Mason",
                    action_type="see_team",
                    targets={},
                ),
                NightAction(
                    player_id=4,
                    role_acting_as="Werewolf",
                    action_type="see_team",
                    targets={},
                ),
            ],
        }

        _final_state, results_by_wave = resolve_night(state, all_actions)

        w2_results = results_by_wave[2]

        # Real Mason (player 2) should see both player 3 AND Doppelganger (player 1)
        mason2_result = next(r for r in w2_results if r.player_id == 2)
        assert sorted(mason2_result.revealed_info["masons"]) == [1, 3], (
            "Real Mason should see Doppelganger-as-Mason and other Mason"
        )

        # Doppelganger-as-Mason should see both real Masons
        doppel_mason_result = next(r for r in w2_results if r.player_id == 1)
        assert sorted(doppel_mason_result.revealed_info["masons"]) == [2, 3], (
            "Doppelganger-as-Mason should see both real Masons"
        )

    def test_minion_sees_doppelganger_as_werewolf(self):
        """Minion should see Doppelganger-as-Werewolf in the Werewolf list."""
        state = _make_state(
            player_roles={
                1: "Doppelganger",
                2: "Werewolf",
                3: "Minion",
                4: "Villager",
                5: "Villager",
            },
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
                    player_id=2,
                    role_acting_as="Werewolf",
                    action_type="see_team",
                    targets={},
                ),
                NightAction(
                    player_id=1,
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
            ],
        }

        _final_state, results_by_wave = resolve_night(state, all_actions)

        w2_results = results_by_wave[2]

        # Minion (player 3) should see both real Werewolf and Doppelganger-as-Werewolf
        minion_result = next(r for r in w2_results if r.player_id == 3)
        assert sorted(minion_result.revealed_info["werewolves"]) == [1, 2], (
            "Minion should see both Doppelganger-as-Werewolf and real Werewolf"
        )
