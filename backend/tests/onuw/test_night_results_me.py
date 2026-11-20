"""
Every phone reads what the night showed it from GET /me/.

``night_results`` lists the caller's own results for windows that have closed (and
the Doppelganger's look as soon as it resolves), each ``{"wave", "action_type",
"revealed_info"}``, and nothing about a window that is still open or about anyone
else. Nothing in the night is sent to one player by socket.
"""

from typing import Any

from django.urls import reverse

import pytest
from rest_framework import status

from apps.onuw.engine.state import NightAction
from apps.onuw.models import Game, Phase
from apps.onuw.services import _client_action_type
from tests.onuw.test_night_windows import PER_PLAYER_NIGHT_EVENTS, Night

pytestmark = pytest.mark.integration

ROLES = {
    "wolf": "Werewolf",
    "seer": "Seer",
    "robber": "Robber",
    "insomniac": "Insomniac",
    "villager": "Villager",
}
CENTER = ["Villager", "Tanner", "Hunter"]


def me(night: Night, name: str) -> dict[str, Any]:
    night.client.force_authenticate(user=night.users[name])
    response = night.client.get(
        reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})
    )
    assert response.status_code == status.HTTP_200_OK
    return response.data


def play_window_two(night: Night) -> None:
    """Every phone with a choice but the Robber's chooses (the Villager and the
    Insomniac have nothing to choose and send nothing): the window stays open."""
    night.post("wolf", "see_team")
    night.post("villager", "none")
    night.post("seer", "peek_player", {"player_id": night.users["robber"].id})
    night.post("insomniac", "none")


def rob(night: Night) -> None:
    """The Robber, the last phone with a choice, takes the Villager's card."""
    night.post("robber", "swap_with_player", {"player_id": night.users["villager"].id})


