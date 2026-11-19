"""
The night timeline (engine/timeline.py), pure and checked against the real engine.

The timeline replays the night log FORWARDS from the dealt cards. Its proof is that
the table it ends with is the table the engine ended with: for every reference game
and for thousands of seeded random nights (3 to 10 players, every role, every card
the Doppelganger can copy).

The nights come from ``night_rules_reference.engine_night``, which collects the
actions the way the server does (seat order, a Doppelganger's follow-up last), so
the logs have the order production writes. Seats are the REVERSE of user-id order
throughout (seat ``i`` is user id ``n - 1 - i``), so a timeline that confused ids
with seats, or sorted by id, would not match.
"""

import json
import random
from pathlib import Path
from typing import Any

import pytest

from apps.onuw.engine import GameState, NightAction, get_effective_team, resolve_night
from apps.onuw.engine.timeline import (
    TimelineError,
    build_night_timeline,
    recover_dealt_center,
    undo_to_dealt,
)

from .night_rules_reference import engine_night, random_game

pytestmark = pytest.mark.unit

GAMES = json.loads(
    (Path(__file__).parent / "data" / "reference_games.json").read_text()
)

# The order the rules wake the roles in, inside each order group.
GROUP_ORDER = {
    2: {"Werewolf": 0, "Minion": 1, "Mason": 2},
    3: {"Seer": 0, "Robber": 1, "Troublemaker": 2, "Drunk": 3},
}


def replay(dealt: list[str], center: list[str], choices: dict) -> dict[str, Any]:
    """Run the night through the engine and build the timeline from its log.

    Returns the timeline plus what the engine ended with, for comparison; ``ids[i]``
    is the user id of the player in seat ``i`` (descending: seat order != id order).
    """
    n = len(dealt)
    ids = [n - 1 - seat for seat in range(n)]
    final, _ = engine_night(dealt, center, choices, ids)
    log = [entry.to_dict() for entry in final.action_log]
    original = {ids[seat]: role for seat, role in enumerate(dealt)}
    timeline = build_night_timeline(ids, original, center, log)
    return {"timeline": timeline, "final": final, "log": log, "ids": ids}


def roles_at(timeline: dict[str, Any], positions: dict[str, Any]):
    """(role per player id, centre roles) for a set of positions."""
    role = {c["card_id"]: c["role"] for c in timeline["cards"]}
    players = {int(uid): role[card] for uid, card in positions["players"].items()}
    return players, [role[card] for card in positions["center"]]


def is_team_view(entry: dict[str, Any]) -> bool:
    """A log entry that shows a team (a lone Werewolf's centre look is not one)."""
    return (
        entry["action_type"] == "see_team"
        and (entry["targets"] or {}).get("center_index") is None
    )


def steps_of(result: dict[str, Any]) -> list[dict[str, Any]]:
    return result["timeline"]["steps"]


def assert_in_wake_order(steps: list[dict[str, Any]]) -> None:
    """Steps are in order group order AND, inside a group, in the order of the rules."""
    keys = []
    for step in steps:
        group = step["order_group"]
        if group == 1:  # the Doppelganger's look, then her follow-up
            rank = 0 if step["role"] == "Doppelganger" else 1
        elif group in GROUP_ORDER:
            # (a Doppelganger acts before the real holder of a group-3 role, after
            # the dealt ones in a team view)
            rank = GROUP_ORDER[group][step["role"]] * 2 + (
                0 if group == 3 and step["doppelganger_actors"] else 1
            )
            if group == 2:
                rank = GROUP_ORDER[group][step["role"]]
        else:
            assert step["role"] == "Insomniac"
            rank = 0
        keys.append((group, rank))
    assert keys == sorted(keys), keys


def holder_roles(result: dict[str, Any]) -> list[str]:
    """The roles the players hold at the end, by seat."""
    return [result["final"].player_roles[uid] for uid in result["ids"]]


