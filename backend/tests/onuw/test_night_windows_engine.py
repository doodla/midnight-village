"""
Engine-level tests for the two-window night and the dealt-card rule.

Pure engine: no Django, no database.

Rules under test:
- Who wakes as a Werewolf or Mason (and who acts in every step) is decided by
  the DEALT card, plus a Doppelganger who copied that role. A card that changes
  hands during the night changes nothing about who wakes.
- Window 1 is the Doppelganger alone. Window 2 prompts every remaining actor at
  once, then resolves team views, Seer -> Robber -> Troublemaker -> Drunk, then
  Insomniac, each step seeing the table after the previous one.
- "skip" is an explicit choice for Seer, Robber and Troublemaker only.
"""

import pytest

from apps.onuw.engine import (
    GameState,
    NightAction,
    build_role_prompt,
    get_required_actions,
    get_required_actions_for_window,
    order_groups_for_window,
    resolve_night,
    resolve_window,
    window_for_order_group,
)
from apps.onuw.engine.behaviors import is_effective_mason, is_effective_werewolf

pytestmark = pytest.mark.unit


def _state(
    dealt: list[str],
    center: list[str],
    held: list[str] | None = None,
    copied: dict[int, str] | None = None,
) -> GameState:
    return GameState(
        player_roles=dict(enumerate(held if held is not None else dealt)),
        center_cards=list(center),
        original_roles=dict(enumerate(dealt)),
        doppelganger_copied_role=dict(copied or {}),
    )


# ── Teams come from DEALT cards ──────────────────────────────────────────────


class TestTeamsComeFromDealtCards:
    def test_player_handed_a_werewolf_card_is_not_a_werewolf(self) -> None:
        # Player 1 (dealt Doppelganger, copied Robber) took player 0's Werewolf.
        state = _state(
            ["Werewolf", "Doppelganger", "Villager"],
            ["Seer", "Villager", "Tanner"],
            held=["Doppelganger", "Werewolf", "Villager"],
            copied={1: "Robber"},
        )
        assert is_effective_werewolf(0, state) is True  # card was taken, still wakes
        assert is_effective_werewolf(1, state) is False  # holds it, does not wake

    def test_doppelganger_who_copied_werewolf_is_a_werewolf_wherever_her_card_went(
        self,
    ) -> None:
        state = _state(
            ["Werewolf", "Doppelganger", "Villager"],
            ["Seer", "Villager", "Tanner"],
            held=["Werewolf", "Villager", "Doppelganger"],  # her card moved on
            copied={1: "Werewolf"},
        )
        assert is_effective_werewolf(1, state) is True
        assert is_effective_werewolf(2, state) is False

    def test_mason_membership_follows_the_dealt_card(self) -> None:
        state = _state(
            ["Mason", "Mason", "Doppelganger", "Villager"],
            ["Seer", "Villager", "Tanner"],
            held=["Villager", "Mason", "Doppelganger", "Mason"],
            copied={2: "Mason"},
        )
        assert is_effective_mason(0, state) is True
        assert is_effective_mason(1, state) is True
        assert is_effective_mason(2, state) is True
        assert is_effective_mason(3, state) is False  # holds a Mason card only

    def test_minion_is_shown_the_dealt_werewolf_set(self) -> None:
        state = _state(
            ["Werewolf", "Doppelganger", "Minion", "Villager"],
            ["Seer", "Villager", "Tanner"],
            held=["Doppelganger", "Werewolf", "Minion", "Villager"],
            copied={1: "Robber"},
        )
        _, results = resolve_window(
            state, [NightAction(2, "Minion", "see_team", {})], window=2
        )
        assert results[0].revealed_info == {"werewolves": [0]}

    def test_dealt_werewolf_whose_card_was_taken_is_still_lone(self) -> None:
        state = _state(
            ["Werewolf", "Doppelganger", "Villager"],
            ["Villager", "Tanner", "Hunter"],
            held=["Doppelganger", "Werewolf", "Villager"],
            copied={1: "Robber"},
        )
        action = NightAction(0, "Werewolf", "see_team", {"center_index": 1})
        _, results = resolve_window(state, [action], window=2)
        assert results[0].revealed_info == {
            "werewolves": [],
            "center_card": {"index": 1, "role": "Tanner"},
        }

    def test_lone_werewolf_prompt_lists_nobody_when_the_other_card_was_taken(
        self,
    ) -> None:
        # Two dealt Werewolves; player 1's card was taken, but player 1 still wakes.
        state = _state(
            ["Werewolf", "Werewolf", "Doppelganger"],
            ["Villager", "Tanner", "Hunter"],
            held=["Werewolf", "Doppelganger", "Werewolf"],
            copied={2: "Robber"},
        )
        prompt = build_role_prompt(state, 0, "Werewolf")
        assert prompt["valid_targets"]["see_team"] == [1]


