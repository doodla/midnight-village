"""
Service- and API-level tests for the two-window night.

Window 1 is the Doppelganger alone. Window 2 prompts every remaining actor at
once and resolves when it closes. Covered here:

- everyone in window 2 is prompted together
- nothing is delivered to a player before the window closes
- the Insomniac sees swaps made in the same window
- minimum window length (deferred close, close at the maximum, host override)
- windows are never skipped for lack of actors
- "skip" for Seer, Robber, Troublemaker (and rejected elsewhere, generically)
- teams come from DEALT cards (a stolen Werewolf card does not move the wake-up)
"""

import logging
from datetime import timedelta
from typing import Any
from unittest.mock import patch

from django.db import transaction
from django.urls import reverse
from django.utils import timezone

import pytest
from rest_framework import status
from rest_framework.test import APIClient

from apps.core.models import Lobby, LobbyMember, User
from apps.onuw import services
from apps.onuw.engine.roles import ROLE_REGISTRY
from apps.onuw.models import Game, Phase, PlayerRole

pytestmark = pytest.mark.integration

GENERIC_INVALID_TYPE = "Invalid action type for this wave."


class _Recorder:
    """Stands in for the channel layer and remembers every event sent."""

    def __init__(self) -> None:
        self.events: list[tuple[str, dict[str, Any]]] = []

    def group_send(self, group: str, event: dict[str, Any]) -> None:
        self.events.append((group, event))


class Night:
    """A game in the night phase, driven through the real service and API layers."""

    def __init__(
        self,
        roles: dict[str, str],
        center: list[str],
        settings: dict[str, Any],
        recorder: _Recorder,
        scheduled: list[tuple[str, float, Any]],
        capture_on_commit: Any,
    ) -> None:
        self.recorder = recorder
        self.scheduled = scheduled
        self._capture_on_commit = capture_on_commit
        self.users = {
            name: User.objects.create_user(username=f"nw_{name}", password="pass")
            for name in roles
        }
        host = self.users[next(iter(roles))]
        lobby = Lobby.objects.create(
            host=host,
            game_type="onuw",
            max_players=10,
            settings={"roles": {}},
        )
        for user in self.users.values():
            LobbyMember.objects.create(lobby=lobby, user=user, is_ready=True)
        lobby.status = Lobby.Status.IN_GAME
        lobby.save()
        self.game = Game.objects.create(
            lobby=lobby,
            phase=Phase.NIGHT,
            random_seed=42,
            settings=settings,
            center_cards=center,
        )
        for name, role in roles.items():
            PlayerRole.objects.create(
                game=self.game,
                user=self.users[name],
                original_role=role,
                current_role=role,
            )
        self.host = host
        self.client = APIClient()

    # -- driving the game ---------------------------------------------------

    def committed(self) -> Any:
        """Run the block, then run its on-commit callbacks (a real commit)."""
        return self._capture_on_commit(execute=True)

    def start(self) -> None:
        with self.committed():
            services.start_night_phase(self.game)
        self.game.refresh_from_db()

    def post(
        self, name: str, action_type: str, targets: dict[str, Any] | None = None
    ) -> Any:
        self.client.force_authenticate(user=self.users[name])
        url = reverse("onuw:night-action", kwargs={"game_id": str(self.game.id)})
        with self.committed():
            return self.client.post(
                url,
                {"action_type": action_type, "targets": targets or {}},
                format="json",
            )

    def host_close_window(self) -> Any:
        self.client.force_authenticate(user=self.host)
        url = reverse("onuw:wave-advance", kwargs={"game_id": str(self.game.id)})
        with self.committed():
            return self.client.post(url, format="json")

    def fire_timer(self, window: int) -> None:
        """Run the most recently scheduled callback for a window (timer expiry)."""
        key = f"{self.game.id}:wave:{window}"
        callbacks = [cb for k, _, cb in self.scheduled if k == key]
        assert callbacks, f"no timer scheduled for window {window}"
        with self.committed():
            callbacks[-1]()
        self.game.refresh_from_db()

    def timer_delays(self, window: int) -> list[float]:
        key = f"{self.game.id}:wave:{window}"
        return [delay for k, delay, _ in self.scheduled if k == key]

    def timer_delays_for(self, name: str) -> list[float]:
        key = f"{self.game.id}:{name}"
        return [delay for k, delay, _ in self.scheduled if k == key]

    def pretend_window_opened(self, seconds_ago: float) -> None:
        Game.objects.filter(id=self.game.id).update(
            night_window_opened_at=timezone.now() - timedelta(seconds=seconds_ago)
        )

    # -- looking at what happened -------------------------------------------

    def refresh(self) -> Game:
        self.game.refresh_from_db()
        return self.game

    def role_of(self, name: str) -> PlayerRole:
        return PlayerRole.objects.get(game=self.game, user=self.users[name])

    def events_to(self, name: str, kind: str | None = None) -> list[dict[str, Any]]:
        group = f"game_{self.game.id}_player_{self.users[name].id}"
        return [
            e
            for g, e in self.recorder.events
            if g == group and (kind is None or e["type"] == kind)
        ]

    def broadcasts(self, kind: str | None = None) -> list[dict[str, Any]]:
        group = f"game_{self.game.id}"
        return [
            e
            for g, e in self.recorder.events
            if g == group and (kind is None or e["type"] == kind)
        ]

    def all_event_types(self) -> list[str]:
        return [e["type"] for _, e in self.recorder.events]

    def result_events(self) -> list[dict[str, Any]]:
        return [e for _, e in self.recorder.events if e["type"] == "action.result"]


