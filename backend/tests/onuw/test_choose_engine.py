"""
The pure ``choose`` engine: how picks are parsed and what they mean for a role.

No database, no HTTP. Every role (and so every Doppelganger copy, which is read as
the copied role) is tried against EVERY ordered list of up to two picks on a small
board, and each result is checked against the reading table in
``docs/specs/frontend/first-time-play.md``.
"""

import itertools

import pytest

from apps.onuw.engine.choose import (
    MAX_PICKS,
    Interpretation,
    Pick,
    build_choose_prompt,
    interpret_choice,
    is_lone_werewolf,
    max_chooses,
    parse_picks,
    prompt_kind,
)
from apps.onuw.engine.roles import ROLE_REGISTRY
from apps.onuw.engine.state import GameState

ME = 10
OTHERS = [11, 12, 13]
CENTER = 3
SELF = Pick("self")
PLAYERS = [Pick("player", p) for p in OTHERS]
CENTERS = [Pick("center", c) for c in range(CENTER)]
BOARD = [SELF, *PLAYERS, *CENTERS]


def every_choice() -> list[list[Pick]]:
    """Every ordered list of 0, 1 or 2 distinct picks on the board."""
    out: list[list[Pick]] = [[]]
    out += [[p] for p in BOARD]
    out += [list(pair) for pair in itertools.permutations(BOARD, 2)]
    return out


CHOICES = every_choice()


def ids(picks: list[Pick]) -> str:
    return (
        ",".join(f"{p.kind}{p.value}" if p.kind != "self" else "self" for p in picks)
        or "nothing"
    )


class TestParsePicks:
    def parse(self, raw):
        return parse_picks(
            raw, own_id=ME, player_ids={ME, *OTHERS}, center_count=CENTER
        )

    def test_zero_one_and_two_picks_in_order(self) -> None:
        assert self.parse([]) == []
        assert self.parse([{"player_id": 11}]) == [Pick("player", 11)]
        assert self.parse([{"center_index": 2}, {"player_id": 12}]) == [
            Pick("center", 2),
            Pick("player", 12),
        ]
        assert self.parse([{"self": True}, {"center_index": 0}]) == [
            SELF,
            Pick("center", 0),
        ]

    def test_ones_own_id_is_the_self_card(self) -> None:
        assert self.parse([{"player_id": ME}]) == [SELF]

    @pytest.mark.parametrize(
        "raw",
        [
            None,
            "x",
            {},
            {"player_id": 11},
            [{"player_id": 11}, {"player_id": 12}, {"player_id": 13}],
            [None],
            ["player_id"],
            [{}],
            [{"player_id": 11, "center_index": 0}],
            [{"unknown": 1}],
            [{"player_id": "11"}],
            [{"player_id": 11.0}],
            [{"player_id": True}],
            [{"player_id": None}],
            [{"player_id": 99}],
            [{"center_index": 3}],
            [{"center_index": -1}],
            [{"center_index": "0"}],
            [{"center_index": False}],
            [{"self": False}],
            [{"self": 1}],
            [{"self": "true"}],
            [{"player_id": 11}, {"player_id": 11}],
            [{"center_index": 1}, {"center_index": 1}],
            [{"self": True}, {"self": True}],
            [{"self": True}, {"player_id": ME}],
        ],
        ids=repr,
    )
    def test_malformed_picks(self, raw) -> None:
        assert self.parse(raw) is None


