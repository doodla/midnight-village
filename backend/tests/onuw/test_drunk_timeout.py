"""
A Drunk who runs out of time MUST still swap.

The card game requires the Drunk to swap, so when the window closes without
their choice (clock ran out, host closed the window, or their phone was gone
past the grace period) the server swaps them with a center card taken from a
dedicated RNG seeded from ``Game.random_seed``. It is logged as an ordinary
swap marked ``made_by_server``, resolves when the window closes exactly like a
chosen swap, and the Drunk's own phone is shown which centre slot was swapped
(never the card), with ``nothing_chosen``: nobody else learns anything. The same
holds for a Drunk who chose nothing that counts, and for a Doppelganger who
copied the Drunk and let window 1 end.
"""

from datetime import timedelta
from typing import Any

from django.urls import reverse
from django.utils import timezone

import pytest
from rest_framework import status

from apps.onuw import services
from apps.onuw.models import Phase, PlayerRole
from tests.onuw.test_night_windows import Night

pytestmark = pytest.mark.integration

ROLES = {
    "wolf": "Werewolf",
    "seer": "Seer",
    "drunk": "Drunk",
    "villager": "Villager",
}
CENTER = ["Robber", "Tanner", "Hunter"]
SEED = 42  # what Night gives every game


def expected_index(night: Night, name: str) -> int:
    return services.drunk_timeout_center_index(SEED, night.users[name].id, 3)


def log_for(night: Night, name: str) -> list[dict[str, Any]]:
    night.refresh()
    return [
        e
        for e in night.game.night_actions_log
        if e["player_id"] == night.users[name].id
    ]


def everyone_else_acts(night: Night) -> None:
    night.post("wolf", "see_team")
    night.post("seer", "skip")
    night.post("villager", "none")


class TestTheSeededChoice:
    def test_same_seed_and_player_always_give_the_same_index(self) -> None:
        picks = {services.drunk_timeout_center_index(7, 12, 3) for _ in range(20)}
        assert len(picks) == 1

    def test_it_ignores_everything_but_seed_player_and_deck_size(self) -> None:
        first = services.drunk_timeout_center_index(99, 5, 3)
        # Other calls in between (other players, other games) change nothing.
        for pid in range(1, 30):
            services.drunk_timeout_center_index(99, pid, 3)
            services.drunk_timeout_center_index(pid, 5, 3)
        assert services.drunk_timeout_center_index(99, 5, 3) == first

    def test_it_varies_across_players_and_games_and_covers_every_card(self) -> None:
        by_player = {
            services.drunk_timeout_center_index(1, pid, 3) for pid in range(60)
        }
        by_game = {
            services.drunk_timeout_center_index(seed, 1, 3) for seed in range(60)
        }
        assert by_player == {0, 1, 2}
        assert by_game == {0, 1, 2}

    def test_it_is_always_a_valid_index(self) -> None:
        for seed in range(50):
            assert 0 <= services.drunk_timeout_center_index(seed, 3, 3) < 3