@pytest.fixture
def make_night(db, django_capture_on_commit_callbacks):
    """Factory for a Night; channel layer and timers are recorded, not run."""
    recorder = _Recorder()
    scheduled: list[tuple[str, float, Any]] = []

    def fake_schedule(key, delay, callback, *args):
        scheduled.append((key, delay, callback))

    mock_layer = type("Layer", (), {"group_send": recorder.group_send})()
    with (
        patch("apps.onuw.services.get_channel_layer", return_value=mock_layer),
        patch("apps.onuw.services.async_to_sync", side_effect=lambda f: f),
        patch("apps.onuw.timers.schedule", side_effect=fake_schedule),
    ):

        def factory(
            roles: dict[str, str],
            center: list[str] | None = None,
            **settings: Any,
        ) -> Night:
            # Defaults: no minimum length and no fixed Doppelganger window, so
            # windows close as soon as there is nothing left to wait for. Tests
            # of those rules set them explicitly.
            merged = {
                "roles": {},
                "night_min_window_seconds": 0,
                "night_doppelganger_window_seconds": 0,
                **settings,
            }
            return Night(
                roles,
                center or ["Villager", "Tanner", "Hunter"],
                merged,
                recorder,
                scheduled,
                django_capture_on_commit_callbacks,
            )

        yield factory


# ── Window 2: everyone is prompted together ──────────────────────────────────


class TestSharedWindowPrompts:
    ROLES = {
        "wolf": "Werewolf",
        "minion": "Minion",
        "mason_a": "Mason",
        "mason_b": "Mason",
        "seer": "Seer",
        "robber": "Robber",
        "trouble": "Troublemaker",
        "drunk": "Drunk",
        "insomniac": "Insomniac",
        "villager": "Villager",
    }

    def test_all_window_2_actors_are_prompted_together(self, make_night) -> None:
        night = make_night(self.ROLES, night_min_window_seconds=8)
        night.start()

        assert night.game.current_wave == 2
        assert [e["wave"] for e in night.broadcasts("wave.start")] == [2]

        prompted = {
            name: night.events_to(name, "action.prompt")
            for name in self.ROLES
            if night.events_to(name, "action.prompt")
        }
        assert {n: p[0]["role_acting_as"] for n, p in prompted.items()} == {
            "wolf": "Werewolf",
            "minion": "Minion",
            "mason_a": "Mason",
            "mason_b": "Mason",
            "seer": "Seer",
            "robber": "Robber",
            "trouble": "Troublemaker",
            "drunk": "Drunk",
            "insomniac": "Insomniac",
        }
        assert all(len(p) == 1 and p[0]["wave"] == 2 for p in prompted.values())

        # The player with no action is told to wait, in the same window.
        waiting = night.events_to("villager", "wave.waiting")
        assert [e["wave"] for e in waiting] == [2]
        assert night.events_to("villager", "action.prompt") == []

    def test_optional_roles_are_offered_skip_and_the_drunk_is_not(
        self, make_night
    ) -> None:
        night = make_night(self.ROLES)
        night.start()

        def offered(name: str) -> list[str]:
            return night.events_to(name, "action.prompt")[0]["action_types"]

        assert "skip" in offered("seer")
        assert "skip" in offered("robber")
        assert "skip" in offered("trouble")
        assert "skip" not in offered("drunk")
        assert "skip" not in offered("wolf")
        assert "skip" not in offered("insomniac")

    def test_window_2_stays_open_until_every_actor_has_submitted(
        self, make_night
    ) -> None:
        night = make_night(
            {"a": "Seer", "b": "Robber", "c": "Villager", "d": "Villager"}
        )
        night.start()

        assert night.post("a", "skip").status_code == status.HTTP_200_OK

        assert night.refresh().phase == Phase.NIGHT
        assert night.game.current_wave == 2

        assert night.post("b", "skip").status_code == status.HTTP_200_OK
        assert night.refresh().phase == Phase.DISCUSSION


# ── Nothing is delivered before the window closes ────────────────────────────


class TestResultsOnlyWhenTheWindowCloses:
    def _roles(self) -> dict[str, str]:
        return {
            "wolf_a": "Werewolf",
            "wolf_b": "Werewolf",
            "seer": "Seer",
            "robber": "Robber",
            "insomniac": "Insomniac",
            "villager": "Villager",
        }

    def test_no_result_is_delivered_or_stored_while_someone_is_still_choosing(
        self, make_night
    ) -> None:
        night = make_night(self._roles())
        night.start()

        night.post("wolf_a", "see_team")
        night.post("wolf_b", "see_team")
        night.post("seer", "peek_player", {"player_id": night.users["robber"].id})
        night.post("insomniac", "none")

        # The Robber has not chosen: the window is open, nothing was shown.
        assert night.refresh().phase == Phase.NIGHT
        assert night.result_events() == []
        assert "wave.complete" not in night.all_event_types()
        for name in ("wolf_a", "wolf_b", "seer", "insomniac"):
            assert "wave_2_result" not in night.role_of(name).night_action_data

        night.post(
            "robber", "swap_with_player", {"player_id": night.users["wolf_a"].id}
        )

        assert night.refresh().phase == Phase.DISCUSSION

    def test_every_actor_gets_exactly_one_result_when_the_window_closes(
        self, make_night
    ) -> None:
        night = make_night(self._roles())
        night.start()
        night.post("wolf_a", "see_team")
        night.post("wolf_b", "see_team")
        night.post("seer", "peek_player", {"player_id": night.users["robber"].id})
        night.post("insomniac", "none")
        night.post(
            "robber", "swap_with_player", {"player_id": night.users["wolf_a"].id}
        )

        for name in ("wolf_a", "wolf_b", "seer", "robber", "insomniac"):
            assert len(night.events_to(name, "action.result")) == 1, name
        assert night.events_to("villager", "action.result") == []

        # Each result belongs to window 2 and stays private to its player.
        seer = night.events_to("seer", "action.result")[0]
        assert seer["wave"] == 2
        assert seer["revealed_info"]["role"] == "robber"  # before the Robber moved
        robber = night.events_to("robber", "action.result")[0]
        assert robber["revealed_info"]["new_role"] == "werewolf"

        # Results are sent, then the window is announced complete, then the day.
        types = night.all_event_types()
        last_result = max(i for i, t in enumerate(types) if t == "action.result")
        assert last_result < types.index("wave.complete") < types.index("phase.change")
        assert [e["wave"] for e in night.broadcasts("wave.complete")] == [2]

    def test_results_are_stored_per_window_and_the_log_stays_in_wake_order(
        self, make_night
    ) -> None:
        night = make_night(self._roles())
        night.start()
        night.post(
            "robber", "swap_with_player", {"player_id": night.users["wolf_a"].id}
        )
        night.post("seer", "skip")
        night.post("insomniac", "none")
        night.post("wolf_b", "see_team")
        night.post("wolf_a", "see_team")

        data = night.role_of("wolf_a").night_action_data
        assert data["wave_2_result"]["werewolves"] == [night.users["wolf_b"].id]
        assert not any(k in data for k in ("wave_3_result", "wave_4_result"))

        groups = [e["wave"] for e in night.refresh().night_actions_log]
        assert groups == sorted(groups)
        assert groups == [2, 2, 3, 3, 4]

    def test_insomniac_result_reflects_swaps_made_in_the_same_window(
        self, make_night
    ) -> None:
        night = make_night(
            {
                "wolf": "Werewolf",
                "insomniac": "Insomniac",
                "robber": "Robber",
                "trouble": "Troublemaker",
                "villager": "Villager",
            }
        )
        night.start()
        ids = {name: user.id for name, user in night.users.items()}

        # The Insomniac submits FIRST; the swaps still count.
        night.post("insomniac", "none")
        night.post(
            "trouble", "swap_others", {"player_ids": [ids["insomniac"], ids["wolf"]]}
        )
        night.post("wolf", "see_team")
        night.post("robber", "swap_with_player", {"player_id": ids["insomniac"]})

        # Robber took the Insomniac card, then the Troublemaker swapped the
        # Insomniac's seat with the Werewolf's.
        result = night.events_to("insomniac", "action.result")[0]
        assert result["action_type"] == "insomniac"
        assert result["revealed_info"] == {"current_role": "werewolf"}
        assert night.role_of("insomniac").night_action_data["wave_2_result"] == {
            "current_role": "Werewolf"
        }