class TestWhoActsIsDecidedFromDealtCards:
    def test_seer_prompt_goes_to_the_dealt_seer_not_the_current_holder(self) -> None:
        state = _state(
            ["Seer", "Robber", "Villager"],
            ["Villager", "Tanner", "Hunter"],
            held=["Robber", "Seer", "Villager"],  # cards already swapped
        )
        prompts = get_required_actions(state, wave=3)
        assert {(p["player_id"], p["role_acting_as"]) for p in prompts} == {
            (0, "Seer"),
            (1, "Robber"),
        }

    def test_werewolf_step_prompts_dealt_werewolves(self) -> None:
        state = _state(
            ["Werewolf", "Villager", "Doppelganger"],
            ["Villager", "Tanner", "Hunter"],
            held=["Doppelganger", "Villager", "Werewolf"],
            copied={2: "Robber"},
        )
        prompts = get_required_actions(state, wave=2)
        assert [p["player_id"] for p in prompts] == [0]


# ── Windows ──────────────────────────────────────────────────────────────────


class TestWindowMapping:
    def test_order_groups_per_window(self) -> None:
        assert order_groups_for_window(1) == (1,)
        assert order_groups_for_window(2) == (2, 3, 4)

    def test_window_of_each_order_group(self) -> None:
        assert [window_for_order_group(g) for g in (1, 2, 3, 4)] == [1, 2, 2, 2]

    def test_unknown_window_or_group_is_rejected(self) -> None:
        with pytest.raises(ValueError, match="Unknown night window"):
            order_groups_for_window(3)
        with pytest.raises(ValueError, match="Unknown order group"):
            window_for_order_group(5)


class TestRequiredActionsForWindow:
    def test_window_1_prompts_only_the_doppelganger(self) -> None:
        state = _state(
            ["Doppelganger", "Seer", "Werewolf"], ["Villager", "Tanner", "Hunter"]
        )
        prompts = get_required_actions_for_window(state, 1)
        assert [(p["player_id"], p["role_acting_as"]) for p in prompts] == [
            (0, "Doppelganger")
        ]

    def test_window_2_prompts_every_remaining_actor_at_once(self) -> None:
        dealt = [
            "Werewolf",
            "Minion",
            "Mason",
            "Mason",
            "Seer",
            "Robber",
            "Troublemaker",
            "Drunk",
            "Insomniac",
            "Villager",
            "Doppelganger",
        ]
        state = _state(
            dealt, ["Werewolf", "Tanner", "Hunter"], copied={10: "Insomniac"}
        )
        prompts = get_required_actions_for_window(state, 2, {10: "Insomniac"})
        assert {(p["player_id"], p["role_acting_as"]) for p in prompts} == {
            (0, "Werewolf"),
            (1, "Minion"),
            (2, "Mason"),
            (3, "Mason"),
            (4, "Seer"),
            (5, "Robber"),
            (6, "Troublemaker"),
            (7, "Drunk"),
            (8, "Insomniac"),
            (10, "Insomniac"),
        }

    @pytest.mark.parametrize("copied", ["Werewolf", "Mason", "Insomniac"])
    def test_window_2_includes_a_doppelganger_who_copied_a_late_role(
        self, copied: str
    ) -> None:
        state = _state(
            ["Doppelganger", copied, "Villager"],
            ["Villager", "Tanner", "Hunter"],
            copied={0: copied},
        )
        prompts = get_required_actions_for_window(state, 2, {0: copied})
        assert (0, copied) in {(p["player_id"], p["role_acting_as"]) for p in prompts}

    @pytest.mark.parametrize("copied", ["Seer", "Robber", "Troublemaker", "Drunk"])
    def test_window_2_leaves_out_a_doppelganger_who_already_acted_in_window_1(
        self, copied: str
    ) -> None:
        state = _state(
            ["Doppelganger", copied, "Villager"],
            ["Villager", "Tanner", "Hunter"],
            copied={0: copied},
        )
        prompts = get_required_actions_for_window(state, 2, {0: copied})
        assert 0 not in {p["player_id"] for p in prompts}


