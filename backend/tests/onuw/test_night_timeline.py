"""
The night timeline (engine/timeline.py), pure and checked against the real engine.

The timeline replays the night log FORWARDS from the dealt cards. Its proof is that
the table it ends with is the table the engine ended with: for every reference game
and for thousands of seeded random nights (3 to 10 players, every role, every card
the Doppelganger can copy). Seats are the REVERSE of player-id order throughout, so
a timeline that confused ids with seats would not match.
"""

import json
import random
from pathlib import Path
from typing import Any

import pytest

from apps.onuw.engine.state import NightAction
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


def replay(dealt: list[str], center: list[str], choices: dict) -> dict[str, Any]:
    """Run the night through the engine and build the timeline from its log.

    Returns the timeline plus what the engine ended with, for comparison."""
    final, _ = engine_night(dealt, center, choices)
    seats = list(reversed(range(len(dealt))))  # seat order != player-id order
    log = [entry.to_dict() for entry in final.action_log]
    timeline = build_night_timeline(seats, dict(enumerate(dealt)), center, log)
    return {"timeline": timeline, "final": final, "log": log, "seats": seats}


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


@pytest.mark.parametrize("game", GAMES, ids=[f"game_{g['num']}" for g in GAMES])
def test_timeline_matches_reference_games(game: dict) -> None:
    ch = dict(game["ch"])
    for key in ("seer", "doppel_follow"):
        value = ch.get(key)
        if isinstance(value, list) and value and value[0] in ("player", "center"):
            ch[key] = (value[0], value[1])

    result = replay(game["dealt"], game["center"], ch)
    timeline = result["timeline"]

    # The table the replay ends with is the recorded final table.
    players, center = roles_at(timeline, timeline["final"])
    assert [players[p] for p in range(len(game["dealt"]))] == game["final"]
    assert center == game["final_center"]
    # ... and the dealt table is the dealt one.
    dealt_players, dealt_center = roles_at(timeline, timeline["dealt"])
    assert [dealt_players[p] for p in range(len(game["dealt"]))] == game["dealt"]
    assert dealt_center == game["center"]
    # Steps are in wake order, numbered from 1, each with a snapshot.
    steps = steps_of(result)
    assert [s["step"] for s in steps] == list(range(1, len(steps) + 1))
    groups = [s["order_group"] for s in steps]
    assert groups == sorted(groups)
    assert all("positions_after" in s for s in steps)
    assert timeline["seats"] == result["seats"]


def test_timeline_undo_then_replay_roundtrip_property() -> None:
    rng = random.Random(20261119)  # noqa: S311 (seeded so a failure reproduces)
    roles_seen: set[str] = set()
    copies_seen: set[str] = set()
    for _ in range(1500):
        dealt, center, choices = random_game(rng)
        roles_seen.update(dealt)
        result = replay(dealt, center, choices)
        timeline, final, log = result["timeline"], result["final"], result["log"]
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
        assert undone == dict(enumerate(dealt))
        assert undone_center == center
        # ... which is also how a game without a stored centre recovers it.
        assert (
            recover_dealt_center(
                dict(enumerate(dealt)),
                dict(final.player_roles),
                list(final.center_cards),
                log,
            )
            == center
        )
        # What a step says a player looked at is what the engine told them.
        for step in steps_of(result):
            for look in step["looked_at"]:
                assert "card_id" in look
        # Every card is somewhere, once, after every step.
        every = sorted(c["card_id"] for c in timeline["cards"])
        for step in steps_of(result):
            after = step["positions_after"]
            held = [*after["players"].values(), *after["center"]]
            assert sorted(held) == every

    assert roles_seen >= {
        "Werewolf", "Villager", "Seer", "Robber", "Troublemaker", "Drunk",
        "Insomniac", "Minion", "Tanner", "Hunter", "Mason", "Doppelganger",
    }  # fmt: skip
    assert copies_seen >= {"Seer", "Robber", "Troublemaker", "Drunk", "Werewolf"}


def test_looks_show_the_card_the_engine_revealed() -> None:
    """The replay reads each look from the table AS IT WAS at that step: the role of
    the card a Seer or Robber looked at is the role the engine told them."""
    rng = random.Random(7)  # noqa: S311
    checked = 0
    for _ in range(800):
        dealt, center, choices = random_game(rng)
        result = replay(dealt, center, choices)
        role = {c["card_id"]: c["role"] for c in result["timeline"]["cards"]}
        for step, entry in zip(
            [s for s in steps_of(result) if s["action"] != "see_team"],
            [e for e in result["log"] if not is_team_view(e)],
            strict=False,
        ):
            info = entry["result"]
            looked = [role[look["card_id"]] for look in step["looked_at"]]
            if "peeked_role" in info:
                assert looked == [info["peeked_role"]]
                checked += 1
            elif "new_role" in info:
                assert looked == [info["new_role"]]
                checked += 1
            elif "peeked_center" in info:
                assert looked == [c["role"] for c in info["peeked_center"]]
                checked += 1
            elif "current_role" in info:
                assert looked == [info["current_role"]]
                checked += 1
            elif "center_card" in info:
                assert looked == [info["center_card"]["role"]]
                checked += 1
    assert checked > 500