# ── Minimum and maximum window length ────────────────────────────────────────


class TestMinimumWindowLength:
    ROLES = {"wolf": "Werewolf", "seer": "Seer", "v1": "Villager", "v2": "Villager"}

    def test_default_minimum_is_eight_seconds(self, make_night) -> None:
        night = make_night(self.ROLES, center=None)
        Game.objects.filter(id=night.game.id).update(
            settings={"roles": {}}  # no timer settings at all
        )
        night.game.refresh_from_db()
        night.game.night_window_opened_at = timezone.now()

        assert 7 < services._min_close_delay(night.game) <= 8

    def test_close_is_deferred_when_everyone_submits_early(self, make_night) -> None:
        night = make_night(
            self.ROLES, night_min_window_seconds=8, night_wave_seconds=30
        )
        night.start()
        assert night.timer_delays(2) == [30]  # the maximum, set when it opened

        night.post("wolf", "see_team")
        night.post("seer", "skip")

        # Everyone is done, but the window is not allowed to close yet.
        assert night.refresh().phase == Phase.NIGHT
        assert night.game.current_wave == 2
        assert night.result_events() == []
        deferred = night.timer_delays(2)[-1]
        assert 0 < deferred <= 8

        # When the minimum is reached the close fires and results go out.
        night.fire_timer(2)
        assert night.game.phase == Phase.DISCUSSION
        assert len(night.result_events()) == 2

    def test_a_window_that_is_already_old_enough_closes_at_once(
        self, make_night
    ) -> None:
        night = make_night(self.ROLES, night_min_window_seconds=8)
        night.start()
        night.pretend_window_opened(seconds_ago=9)

        night.post("wolf", "see_team")
        night.post("seer", "skip")

        assert night.refresh().phase == Phase.DISCUSSION

    def test_window_closes_at_the_maximum_when_someone_never_submits(
        self, make_night
    ) -> None:
        night = make_night(
            self.ROLES, night_min_window_seconds=8, night_wave_seconds=30
        )
        night.start()
        night.post("wolf", "see_team")  # the Seer never submits

        assert night.refresh().phase == Phase.NIGHT
        assert night.timer_delays(2) == [30]  # nothing earlier was scheduled

        night.fire_timer(2)

        assert night.game.phase == Phase.DISCUSSION
        seer_log = [
            e
            for e in night.game.night_actions_log
            if e["player_id"] == night.users["seer"].id
        ]
        assert [e["action_type"] for e in seer_log] == ["skip"]

    def test_the_minimum_never_exceeds_the_maximum(self, make_night) -> None:
        night = make_night(
            self.ROLES, night_min_window_seconds=60, night_wave_seconds=5
        )
        night.start()
        night.post("wolf", "see_team")
        night.post("seer", "skip")

        assert night.refresh().phase == Phase.NIGHT
        assert 0 < night.timer_delays(2)[-1] <= 5

    def test_host_can_still_close_the_window_before_the_minimum(
        self, make_night
    ) -> None:
        night = make_night(self.ROLES, night_min_window_seconds=8)
        night.start()

        response = night.host_close_window()

        assert response.status_code == status.HTTP_200_OK
        assert night.refresh().phase == Phase.DISCUSSION

    def test_stale_timer_for_a_finished_window_does_nothing(self, make_night) -> None:
        night = make_night({"d": "Doppelganger", "s": "Seer", "v": "Villager"})
        night.start()
        assert night.game.current_wave == 1
        stale = [cb for k, _, cb in night.scheduled if k.endswith(":wave:1")][-1]

        night.host_close_window()  # closes window 1, opens window 2
        assert night.refresh().current_wave == 2
        stale()  # the old window-1 timer fires late

        assert night.refresh().current_wave == 2
        assert night.game.phase == Phase.NIGHT


# ── Windows are never skipped ────────────────────────────────────────────────