# ── Resolution inside window 2 ───────────────────────────────────────────────


class TestResolveWindowTwo:
    def _table(self) -> GameState:
        # 0 Werewolf, 1 Seer, 2 Robber, 3 Troublemaker, 4 Insomniac, 5 Villager
        return _state(
            ["Werewolf", "Seer", "Robber", "Troublemaker", "Insomniac", "Villager"],
            ["Drunk", "Tanner", "Hunter"],
        )

    def test_insomniac_sees_swaps_made_in_the_same_window(self) -> None:
        state = self._table()
        actions = [
            NightAction(4, "Insomniac", "none", {}),
            NightAction(3, "Troublemaker", "swap_others", {"player_ids": [4, 0]}),
            NightAction(2, "Robber", "swap_with_player", {"player_id": 4}),
            NightAction(0, "Werewolf", "see_team", {}),
        ]
        final, results = resolve_window(state, actions, window=2)

        # Robber took the Insomniac card (4 holds Robber), then the
        # Troublemaker swapped 4 and 0 -> 4 holds the Werewolf card.
        insomniac = next(r for r in results if r.player_id == 4)
        assert insomniac.revealed_info == {"current_role": "Werewolf"}
        assert final.player_roles[4] == "Werewolf"
        assert final.player_roles[0] == "Robber"
        assert final.player_roles[2] == "Insomniac"

    def test_seer_looks_before_the_robber_moves(self) -> None:
        state = self._table()
        actions = [
            NightAction(2, "Robber", "swap_with_player", {"player_id": 0}),
            NightAction(1, "Seer", "peek_player", {"player_id": 2}),
        ]
        _, results = resolve_window(state, actions, window=2)
        seer = next(r for r in results if r.player_id == 1)
        assert seer.revealed_info == {"peeked_role": "Robber"}

    def test_results_come_in_wake_order_regardless_of_submission_order(self) -> None:
        state = self._table()
        actions = [
            NightAction(4, "Insomniac", "none", {}),
            NightAction(3, "Troublemaker", "swap_others", {"player_ids": [0, 5]}),
            NightAction(2, "Robber", "swap_with_player", {"player_id": 5}),
            NightAction(1, "Seer", "peek_player", {"player_id": 0}),
            NightAction(0, "Werewolf", "see_team", {}),
        ]
        new_state, results = resolve_window(state, actions, window=2)
        assert [r.player_id for r in results] == [0, 1, 2, 3, 4]
        # Log entries keep their order group, in wake order.
        assert [e.wave for e in new_state.action_log] == [2, 3, 3, 3, 4]

    def test_skip_is_resolved_and_logged_without_changing_the_table(self) -> None:
        state = self._table()
        actions = [
            NightAction(1, "Seer", "skip", {}),
            NightAction(2, "Robber", "skip", {}),
            NightAction(3, "Troublemaker", "skip", {}),
        ]
        final, results = resolve_window(state, actions, window=2)
        assert final.player_roles == state.player_roles
        assert [r.revealed_info for r in results] == [{}, {}, {}]
        assert [e.action_type for e in final.action_log] == ["skip"] * 3

    def test_action_from_another_window_is_rejected(self) -> None:
        state = self._table()
        with pytest.raises(ValueError, match="does not belong"):
            resolve_window(
                state, [NightAction(0, "Doppelganger", "peek_player", {})], window=2
            )

    def test_unknown_window_is_rejected(self) -> None:
        with pytest.raises(ValueError, match="Unknown night window"):
            resolve_window(self._table(), [], window=3)

    def test_doppelganger_copied_late_role_missing_action_is_skipped(self) -> None:
        state = _state(
            ["Doppelganger", "Werewolf", "Villager"],
            ["Villager", "Tanner", "Hunter"],
            copied={0: "Werewolf"},
        )
        final, results = resolve_window(state, [], window=2)
        assert [(r.player_id, r.revealed_info) for r in results] == [(0, {})]
        assert final.action_log[0].action_type == "skip"