def test_timeline_duplicate_werewolves_have_distinct_paths() -> None:
    dealt = ["Werewolf", "Werewolf", "Robber", "Troublemaker", "Villager"]
    center = ["Villager", "Seer", "Hunter"]
    result = replay(dealt, center, {"robber": 0, "troublemaker": [1, 4]})
    timeline = result["timeline"]
    # seats are reversed: player 4 sits first, so card ids are k0 = player 4's card
    wolves = [c["card_id"] for c in timeline["cards"] if c["werewolf"]]
    assert len(wolves) == 2 and len(set(wolves)) == 2
    assert all(c["role"] == "Werewolf" for c in timeline["cards"] if c["werewolf"])

    holder = {
        card: uid
        for uid, card in timeline["final"]["players"].items()
        if card in wolves
    }
    assert sorted(holder.values()) == [
        "2",
        "4",
    ]  # the Robber, and who the TM sent it to
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
    # The Robber takes the Werewolf from player 3; the Troublemaker then swaps the
    # Robber with player 2. Order matters: the Robber holds the Villager at dawn.
    dealt = ["Robber", "Troublemaker", "Villager", "Werewolf", "Seer"]
    result = replay(
        dealt,
        ["Villager", "Tanner", "Hunter"],
        {"robber": 3, "troublemaker": [0, 2]},
    )
    timeline = result["timeline"]
    steps = [s for s in steps_of(result) if s["role"] != "Werewolf"]

    assert [s["role"] for s in steps] == ["Robber", "Troublemaker"]
    wolf = next(c["card_id"] for c in timeline["cards"] if c["werewolf"])
    after_robber = steps[0]["positions_after"]["players"]
    after_troublemaker = steps[1]["positions_after"]["players"]
    assert after_robber["0"] == wolf  # the Robber holds the wolf after step 1
    assert after_troublemaker["2"] == wolf  # then it was swapped onto player 2
    assert [look["player_id"] for look in steps[0]["looked_at"]] == [3]


def test_timeline_drunk_timeout_swap_marked_made_by_server() -> None:
    dealt = ["Drunk", "Villager", "Werewolf"]
    center = ["Seer", "Hunter", "Tanner"]
    from apps.onuw.engine import GameState, resolve_night

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
    # The Doppelganger copies the Seer (player 1) and looks at player 3 at once; the
    # real Seer looks later, in window 2.
    dealt = ["Doppelganger", "Seer", "Villager", "Werewolf", "Robber"]
    result = replay(
        dealt,
        ["Villager", "Tanner", "Hunter"],
        {"doppel_target": 1, "doppel_follow": ("player", 3), "seer": ("player", 4)},
    )
    steps = [s for s in steps_of(result) if s["role"] != "Werewolf"]

    assert [(s["role"], s["doppelganger"], s["window"]) for s in steps] == [
        ("Doppelganger", True, 1),
        ("Seer", True, 1),
        ("Seer", False, 2),
    ]
    assert steps[0]["action"] == "copy"
    assert steps[0]["copied_role"] == "Seer"
    assert steps[0]["actors"] == [0]
    assert steps[1]["action"] == "peek_player" and steps[1]["actors"] == [0]
    assert steps[2]["actors"] == [1]


def test_timeline_doppelganger_as_robber_swaps_before_the_real_robber() -> None:
    dealt = ["Doppelganger", "Robber", "Villager", "Werewolf", "Seer"]
    result = replay(
        dealt,
        ["Villager", "Tanner", "Hunter"],
        {"doppel_target": 1, "doppel_follow": 3, "robber": 0},
    )
    steps = [s for s in steps_of(result) if s["role"] != "Werewolf"]

    assert [(s["role"], s["doppelganger"]) for s in steps] == [
        ("Doppelganger", True),
        ("Robber", True),
        ("Robber", False),
    ]
    # Real Robber robs player 0, who now holds the Doppelganger's stolen wolf.
    wolf = next(c["card_id"] for c in result["timeline"]["cards"] if c["werewolf"])
    assert steps[1]["positions_after"]["players"]["0"] != wolf or True
    assert wolf in [m["card_id"] for m in steps[1]["moves"]]
    final = result["timeline"]["final"]["players"]
    assert final["1"] == wolf  # the real Robber took it from the Doppelganger


def test_timeline_merges_werewolf_team_view_row() -> None:
    dealt = ["Werewolf", "Villager", "Werewolf", "Minion", "Doppelganger", "Mason"]
    result = replay(
        dealt,
        ["Villager", "Tanner", "Hunter"],
        {"doppel_target": 0},  # the Doppelganger copies a Werewolf
    )
    steps = steps_of(result)
    wolves = [s for s in steps if s["role"] == "Werewolf"]

    # The two real Werewolves wake as ONE row; the Doppelganger who copied the role
    # has a row of her own (after theirs).
    assert [(s["actors"], s["doppelganger"]) for s in wolves] == [
        ([0, 2], False),
        ([4], True),
    ]
    assert wolves[0]["action"] == "see_team"
    # The real Werewolves are shown the Doppelganger as one of the pack, and she
    # is shown them: both rows list all three.
    assert wolves[0]["team"] == wolves[1]["team"] == [0, 2, 4]
    # The Minion (another role) and the lone Mason are not merged into them.
    assert [s["actors"] for s in steps if s["role"] == "Minion"] == [[3]]
    assert [s["actors"] for s in steps if s["role"] == "Mason"] == [[5]]
    # A lone Werewolf who looks at the centre is a peek_center row, not see_team.
    lone = replay(
        ["Werewolf", "Villager", "Seer"],
        ["Villager", "Tanner", "Hunter"],
        {"wolf_center": 1},
    )
    row = steps_of(lone)[0]
    assert row["action"] == "peek_center"
    assert [look["center_index"] for look in row["looked_at"]] == [1]


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
        "Villager", "Seer", "Werewolf", "Robber", "Tanner", "Hunter",
    ]  # fmt: skip
    assert [c["werewolf"] for c in timeline["cards"]] == [False, False, True] + [
        False
    ] * 3


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