class TestWindowsAlwaysRun:
    def test_window_1_runs_with_the_doppelganger_card_in_the_center(
        self, make_night
    ) -> None:
        night = make_night(
            {"a": "Villager", "b": "Seer", "c": "Werewolf"},
            center=["Doppelganger", "Robber", "Tanner"],
            night_min_window_seconds=8,
        )
        night.start()

        assert night.game.current_wave == 1
        assert [e["wave"] for e in night.broadcasts("wave.start")] == [1]
        for name in ("a", "b", "c"):
            assert [e["wave"] for e in night.events_to(name, "wave.waiting")] == [1]
            assert night.events_to(name, "action.prompt") == []

        # Nobody can act, yet it still lasts its minimum length.
        assert night.game.phase == Phase.NIGHT
        assert 0 < night.timer_delays(1)[-1] <= 8
        night.fire_timer(1)
        assert night.game.current_wave == 2
        assert [e["wave"] for e in night.broadcasts("wave.start")] == [1, 2]

    def test_window_1_does_not_run_when_the_doppelganger_is_not_in_the_deck(
        self, make_night
    ) -> None:
        night = make_night({"a": "Villager", "b": "Seer", "c": "Werewolf"})
        night.start()

        assert night.game.current_wave == 2
        assert [e["wave"] for e in night.broadcasts("wave.start")] == [2]

    def test_empty_window_1_passes_straight_to_window_2_when_minimum_is_zero(
        self, make_night
    ) -> None:
        night = make_night(
            {"a": "Villager", "b": "Seer", "c": "Werewolf"},
            center=["Doppelganger", "Robber", "Tanner"],
        )
        night.start()

        assert [e["wave"] for e in night.broadcasts("wave.start")] == [1, 2]
        assert [e["wave"] for e in night.broadcasts("wave.complete")] == [1]
        assert night.game.current_wave == 2

    def test_an_all_villager_table_still_gets_window_2(self, make_night) -> None:
        night = make_night(
            {"a": "Villager", "b": "Villager", "c": "Villager"},
            night_min_window_seconds=8,
        )
        night.start()

        assert night.game.phase == Phase.NIGHT
        assert night.game.current_wave == 2
        for name in ("a", "b", "c"):
            assert [e["wave"] for e in night.events_to(name, "wave.waiting")] == [2]

        # Nobody has a choice, so it lasts exactly its minimum length.
        assert 0 < night.timer_delays(2)[-1] <= 8
        night.fire_timer(2)
        assert night.game.phase == Phase.DISCUSSION
        assert [e["wave"] for e in night.broadcasts("wave.complete")] == [2]

    def test_an_all_villager_table_with_no_minimum_goes_straight_to_the_day(
        self, make_night
    ) -> None:
        night = make_night({"a": "Villager", "b": "Villager", "c": "Villager"})
        night.start()

        assert night.game.phase == Phase.DISCUSSION
        assert [e["wave"] for e in night.broadcasts("wave.start")] == [2]
        assert [e["wave"] for e in night.broadcasts("wave.complete")] == [2]

    def test_current_wave_is_zero_outside_the_night(self, make_night) -> None:
        night = make_night({"a": "Villager", "b": "Villager", "c": "Villager"})
        night.start()

        assert night.game.current_wave == 0
        assert night.game.night_window_opened_at is None


# ── skip ─────────────────────────────────────────────────────────────────────


class TestSkip:
    ROLES = {
        "seer": "Seer",
        "robber": "Robber",
        "trouble": "Troublemaker",
        "drunk": "Drunk",
        "wolf": "Werewolf",
        "insomniac": "Insomniac",
        "villager": "Villager",
    }

    @pytest.mark.parametrize("who", ["seer", "robber", "trouble"])
    def test_skip_is_accepted_for_seer_robber_and_troublemaker(
        self, make_night, who: str
    ) -> None:
        night = make_night(self.ROLES)
        night.start()

        response = night.post(who, "skip")

        assert response.status_code == status.HTTP_200_OK
        data = night.role_of(who).night_action_data
        assert data["action_type"] == "skip"
        assert data["targets"] == {}

    def test_skipping_changes_nothing_and_is_logged(self, make_night) -> None:
        night = make_night(self.ROLES)
        night.start()
        before = {n: night.role_of(n).current_role for n in self.ROLES}
        for who in ("seer", "robber", "trouble"):
            night.post(who, "skip")
        night.host_close_window()

        assert {n: night.role_of(n).current_role for n in self.ROLES} == before
        night.refresh()
        skippers = {night.users[n].id for n in ("seer", "robber", "trouble")}
        skips = [
            e
            for e in night.game.night_actions_log
            if e["action_type"] == "skip" and e["player_id"] in skippers
        ]
        assert len(skips) == 3
        assert night.result_events()  # the skippers are told it was a skip
        seer_result = night.events_to("seer", "action.result")[0]
        assert seer_result["action_type"] == "skip"
        assert seer_result["revealed_info"] == {}

    def test_skip_is_rejected_for_the_drunk_with_a_generic_error(
        self, make_night
    ) -> None:
        night = make_night(self.ROLES)
        night.start()

        response = night.post("drunk", "skip")

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["detail"] == [GENERIC_INVALID_TYPE]
        assert not night.role_of("drunk").has_acted

        # Indistinguishable from any other invalid action type.
        other = night.post("seer", "no_such_action")
        assert other.data["detail"] == response.data["detail"]
        # And it names no role.
        text = str(response.data).lower()
        assert not any(name.lower() in text for name in ROLE_REGISTRY)

    @pytest.mark.parametrize("who", ["wolf", "insomniac"])
    def test_skip_is_rejected_for_view_only_roles(self, make_night, who: str) -> None:
        night = make_night(self.ROLES)
        night.start()

        response = night.post(who, "skip")

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["detail"] == [GENERIC_INVALID_TYPE]

    def test_skip_is_rejected_for_the_doppelgangers_first_look(
        self, make_night
    ) -> None:
        night = make_night({"d": "Doppelganger", "s": "Seer", "v": "Villager"})
        night.start()
        assert night.game.current_wave == 1

        response = night.post("d", "skip")

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["detail"] == [GENERIC_INVALID_TYPE]
        assert night.refresh().current_wave == 1

    def test_skip_with_targets_is_rejected(self, make_night) -> None:
        night = make_night(self.ROLES)
        night.start()

        response = night.post("seer", "skip", {"player_id": night.users["wolf"].id})

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert not night.role_of("seer").has_acted

    @pytest.mark.parametrize("copied", ["Seer", "Robber", "Troublemaker"])
    def test_doppelganger_can_skip_the_follow_up_of_an_optional_role(
        self, make_night, copied: str
    ) -> None:
        night = make_night(
            {
                "d": "Doppelganger",
                "target": copied,
                "w": "Werewolf",
                "v1": "Villager",
                "v2": "Villager",
            }
        )
        night.start()
        night.post("d", "peek_player", {"player_id": night.users["target"].id})
        follow_up = night.events_to("d", "action.prompt")[-1]
        assert follow_up["role_acting_as"] == copied
        assert "skip" in follow_up["action_types"]

        response = night.post("d", "skip")

        assert response.status_code == status.HTTP_200_OK
        assert night.refresh().current_wave == 2  # window 1 closed, window 2 opened
        assert night.role_of("d").current_role == "Doppelganger"

    def test_doppelganger_cannot_skip_a_drunk_follow_up(self, make_night) -> None:
        night = make_night(
            {"d": "Doppelganger", "drunk": "Drunk", "w": "Werewolf", "v": "Villager"}
        )
        night.start()
        night.post("d", "peek_player", {"player_id": night.users["drunk"].id})

        response = night.post("d", "skip")

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert response.data["detail"] == [GENERIC_INVALID_TYPE]
        follow_up = night.events_to("d", "action.prompt")[-1]
        assert "skip" not in follow_up["action_types"]