class TestReadingTable:
    """Every role against every list of picks."""

    @pytest.mark.parametrize("picks", CHOICES, ids=ids)
    def test_seer(self, picks) -> None:
        got = interpret_choice("Seer", picks)

        if len(picks) == 2 and picks[0].kind == picks[1].kind == "center":
            assert got == Interpretation(
                "peek_center", {"center_indices": [picks[0].value, picks[1].value]}
            )
        elif any(p.kind == "player" for p in picks):
            first = next(p for p in picks if p.kind == "player")
            assert got == Interpretation("peek_player", {"player_id": first.value})
        else:
            assert got is None

    @pytest.mark.parametrize("picks", CHOICES, ids=ids)
    def test_robber(self, picks) -> None:
        got = interpret_choice("Robber", picks)

        players = [p for p in picks if p.kind == "player"]
        assert got == (
            Interpretation("swap_with_player", {"player_id": players[0].value})
            if players
            else None
        )

    @pytest.mark.parametrize("picks", CHOICES, ids=ids)
    def test_troublemaker(self, picks) -> None:
        got = interpret_choice("Troublemaker", picks)

        if len(picks) == 2 and picks[0].kind == picks[1].kind == "player":
            assert got == Interpretation(
                "swap_others", {"player_ids": [picks[0].value, picks[1].value]}
            )
        else:
            assert got is None

    @pytest.mark.parametrize("picks", CHOICES, ids=ids)
    def test_drunk(self, picks) -> None:
        got = interpret_choice("Drunk", picks)

        centers = [p for p in picks if p.kind == "center"]
        assert got == (
            Interpretation("swap_with_center", {"center_index": centers[0].value})
            if centers
            else None
        )

    @pytest.mark.parametrize("picks", CHOICES, ids=ids)
    def test_lone_werewolf(self, picks) -> None:
        got = interpret_choice("Werewolf", picks, lone_werewolf=True)

        centers = [p for p in picks if p.kind == "center"]
        assert got == (
            Interpretation("see_team", {"center_index": centers[0].value})
            if centers
            else None
        )

    @pytest.mark.parametrize("picks", CHOICES, ids=ids)
    def test_a_werewolf_in_a_pack_reads_nothing(self, picks) -> None:
        assert interpret_choice("Werewolf", picks, lone_werewolf=False) is None

    @pytest.mark.parametrize("picks", CHOICES, ids=ids)
    def test_the_doppelgangers_look(self, picks) -> None:
        got = interpret_choice("Doppelganger", picks)

        players = [p for p in picks if p.kind == "player"]
        assert got == (
            Interpretation("peek_player", {"player_id": players[0].value})
            if players
            else None
        )

    @pytest.mark.parametrize(
        "role",
        sorted(
            set(ROLE_REGISTRY)
            - {"Seer", "Robber", "Troublemaker", "Drunk", "Werewolf", "Doppelganger"}
        ),
    )
    def test_every_other_role_reads_nothing_whatever_it_picks(self, role) -> None:
        # Villager, Hunter, Tanner, Mason, Minion, Insomniac: sleep, however it taps.
        assert all(interpret_choice(role, picks) is None for picks in CHOICES)

    @pytest.mark.parametrize("role", sorted(ROLE_REGISTRY))
    @pytest.mark.parametrize("lone", [False, True])
    @pytest.mark.parametrize("picks", CHOICES, ids=ids)
    def test_nothing_ever_targets_the_player_itself(self, role, lone, picks) -> None:
        # "You" is never a valid target: no reading names the player's own id, and a
        # swap or look is always of another player, with distinct cards.
        got = interpret_choice(role, picks, lone_werewolf=lone)
        if got is None:
            return
        flat = []
        for key in ("player_id", "player_ids", "center_index", "center_indices"):
            value = got.targets.get(key)
            flat += (
                value
                if isinstance(value, list)
                else [value]
                if value is not None
                else []
            )
        assert ME not in flat
        assert len(flat) == len(set(flat))
        assert got.action_type in {
            "peek_player",
            "peek_center",
            "swap_with_player",
            "swap_others",
            "swap_with_center",
            "see_team",
        }

    def test_the_first_valid_action_in_tap_order_wins(self) -> None:
        # A Seer who taps a player and then the centre looks at the player.
        both = [Pick("player", 11), Pick("center", 0)]
        assert interpret_choice("Seer", both) == Interpretation(
            "peek_player", {"player_id": 11}
        )
        assert interpret_choice("Seer", both[::-1]) == Interpretation(
            "peek_player", {"player_id": 11}
        )
        # A Seer who taps one centre card and "You" reads nothing.
        assert interpret_choice("Seer", [Pick("center", 1), SELF]) is None

    def test_readings_do_not_depend_on_the_player_id_values(self) -> None:
        a = interpret_choice("Troublemaker", [Pick("player", 5), Pick("player", 6)])
        b = interpret_choice("Troublemaker", [Pick("player", 6), Pick("player", 5)])
        assert a.targets == {"player_ids": [5, 6]}  # type: ignore[union-attr]
        assert b.targets == {"player_ids": [6, 5]}  # type: ignore[union-attr]