class TestResolveWindowOne:
    def test_look_then_immediate_follow_up_in_one_window(self) -> None:
        state = _state(
            ["Doppelganger", "Robber", "Werewolf"], ["Villager", "Tanner", "Hunter"]
        )
        actions = [
            NightAction(0, "Doppelganger", "peek_player", {"player_id": 1}),
            NightAction(0, "Robber", "swap_with_player", {"player_id": 2}),
        ]
        final, results = resolve_window(state, actions, window=1)
        assert [r.revealed_info for r in results] == [
            {"copied_role": "Robber"},
            {"new_role": "Werewolf"},
        ]
        assert final.player_roles[0] == "Werewolf"
        assert final.player_roles[2] == "Doppelganger"
        assert [e.wave for e in final.action_log] == [1, 1]

    def test_missing_follow_up_is_skipped(self) -> None:
        state = _state(
            ["Doppelganger", "Seer", "Werewolf"], ["Villager", "Tanner", "Hunter"]
        )
        actions = [NightAction(0, "Doppelganger", "peek_player", {"player_id": 1})]
        final, results = resolve_window(state, actions, window=1)
        assert results[-1].revealed_info == {}
        assert final.action_log[-1].action_type == "skip"

    def test_follow_up_alone_resolves_when_the_look_was_resolved_earlier(self) -> None:
        state = _state(
            ["Doppelganger", "Seer", "Werewolf"],
            ["Villager", "Tanner", "Hunter"],
            copied={0: "Seer"},
        )
        actions = [NightAction(0, "Seer", "peek_player", {"player_id": 2})]
        _, results = resolve_window(state, actions, window=1)
        assert [r.revealed_info for r in results] == [{"peeked_role": "Werewolf"}]


# ── Skip ─────────────────────────────────────────────────────────────────────


class TestSkipAdvertisement:
    @pytest.mark.parametrize("role", ["Seer", "Robber", "Troublemaker"])
    def test_prompt_advertises_skip_for_optional_roles(self, role: str) -> None:
        state = _state(["Villager", role, "Villager"], ["Villager", "Tanner", "Hunter"])
        assert "skip" in build_role_prompt(state, 1, role)["action_types"]

    @pytest.mark.parametrize(
        "role",
        ["Drunk", "Werewolf", "Minion", "Mason", "Insomniac", "Doppelganger"],
    )
    def test_prompt_does_not_advertise_skip_for_the_rest(self, role: str) -> None:
        state = _state(["Villager", role, "Villager"], ["Villager", "Tanner", "Hunter"])
        assert "skip" not in build_role_prompt(state, 1, role)["action_types"]

    def test_skip_adds_no_targets(self) -> None:
        state = _state(
            ["Villager", "Seer", "Villager"], ["Villager", "Tanner", "Hunter"]
        )
        prompt = build_role_prompt(state, 1, "Seer")
        assert prompt["action_types"] == ["peek_player", "peek_center", "skip"]
        assert set(prompt["valid_targets"]) == {"player_ids", "center_indices"}


# ── resolve_night keeps working ──────────────────────────────────────────────


def test_resolve_night_still_takes_actions_keyed_by_order_group() -> None:
    state = _state(
        ["Werewolf", "Seer", "Robber", "Insomniac"], ["Villager", "Tanner", "Hunter"]
    )
    all_actions = {
        1: [],
        2: [NightAction(0, "Werewolf", "see_team", {"center_index": 0})],
        3: [
            NightAction(1, "Seer", "peek_player", {"player_id": 0}),
            NightAction(2, "Robber", "swap_with_player", {"player_id": 3}),
        ],
        4: [NightAction(3, "Insomniac", "none", {})],
    }
    final, results = resolve_night(state, all_actions)

    assert sorted(results) == [2, 3, 4]
    assert results[4][0].revealed_info == {"current_role": "Robber"}
    assert final.player_roles[2] == "Insomniac"