# ── Window 1: the Doppelganger ───────────────────────────────────────────────


class TestDoppelgangerWindow:
    def test_the_look_is_delivered_at_once_but_the_follow_up_waits_for_the_close(
        self, make_night
    ) -> None:
        night = make_night(
            {"d": "Doppelganger", "r": "Robber", "w": "Werewolf", "v": "Villager"},
            night_min_window_seconds=8,
        )
        night.start()

        night.post("d", "peek_player", {"player_id": night.users["r"].id})
        looks = night.events_to("d", "action.result")
        assert [e["revealed_info"]["copied_role"] for e in looks] == ["Robber"]
        assert night.broadcasts("wave.complete") == []  # nobody learns she copied

        night.post("d", "swap_with_player", {"player_id": night.users["w"].id})

        # Everything is submitted; the window waits out its minimum.
        assert night.refresh().current_wave == 1
        assert len(night.events_to("d", "action.result")) == 1
        assert night.role_of("d").current_role == "Doppelganger"  # not applied yet

        night.fire_timer(1)

        assert night.game.current_wave == 2
        assert night.role_of("d").current_role == "Werewolf"
        assert night.role_of("w").current_role == "Doppelganger"
        results = night.events_to("d", "action.result")
        assert [e["action_type"] for e in results] == [
            "peek_player",
            "swap_with_player",
        ]
        assert results[1]["revealed_info"]["new_role"] == "werewolf"
        assert [e["wave"] for e in night.broadcasts("wave.complete")] == [1]

    def test_window_1_deadline_does_not_reveal_a_follow_up(self, make_night) -> None:
        night = make_night(
            {"d": "Doppelganger", "s": "Seer", "w": "Werewolf", "v": "Villager"},
            night_wave_seconds=30,
        )
        night.start()
        deadline_before = night.refresh().phase_deadline

        night.post("d", "peek_player", {"player_id": night.users["s"].id})

        assert night.refresh().phase_deadline == deadline_before

    def test_doppelganger_who_copied_a_late_role_acts_in_window_2(
        self, make_night
    ) -> None:
        night = make_night(
            {"d": "Doppelganger", "w1": "Werewolf", "w2": "Werewolf", "v": "Villager"}
        )
        night.start()
        night.post("d", "peek_player", {"player_id": night.users["w1"].id})

        assert night.refresh().current_wave == 2
        prompt = night.events_to("d", "action.prompt")[-1]
        assert prompt["role_acting_as"] == "Werewolf"
        assert prompt["wave"] == 2

        night.post("d", "see_team")
        night.post("w1", "see_team")
        night.post("w2", "see_team")

        assert night.refresh().phase == Phase.DISCUSSION
        result = night.events_to("d", "action.result")[-1]
        assert set(result["revealed_info"]["teammate_names"]) == {
            night.users["w1"].display_name or night.users["w1"].username,
            night.users["w2"].display_name or night.users["w2"].username,
        }
        # At most one result in window 2 (plus the look from window 1).
        assert [e["wave"] for e in night.events_to("d", "action.result")] == [1, 2]


# ── Teams come from DEALT cards ──────────────────────────────────────────────