@pytest.mark.parametrize("game", GAMES, ids=[f"game_{g['num']}" for g in GAMES])
def test_timeline_matches_reference_games(game: dict) -> None:
    ch = dict(game["ch"])
    for key in ("seer", "doppel_follow"):
        value = ch.get(key)
        if isinstance(value, list) and value and value[0] in ("player", "center"):
            ch[key] = (value[0], value[1])

    result = replay(game["dealt"], game["center"], ch)
    timeline, ids = result["timeline"], result["ids"]

    # The table the replay ends with is the recorded final table.
    players, center = roles_at(timeline, timeline["final"])
    assert [players[uid] for uid in ids] == game["final"]
    assert center == game["final_center"]
    # ... and the dealt table is the dealt one.
    dealt_players, dealt_center = roles_at(timeline, timeline["dealt"])
    assert [dealt_players[uid] for uid in ids] == game["dealt"]
    assert dealt_center == game["center"]
    # Steps are numbered, snapshotted, and in wake order inside each group.
    steps = steps_of(result)
    assert [s["step"] for s in steps] == list(range(1, len(steps) + 1))
    assert all("positions_after" in s for s in steps)
    assert_in_wake_order(steps)
    assert timeline["seats"] == ids


def test_timeline_undo_then_replay_roundtrip_property() -> None:
    rng = random.Random(20261119)  # noqa: S311 (seeded so a failure reproduces)
    roles_seen: set[str] = set()
    copies_seen: set[str] = set()
    for _ in range(1500):
        dealt, center, choices = random_game(rng)
        roles_seen.update(dealt)
        result = replay(dealt, center, choices)
        timeline, final, log = result["timeline"], result["final"], result["log"]
        original = {uid: dealt[seat] for seat, uid in enumerate(result["ids"])}
        for step in steps_of(result):
            if step["action"] == "copy":
                copies_seen.add(step["copied_role"])

        # Forward: the replay ends where the engine ended.
        players, final_center = roles_at(timeline, timeline["final"])
        assert players == final.player_roles, (dealt, center, choices)
        assert final_center == list(final.center_cards)
        # Backward: undoing the log from the final table gives back the deal ...
        undone, undone_center = undo_to_dealt(
            dict(final.player_roles), list(final.center_cards), log
        )
        assert undone == original
        assert undone_center == center
        # ... which is also how a game without a stored centre recovers it.
        assert (
            recover_dealt_center(
                original, dict(final.player_roles), list(final.center_cards), log
            )
            == center
        )
        # Wake order inside each group, and every card somewhere, once, after every step.
        assert_in_wake_order(steps_of(result))
        every = sorted(c["card_id"] for c in timeline["cards"])
        for step in steps_of(result):
            after = step["positions_after"]
            held = [*after["players"].values(), *after["center"]]
            assert sorted(held) == every
        # The werewolf flag: whoever holds a flagged card at dawn is a werewolf
        # by the win rules (a Doppelganger card that copied Werewolf included).
        flagged = {c["card_id"] for c in timeline["cards"] if c["werewolf"]}
        for uid, card in timeline["final"]["players"].items():
            team = get_effective_team(
                int(uid), final.player_roles, final.doppelganger_copied_role
            )
            holds = final.player_roles[int(uid)]
            copied = list(final.doppelganger_copied_role.values())
            effective = copied[0] if holds == "Doppelganger" and copied else holds
            assert (card in flagged) == (effective == "Werewolf"), (dealt, choices)
            if card in flagged:
                assert team == "werewolf"

    assert roles_seen >= {
        "Werewolf", "Villager", "Seer", "Robber", "Troublemaker", "Drunk",
        "Insomniac", "Minion", "Tanner", "Hunter", "Mason", "Doppelganger",
    }  # fmt: skip
    assert copies_seen >= {"Seer", "Robber", "Troublemaker", "Drunk", "Werewolf"}


