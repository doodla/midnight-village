"""
A Doppelganger whose look is stored but not yet resolved when window 1 closes.

The look used to be resolved in a second step after the submission committed. If
the window job took the Game lock in between (or that step failed), the window
closed knowing nothing of her copied role and her follow-up was skipped, even
when the copied role must act (a Drunk must swap, a Minion still looks). Now the
look resolves in the transaction that stores it, and a close that still finds an
unresolved look resolves it first, so the follow-up gets its timeout default.
"""

from typing import Any
from unittest.mock import patch

import pytest
from rest_framework import status

from apps.onuw import services
from apps.onuw.models import Phase, PlayerRole

pytestmark = pytest.mark.integration

CENTER = ["Robber", "Tanner", "Hunter"]


def store_look_without_resolving(night: Any, who: str, target: str) -> None:
    """The look is committed (stored, has_acted) but check_and_maybe_advance
    never ran: exactly the state the window job can find."""
    PlayerRole.objects.filter(game=night.game, user=night.users[who]).update(
        has_acted=True,
        night_action_data={
            "wave": 1,
            "role_acting_as": "Doppelganger",
            "action_type": "peek_player",
            "targets": {"player_id": night.users[target].id},
        },
    )


def as_socket(event: dict[str, Any]) -> dict[str, Any]:
    return {k: event[k] for k in ("wave", "action_type", "revealed_info")}


class TestTheLookIsResolvedWhereItIsStored:
    def test_the_submission_resolves_the_look_even_if_nothing_runs_after_it(
        self, make_night
    ) -> None:
        night = make_night(
            {"d": "Doppelganger", "dr": "Drunk", "w": "Werewolf", "v": "Villager"},
            CENTER,
            night_wave_seconds=60,
        )
        night.start()

        with patch(
            "apps.onuw.views.check_and_maybe_advance"
        ):  # the second step never happens
            response = night.post(
                "d", "peek_player", {"player_id": night.users["dr"].id}
            )

        assert response.status_code == status.HTTP_200_OK
        data = night.role_of("d").night_action_data
        assert data["copied_role"] == "Drunk"  # copied role known and stored
        assert [e["action_type"] for e in night.events_to("d", "action.result")] == [
            "peek_player"
        ]
        prompt = night.events_to("d", "action.prompt")[-1]
        assert prompt["role_acting_as"] == "Drunk"  # the follow-up was prompted

    def test_a_window_closing_after_that_gives_the_drunk_copy_its_swap(
        self, make_night
    ) -> None:
        night = make_night(
            {"d": "Doppelganger", "dr": "Drunk", "w": "Werewolf", "v": "Villager"},
            CENTER,
            night_wave_seconds=60,
        )
        night.start()
        with patch("apps.onuw.views.check_and_maybe_advance"):
            night.post("d", "peek_player", {"player_id": night.users["dr"].id})
        idx = services.drunk_timeout_center_index(42, night.users["d"].id, 3)

        night.host_close_window()

        assert night.role_of("d").current_role == CENTER[idx]


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
        idx = services.drunk_timeout_center_index(42, night.users["d"].id, 3)

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

        results = [as_socket(e) for e in night.events_to("d", "action.result")]
        assert [r["action_type"] for r in results] == ["peek_player", "see_team"]
        assert results[1]["revealed_info"]["teammate_names"] == [
            night.users["w"].display_name or night.users["w"].username
        ]

    def test_the_look_result_is_sent_once_and_is_never_replaced_by_an_empty_one(
        self, make_night, closer
    ) -> None:
        night = self._night(
            make_night,
            {"d": "Doppelganger", "s": "Seer", "w": "Werewolf", "v": "Villager"},
        )
        store_look_without_resolving(night, "d", "s")

        self._close(night, closer)

        looks = [
            e
            for e in night.events_to("d", "action.result")
            if e["action_type"] == "peek_player"
        ]
        assert len(looks) == 1
        assert looks[0]["revealed_info"]["role"] == "seer"
        assert looks[0]["revealed_info"]["copied_role"] == "Seer"
        # The unsubmitted Seer follow-up is a plain skip, labelled as one.
        assert [e["action_type"] for e in night.events_to("d", "action.result")] == [
            "peek_player",
            "skip",
        ]

    def test_other_players_are_unaffected(self, make_night, closer) -> None:
        night = self._night(
            make_night,
            {"d": "Doppelganger", "dr": "Drunk", "w": "Werewolf", "v": "Villager"},
        )
        store_look_without_resolving(night, "d", "dr")

        self._close(night, closer)

        assert night.events_to("v", "action.result") == []
        assert night.role_of("w").current_role == "Werewolf"
        # The real Drunk is not touched until window 2.
        assert night.refresh().phase == Phase.NIGHT


def test_each_result_is_labelled_with_its_own_action(make_night) -> None:
    """Directly: a look and a follow-up resolved in ONE close map to their own actions."""
    from apps.onuw.engine.state import ActionResult, NightAction

    night = make_night(
        {"d": "Doppelganger", "s": "Seer", "w": "Werewolf", "v": "Villager"},
        CENTER,
    )
    d = night.users["d"].id
    look = NightAction(
        d, "Doppelganger", "peek_player", {"player_id": night.users["s"].id}
    )
    follow = NightAction(d, "Seer", "peek_player", {"player_id": night.users["w"].id})
    results = [
        ActionResult(d, {"copied_role": "Seer"}, []),
        ActionResult(d, {"peeked_role": "Werewolf"}, []),
    ]

    messages = services._action_result_messages(night.game, results, [follow, look], 1)

    payloads = [event["revealed_info"] for _group, event in messages]
    assert payloads[0]["copied_role"] == "Seer" and payloads[0]["role"] == "seer"
    assert payloads[1]["role"] == "werewolf"