class TestDealtCardsDecideWhoWakes:
    def _steal_the_wolf_in_window_1(self, night: Night, victim: str) -> None:
        """The Doppelganger copies the Robber, then robs `victim` in window 1."""
        night.start()
        night.post("d", "peek_player", {"player_id": night.users["r"].id})
        night.post("d", "swap_with_player", {"player_id": night.users[victim].id})
        assert night.refresh().current_wave == 2

    def test_dealt_werewolf_whose_card_was_stolen_is_still_prompted_and_is_lone(
        self, make_night
    ) -> None:
        night = make_night(
            {"d": "Doppelganger", "w": "Werewolf", "r": "Robber", "v": "Villager"},
            center=["Seer", "Villager", "Tanner"],
        )
        self._steal_the_wolf_in_window_1(night, victim="w")
        assert night.role_of("d").current_role == "Werewolf"  # the thief holds it
        assert night.role_of("w").current_role == "Doppelganger"

        # The victim is prompted as a Werewolf, and nobody else is on the team.
        prompt = night.events_to("w", "action.prompt")[-1]
        assert prompt["role_acting_as"] == "Werewolf"
        assert prompt["valid_targets"]["see_team"] == []
        # The thief is not prompted: she woke (and acted) as the Robber.
        assert night.events_to("d", "action.prompt")[-1]["wave"] == 1
        assert [e["wave"] for e in night.events_to("d", "wave.waiting")] == [2]
        assert sorted(services.get_wave_actors(night.game, 2)) == sorted(
            [night.users["w"].id, night.users["r"].id]
        )

        # So the victim may look at a center card; the thief may not act.
        assert night.post("d", "see_team").status_code == status.HTTP_400_BAD_REQUEST
        peek = night.post("w", "see_team", {"center_index": 0})
        assert peek.status_code == status.HTTP_200_OK
        night.post("r", "skip")

        result = night.events_to("w", "action.result")[-1]
        assert result["revealed_info"]["teammate_names"] == []
        assert result["revealed_info"]["center_card"] == {"index": 0, "role": "seer"}

    def test_a_werewolf_whose_partner_was_robbed_is_not_lone(self, make_night) -> None:
        night = make_night(
            {
                "d": "Doppelganger",
                "w1": "Werewolf",
                "w2": "Werewolf",
                "r": "Robber",
                "v": "Villager",
            },
            center=["Seer", "Villager", "Tanner"],
        )
        self._steal_the_wolf_in_window_1(night, victim="w2")

        # w2's card moved, but w2 still wakes: w1 sees w2 and may not peek.
        prompt = night.events_to("w1", "action.prompt")[-1]
        assert prompt["valid_targets"]["see_team"] == [night.users["w2"].id]
        refused = night.post("w1", "see_team", {"center_index": 0})
        assert refused.status_code == status.HTTP_400_BAD_REQUEST
        assert refused.data["detail"] == ["Center card peek is not available."]

        assert night.post("w1", "see_team").status_code == status.HTTP_200_OK
        assert night.post("w2", "see_team").status_code == status.HTTP_200_OK
        # The thief (holding a Werewolf card) is NOT shown to them.
        night.post("r", "skip")
        seen = night.events_to("w1", "action.result")[-1]
        assert seen["revealed_info"]["teammate_names"] == [
            night.users["w2"].display_name or night.users["w2"].username
        ]

    def test_minion_is_shown_the_dealt_werewolves_not_the_thief(
        self, make_night
    ) -> None:
        night = make_night(
            {
                "d": "Doppelganger",
                "w": "Werewolf",
                "r": "Robber",
                "m": "Minion",
                "v": "Villager",
            }
        )
        self._steal_the_wolf_in_window_1(night, victim="w")

        night.post("m", "see_team")
        night.post("w", "see_team")
        night.post("r", "skip")

        shown = night.events_to("m", "action.result")[-1]
        assert shown["revealed_info"]["teammate_names"] == [
            night.users["w"].display_name or night.users["w"].username
        ]

    def test_the_seer_dealt_the_card_still_wakes_after_it_was_taken(
        self, make_night
    ) -> None:
        # Doppelganger-as-Robber takes the Seer's card in window 1.
        night = make_night(
            {"d": "Doppelganger", "s": "Seer", "r": "Robber", "v": "Villager"}
        )
        self._steal_the_wolf_in_window_1(night, victim="s")

        prompt = night.events_to("s", "action.prompt")[-1]
        assert prompt["role_acting_as"] == "Seer"
        assert (
            night.events_to("d", "action.prompt")[-1]["wave"] == 1
        )  # none in window 2


# ── Window 1 has a fixed length ──────────────────────────────────────────────


class TestFixedDoppelgangerWindow:
    """Window 1 lasts exactly night_doppelganger_window_seconds, whatever happens.

    Its length must not say whether the Doppelganger is in play, whether she
    copied anything, or whether she has a follow-up. One timer is scheduled when
    it opens and nothing moves it.
    """

    SECONDS = 10

    def _night(self, make_night, roles, center=None):
        return make_night(
            roles,
            center=center,
            night_doppelganger_window_seconds=self.SECONDS,
            night_wave_seconds=30,
            night_min_window_seconds=0,
        )

    def _assert_one_untouched_timer(self, night: Night, deadline) -> None:
        assert night.timer_delays(1) == [self.SECONDS]
        assert night.refresh().phase_deadline == deadline
        assert night.game.current_wave == 1

    def test_default_length_is_ten_seconds(self, make_night) -> None:
        night = make_night({"a": "Villager", "b": "Villager", "c": "Villager"})
        night.game.settings = {}

        assert services._fixed_window_seconds(night.game, 1) == 10
        assert services._fixed_window_seconds(night.game, 2) == 0

    def test_deadline_announced_at_the_start_is_the_real_close_time(
        self, make_night
    ) -> None:
        night = self._night(
            make_night,
            {"d": "Doppelganger", "s": "Seer", "v": "Villager"},
        )
        night.start()

        start = night.broadcasts("wave.start")[0]
        game = night.refresh()
        assert game.night_window_opened_at is not None
        expected = game.night_window_opened_at + timedelta(seconds=self.SECONDS)
        assert game.phase_deadline == expected
        assert start["deadline"] == expected.isoformat()
        assert night.timer_delays(1) == [self.SECONDS]

    def test_card_in_the_center_nobody_can_act_still_lasts_the_full_length(
        self, make_night
    ) -> None:
        night = self._night(
            make_night,
            {"a": "Villager", "b": "Seer", "c": "Werewolf"},
            center=["Doppelganger", "Robber", "Tanner"],
        )
        night.start()
        deadline = night.game.phase_deadline

        self._assert_one_untouched_timer(night, deadline)
        night.fire_timer(1)
        assert night.game.current_wave == 2

    def test_look_at_a_role_with_no_follow_up_does_not_close_it_early(
        self, make_night
    ) -> None:
        night = self._night(
            make_night,
            {"d": "Doppelganger", "v1": "Villager", "w": "Werewolf", "v2": "Villager"},
        )
        night.start()
        deadline = night.game.phase_deadline

        night.post("d", "peek_player", {"player_id": night.users["v1"].id})

        # The look is resolved and delivered at once ...
        assert len(night.events_to("d", "action.result")) == 1
        # ... but the window runs to its fixed length, like every other case.
        self._assert_one_untouched_timer(night, deadline)
        night.fire_timer(1)
        assert night.game.current_wave == 2

    def test_follow_up_neither_extends_nor_shortens_it(self, make_night) -> None:
        night = self._night(
            make_night,
            {"d": "Doppelganger", "s": "Seer", "w": "Werewolf", "v": "Villager"},
        )
        night.start()
        deadline = night.game.phase_deadline

        night.post("d", "peek_player", {"player_id": night.users["s"].id})
        # The follow-up prompt goes out at once, with no new timer or deadline.
        prompt = night.events_to("d", "action.prompt")[-1]
        assert prompt["role_acting_as"] == "Seer"
        self._assert_one_untouched_timer(night, deadline)

        night.post("d", "peek_player", {"player_id": night.users["w"].id})
        # Everything submitted: still no early close, and the follow-up's
        # result is held until the window closes.
        self._assert_one_untouched_timer(night, deadline)
        assert len(night.events_to("d", "action.result")) == 1

        night.fire_timer(1)

        assert night.game.current_wave == 2
        results = night.events_to("d", "action.result")
        assert [e["action_type"] for e in results] == ["peek_player", "peek_player"]
        assert results[1]["revealed_info"]["role"] == "werewolf"

    def test_follow_up_not_submitted_is_skipped_when_the_timer_fires(
        self, make_night
    ) -> None:
        night = self._night(
            make_night,
            {"d": "Doppelganger", "r": "Robber", "w": "Werewolf", "v": "Villager"},
        )
        night.start()
        night.post("d", "peek_player", {"player_id": night.users["r"].id})

        night.fire_timer(1)

        assert night.game.current_wave == 2
        assert night.role_of("d").current_role == "Doppelganger"  # nothing taken
        entries = [
            e
            for e in night.game.night_actions_log
            if e["player_id"] == night.users["d"].id
        ]
        assert [e["action_type"] for e in entries] == ["peek_player", "skip"]

    def test_look_not_submitted_is_skipped_when_the_timer_fires(
        self, make_night
    ) -> None:
        night = self._night(
            make_night, {"d": "Doppelganger", "s": "Seer", "v": "Villager"}
        )
        night.start()

        night.fire_timer(1)

        assert night.game.current_wave == 2
        assert "copied_role" not in night.role_of("d").night_action_data

    def test_host_may_still_close_it_immediately(self, make_night) -> None:
        night = self._night(
            make_night, {"d": "Doppelganger", "s": "Seer", "v": "Villager"}
        )
        night.start()

        assert night.host_close_window().status_code == status.HTTP_200_OK

        assert night.refresh().current_wave == 2

    def test_window_2_is_not_fixed_and_keeps_its_own_timer(self, make_night) -> None:
        night = self._night(
            make_night, {"d": "Doppelganger", "s": "Seer", "v": "Villager"}
        )
        night.start()
        night.fire_timer(1)

        assert night.timer_delays(2) == [30]  # night_wave_seconds, not the fixed length

    def test_zero_turns_the_fixed_length_off(self, make_night) -> None:
        # 0: window 1 closes like window 2, as soon as its actors are done
        # (no sooner than the minimum, no later than night_wave_seconds).
        night = make_night(
            {"d": "Doppelganger", "v1": "Villager", "v2": "Villager"},
            night_doppelganger_window_seconds=0,
            night_wave_seconds=30,
            night_min_window_seconds=0,
        )
        night.start()
        assert night.timer_delays(1) == [30]

        night.post("d", "peek_player", {"player_id": night.users["v1"].id})

        # Window 1 closed at once (window 2 then had nobody to wait for).
        assert [e["wave"] for e in night.broadcasts("wave.start")] == [1, 2]
        assert [e["wave"] for e in night.broadcasts("wave.complete")] == [1, 2]