class TestNightResultsInMe:
    def test_empty_before_any_window_closes_and_for_a_player_with_nothing_to_show(
        self, make_night
    ) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()

        for name in ROLES:
            assert me(night, name)["night_results"] == []

    def test_nothing_appears_while_the_window_is_still_open(self, make_night) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()

        play_window_two(night)  # the Robber has not chosen: the window is open

        assert night.refresh().current_wave == 2
        for name in ROLES:
            assert me(night, name)["night_results"] == []
        # and nothing by socket either
        assert not PER_PLAYER_NIGHT_EVENTS & set(night.all_event_types())

    def test_every_actor_reads_its_one_result_once_the_window_closed(
        self, make_night
    ) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()
        play_window_two(night)
        rob(night)
        assert night.refresh().phase == Phase.DISCUSSION

        for name in ("wolf", "seer", "robber", "insomniac"):
            payload = me(night, name)["night_results"]
            assert len(payload) == 1
            assert payload[0]["wave"] == 2
        # Spot-check the content rather than only the equality.
        seer = me(night, "seer")["night_results"][0]
        assert seer["action_type"] == "peek_player"
        assert seer["revealed_info"]["role"] == "Robber"
        robber = me(night, "robber")["night_results"][0]
        assert robber["action_type"] == "swap_with_player"
        assert robber["revealed_info"]["new_role"] == "Villager"

    def test_the_insomniac_dawn_result_is_included(self, make_night) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()
        play_window_two(night)
        rob(night)

        entry = me(night, "insomniac")["night_results"]

        # The Insomniac looks at the end of the night: she sees her own card
        # after the Robber's swap (she was not touched, so still the Insomniac).
        assert entry == [
            {
                "wave": 2,
                "action_type": "insomniac",
                "revealed_info": {"current_role": "Insomniac"},
            }
        ]

    def test_the_dawn_result_sees_a_swap_made_the_same_night(self, make_night) -> None:
        night = make_night(
            {"rob": "Robber", "ins": "Insomniac", "wolf": "Werewolf", "v": "Villager"},
            CENTER,
        )
        night.start()
        night.post("rob", "swap_with_player", {"player_id": night.users["ins"].id})
        night.post("wolf", "see_team")
        night.post("v", "none")
        night.post("ins", "none")
        assert night.refresh().phase == Phase.DISCUSSION

        assert me(night, "ins")["night_results"] == [
            {
                "wave": 2,
                "action_type": "insomniac",
                "revealed_info": {"current_role": "Robber"},
            }
        ]
        assert me(night, "rob")["night_results"][0]["revealed_info"] == {
            "target_name": night.users["ins"].display_name
            or night.users["ins"].username,
            "new_role": "Insomniac",
        }

    def test_a_timed_out_player_still_learns_what_the_night_gives_them(
        self, make_night
    ) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()
        night.post("seer", "skip")
        night.host_close_window()  # the wolf and the insomniac never submitted

        assert night.refresh().phase == Phase.DISCUSSION
        assert me(night, "wolf")["night_results"][0]["action_type"] == "see_team"
        assert me(night, "insomniac")["night_results"][0]["action_type"] == "insomniac"
        # A choice that did nothing is told to its own phone, as nothing.
        assert me(night, "seer")["night_results"] == [
            {
                "wave": 2,
                "action_type": "skip",
                "revealed_info": {"nothing_chosen": True},
            }
        ]

    def test_other_players_results_are_never_in_the_list(self, make_night) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()
        play_window_two(night)
        rob(night)

        villager = me(night, "villager")["night_results"]
        seer = me(night, "seer")["night_results"]

        assert villager == []
        # The Seer's list is only the Seer's own result, nothing of the wolf's
        # team view or the Robber's swap.
        assert [r["action_type"] for r in seer] == ["peek_player"]
        text = str(seer)
        wolf_name = night.users["wolf"].display_name or night.users["wolf"].username
        assert wolf_name not in text
        assert "teammate_names" not in text
        assert "new_role" not in text

    def test_the_list_is_available_in_discussion_voting_and_results(
        self, make_night
    ) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()
        play_window_two(night)
        rob(night)
        expected = me(night, "seer")["night_results"]
        assert expected

        for phase in (Phase.DISCUSSION, Phase.VOTING, Phase.RESULTS):
            Game.objects.filter(id=night.game.id).update(phase=phase)
            data = me(night, "seer")
            assert data["phase"] == phase
            assert data["night_results"] == expected

    def test_the_raw_stored_results_are_not_what_the_list_shows(
        self, make_night
    ) -> None:
        """The list is the transformed (client) shape, never the engine's raw one."""
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()
        play_window_two(night)
        rob(night)

        revealed = me(night, "seer")["night_results"][0]["revealed_info"]

        assert set(revealed) == {"target_name", "role"}  # names, never raw ids
        assert "peeked_role" not in revealed