class TestARealDrunkRunsOutOfTime:
    def test_the_host_closing_the_window_makes_the_server_swap_them(
        self, make_night
    ) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()
        everyone_else_acts(night)
        idx = expected_index(night, "drunk")

        night.host_close_window()

        assert night.refresh().phase == Phase.DISCUSSION
        assert night.role_of("drunk").current_role == CENTER[idx]
        assert night.game.center_cards[idx] == "Drunk"
        assert night.role_of("drunk").original_role == "Drunk"

    def test_the_window_timer_expiring_does_the_same(self, make_night) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()
        idx = expected_index(night, "drunk")

        night.fire_timer(2)

        assert night.game.phase == Phase.DISCUSSION
        assert night.role_of("drunk").current_role == CENTER[idx]

    def test_the_swap_is_logged_like_any_other_action_and_marked_as_the_servers(
        self, make_night
    ) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()
        idx = expected_index(night, "drunk")
        night.host_close_window()

        (entry,) = log_for(night, "drunk")

        assert entry["action_type"] == "swap_with_center"
        assert entry["targets"] == {"center_index": idx}
        assert entry["role_acting_as"] == "Drunk"
        assert entry["wave"] == 3  # the order group, like a chosen swap
        assert entry["made_by_server"] is True

    def test_a_chosen_swap_has_no_such_mark(self, make_night) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()
        night.post("drunk", "swap_with_center", {"center_index": 1})
        night.host_close_window()

        (entry,) = log_for(night, "drunk")

        assert entry["action_type"] == "swap_with_center"
        assert "made_by_server" not in entry
        assert night.role_of("drunk").current_role == CENTER[1]

    def test_the_drunk_is_told_the_slot_and_that_the_server_chose_never_the_card(
        self, make_night
    ) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()
        idx = expected_index(night, "drunk")
        night.host_close_window()

        results = night.results("drunk")

        assert len(results) == 1
        assert results[0]["wave"] == 2
        assert results[0]["action_type"] == "swap_with_center"
        assert results[0]["revealed_info"] == {
            "card_index": idx,
            "nothing_chosen": True,
        }
        assert CENTER[idx] not in str(results[0])

    def test_nothing_is_delivered_or_swapped_before_the_window_closes(
        self, make_night
    ) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()
        everyone_else_acts(night)

        assert night.refresh().phase == Phase.NIGHT
        assert night.role_of("drunk").current_role == "Drunk"
        assert night.results("drunk") == []

    def test_nothing_in_what_other_players_receive_points_to_the_server_move(
        self, make_night
    ) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()
        night.host_close_window()

        for _group, event in night.recorder.events:
            assert "made_by_server" not in str(event)
            assert "server" not in str(event).lower()
        # The others' own results are exactly what they would be anyway.
        assert [e["action_type"] for e in night.results("seer")] == ["skip"]
        assert "made_by_server" not in str(night.results("seer"))

    def test_night_results_in_me_name_the_slot_whoever_chose_the_swap(
        self, make_night
    ) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()
        idx = expected_index(night, "drunk")
        night.host_close_window()
        night.client.force_authenticate(user=night.users["drunk"])

        data = night.client.get(
            reverse("onuw:game-me", kwargs={"game_id": str(night.game.id)})
        ).data

        # The Drunk's own phone learns which centre slot was swapped (never the
        # card), however the swap came about; that nothing it chose counted is
        # told to it alone.
        assert data["night_results"] == [
            {
                "wave": 2,
                "action_type": "swap_with_center",
                "revealed_info": {"card_index": idx, "nothing_chosen": True},
            }
        ]

    def test_a_drunk_who_chooses_nothing_is_still_swapped_by_the_server(
        self, make_night
    ) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()
        idx = expected_index(night, "drunk")

        assert night.prompt("drunk")["kind"] == "drunk"
        assert night.choose("drunk", [{"self": True}]).status_code == status.HTTP_200_OK
        night.host_close_window()

        (entry,) = log_for(night, "drunk")
        assert entry["made_by_server"] is True
        assert night.role_of("drunk").current_role == CENTER[idx]

    def test_the_same_game_seed_gives_the_same_center_card_every_time(
        self, make_night
    ) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()
        night.host_close_window()
        (first,) = log_for(night, "drunk")

        replay = services.drunk_timeout_center_index(
            night.game.random_seed, night.users["drunk"].id, 3
        )

        assert first["targets"]["center_index"] == replay

    def test_a_different_game_seed_can_give_a_different_card(self, make_night) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        mine = night.users["drunk"].id
        picks = {services.drunk_timeout_center_index(s, mine, 3) for s in range(30)}
        assert len(picks) > 1