# ── Side effects wait for the commit ─────────────────────────────────────────


class TestSideEffectsWaitForCommit:
    def test_nothing_is_sent_or_scheduled_until_the_transaction_commits(
        self, make_night, django_capture_on_commit_callbacks
    ) -> None:
        night = make_night({"s": "Seer", "r": "Robber", "v": "Villager"})

        with django_capture_on_commit_callbacks(execute=False) as callbacks:
            services.start_night_phase(night.game)

        # The window is open in the database, but nobody was told yet and no
        # timer exists.
        assert night.refresh().current_wave == 2
        assert night.recorder.events == []
        assert night.scheduled == []
        assert callbacks

        for callback in callbacks:  # the commit happens
            callback()

        assert [e["wave"] for e in night.broadcasts("wave.start")] == [2]
        assert [k for k, _, _ in night.scheduled] == [f"{night.game.id}:wave:2"]

    def test_closing_a_window_sends_results_only_after_the_commit(
        self, make_night, django_capture_on_commit_callbacks
    ) -> None:
        night = make_night({"s": "Seer", "r": "Robber", "v": "Villager"})
        night.start()
        night.post("s", "skip")
        sent_before = len(night.recorder.events)

        with django_capture_on_commit_callbacks(execute=False) as callbacks:
            services.advance_wave(night.game)

        assert night.refresh().phase == Phase.DISCUSSION
        assert len(night.recorder.events) == sent_before  # nothing yet
        for callback in callbacks:
            callback()
        types = [e["type"] for _, e in night.recorder.events[sent_before:]]
        assert types.index("action.result") < types.index("wave.complete")
        assert types.index("wave.complete") < types.index("phase.change")

    def test_a_failure_while_opening_the_next_window_changes_and_sends_nothing(
        self, make_night, django_capture_on_commit_callbacks
    ) -> None:
        night = make_night(
            {"d": "Doppelganger", "s": "Seer", "v": "Villager"},
            night_doppelganger_window_seconds=10,
        )
        night.start()
        events_before = len(night.recorder.events)
        scheduled_before = len(night.scheduled)

        with (
            patch("apps.onuw.timers.cancel") as cancel,
            patch(
                "apps.onuw.services.send_wave_prompts", side_effect=RuntimeError("boom")
            ),
            django_capture_on_commit_callbacks(execute=True) as callbacks,
            pytest.raises(RuntimeError),
            transaction.atomic(),
        ):
            services.advance_wave(night.game)

        # Rolled back: still window 1, no log, nothing sent, timer untouched.
        assert callbacks == []
        game = night.refresh()
        assert game.current_wave == 1
        assert game.night_actions_log == []
        assert len(night.recorder.events) == events_before
        assert len(night.scheduled) == scheduled_before
        cancel.assert_not_called()

    def test_failed_timer_callback_is_logged_and_the_night_is_left_as_it_was(
        self, make_night, caplog
    ) -> None:
        night = make_night({"s": "Seer", "r": "Robber", "v": "Villager"})
        night.start()
        callback = night.scheduled[-1][2]

        with (
            patch("apps.onuw.services.advance_wave", side_effect=RuntimeError("boom")),
            caplog.at_level(logging.ERROR, logger="apps.onuw.timers"),
        ):
            callback()  # must not raise inside the timer thread

        assert "Timer callback failed" in caplog.text
        assert "boom" in caplog.text
        game = night.refresh()
        assert (game.phase, game.current_wave) == (Phase.NIGHT, 2)

        # The host can still carry on.
        assert night.host_close_window().status_code == status.HTTP_200_OK
        assert night.refresh().phase == Phase.DISCUSSION