def test_looks_show_the_card_the_engine_revealed() -> None:
    """The replay reads each look from the table AS IT WAS at that step: the role of
    the card a Seer, Robber or Doppelganger looked at is the role the engine told them."""
    rng = random.Random(7)  # noqa: S311
    checked: set[str] = set()
    for _ in range(800):
        dealt, center, choices = random_game(rng)
        result = replay(dealt, center, choices)
        role = {c["card_id"]: c["role"] for c in result["timeline"]["cards"]}
        for step, entry in zip(
            [s for s in steps_of(result) if s["action"] != "see_team"],
            [e for e in result["log"] if not is_team_view(e)],
            strict=True,
        ):
            info = entry["result"]
            looked = [role[look["card_id"]] for look in step["looked_at"]]
            if "copied_role" in info:
                assert step["action"] == "copy"
                assert looked == [info["copied_role"]] == [step["copied_role"]]
                checked.add("copy")
            elif "peeked_role" in info:
                assert looked == [info["peeked_role"]]
                checked.add("peek_player")
            elif "new_role" in info:
                assert looked == [info["new_role"]]
                checked.add("rob")
            elif "peeked_center" in info:
                assert looked == [c["role"] for c in info["peeked_center"]]
                checked.add("peek_center")
            elif "current_role" in info:
                assert looked == [info["current_role"]]
                checked.add("insomniac")
            elif "center_card" in info:
                assert looked == [info["center_card"]["role"]]
                checked.add("werewolf_center")
    assert checked == {
        "copy", "peek_player", "rob", "peek_center", "insomniac", "werewolf_center",
    }  # fmt: skip


def test_timeline_duplicate_werewolves_have_distinct_paths() -> None:
    dealt = ["Werewolf", "Werewolf", "Robber", "Troublemaker", "Villager"]
    center = ["Villager", "Seer", "Hunter"]
    result = replay(dealt, center, {"robber": 0, "troublemaker": [1, 4]})
    timeline, ids = result["timeline"], result["ids"]
    wolves = [c["card_id"] for c in timeline["cards"] if c["werewolf"]]
    assert len(wolves) == 2 and len(set(wolves)) == 2

    holder = {
        card: int(uid)
        for uid, card in timeline["final"]["players"].items()
        if card in wolves
    }
    # the Robber (seat 2) holds one; the Troublemaker sent the other to seat 4
    assert sorted(holder.values()) == sorted([ids[2], ids[4]])
    path = {
        card: [
            (m["from"], m["to"])
            for s in steps_of(result)
            for m in s["moves"]
            if m["card_id"] == card
        ]
        for card in wolves
    }
    assert path[wolves[0]] != path[wolves[1]]
    assert all(path[card] for card in wolves)  # both really moved


def test_timeline_robber_then_troublemaker_same_player_order() -> None:
    # The Robber takes the Werewolf from seat 3; the Troublemaker then swaps the
    # Robber with seat 2. Order matters: the wolf ends on seat 2's player.
    dealt = ["Robber", "Troublemaker", "Villager", "Werewolf", "Seer"]
    result = replay(
        dealt,
        ["Villager", "Tanner", "Hunter"],
        {"robber": 3, "troublemaker": [0, 2]},
    )
    ids, timeline = result["ids"], result["timeline"]
    steps = [s for s in steps_of(result) if s["role"] in ("Robber", "Troublemaker")]

    assert [s["role"] for s in steps] == ["Robber", "Troublemaker"]
    wolf = next(c["card_id"] for c in timeline["cards"] if c["werewolf"])
    assert steps[0]["positions_after"]["players"][str(ids[0])] == wolf
    assert steps[1]["positions_after"]["players"][str(ids[2])] == wolf
    assert [look["player_id"] for look in steps[0]["looked_at"]] == [ids[3]]


