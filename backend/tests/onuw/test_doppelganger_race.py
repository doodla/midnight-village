"""
A Doppelganger whose look is stored but not yet resolved when window 1 closes.

Her look resolves in the request that stores it (``choose_night.submit_choose``,
``test_choose_night.py``). A row that holds an unresolved look anyway (older data,
a failure) must not cost her the copied role: a close that finds one resolves it
first, so the follow-up gets its timeout default (a Drunk must swap, a Minion still
looks).
"""

from typing import Any

import pytest

from apps.onuw import night_window
from apps.onuw.models import Phase, PlayerRole

pytestmark = pytest.mark.integration

CENTER = ["Robber", "Tanner", "Hunter"]


def store_look_without_resolving(night: Any, who: str, target: str) -> None:
    """The look is committed (stored, has_acted) but was never resolved: the state
    a close must cope with."""
    PlayerRole.objects.filter(game=night.game, user=night.users[who]).update(
        has_acted=True,
        night_action_data={
            "wave": 1,
            "role_acting_as": "Doppelganger",
            "action_type": "peek_player",
            "targets": {"player_id": night.users[target].id},
        },
    )


@pytest.mark.parametrize("closer", ["host", "timer"])
class TestTheWindowClosesBeforeTheLookWasResolved:
    def _close(self, night: Any, closer: str) -> None:
        if closer == "host":
            night.host_close_window()
        else:
            night.fire_timer(1)

    def _night(self, make_night, roles: dict[str, str]) -> Any:
        night = make_night(
            roles,
            CENTER,
            night_doppelganger_window_seconds=10,
            night_wave_seconds=60,
        )
        night.start()
        assert night.refresh().current_wave == 1
        return night

    def test_a_drunk_copy_is_still_swapped_by_the_server(
        self, make_night, closer
    ) -> None:
        night = self._night(
            make_night,
            {"d": "Doppelganger", "dr": "Drunk", "w": "Werewolf", "v": "Villager"},
        )
        store_look_without_resolving(night, "d", "dr")
        idx = night_window.drunk_timeout_center_index(42, night.users["d"].id, 3)

        self._close(night, closer)

        assert night.refresh().current_wave == 2
        assert night.role_of("d").current_role == CENTER[idx]
        assert night.game.center_cards[idx] == "Doppelganger"
        swap = [
            e
            for e in night.game.night_actions_log
            if e["player_id"] == night.users["d"].id
            and e["action_type"] == "swap_with_center"
        ]
        assert len(swap) == 1
        assert swap[0]["role_acting_as"] == "Drunk"
        assert swap[0]["made_by_server"] is True

    def test_a_minion_copy_still_sees_the_werewolves(self, make_night, closer) -> None:
        night = self._night(
            make_night,
            {"d": "Doppelganger", "m": "Minion", "w": "Werewolf", "v": "Villager"},
        )
        store_look_without_resolving(night, "d", "m")

        self._close(night, closer)

        results = night.results("d")
        assert [r["action_type"] for r in results] == ["peek_player", "see_team"]
        assert results[1]["revealed_info"]["teammate_names"] == [
            night.users["w"].display_name or night.users["w"].username
        ]

    def test_the_look_result_is_listed_once_and_never_replaced_by_an_empty_one(
        self, make_night, closer
    ) -> None:
        night = self._night(
            make_night,
            {"d": "Doppelganger", "s": "Seer", "w": "Werewolf", "v": "Villager"},
        )
        store_look_without_resolving(night, "d", "s")

        self._close(night, closer)

        results = night.results("d")
        looks = [e for e in results if e["action_type"] == "peek_player"]
        assert len(looks) == 1
        assert looks[0]["revealed_info"]["role"] == "Seer"
        assert looks[0]["revealed_info"]["copied_role"] == "Seer"
        # The unchosen Seer follow-up is a plain skip, labelled as one.
        assert [e["action_type"] for e in results] == ["peek_player", "skip"]

    def test_other_players_are_unaffected(self, make_night, closer) -> None:
        night = self._night(
            make_night,
            {"d": "Doppelganger", "dr": "Drunk", "w": "Werewolf", "v": "Villager"},
        )
        store_look_without_resolving(night, "d", "dr")

        self._close(night, closer)

        assert night.results("v") == []
        assert night.role_of("w").current_role == "Werewolf"
        # The real Drunk is not touched until window 2.
        assert night.refresh().phase == Phase.NIGHT