# ── Malformed input is a 400 ─────────────────────────────────────────────────

BAD_VALUES = [
    pytest.param("abc", id="word"),
    pytest.param("3", id="numeric-string"),
    pytest.param(None, id="null"),
    pytest.param(True, id="true"),
    pytest.param(False, id="false"),
    pytest.param(1.5, id="float"),
    pytest.param([0], id="list"),
    pytest.param([[0]], id="nested-list"),
    pytest.param({"a": 1}, id="object"),
]


class TestMalformedTargetsAreRejected:
    ROLES = {
        "seer": "Seer",
        "robber": "Robber",
        "trouble": "Troublemaker",
        "drunk": "Drunk",
        "wolf": "Werewolf",
        "villager": "Villager",
    }

    def _cases(self, night: Night, bad: Any) -> list[tuple[str, str, dict[str, Any]]]:
        good = night.users["villager"].id
        return [
            ("seer", "peek_player", {"player_id": bad}),
            ("seer", "peek_center", {"center_indices": [bad, 1]}),
            ("seer", "peek_center", {"center_indices": [0, bad]}),
            ("seer", "peek_center", {"center_indices": bad}),
            ("robber", "swap_with_player", {"player_id": bad}),
            ("trouble", "swap_others", {"player_ids": [bad, good]}),
            ("trouble", "swap_others", {"player_ids": [good, bad]}),
            ("trouble", "swap_others", {"player_ids": bad}),
            ("drunk", "swap_with_center", {"center_index": bad}),
            # null center_index just means "no peek": valid for a lone Werewolf.
            *([("wolf", "see_team", {"center_index": bad})] if bad is not None else []),
        ]

    @pytest.mark.parametrize("bad", BAD_VALUES)
    def test_wrong_typed_target_values_get_a_400_not_a_500(
        self, make_night, bad: Any
    ) -> None:
        night = make_night(self.ROLES)
        night.start()

        for who, action_type, targets in self._cases(night, bad):
            response = night.post(who, action_type, targets)
            assert response.status_code == status.HTTP_400_BAD_REQUEST, (
                who,
                action_type,
                targets,
                response.data,
            )
            assert not night.role_of(who).has_acted

        # Nothing was recorded, and the window still works afterwards.
        assert night.refresh().phase == Phase.NIGHT
        ok = night.post("seer", "peek_player", {"player_id": night.users["wolf"].id})
        assert ok.status_code == status.HTTP_200_OK

    def test_malformed_values_get_the_generic_message(self, make_night) -> None:
        night = make_night(self.ROLES)
        night.start()

        response = night.post("seer", "peek_player", {"player_id": "abc"})

        assert response.data["detail"] == [services.MALFORMED_TARGET]

    def test_malformed_look_target_is_rejected_for_the_doppelganger(
        self, make_night
    ) -> None:
        night = make_night({"d": "Doppelganger", "s": "Seer", "v": "Villager"})
        night.start()

        for bad in ("abc", None, True, [1], {"a": 1}):
            response = night.post("d", "peek_player", {"player_id": bad})
            assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert night.refresh().current_wave == 1
        assert not night.role_of("d").has_acted

    def test_non_object_targets_and_non_string_action_types_are_rejected(
        self, make_night
    ) -> None:
        night = make_night(self.ROLES)
        night.start()
        night.client.force_authenticate(user=night.users["seer"])
        url = reverse("onuw:night-action", kwargs={"game_id": str(night.game.id)})

        for payload in (
            {"action_type": "peek_player", "targets": [1]},
            {"action_type": "peek_player", "targets": "x"},
            {"action_type": ["peek_player"], "targets": {}},
            {"action_type": {"a": 1}, "targets": {}},
        ):
            with night.committed():
                response = night.client.post(url, payload, format="json")
            assert response.status_code == status.HTTP_400_BAD_REQUEST, payload


# ── Bad stored timer values cannot break a night ─────────────────────────────


class TestBadStoredTimerValues:
    @pytest.mark.parametrize("bad", ["abc", -5, 99999, None, True, 2.5, [3], {"a": 1}])
    def test_get_timer_seconds_falls_back_to_the_default(
        self, make_night, bad: Any
    ) -> None:
        night = make_night({"a": "Villager", "b": "Villager", "c": "Villager"})
        night.game.settings = {"night_wave_seconds": bad}

        assert services.get_timer_seconds(night.game, "night_wave_seconds", 30) == 30
        assert services.get_timer_seconds(night.game, "voting_seconds", 120) == 120

    def test_valid_values_are_used_and_a_non_object_row_falls_back(
        self, make_night
    ) -> None:
        night = make_night({"a": "Villager", "b": "Villager", "c": "Villager"})
        night.game.settings = {"night_wave_seconds": 0, "voting_seconds": 45}
        assert services.get_timer_seconds(night.game, "night_wave_seconds", 30) == 0
        assert services.get_timer_seconds(night.game, "voting_seconds", 120) == 45

        night.game.settings = ["not", "an", "object"]
        assert services.get_timer_seconds(night.game, "voting_seconds", 120) == 120

    def test_a_whole_night_runs_on_garbage_timer_settings(self, make_night) -> None:
        night = make_night(
            {"d": "Doppelganger", "s": "Seer", "v": "Villager"},
            night_wave_seconds="abc",
            night_min_window_seconds=-3,
            night_doppelganger_window_seconds=[1],
            discussion_seconds="soon",
        )
        night.start()

        assert night.timer_delays(1) == [10]  # default fixed length
        night.host_close_window()
        assert night.refresh().current_wave == 2
        assert night.timer_delays(2) == [30]  # default maximum
        night.host_close_window()

        assert night.refresh().phase == Phase.DISCUSSION
        assert night.timer_delays_for("discussion") == [300]