def test_timeline_drunk_timeout_swap_marked_made_by_server() -> None:
    dealt = ["Drunk", "Villager", "Werewolf"]
    center = ["Seer", "Hunter", "Tanner"]
    state = GameState(
        player_roles=dict(enumerate(dealt)),
        center_cards=list(center),
        original_roles=dict(enumerate(dealt)),
    )
    final, _ = resolve_night(
        state,
        {
            3: [
                NightAction(0, "Drunk", "swap_with_center", {"center_index": 1}, True),
                NightAction(1, "Seer", "skip", {}),
            ]
        },
    )
    log = [e.to_dict() for e in final.action_log]

    timeline = build_night_timeline([2, 1, 0], dict(enumerate(dealt)), center, log)

    drunk = next(s for s in timeline["steps"] if s["role"] == "Drunk")
    assert drunk["made_by_server"] is True
    assert drunk["action"] == "swap_with_center"
    assert [m["to"] for m in drunk["moves"]] == [{"center_index": 1}, {"player_id": 0}]
    assert timeline["center_moved"] == [False, True, False]
    # A skip is a row with no looks and no moves, never made by the server.
    skip = next(s for s in timeline["steps"] if s["action"] == "skip")
    assert (skip["looked_at"], skip["moves"], skip["made_by_server"]) == ([], [], False)


def test_timeline_doppelganger_copy_then_followup_rows_before_real_role() -> None:
    # The Doppelganger copies the Seer (seat 1) and looks at seat 3 at once; the
    # real Seer looks later, in window 2.
    dealt = ["Doppelganger", "Seer", "Villager", "Werewolf", "Robber"]
    result = replay(
        dealt,
        ["Villager", "Tanner", "Hunter"],
        {"doppel_target": 1, "doppel_follow": ("player", 3), "seer": ("player", 4)},
    )
    ids = result["ids"]
    steps = [s for s in steps_of(result) if s["role"] in ("Doppelganger", "Seer")]

    assert [
        (s["role"], bool(s["doppelganger_actors"]), s["window"]) for s in steps
    ] == [
        ("Doppelganger", True, 1),
        ("Seer", True, 1),
        ("Seer", False, 2),
    ]
    assert steps[0]["action"] == "copy"
    assert steps[0]["copied_role"] == "Seer"
    assert steps[0]["actors"] == [ids[0]] == steps[0]["doppelganger_actors"]
    assert steps[1]["action"] == "peek_player" and steps[1]["actors"] == [ids[0]]
    assert steps[2]["actors"] == [ids[1]]


def test_timeline_doppelganger_as_robber_swaps_before_the_real_robber() -> None:
    dealt = ["Doppelganger", "Robber", "Villager", "Werewolf", "Seer"]
    result = replay(
        dealt,
        ["Villager", "Tanner", "Hunter"],
        {"doppel_target": 1, "doppel_follow": 3, "robber": 0},
    )
    ids = result["ids"]
    steps = [s for s in steps_of(result) if s["role"] in ("Doppelganger", "Robber")]

    assert [(s["role"], bool(s["doppelganger_actors"])) for s in steps] == [
        ("Doppelganger", True),
        ("Robber", True),
        ("Robber", False),
    ]
    # The Doppelganger robbed the wolf from seat 3; the real Robber then robs her.
    wolf = next(c["card_id"] for c in result["timeline"]["cards"] if c["werewolf"])
    assert wolf in [m["card_id"] for m in steps[1]["moves"]]
    assert steps[1]["positions_after"]["players"][str(ids[0])] == wolf
    assert result["timeline"]["final"]["players"][str(ids[1])] == wolf


