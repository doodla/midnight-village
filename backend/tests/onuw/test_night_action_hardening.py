"""
One player's stored action can never keep a night from closing.

A ``choose`` is parsed strictly before anything is stored (``engine.choose.parse_picks``,
``test_choose_engine.py``). If a stored action is poisoned anyway (older data, a bug,
a hand-edited row), the close treats that one action as a timeout, logs it loudly,
and carries on.
"""

import logging
from typing import Any

import pytest

from apps.onuw.engine.behaviors import execute_werewolf
from apps.onuw.engine.state import GameState, NightAction
from apps.onuw.models import Phase, PlayerRole

pytestmark = pytest.mark.integration

CENTER = ["Villager", "Tanner", "Hunter"]


class TestTheEngineIgnoresANullPeek:
    def test_a_null_center_index_is_no_peek(self):
        state = GameState(
            player_roles={1: "Werewolf", 2: "Villager"},
            center_cards=list(CENTER),
            original_roles={1: "Werewolf", 2: "Villager"},
        )
        action = NightAction(1, "Werewolf", "see_team", {"center_index": None})

        _state, result = execute_werewolf(state, action)

        assert result.revealed_info == {"werewolves": []}


POISON = [
    ("Werewolf", "see_team", {"center_index": None}),
    ("Werewolf", "see_team", {"center_index": "x"}),
    ("Seer", "peek_player", {"player_id": None}),
    ("Seer", "peek_player", {"player_id": "nobody"}),
    ("Seer", "peek_center", {"center_indices": None}),
    ("Seer", "peek_center", {"center_indices": [9, 9]}),
    ("Robber", "swap_with_player", {}),
    ("Robber", "swap_with_player", {"player_id": 999999}),
    ("Troublemaker", "swap_others", {"player_ids": [None, 1]}),
    ("Troublemaker", "swap_others", {"player_ids": "ab"}),
    ("Drunk", "swap_with_center", {"center_index": None}),
    ("Drunk", "swap_with_center", {"center_index": 99}),
    ("Insomniac", "none", {"center_index": None}),
]


class TestAPoisonedStoredActionCannotStopTheNight:
    def _poison(
        self, night, name: str, role: str, action_type: str, targets: Any
    ) -> None:
        PlayerRole.objects.filter(game=night.game, user=night.users[name]).update(
            has_acted=True,
            night_action_data={
                "wave": 2,
                "role_acting_as": role,
                "action_type": action_type,
                "targets": targets,
            },
        )

    @pytest.mark.parametrize(("role", "action_type", "targets"), POISON)
    def test_the_window_still_closes_and_the_others_are_unaffected(
        self, make_night, caplog, role, action_type, targets
    ):
        roles = {
            "p": role,
            "other_wolf": "Werewolf",
            "s": "Seer" if role != "Seer" else "Robber",
            "v": "Villager",
        }
        night = make_night(roles, CENTER, night_wave_seconds=60)
        night.start()
        self._poison(night, "p", role, action_type, targets)
        night.post("other_wolf", "see_team")

        with caplog.at_level(logging.ERROR):
            night.host_close_window()

        assert night.refresh().phase == Phase.DISCUSSION  # the night went on
        # The honest player's result is untouched.
        assert night.results("other_wolf")
        # The poisoned one was treated as a timeout, and the log says so.
        # (A null peek and an Insomniac's stray target are no longer errors for the
        # engine at all; everything else is logged as a timeout.)
        if not (
            role in ("Insomniac", "Werewolf") and targets == {"center_index": None}
        ):
            assert "treated as a timeout" in caplog.text or "Malformed" in caplog.text

    def test_the_window_timer_closes_a_poisoned_window_too(self, make_night, caplog):
        night = make_night(
            {"w": "Werewolf", "s": "Seer", "v": "Villager", "x": "Villager"},
            CENTER,
            night_wave_seconds=60,
        )
        night.start()
        self._poison(night, "w", "Werewolf", "see_team", {"center_index": None})

        with caplog.at_level(logging.ERROR):
            night.fire_timer(2)

        assert night.refresh().phase == Phase.DISCUSSION
        # The werewolf still got the automatic team view.
        (result,) = night.results("w")
        assert result["action_type"] == "see_team"

    def test_a_poisoned_drunk_is_still_swapped_by_the_server(self, make_night, caplog):
        from apps.onuw import services

        night = make_night(
            {"d": "Drunk", "w": "Werewolf", "v": "Villager", "x": "Villager"},
            CENTER,
            night_wave_seconds=60,
        )
        night.start()
        self._poison(night, "d", "Drunk", "swap_with_center", {"center_index": None})
        idx = services.drunk_timeout_center_index(42, night.users["d"].id, 3)

        with caplog.at_level(logging.ERROR):
            night.host_close_window()

        assert night.refresh().phase == Phase.DISCUSSION
        assert night.role_of("d").current_role == CENTER[idx]

    @pytest.mark.parametrize(
        "stored",
        [
            {"wave": 2, "role_acting_as": "Seer", "targets": {}},  # no action_type
            {"wave": 2, "role_acting_as": "Seer", "action_type": 5, "targets": {}},
            {
                "wave": 2,
                "role_acting_as": "Seer",
                "action_type": "peek_player",
                "targets": [1],
            },
        ],
    )
    def test_a_malformed_stored_record_is_a_timeout(self, make_night, caplog, stored):
        night = make_night(
            {"s": "Seer", "w": "Werewolf", "v": "Villager", "x": "Villager"},
            CENTER,
            night_wave_seconds=60,
        )
        night.start()
        PlayerRole.objects.filter(game=night.game, user=night.users["s"]).update(
            has_acted=True, night_action_data=stored
        )

        with caplog.at_level(logging.ERROR):
            night.host_close_window()

        assert night.refresh().phase == Phase.DISCUSSION
        assert "Malformed" in caplog.text

    def test_two_poisoned_players_do_not_stop_it_either(self, make_night, caplog):
        night = make_night(
            {"w": "Werewolf", "s": "Seer", "r": "Robber", "v": "Villager"},
            CENTER,
            night_wave_seconds=60,
        )
        night.start()
        self._poison(night, "w", "Werewolf", "see_team", {"center_index": None})
        self._poison(night, "s", "Seer", "peek_player", {"player_id": None})
        self._poison(night, "r", "Robber", "swap_with_player", {})

        with caplog.at_level(logging.ERROR):
            night.host_close_window()

        assert night.refresh().phase == Phase.DISCUSSION