class TestWindows:
    def test_window_one_takes_two_chooses_and_window_two_one(self) -> None:
        assert (max_chooses(1), max_chooses(2)) == (2, 1)
        assert max_chooses(0) == 0
        assert MAX_PICKS == 2


def state(roles: dict[int, str], center: list[str], copied=None) -> GameState:
    return GameState(
        player_roles=dict(roles),
        center_cards=list(center),
        original_roles=dict(roles),
        doppelganger_copied_role=dict(copied or {}),
    )


class TestPrompt:
    TABLE = {ME: "Seer", 11: "Werewolf", 12: "Villager", 13: "Robber"}
    CENTRE = ["Villager", "Tanner", "Hunter"]

    def prompt(self, acting, *, table=None, chosen=0, window=2, who=ME):
        return build_choose_prompt(
            state(table or self.TABLE, self.CENTRE), who, window, acting, chosen
        )

    @pytest.mark.parametrize(
        ("acting", "kind"),
        [
            ("Seer", "seer"),
            ("Robber", "robber"),
            ("Troublemaker", "troublemaker"),
            ("Drunk", "drunk"),
            ("Doppelganger", "doppelganger_look"),
            ("Werewolf", "none"),  # not alone here
            ("Minion", "none"),
            ("Mason", "none"),
            ("Insomniac", "none"),
            (None, "none"),
        ],
    )
    def test_kind(self, acting, kind) -> None:
        assert self.prompt(acting)["kind"] == kind

    def test_a_lone_werewolf_is_told_its_real_option(self) -> None:
        table = {ME: "Werewolf", 11: "Seer", 12: "Villager", 13: "Robber"}

        prompt = self.prompt("Werewolf", table=table)

        assert prompt["kind"] == "lone_werewolf"
        assert prompt["valid_targets"]["center_indices"] == [0, 1, 2]

    def test_a_pack_werewolf_is_not_told_who_the_others_are(self) -> None:
        table = {ME: "Werewolf", 11: "Werewolf", 12: "Villager", 13: "Robber"}

        prompt = self.prompt("Werewolf", table=table)

        assert prompt["kind"] == "none"
        assert "teammates" not in prompt and "see_team" not in prompt["valid_targets"]

    def test_a_doppelganger_who_copied_the_lone_werewolf_is_lone_too(self) -> None:
        table = {ME: "Doppelganger", 11: "Seer", 12: "Villager", 13: "Robber"}
        copied = {ME: "Werewolf"}
        prompt = build_choose_prompt(
            state(table, self.CENTRE, copied), ME, 2, "Werewolf", 0
        )
        assert prompt["kind"] == "lone_werewolf"

    def test_the_board_is_the_same_for_every_kind(self) -> None:
        boards = {
            repr(self.prompt(acting)["valid_targets"])
            for acting in (
                "Seer",
                "Robber",
                "Troublemaker",
                "Drunk",
                "Doppelganger",
                "Werewolf",
                "Insomniac",
                None,
            )
        }
        assert len(boards) == 1

    def test_the_shape_is_the_same_for_every_kind(self) -> None:
        shapes = {
            tuple(sorted(self.prompt(acting))) for acting in ("Seer", "Villager", None)
        }
        assert len(shapes) == 1

    def test_it_says_how_many_chooses_remain(self) -> None:
        assert self.prompt("Seer", window=1, chosen=1)["max_chooses"] == 2
        assert self.prompt("Seer", window=2, chosen=1)["max_chooses"] == 1
        assert self.prompt("Seer", chosen=1)["chosen"] == 1

    def test_the_players_own_card_is_not_in_the_board(self) -> None:
        assert ME not in self.prompt("Seer")["valid_targets"]["player_ids"]

    def test_prompt_kind_and_lone_helper(self) -> None:
        assert prompt_kind(None) == "none"
        assert prompt_kind("Werewolf", lone_werewolf=True) == "lone_werewolf"
        assert is_lone_werewolf(
            state({1: "Werewolf", 2: "Seer", 3: "Robber"}, ["Villager"] * 3), 1
        )
        assert not is_lone_werewolf(
            state({1: "Werewolf", 2: "Werewolf", 3: "Robber"}, ["Villager"] * 3), 1
        )