class TestTeamViewsWakeInTheOrderOfTheRules:
    """Production resolves group 2 in SEAT order (the dealt cards walked seat by
    seat, a Doppelganger's follow-up appended last), so its log interleaves the
    roles. The timeline must still wake Werewolves, then Minion, then Masons."""

    DEALT = ["Werewolf", "Minion", "Werewolf", "Mason", "Doppelganger", "Mason"]
    CENTER = ["Villager", "Tanner", "Hunter"]

    def test_the_log_is_in_seat_order_but_the_timeline_is_in_wake_order(self) -> None:
        result = replay(self.DEALT, self.CENTER, {"doppel_target": 0})
        ids = result["ids"]

        in_log = [(e["role_acting_as"], e["player_id"]) for e in result["log"]]
        assert [r for r, _ in in_log] == [
            "Doppelganger",
            "Werewolf",
            "Minion",
            "Werewolf",
            "Mason",
            "Mason",
            "Werewolf",  # her follow-up as a Werewolf comes last
        ]
        rows = [
            (s["role"], s["actors"], s["doppelganger_actors"]) for s in steps_of(result)
        ]
        assert rows == [
            ("Doppelganger", [ids[4]], [ids[4]]),
            # the dealt Werewolves, then the Doppelganger who copied the role:
            # ONE step, with her marked inside it
            ("Werewolf", [ids[0], ids[2], ids[4]], [ids[4]]),
            ("Minion", [ids[1]], []),
            ("Mason", [ids[3], ids[5]], []),
        ]
        wolves = steps_of(result)[1]
        assert wolves["team"] == sorted([ids[0], ids[2], ids[4]])
        assert steps_of(result)[2]["team"] == sorted([ids[0], ids[2], ids[4]])
        assert_in_wake_order(steps_of(result))

    def test_no_card_moves_and_the_snapshots_are_unchanged(self) -> None:
        result = replay(self.DEALT, self.CENTER, {"doppel_target": 0})
        timeline = result["timeline"]

        assert all(s["moves"] == [] for s in timeline["steps"])
        assert all(s["positions_after"] == timeline["dealt"] for s in timeline["steps"])
        assert timeline["final"] == timeline["dealt"]
        assert timeline["center_moved"] == [False, False, False]

    def test_an_old_log_in_any_order_comes_out_in_wake_order(self) -> None:
        """Games already played have their log as written: the fix is in the build."""
        result = replay(self.DEALT, self.CENTER, {"doppel_target": 0})
        original = {uid: self.DEALT[s] for s, uid in enumerate(result["ids"])}
        scrambled = random.Random(3).sample(result["log"], len(result["log"]))  # noqa: S311
        group_two = [e for e in scrambled if e["wave"] == 2]
        others = [e for e in scrambled if e["wave"] != 2]
        # (keep window 1 before window 2, as any real log has it)
        timeline = build_night_timeline(
            result["ids"], original, self.CENTER, [*others, *group_two]
        )

        roles = [s["role"] for s in timeline["steps"] if s["order_group"] == 2]
        assert roles == ["Werewolf", "Minion", "Mason"]

    def test_a_doppelganger_who_copied_a_mason_joins_the_masons(self) -> None:
        dealt = ["Mason", "Doppelganger", "Villager", "Mason", "Werewolf"]
        result = replay(dealt, self.CENTER, {"doppel_target": 0})
        ids = result["ids"]

        masons = [s for s in steps_of(result) if s["role"] == "Mason"]

        assert [(s["actors"], s["doppelganger_actors"]) for s in masons] == [
            ([ids[0], ids[3], ids[1]], [ids[1]])
        ]

    def test_a_minion_next_to_a_doppelganger_minion_stay_two_steps(self) -> None:
        """She copied Minion in window 1 (group 1): her row is not the Minion's."""
        dealt = ["Minion", "Doppelganger", "Villager", "Werewolf"]
        result = replay(dealt, self.CENTER, {"doppel_target": 0})

        minions = [s for s in steps_of(result) if s["role"] == "Minion"]

        assert [(s["window"], len(s["actors"])) for s in minions] == [(1, 1), (2, 1)]