class TestAnAbsentDrunk:
    def test_a_drunk_whose_phone_is_gone_past_grace_is_still_swapped(
        self, make_night
    ) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()
        idx = expected_index(night, "drunk")
        with night.committed():
            services.register_connection(night.game.id, night.users["drunk"].id)
        with night.committed():
            services.unregister_connection(night.game.id, night.users["drunk"].id)
        PlayerRole.objects.filter(game=night.game, user=night.users["drunk"]).update(
            disconnected_at=timezone.now() - timedelta(seconds=40)
        )
        # Everyone else acts; the Drunk's phone has been gone past the grace
        # period, so the window closes without waiting for them.
        everyone_else_acts(night)

        assert night.refresh().phase == Phase.DISCUSSION
        assert night.role_of("drunk").current_role == CENTER[idx]
        (entry,) = log_for(night, "drunk")
        assert entry["made_by_server"] is True

    def test_a_drunk_who_comes_back_in_time_chooses_for_themselves(
        self, make_night
    ) -> None:
        night = make_night(ROLES, CENTER, night_wave_seconds=60)
        night.start()
        everyone_else_acts(night)
        wanted = (expected_index(night, "drunk") + 1) % 3

        night.post("drunk", "swap_with_center", {"center_index": wanted})

        night.refresh()
        if night.game.phase == Phase.NIGHT:
            night.host_close_window()
        assert night.role_of("drunk").current_role == CENTER[wanted]
        (entry,) = log_for(night, "drunk")
        assert "made_by_server" not in entry


class TestDoppelgangerAsDrunk:
    DOPPEL = {"d": "Doppelganger", "dr": "Drunk", "w": "Werewolf", "v": "Villager"}

    def test_a_doppelganger_who_copied_the_drunk_and_never_chose_is_swapped(
        self, make_night
    ) -> None:
        night = make_night(
            self.DOPPEL,
            CENTER,
            night_doppelganger_window_seconds=10,
            night_wave_seconds=60,
        )
        night.start()
        night.post("d", "peek_player", {"player_id": night.users["dr"].id})
        assert night.refresh().current_wave == 1  # her follow-up is pending
        idx = services.drunk_timeout_center_index(SEED, night.users["d"].id, 3)

        night.fire_timer(1)  # window 1's own timer: she did not choose

        assert night.refresh().current_wave == 2
        assert night.role_of("d").current_role == CENTER[idx]
        assert night.game.center_cards[idx] == "Doppelganger"
        (look, swap) = log_for(night, "d")
        assert look["action_type"] == "peek_player"
        assert swap["action_type"] == "swap_with_center"
        assert swap["role_acting_as"] == "Drunk"
        assert swap["wave"] == 1
        assert swap["made_by_server"] is True
        assert "made_by_server" not in look

    def test_her_choice_is_used_when_she_makes_one(self, make_night) -> None:
        night = make_night(self.DOPPEL, CENTER, night_wave_seconds=60)
        night.start()
        night.post("d", "peek_player", {"player_id": night.users["dr"].id})
        night.post("d", "swap_with_center", {"center_index": 2})
        night.rest_choose()

        assert night.refresh().current_wave == 2
        assert night.role_of("d").current_role == CENTER[2]
        assert "made_by_server" not in log_for(night, "d")[-1]

    def test_the_real_drunk_is_swapped_separately_in_window_two(
        self, make_night
    ) -> None:
        night = make_night(self.DOPPEL, CENTER, night_wave_seconds=60)
        night.start()
        night.post("d", "peek_player", {"player_id": night.users["dr"].id})
        night.host_close_window()  # window 1: she is swapped by the server
        assert night.refresh().current_wave == 2

        night.host_close_window()  # window 2: so is the real Drunk

        assert night.refresh().phase == Phase.DISCUSSION
        marks = [e for e in night.game.night_actions_log if e.get("made_by_server")]
        assert sorted(e["player_id"] for e in marks) == sorted(
            [night.users["d"].id, night.users["dr"].id]
        )

    def test_a_doppelganger_who_never_looked_copies_nothing_and_swaps_nothing(
        self, make_night
    ) -> None:
        night = make_night(self.DOPPEL, CENTER, night_wave_seconds=60)
        night.start()

        night.host_close_window()  # window 1 ends with no look

        assert night.refresh().current_wave == 2
        assert [
            e for e in log_for(night, "d") if e["action_type"] == "swap_with_center"
        ] == []
        assert night.role_of("d").current_role == "Doppelganger"