class TestDoppelgangerWindowOne:
    DOPPEL = {"d": "Doppelganger", "s": "Seer", "w": "Werewolf", "v": "Villager"}

    def test_her_look_appears_at_once_and_her_follow_up_once_window_one_closed(
        self, make_night
    ) -> None:
        night = make_night(self.DOPPEL, ["Robber", "Tanner", "Hunter"])
        night.start()
        assert night.game.current_wave == 1

        # The look is resolved at once and listed (she needs it to choose).
        night.post("d", "peek_player", {"player_id": night.users["s"].id})
        assert night.refresh().current_wave == 1  # window 1 open: follow-up pending
        assert [r["action_type"] for r in me(night, "d")["night_results"]] == [
            "peek_player"
        ]

        assert len(me(night, "d")["night_results"]) == 1  # the follow-up waits
        # Her follow-up is the last choice window 1 waits for: it closes at once
        # (nobody else has anything to choose there).
        night.post("d", "peek_center", {"center_indices": [0, 1]})
        assert night.refresh().current_wave == 2

        results = me(night, "d")["night_results"]
        assert [(r["wave"], r["action_type"]) for r in results] == [
            (1, "peek_player"),
            (1, "peek_center"),
        ]
        assert results[0]["revealed_info"]["copied_role"] == "Seer"
        assert results[1]["revealed_info"] == {
            "roles": ["Robber", "Tanner"],
            "center_indices": [0, 1],
        }

    def test_window_two_open_shows_window_one_but_nothing_of_window_two(
        self, make_night
    ) -> None:
        # Window 2 has nothing to choose (two Werewolves, a Villager, the
        # Insomniac): it stays open for the table's minimum length.
        night = make_night(
            {"d": "Doppelganger", "w": "Werewolf", "v": "Villager", "i": "Insomniac"},
            ["Seer", "Tanner", "Hunter"],
            night_wave_seconds=60,
            night_min_window_seconds=5,
        )
        night.start()
        night.post("d", "peek_player", {"player_id": night.users["w"].id})
        night.fire_timer(1)
        assert night.refresh().current_wave == 2  # a Werewolf copy acts in window 2

        assert [r["wave"] for r in me(night, "d")["night_results"]] == [1]
        assert me(night, "w")["night_results"] == []
        night.fire_timer(2)
        assert night.refresh().phase == Phase.DISCUSSION

        later = me(night, "d")["night_results"]
        assert [(r["wave"], r["action_type"]) for r in later] == [
            (1, "peek_player"),
            (2, "see_team"),
        ]
        # The Doppelganger who copied the Werewolf sees the real Werewolf in her team view.
        assert later[1]["revealed_info"]["teammate_names"] == [
            night.users["w"].display_name or night.users["w"].username
        ]

    def test_a_doppelganger_who_copied_the_insomniac_gets_the_dawn_result(
        self, make_night
    ) -> None:
        night = make_night(
            {"d": "Doppelganger", "i": "Insomniac", "w": "Werewolf", "v": "Villager"},
            ["Seer", "Tanner", "Hunter"],
        )
        night.start()
        night.post("d", "peek_player", {"player_id": night.users["i"].id})
        night.rest_choose()
        night.post("w", "see_team")
        night.post("i", "none")
        night.post("d", "none")
        night.post("v", "none")
        assert night.refresh().phase == Phase.DISCUSSION

        results = me(night, "d")["night_results"]

        assert [(r["wave"], r["action_type"]) for r in results] == [
            (1, "peek_player"),
            (2, "insomniac"),
        ]

    def test_players_with_no_window_one_part_get_nothing_for_it(
        self, make_night
    ) -> None:
        night = make_night(
            self.DOPPEL, ["Robber", "Tanner", "Hunter"], night_wave_seconds=60
        )
        night.start()
        night.post("d", "peek_player", {"player_id": night.users["s"].id})
        night.post("d", "peek_center", {"center_indices": [0, 1]})
        assert night.refresh().current_wave == 2

        for name in ("s", "w", "v"):
            assert me(night, name)["night_results"] == []


# ── /me/ shows each player exactly their own results, for every action type ──


def resolve_targets(night: Night, spec: dict[str, Any]) -> dict[str, Any]:
    """Names in a target spec ("player_id": "seer") become user ids."""
    out: dict[str, Any] = {}
    for key, value in spec.items():
        if key == "player_id":
            out[key] = night.users[value].id
        elif key == "player_ids":
            out[key] = [night.users[name].id for name in value]
        else:
            out[key] = value
    return out


CENTER3 = ["Villager", "Tanner", "Hunter"]