class TestTheWerewolfFlagFollowsTheCard:
    def flags(self, result: dict[str, Any]) -> dict[str, bool]:
        return {c["card_id"]: c["werewolf"] for c in result["timeline"]["cards"]}

    def test_a_doppelganger_card_that_copied_a_werewolf_is_a_werewolf_card(
        self,
    ) -> None:
        dealt = ["Doppelganger", "Werewolf", "Villager", "Seer"]
        result = replay(dealt, ["Villager", "Tanner", "Hunter"], {"doppel_target": 1})
        timeline = result["timeline"]

        dealt_card = timeline["dealt"]["players"][str(result["ids"][0])]
        assert self.flags(result)[dealt_card] is True
        roles = {c["card_id"]: c["role"] for c in timeline["cards"]}
        assert roles[dealt_card] == "Doppelganger"  # it still says Doppelganger

    def test_the_flag_stays_with_the_card_when_it_is_robbed_or_swapped(self) -> None:
        # seat 0 copies the Werewolf; the Robber (seat 2) robs her; the Troublemaker
        # (seat 4) then swaps the Robber (who now holds the card) with seat 3.
        dealt = ["Doppelganger", "Werewolf", "Robber", "Villager", "Troublemaker"]
        result = replay(
            dealt,
            ["Villager", "Tanner", "Hunter"],
            {"doppel_target": 1, "robber": 0, "troublemaker": [2, 3]},
        )
        timeline, ids = result["timeline"], result["ids"]
        card = timeline["dealt"]["players"][str(ids[0])]
        flags = self.flags(result)

        assert flags[card] is True
        assert timeline["final"]["players"][str(ids[3])] == card  # it moved twice
        # exactly two werewolf cards: the Werewolf and the Doppelganger's
        assert sorted(c for c, flagged in flags.items() if flagged) == sorted(
            [card, timeline["dealt"]["players"][str(ids[1])]]
        )
        # and the win rules agree about who ends the night on the werewolf side
        final = result["final"]
        assert (
            get_effective_team(
                ids[3], final.player_roles, final.doppelganger_copied_role
            )
            == "werewolf"
        )

    @pytest.mark.parametrize("copied", ["Seer", "Villager", "Minion", "Mason"], ids=str)
    def test_a_doppelganger_that_copied_anything_else_is_not_a_werewolf_card(
        self, copied
    ) -> None:
        dealt = ["Doppelganger", copied, "Werewolf", "Mason", "Villager"]
        result = replay(dealt, ["Villager", "Tanner", "Hunter"], {"doppel_target": 1})
        card = result["timeline"]["dealt"]["players"][str(result["ids"][0])]

        assert self.flags(result)[card] is False

    def test_a_doppelganger_in_the_centre_or_that_never_copied_is_not_one(self) -> None:
        never = replay(
            ["Doppelganger", "Werewolf", "Villager"],
            ["Villager", "Tanner", "Hunter"],
            {},
        )
        centre = replay(
            ["Villager", "Werewolf", "Seer"],
            ["Doppelganger", "Tanner", "Hunter"],
            {},
        )

        assert sorted(
            c["role"] for c in never["timeline"]["cards"] if c["werewolf"]
        ) == ["Werewolf"]
        assert [c["card_id"] for c in centre["timeline"]["cards"] if c["werewolf"]] == [
            "k1"
        ]


def test_center_moved_and_final_describe_the_night() -> None:
    dealt = ["Drunk", "Villager", "Werewolf", "Seer"]
    result = replay(
        dealt, ["Hunter", "Tanner", "Villager"], {"drunk": 2, "seer": ("player", 2)}
    )
    timeline = result["timeline"]

    assert timeline["center_moved"] == [False, False, True]
    assert timeline["final"] == steps_of(result)[-1]["positions_after"]
    assert timeline["dealt"] != timeline["final"]
    quiet = replay(
        ["Villager", "Villager", "Villager"], ["Seer", "Tanner", "Hunter"], {}
    )
    assert quiet["timeline"]["steps"] == []
    assert quiet["timeline"]["dealt"] == quiet["timeline"]["final"]
    assert quiet["timeline"]["center_moved"] == [False, False, False]


def test_cards_are_numbered_by_seat_then_centre() -> None:
    result = replay(
        ["Werewolf", "Seer", "Villager"], ["Robber", "Tanner", "Hunter"], {}
    )
    timeline = result["timeline"]

    assert timeline["seats"] == [2, 1, 0]
    assert [c["card_id"] for c in timeline["cards"]] == [f"k{i}" for i in range(6)]
    # k0 is the card dealt to the FIRST SEAT (player 2), k3.. are the centre.
    assert timeline["dealt"]["players"] == {"2": "k0", "1": "k1", "0": "k2"}
    assert timeline["dealt"]["center"] == ["k3", "k4", "k5"]
    assert [c["role"] for c in timeline["cards"]] == [
        "Werewolf", "Seer", "Villager", "Robber", "Tanner", "Hunter",
    ]  # fmt: skip
    assert [c["werewolf"] for c in timeline["cards"]] == [True] + [False] * 5


class TestUndoForGamesWithoutAStoredCentre:
    def test_the_dealt_centre_is_recovered_and_verified(self) -> None:
        dealt = ["Drunk", "Troublemaker", "Werewolf", "Robber", "Seer"]
        center = ["Villager", "Tanner", "Hunter"]
        final, _ = engine_night(
            dealt, center, {"drunk": 1, "troublemaker": [2, 4], "robber": 2}
        )
        log = [e.to_dict() for e in final.action_log]

        recovered = recover_dealt_center(
            dict(enumerate(dealt)),
            dict(final.player_roles),
            list(final.center_cards),
            log,
        )

        assert recovered == center
        assert list(final.center_cards) != center  # the live centre was overwritten

    def test_a_log_that_does_not_lead_back_to_the_deal_is_refused(self) -> None:
        dealt = ["Drunk", "Troublemaker", "Werewolf", "Robber", "Seer"]
        final, _ = engine_night(
            dealt,
            ["Villager", "Tanner", "Hunter"],
            {"drunk": 1, "troublemaker": [2, 4], "robber": 2},
        )
        log = [e.to_dict() for e in final.action_log]
        lost_a_move = [e for e in log if e["action_type"] != "swap_others"]

        with pytest.raises(TimelineError):
            recover_dealt_center(
                dict(enumerate(dealt)),
                dict(final.player_roles),
                list(final.center_cards),
                lost_a_move,
            )

    def test_the_check_is_only_about_the_players_cards(self) -> None:
        """What the undo does NOT prove, written down: a log that loses a swap of two
        players who hold the same role is accepted (the players' cards still equal
        the deal), so a log fault of that kind goes unnoticed."""
        dealt = ["Werewolf", "Werewolf", "Troublemaker"]
        center = ["Villager", "Tanner", "Hunter"]
        final, _ = engine_night(dealt, center, {"troublemaker": [0, 1]})
        log = [e.to_dict() for e in final.action_log]
        without_the_swap = [e for e in log if e["action_type"] != "swap_others"]
        assert len(without_the_swap) < len(log)

        recovered = recover_dealt_center(
            dict(enumerate(dealt)),
            dict(final.player_roles),
            list(final.center_cards),
            without_the_swap,
        )

        assert recovered == center  # accepted, though the log lost a move


class TestAMalformedLogIsRefused:
    DEALT = {0: "Robber", 1: "Villager", 2: "Seer"}
    CENTER = ["Villager", "Tanner", "Hunter"]

    def entry(self, **changes: Any) -> dict[str, Any]:
        base = {
            "wave": 3,
            "player_id": 0,
            "action_type": "swap_with_player",
            "targets": {"player_id": 1},
            "result": {},
            "timestamp_order": 0,
            "role_acting_as": "Robber",
        }
        return {**base, **changes}

    @pytest.mark.parametrize(
        "changes",
        [
            {"targets": {"player_id": 99}},  # a player who is not at the table
            {"targets": {}},
            {"role_acting_as": ""},  # an entry from before the field existed
            {"wave": 9},
            {"action_type": "dance"},
        ],
    )
    def test_each_bad_entry_raises_a_timeline_error(self, changes) -> None:
        with pytest.raises(TimelineError):
            build_night_timeline(
                [0, 1, 2], self.DEALT, self.CENTER, [self.entry(**changes)]
            )

    def test_players_must_match_the_dealt_cards(self) -> None:
        with pytest.raises(TimelineError):
            build_night_timeline([0, 1], self.DEALT, self.CENTER, [])