# id: (roles in join order, centre cards, [(who, action_type, target spec)])
SCENARIOS: dict[str, tuple[dict[str, str], list[str], list[tuple[str, str, dict]]]] = {
    "lone_werewolf_peeks_the_centre": (
        {"w": "Werewolf", "s": "Seer", "v": "Villager", "x": "Villager"},
        CENTER3,
        [("w", "see_team", {"center_index": 1})],
    ),
    "two_werewolves_see_each_other": (
        {"w": "Werewolf", "w2": "Werewolf", "s": "Seer", "v": "Villager"},
        CENTER3,
        [("w", "see_team", {}), ("w2", "see_team", {})],
    ),
    "minion_sees_the_werewolf": (
        {"w": "Werewolf", "m": "Minion", "v": "Villager", "x": "Villager"},
        CENTER3,
        [("w", "see_team", {}), ("m", "see_team", {})],
    ),
    "masons_see_each_other": (
        {"a": "Mason", "b": "Mason", "w": "Werewolf", "v": "Villager"},
        CENTER3,
        [("a", "see_team", {}), ("b", "see_team", {})],
    ),
    "seer_looks_at_a_player": (
        {"s": "Seer", "w": "Werewolf", "v": "Villager", "x": "Villager"},
        CENTER3,
        [("s", "peek_player", {"player_id": "w"})],
    ),
    "seer_looks_at_two_centre_cards": (
        {"s": "Seer", "w": "Werewolf", "v": "Villager", "x": "Villager"},
        CENTER3,
        [("s", "peek_center", {"center_indices": [0, 2]})],
    ),
    "robber_takes_a_card": (
        {"r": "Robber", "w": "Werewolf", "v": "Villager", "x": "Villager"},
        CENTER3,
        [("r", "swap_with_player", {"player_id": "w"})],
    ),
    "troublemaker_swaps_two_players": (
        {"t": "Troublemaker", "w": "Werewolf", "v": "Villager", "x": "Villager"},
        CENTER3,
        [("t", "swap_others", {"player_ids": ["w", "v"]})],
    ),
    "drunk_chooses_a_centre_card": (
        {"d": "Drunk", "w": "Werewolf", "v": "Villager", "x": "Villager"},
        CENTER3,
        [("d", "swap_with_center", {"center_index": 2})],
    ),
    "drunk_runs_out_of_time_and_the_server_swaps": (
        {"d": "Drunk", "w": "Werewolf", "v": "Villager", "x": "Villager"},
        CENTER3,
        [],
    ),
    "insomniac_looks_at_dawn": (
        {"i": "Insomniac", "r": "Robber", "w": "Werewolf", "v": "Villager"},
        CENTER3,
        [("r", "swap_with_player", {"player_id": "i"}), ("i", "none", {})],
    ),
    "doppelganger_copies_seer": (
        {"d": "Doppelganger", "s": "Seer", "w": "Werewolf", "v": "Villager"},
        CENTER3,
        [
            ("d", "peek_player", {"player_id": "s"}),
            ("d", "peek_player", {"player_id": "w"}),
        ],
    ),
    "doppelganger_copies_seer_and_peeks_the_centre": (
        {"d": "Doppelganger", "s": "Seer", "w": "Werewolf", "v": "Villager"},
        CENTER3,
        [
            ("d", "peek_player", {"player_id": "s"}),
            ("d", "peek_center", {"center_indices": [0, 1]}),
        ],
    ),
    "doppelganger_copies_robber": (
        {"d": "Doppelganger", "r": "Robber", "w": "Werewolf", "v": "Villager"},
        CENTER3,
        [
            ("d", "peek_player", {"player_id": "r"}),
            ("d", "swap_with_player", {"player_id": "w"}),
        ],
    ),
    "doppelganger_copies_troublemaker": (
        {"d": "Doppelganger", "t": "Troublemaker", "w": "Werewolf", "v": "Villager"},
        CENTER3,
        [
            ("d", "peek_player", {"player_id": "t"}),
            ("d", "swap_others", {"player_ids": ["w", "v"]}),
        ],
    ),
    "doppelganger_copies_drunk_and_chooses": (
        {"d": "Doppelganger", "dr": "Drunk", "w": "Werewolf", "v": "Villager"},
        CENTER3,
        [
            ("d", "peek_player", {"player_id": "dr"}),
            ("d", "swap_with_center", {"center_index": 1}),
        ],
    ),
    "doppelganger_copies_drunk_and_runs_out_of_time": (
        {"d": "Doppelganger", "dr": "Drunk", "w": "Werewolf", "v": "Villager"},
        CENTER3,
        [("d", "peek_player", {"player_id": "dr"})],
    ),
    "doppelganger_copies_minion": (
        {"d": "Doppelganger", "m": "Minion", "w": "Werewolf", "v": "Villager"},
        CENTER3,
        [("d", "peek_player", {"player_id": "m"}), ("d", "see_team", {})],
    ),
    "doppelganger_copies_werewolf": (
        {"d": "Doppelganger", "w": "Werewolf", "v": "Villager", "x": "Villager"},
        CENTER3,
        [("d", "peek_player", {"player_id": "w"}), ("d", "see_team", {})],
    ),
    "doppelganger_copies_mason": (
        {"d": "Doppelganger", "a": "Mason", "b": "Mason", "w": "Werewolf"},
        CENTER3,
        [("d", "peek_player", {"player_id": "a"}), ("d", "see_team", {})],
    ),
    "doppelganger_copies_insomniac": (
        {"d": "Doppelganger", "i": "Insomniac", "w": "Werewolf", "v": "Villager"},
        CENTER3,
        [("d", "peek_player", {"player_id": "i"}), ("d", "none", {})],
    ),
}


@pytest.mark.parametrize("scenario", list(SCENARIOS))
def test_me_shows_each_player_their_own_results_for_every_action(
    make_night, scenario: str
) -> None:
    roles, center, actions = SCENARIOS[scenario]
    night = make_night(roles, center, night_wave_seconds=60)
    night.start()
    for who, action_type, spec in actions:
        if night.refresh().phase != Phase.NIGHT:
            break  # nobody left with a choice: the night is over
        response = night.post(who, action_type, resolve_targets(night, spec))
        if response is None:
            continue  # a phone with nothing to choose sends nothing
        assert response.status_code == status.HTTP_200_OK, (
            who,
            action_type,
            response.data,
        )
    for _ in range(
        3
    ):  # whoever has not chosen (or is waiting out the minimum) runs out of time
        if night.refresh().phase != Phase.NIGHT:
            break
        night.host_close_window()
    assert night.refresh().phase == Phase.DISCUSSION

    log = night.refresh().night_actions_log
    for name, user in night.users.items():
        own = [
            _client_action_type(
                NightAction(
                    player_id=user.id,
                    role_acting_as=e["role_acting_as"],
                    action_type=e["action_type"],
                    targets=e["targets"],
                )
            )
            for e in log
            if e["player_id"] == user.id
        ]
        shown = me(night, name)["night_results"]
        # Exactly the player's own log entries, in order, as the client shape.
        assert [r["action_type"] for r in shown] == own, f"{scenario}: {name}"
        for result in shown:
            assert "peeked_role" not in result["revealed_info"]
    # The scenario really did give somebody something (not a vacuous pass).
    assert any(me(night, name)["night_results"] for name in roles), scenario


def test_every_swap_is_in_me_even_though_its_engine_result_is_empty(make_night) -> None:
    night = make_night(
        {"t": "Troublemaker", "d": "Drunk", "w": "Werewolf", "v": "Villager"},
        CENTER3,
        night_wave_seconds=60,
    )
    night.start()
    night.post(
        "t", "swap_others", {"player_ids": [night.users["w"].id, night.users["v"].id]}
    )
    night.post("d", "swap_with_center", {"center_index": 0})
    night.host_close_window()

    names = {
        u: (night.users[u].display_name or night.users[u].username) for u in ("w", "v")
    }
    assert me(night, "t")["night_results"] == [
        {
            "wave": 2,
            "action_type": "swap_others",
            "revealed_info": {"player1_name": names["w"], "player2_name": names["v"]},
        }
    ]
    assert me(night, "d")["night_results"] == [
        {
            "wave": 2,
            "action_type": "swap_with_center",
            "revealed_info": {"card_index": 0},
        }
    ]


def test_a_choice_that_did_nothing_is_listed_as_nothing_chosen(make_night) -> None:
    night = make_night(
        {"s": "Seer", "w": "Werewolf", "v": "Villager", "x": "Villager"},
        CENTER3,
        night_wave_seconds=60,
    )
    night.start()
    night.post("s", "skip")
    night.host_close_window()

    assert me(night, "s")["night_results"] == [
        {"wave": 2, "action_type": "skip", "revealed_info": {"nothing_chosen": True}}
    ]
