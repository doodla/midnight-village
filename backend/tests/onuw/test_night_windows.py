"""
Service- and API-level tests for the two-window night.

Window 1 is the Doppelganger's. Window 2 asks every phone at once and resolves when
it closes. A phone with a choice sends one ``choose`` per window; a phone with nothing
to choose (its prompt's ``kind`` is ``none``) sends nothing and is not waited for
(``Night.post`` sends the choose whose picks mean a move, nothing for a phone with no
turn and no move; ``Night.rest_choose`` the empty choose of every phone whose turn is
still open). Covered here:

- window 2 opens with one group event and every phone has a prompt
- nothing is shown to a player before the window closes
- the Insomniac sees swaps made in the same window
- minimum window length (deferred close, close at the maximum, host override)
- windows are never skipped for lack of actors
- an empty choose changes nothing and is logged as a skip
- teams come from DEALT cards (a stolen Werewolf card does not move the wake-up)
- the fixed-length Doppelganger window
- side effects wait for the commit; garbage timer settings cannot break a night
"""

import functools
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

from apps.core import timers
from apps.core.lobbies import add_member
from apps.core.models import Lobby, User
from apps.core.wire import wire_time
from apps.onuw import (
    basics,
    choose_night,
    night_flow,
    night_results,
    night_window,
    turns,
)
from apps.onuw.models import Game, Phase, PlayerRole
from tests.onuw.stages import staged

pytestmark = pytest.mark.integration

# The events a night used to send to one player; nothing in a night is sent to one
# player now (each phone reads its prompt and results from GET /me/).
PER_PLAYER_NIGHT_EVENTS = {"action.prompt", "action.result", "wave.waiting"}


def picks_for(action_type: str, targets: dict[str, Any]) -> list[dict[str, Any]]:
    """The picks of the ``choose`` that means a night move, in the move's words:
    ``peek_player`` / ``swap_with_player`` one player, ``peek_center`` two centre
    cards, ``swap_others`` two players, ``swap_with_center`` one centre card,
    ``see_team`` (a lone Werewolf's centre look, if any); ``skip``, ``none`` and a
    plain ``see_team``: nothing."""
    if action_type in ("peek_player", "swap_with_player"):
        return [{"player_id": targets["player_id"]}]
    if action_type == "peek_center":
        return [{"center_index": i} for i in targets["center_indices"]]
    if action_type == "swap_others":
        return [{"player_id": p} for p in targets["player_ids"]]
    if action_type == "swap_with_center":
        return [{"center_index": targets["center_index"]}]
    if action_type == "see_team" and "center_index" in targets:
        return [{"center_index": targets["center_index"]}]
    assert action_type in ("skip", "none", "see_team"), action_type
    return []


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
        # Seat order (the order of ``roles``, the host first) is the REVERSE of
        # user-id order, so a list that comes back in user-id order is not mistaken
        # for one in seat order.
        created = {
            # Every player has a name of their own, and it is not their username: a
            # body that named anyone by username would show here.
            name: User.objects.create_user(
                username=f"nw_{name}", password="pass", display_name=f"Named {name}"
            )
            for name in reversed(list(roles))
        }
        self.users = {name: created[name] for name in roles}
        host = self.users[next(iter(roles))]
        lobby = Lobby.objects.create(
            host=host,
            game_type="onuw",
            max_players=10,
            settings={"roles": {}},
        )
        members = {}
        for user in self.users.values():
            members[user.id] = add_member(lobby, user.id)
        lobby.status = Lobby.Status.IN_GAME
        lobby.save()
        self.game = Game.objects.create(
            lobby=lobby,
            phase=Phase.NIGHT,
            random_seed=42,
            settings=settings,
            center_cards=center,
        )
        for seat, (name, role) in enumerate(roles.items()):
            user = self.users[name]
            PlayerRole.objects.create(
                game=self.game,
                user=user,
                original_role=role,
                current_role=role,
                seat=seat,
                token=members[user.id].token,
            )
        self.host = host
        self.client = APIClient()

    # -- driving the game ---------------------------------------------------

    def committed(self) -> Any:
        """Run the block, then run its on-commit callbacks (a real commit)."""
        return self._capture_on_commit(execute=True)

    def start(self) -> None:
        with self.committed():
            night_flow.start_night_phase(self.game)
        self.game.refresh_from_db()

    def chosen(self, name: str) -> int:
        """How many chooses ``name``'s phone has sent in the open window (its
        prompt's ``chosen``)."""
        game = Game.objects.get(id=self.game.id)
        pr = PlayerRole.objects.get(game=game, user=self.users[name])
        return turns.chose_count(pr, game.current_wave)

    def choose(self, name: str, picks: list[dict[str, Any]] | None = None) -> Any:
        """``name``'s phone sends its ``choose`` for the open window, naming the
        stage and answering the prompt as ``GET /me/`` shows them now."""
        self.client.force_authenticate(user=self.users[name])
        url = reverse("onuw:night-action", kwargs={"game_id": str(self.game.id)})
        body = {
            "action_type": "choose",
            "picks": picks or [],
            "chosen": self.chosen(name),
        }
        with self.committed():
            return self.client.post(url, staged(self, body), format="json")

    def turn_open(self, name: str) -> bool:
        """``name``'s phone still has a choose to send (its prompt's
        ``chooses_left`` is above 0; never for a phone with nothing to choose)."""
        game = Game.objects.get(id=self.game.id)
        pr = PlayerRole.objects.get(game=game, user=self.users[name])
        return turns.turn_open(basics.build_game_state(game), pr, game.current_wave)

    def post(
        self, name: str, action_type: str, targets: dict[str, Any] | None = None
    ) -> Any:
        """``name`` makes a night move: the choose whose picks mean it
        (``picks_for``). A phone with nothing to choose sends nothing for a move of
        no picks, as the app's phone does (returns None)."""
        picks = picks_for(action_type, targets or {})
        if not picks and not self.turn_open(name):
            return None
        return self.choose(name, picks)

    def rest_choose(self) -> None:
        """Every phone whose turn is still open in the open window chooses nothing
        (a phone with nothing to choose sends nothing)."""
        for name in self.users:
            if self.refresh().phase != Phase.NIGHT:
                return
            if self.turn_open(name):
                self.choose(name)

    def host_close_window(self) -> Any:
        self.client.force_authenticate(user=self.host)
        url = reverse("onuw:wave-advance", kwargs={"game_id": str(self.game.id)})
        with self.committed():
            return self.client.post(url, staged(self, {}), format="json")

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

    def me(self, name: str) -> dict[str, Any]:
        """``GET /me/`` as ``name``."""
        self.client.force_authenticate(user=self.users[name])
        response = self.client.get(
            reverse("onuw:game-me", kwargs={"game_id": str(self.game.id)})
        )
        assert response.status_code == status.HTTP_200_OK
        return response.data

    def prompt(self, name: str) -> dict[str, Any] | None:
        """``name``'s ``action_prompt``, as ``GET /me/`` builds it (read without the
        request, whose timer repair would add to the timers a test counts)."""
        return choose_night.prompt_for(self.refresh(), self.role_of(name))

    def results(self, name: str) -> list[dict[str, Any]]:
        """``name``'s own ``night_results``, as ``GET /me/`` builds them."""
        game = self.refresh()
        names = {
            pr.user_id: pr.user.display_name or pr.user.username
            for pr in game.player_roles.select_related("user")
        }
        return night_results.night_results_for_player(
            game, self.users[name].id, names, self.role_of(name).night_action_data
        )

    def display_name(self, name: str) -> str:
        user = self.users[name]
        return user.display_name or user.username

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

    def windows_opened(self) -> list[int]:
        return [e["window"] for e in self.broadcasts("night.window")]


@pytest.fixture
def make_night(db, django_capture_on_commit_callbacks):
    """Factory for a Night; channel layer and timers are recorded, not run."""
    recorder = _Recorder()
    scheduled: list[tuple[str, float, Any]] = []

    def fake_schedule(key, delay, job, params=None):
        # Record the timer; calling the callback runs the job as a firing would.
        scheduled.append(
            (key, delay, functools.partial(timers.run_job_quietly, job, params))
        )

    mock_layer = type("Layer", (), {"group_send": recorder.group_send})()
    with (
        patch("apps.core.effects.get_channel_layer", return_value=mock_layer),
        patch("apps.core.effects.async_to_sync", side_effect=lambda f: f),
        patch("apps.core.timers.schedule", side_effect=fake_schedule),
    ):

        def factory(
            roles: dict[str, str],
            center: list[str] | None = None,
            **settings: Any,
        ) -> Night:
            # Defaults: no minimum length and no fixed Doppelganger window, so
            # windows close as soon as every phone with a choice has chosen. Tests of those
            # rules set them explicitly.
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


# ── Window 2: everyone is asked together ─────────────────────────────────────


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

    def test_window_2_opens_once_for_everyone_and_every_phone_has_a_prompt(
        self, make_night
    ) -> None:
        night = make_night(self.ROLES, night_min_window_seconds=8)
        night.start()

        assert night.game.current_wave == 2
        assert night.windows_opened() == [2]
        kinds = {name: night.prompt(name)["kind"] for name in self.ROLES}
        assert kinds == {
            "wolf": "lone_werewolf",
            "minion": "none",
            "mason_a": "none",
            "mason_b": "none",
            "seer": "seer",
            "robber": "robber",
            "trouble": "troublemaker",
            "drunk": "drunk",
            "insomniac": "none",
            "villager": "none",
        }
        assert {night.prompt(n)["window"] for n in self.ROLES} == {2}
        assert not PER_PLAYER_NIGHT_EVENTS & set(night.all_event_types())

    def test_window_2_stays_open_until_every_phone_with_a_choice_has_chosen(
        self, make_night
    ) -> None:
        night = make_night(
            {"a": "Seer", "b": "Robber", "c": "Villager", "d": "Villager"}
        )
        night.start()

        # A sleeper's choose is still taken, and holds nothing open.
        for name in ("a", "c"):
            assert night.choose(name).status_code == status.HTTP_200_OK
            assert night.refresh().phase == Phase.NIGHT
            assert night.game.current_wave == 2

        # The last phone with a choice closes it; "d" never sent anything.
        assert night.choose("b").status_code == status.HTTP_200_OK
        assert night.refresh().phase == Phase.DISCUSSION
        assert night.chosen("d") == 0

    def test_a_window_never_waits_for_a_phone_with_nothing_to_choose(
        self, make_night
    ) -> None:
        night = make_night(
            {"seer": "Seer", "w1": "Werewolf", "w2": "Werewolf", "v": "Villager"},
            night_wave_seconds=60,
        )
        night.start()
        assert {n: night.prompt(n)["chooses_left"] for n in night.users} == {
            "seer": 1,
            "w1": 0,
            "w2": 0,
            "v": 0,
        }

        night.post("seer", "peek_player", {"player_id": night.users["v"].id})

        assert night.refresh().phase == Phase.DISCUSSION
        for name in ("w1", "w2", "v"):
            assert night.chosen(name) == 0, name
        # Their automatic results still happen.
        assert night.results("w1")[-1]["revealed_info"]["teammate_names"] == [
            night.display_name("w2")
        ]


# ── Nothing is shown before the window closes ────────────────────────────────


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

    def test_no_result_is_shown_or_stored_while_someone_is_still_choosing(
        self, make_night
    ) -> None:
        night = make_night(self._roles())
        night.start()

        night.post("wolf_a", "see_team")
        night.post("wolf_b", "see_team")
        night.post("seer", "peek_player", {"player_id": night.users["robber"].id})
        night.post("insomniac", "none")
        night.post("villager", "none")

        # The Robber has not chosen: the window is open, nothing was shown.
        assert night.refresh().phase == Phase.NIGHT
        for name in ("wolf_a", "wolf_b", "seer", "insomniac"):
            assert night.results(name) == [], name
            assert "wave_2_result" not in night.role_of(name).night_action_data
        assert night.refresh().night_actions_log == []

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
        night.post("villager", "none")
        night.post(
            "robber", "swap_with_player", {"player_id": night.users["wolf_a"].id}
        )

        for name in ("wolf_a", "wolf_b", "seer", "robber", "insomniac"):
            assert len(night.results(name)) == 1, name
        assert night.results("villager") == []

        # Each result belongs to window 2 and stays private to its player.
        seer = night.results("seer")[0]
        assert seer["wave"] == 2
        assert seer["revealed_info"]["role"] == "Robber"  # before the Robber moved
        robber = night.results("robber")[0]
        assert robber["revealed_info"]["new_role"] == "Werewolf"

        # The table is told only that the day began; nothing went to one player.
        assert [e["phase"] for e in night.broadcasts("phase.change")] == ["discussion"]
        assert not PER_PLAYER_NIGHT_EVENTS & set(night.all_event_types())

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
        night.post("villager", "none")
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

        # The Insomniac chooses FIRST; the swaps still count.
        night.post("insomniac", "none")
        night.post(
            "trouble", "swap_others", {"player_ids": [ids["insomniac"], ids["wolf"]]}
        )
        night.post("wolf", "see_team")
        night.post("villager", "none")
        night.post("robber", "swap_with_player", {"player_id": ids["insomniac"]})

        # Robber took the Insomniac card, then the Troublemaker swapped the
        # Insomniac's seat with the Werewolf's.
        result = night.results("insomniac")[0]
        assert result["action_type"] == "insomniac"
        assert result["revealed_info"] == {"current_role": "Werewolf"}
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

        assert 7 < night_window._min_close_delay(night.game) <= 8

    def test_close_is_deferred_when_everyone_chooses_early(self, make_night) -> None:
        night = make_night(
            self.ROLES, night_min_window_seconds=8, night_wave_seconds=30
        )
        night.start()
        assert night.timer_delays(2) == [30]  # the maximum, set when it opened

        night.post("wolf", "see_team")
        night.post("seer", "skip")
        night.rest_choose()

        # Everyone is done, but the window is not allowed to close yet.
        assert night.refresh().phase == Phase.NIGHT
        assert night.game.current_wave == 2
        assert night.results("wolf") == []
        deferred = night.timer_delays(2)[-1]
        assert 0 < deferred <= 8

        # When the minimum is reached the close fires and the results are there.
        night.fire_timer(2)
        assert night.game.phase == Phase.DISCUSSION
        assert len(night.results("wolf")) == 1
        assert len(night.results("seer")) == 1

    def test_a_window_that_is_already_old_enough_closes_at_once(
        self, make_night
    ) -> None:
        night = make_night(self.ROLES, night_min_window_seconds=8)
        night.start()
        night.pretend_window_opened(seconds_ago=9)

        night.post("wolf", "see_team")
        night.post("seer", "skip")
        night.rest_choose()

        assert night.refresh().phase == Phase.DISCUSSION

    def test_window_closes_at_the_maximum_when_someone_never_chooses(
        self, make_night
    ) -> None:
        night = make_night(
            self.ROLES, night_min_window_seconds=8, night_wave_seconds=30
        )
        night.start()
        for name in ("wolf", "v1", "v2"):  # the Seer never chooses
            night.choose(name)

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
        night.rest_choose()

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
        assert night.windows_opened() == [1]
        for name in ("a", "b", "c"):
            assert night.prompt(name)["kind"] == "none"

        # Nobody can act: it still lasts its minimum length.
        night.rest_choose()
        assert night.refresh().phase == Phase.NIGHT
        assert 0 < night.timer_delays(1)[-1] <= 8
        night.fire_timer(1)
        assert night.game.current_wave == 2
        assert night.windows_opened() == [1, 2]

    def test_window_1_does_not_run_when_the_doppelganger_is_not_in_the_deck(
        self, make_night
    ) -> None:
        night = make_night({"a": "Villager", "b": "Seer", "c": "Werewolf"})
        night.start()

        assert night.game.current_wave == 2
        assert night.windows_opened() == [2]

    def test_empty_window_1_passes_to_window_2_at_once(self, make_night) -> None:
        # Nobody has anything to choose in window 1 (with no fixed length).
        night = make_night(
            {"a": "Villager", "b": "Seer", "c": "Werewolf"},
            center=["Doppelganger", "Robber", "Tanner"],
        )
        night.start()

        assert night.windows_opened() == [1, 2]
        assert night.refresh().current_wave == 2

    def test_an_all_villager_table_still_gets_window_2(self, make_night) -> None:
        night = make_night(
            {"a": "Villager", "b": "Villager", "c": "Villager"},
            night_min_window_seconds=8,
        )
        night.start()

        assert night.game.phase == Phase.NIGHT
        assert night.game.current_wave == 2
        assert {night.prompt(n)["kind"] for n in ("a", "b", "c")} == {"none"}

        # Nobody has a choice, so it lasts its minimum length once all chose.
        night.rest_choose()
        assert 0 < night.timer_delays(2)[-1] <= 8
        night.fire_timer(2)
        assert night.game.phase == Phase.DISCUSSION

    def test_an_all_villager_table_with_no_minimum_goes_to_the_day_at_once(
        self, make_night
    ) -> None:
        night = make_night({"a": "Villager", "b": "Villager", "c": "Villager"})
        night.start()

        assert night.refresh().phase == Phase.DISCUSSION
        assert night.windows_opened() == [2]

    def test_current_wave_is_zero_outside_the_night(self, make_night) -> None:
        night = make_night({"a": "Villager", "b": "Villager", "c": "Villager"})
        night.start()
        night.rest_choose()

        assert night.refresh().current_wave == 0
        # The open time now belongs to the talk (``/me/`` ``stage_started_at``),
        # set when the talk opened: no night window's is left behind.
        assert night.game.phase == Phase.DISCUSSION
        assert night.game.night_window_opened_at is not None
        assert night.game.phase_deadline == night.game.night_window_opened_at + (
            timedelta(seconds=300)
        )


# ── Choosing nothing ─────────────────────────────────────────────────────────


class TestChoosingNothing:
    ROLES = {
        "seer": "Seer",
        "robber": "Robber",
        "trouble": "Troublemaker",
        "drunk": "Drunk",
        "wolf": "Werewolf",
        "insomniac": "Insomniac",
        "villager": "Villager",
    }

    def test_choosing_nothing_changes_nothing_and_is_logged_as_a_skip(
        self, make_night
    ) -> None:
        night = make_night(self.ROLES)
        night.start()
        # (The Drunk is left out: one who keeps their card is swapped by the server.)
        others = [n for n in self.ROLES if n != "drunk"]
        before = {n: night.role_of(n).current_role for n in others}
        for who in ("seer", "robber", "trouble"):
            night.choose(who)
        night.host_close_window()

        assert {n: night.role_of(n).current_role for n in others} == before
        night.refresh()
        skippers = {night.users[n].id for n in ("seer", "robber", "trouble")}
        skips = [
            e
            for e in night.game.night_actions_log
            if e["action_type"] == "skip" and e["player_id"] in skippers
        ]
        assert len(skips) == 3
        # The phone is told its choice did nothing; nobody else is told anything.
        assert night.results("seer") == [
            {
                "wave": 2,
                "action_type": "skip",
                "revealed_info": {"nothing_chosen": True},
            }
        ]
        assert night.results("villager") == []

    @pytest.mark.parametrize("copied", ["Seer", "Robber", "Troublemaker"])
    def test_a_doppelganger_may_choose_nothing_for_the_follow_up(
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
        follow_up = night.prompt("d")
        assert follow_up["role_acting_as"] == copied
        assert follow_up["chooses_left"] == 1

        response = night.choose("d")

        assert response.status_code == status.HTTP_200_OK
        assert night.refresh().current_wave == 2  # window 1 closed, window 2 opened
        assert night.role_of("d").current_role == "Doppelganger"


# ── Window 1: the Doppelganger ───────────────────────────────────────────────


class TestDoppelgangerWindow:
    def test_the_look_is_shown_at_once_but_the_follow_up_waits_for_the_close(
        self, make_night
    ) -> None:
        night = make_night(
            {"d": "Doppelganger", "r": "Robber", "w": "Werewolf", "v": "Villager"},
            night_min_window_seconds=8,
        )
        night.start()

        night.post("d", "peek_player", {"player_id": night.users["r"].id})
        looks = night.results("d")
        assert [e["revealed_info"]["copied_role"] for e in looks] == ["Robber"]
        assert night.windows_opened() == [1]  # nobody learns she copied

        night.post("d", "swap_with_player", {"player_id": night.users["w"].id})
        night.rest_choose()

        # Everything is chosen; the window waits out its minimum.
        assert night.refresh().current_wave == 1
        assert len(night.results("d")) == 1
        assert night.role_of("d").current_role == "Doppelganger"  # not applied yet

        night.fire_timer(1)

        assert night.game.current_wave == 2
        assert night.role_of("d").current_role == "Werewolf"
        assert night.role_of("w").current_role == "Doppelganger"
        results = night.results("d")
        assert [e["action_type"] for e in results] == [
            "peek_player",
            "swap_with_player",
        ]
        assert results[1]["revealed_info"]["new_role"] == "Werewolf"
        assert night.windows_opened() == [1, 2]

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
        # Nobody has anything to choose after her look: each window lasts the
        # table's minimum.
        night = make_night(
            {"d": "Doppelganger", "w1": "Werewolf", "w2": "Werewolf", "v": "Villager"},
            night_min_window_seconds=5,
        )
        night.start()
        night.post("d", "peek_player", {"player_id": night.users["w1"].id})
        night.fire_timer(1)

        assert night.refresh().current_wave == 2
        prompt = night.prompt("d")
        assert prompt["role_acting_as"] == "Werewolf"
        assert prompt["window"] == 2

        night.fire_timer(2)

        assert night.refresh().phase == Phase.DISCUSSION
        result = night.results("d")[-1]
        assert set(result["revealed_info"]["teammate_names"]) == {
            night.display_name("w1"),
            night.display_name("w2"),
        }
        # At most one result in window 2 (plus the look from window 1).
        assert [e["wave"] for e in night.results("d")] == [1, 2]


# ── Teams come from DEALT cards ──────────────────────────────────────────────


class TestDealtCardsDecideWhoWakes:
    def _steal_in_window_1(self, night: Night, victim: str) -> None:
        """The Doppelganger copies the Robber, then robs `victim` in window 1."""
        night.start()
        night.post("d", "peek_player", {"player_id": night.users["r"].id})
        night.post("d", "swap_with_player", {"player_id": night.users[victim].id})
        assert night.refresh().current_wave == 2  # her follow-up closed window 1

    def test_dealt_werewolf_whose_card_was_stolen_still_wakes_and_is_lone(
        self, make_night
    ) -> None:
        night = make_night(
            {"d": "Doppelganger", "w": "Werewolf", "r": "Robber", "v": "Villager"},
            center=["Seer", "Villager", "Tanner"],
        )
        self._steal_in_window_1(night, victim="w")
        assert night.role_of("d").current_role == "Werewolf"  # the thief holds it
        assert night.role_of("w").current_role == "Doppelganger"

        # The victim is asked as the lone Werewolf; the thief has nothing to do:
        # she woke (and acted) as the Robber.
        assert night.prompt("w")["kind"] == "lone_werewolf"
        assert night.prompt("w")["role_acting_as"] == "Werewolf"
        assert night.prompt("d")["kind"] == "none"
        assert sorted(night_window.get_wave_actors(night.game, 2)) == sorted(
            [night.users["w"].id, night.users["r"].id]
        )

        # So the victim may look at a centre card; the thief's picks mean nothing.
        night.choose("d", [{"center_index": 1}])
        night.post("w", "see_team", {"center_index": 0})
        night.post("r", "skip")
        night.rest_choose()

        result = night.results("w")[-1]
        assert result["revealed_info"]["teammate_names"] == []
        assert result["revealed_info"]["center_card"] == {"index": 0, "role": "Seer"}
        assert [e["wave"] for e in night.results("d")] == [1, 1]

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
        self._steal_in_window_1(night, victim="w2")

        # w2's card moved, but w2 still wakes: w1 is in a pack and its centre pick
        # means nothing.
        assert night.prompt("w1")["kind"] == "none"
        night.choose("w1", [{"center_index": 0}])
        night.post("r", "skip")
        night.rest_choose()

        # The thief (holding a Werewolf card) is NOT shown to them.
        seen = night.results("w1")[-1]
        assert seen["revealed_info"]["teammate_names"] == [night.display_name("w2")]
        assert "center_card" not in seen["revealed_info"]

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
        self._steal_in_window_1(night, victim="w")

        night.post("r", "skip")
        night.rest_choose()

        shown = night.results("m")[-1]
        assert shown["revealed_info"]["teammate_names"] == [night.display_name("w")]

    def test_the_seer_dealt_the_card_still_wakes_after_it_was_taken(
        self, make_night
    ) -> None:
        # Doppelganger-as-Robber takes the Seer's card in window 1.
        night = make_night(
            {"d": "Doppelganger", "s": "Seer", "r": "Robber", "v": "Villager"}
        )
        self._steal_in_window_1(night, victim="s")

        assert night.prompt("s")["kind"] == "seer"
        assert night.prompt("s")["role_acting_as"] == "Seer"
        assert night.prompt("d")["kind"] == "none"  # nothing for her in window 2


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

        assert night_window._fixed_window_seconds(night.game, 1) == 10
        assert night_window._fixed_window_seconds(night.game, 2) == 0

    def test_deadline_announced_at_the_start_is_the_real_close_time(
        self, make_night
    ) -> None:
        night = self._night(
            make_night,
            {"d": "Doppelganger", "s": "Seer", "v": "Villager"},
        )
        night.start()

        opened = night.broadcasts("night.window")[0]
        game = night.refresh()
        assert game.night_window_opened_at is not None
        expected = game.night_window_opened_at + timedelta(seconds=self.SECONDS)
        assert game.phase_deadline == expected
        assert opened["deadline"] == wire_time(expected)
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
        night.rest_choose()

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
        night.rest_choose()

        # The look is resolved and shown to her at once ...
        assert len(night.results("d")) == 1
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
        # Her follow-up is armed at once, with no new timer or deadline.
        prompt = night.prompt("d")
        assert prompt["role_acting_as"] == "Seer"
        assert prompt["chooses_left"] == 1
        self._assert_one_untouched_timer(night, deadline)

        night.post("d", "peek_player", {"player_id": night.users["w"].id})
        night.rest_choose()
        # Everything chosen: still no early close, and the follow-up's result is
        # held until the window closes.
        self._assert_one_untouched_timer(night, deadline)
        assert len(night.results("d")) == 1

        night.fire_timer(1)

        assert night.game.current_wave == 2
        results = night.results("d")
        assert [e["action_type"] for e in results] == ["peek_player", "peek_player"]
        assert results[1]["revealed_info"]["role"] == "Werewolf"

    def test_follow_up_not_chosen_is_skipped_when_the_timer_fires(
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

    def test_look_not_chosen_is_skipped_when_the_timer_fires(self, make_night) -> None:
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
        # 0: window 1 closes like window 2, as soon as every phone with a choice
        # has chosen (no sooner than the minimum, no later than night_wave_seconds).
        night = make_night(
            {"d": "Doppelganger", "v1": "Villager", "v2": "Villager", "s": "Seer"},
            night_doppelganger_window_seconds=0,
            night_wave_seconds=30,
            night_min_window_seconds=0,
        )
        night.start()
        assert night.timer_delays(1) == [30]

        # Her look is the only choice of window 1 (a Villager copy has no
        # follow-up): it closes at once.
        night.post("d", "peek_player", {"player_id": night.users["v1"].id})

        assert night.refresh().current_wave == 2
        night.rest_choose()
        assert night.windows_opened() == [1, 2]
        assert night.refresh().phase == Phase.DISCUSSION


# ── Side effects wait for the commit ─────────────────────────────────────────


class TestSideEffectsWaitForCommit:
    def test_nothing_is_sent_or_scheduled_until_the_transaction_commits(
        self, make_night, django_capture_on_commit_callbacks
    ) -> None:
        night = make_night({"s": "Seer", "r": "Robber", "v": "Villager"})

        with django_capture_on_commit_callbacks(execute=False) as callbacks:
            night_flow.start_night_phase(night.game)

        # The window is open in the database, but nobody was told yet and no
        # timer exists.
        assert night.refresh().current_wave == 2
        assert night.recorder.events == []
        assert night.scheduled == []
        assert callbacks

        for callback in callbacks:  # the commit happens
            callback()

        assert night.windows_opened() == [2]
        assert [k for k, _, _ in night.scheduled] == [f"{night.game.id}:wave:2"]

    def test_closing_a_window_tells_the_table_only_after_the_commit(
        self, make_night, django_capture_on_commit_callbacks
    ) -> None:
        night = make_night({"s": "Seer", "r": "Robber", "v": "Villager"})
        night.start()
        night.post("s", "skip")
        sent_before = len(night.recorder.events)

        with django_capture_on_commit_callbacks(execute=False) as callbacks:
            night_flow.advance_wave(night.game)

        assert night.refresh().phase == Phase.DISCUSSION
        assert len(night.recorder.events) == sent_before  # nothing yet
        for callback in callbacks:
            callback()
        types = [e["type"] for _, e in night.recorder.events[sent_before:]]
        assert "phase.change" in types
        assert not PER_PLAYER_NIGHT_EVENTS & set(types)

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
            patch("apps.core.timers.cancel") as cancel,
            patch(
                "apps.onuw.night_window.send_wave_prompts",
                side_effect=RuntimeError("boom"),
            ),
            django_capture_on_commit_callbacks(execute=True) as callbacks,
            pytest.raises(RuntimeError),
            transaction.atomic(),
        ):
            night_flow.advance_wave(night.game)

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
            patch(
                "apps.onuw.night_flow.advance_wave", side_effect=RuntimeError("boom")
            ),
            caplog.at_level(logging.ERROR, logger="apps.core.timers"),
        ):
            callback()  # must not raise inside the timer thread

        assert "Timer callback failed" in caplog.text
        assert "boom" in caplog.text
        game = night.refresh()
        assert (game.phase, game.current_wave) == (Phase.NIGHT, 2)

        # The host can still carry on.
        assert night.host_close_window().status_code == status.HTTP_200_OK
        assert night.refresh().phase == Phase.DISCUSSION


# ── Bad stored timer values cannot break a night ─────────────────────────────


class TestBadStoredTimerValues:
    @pytest.mark.parametrize("bad", ["abc", -5, 99999, None, True, 2.5, [3], {"a": 1}])
    def test_get_timer_seconds_falls_back_to_the_default(
        self, make_night, bad: Any
    ) -> None:
        night = make_night({"a": "Villager", "b": "Villager", "c": "Villager"})
        night.game.settings = {"night_wave_seconds": bad}

        assert basics.get_timer_seconds(night.game, "night_wave_seconds", 30) == 30
        assert basics.get_timer_seconds(night.game, "voting_seconds", 120) == 120

    def test_valid_values_are_used_and_a_non_object_row_falls_back(
        self, make_night
    ) -> None:
        night = make_night({"a": "Villager", "b": "Villager", "c": "Villager"})
        night.game.settings = {"night_wave_seconds": 0, "voting_seconds": 45}
        assert basics.get_timer_seconds(night.game, "night_wave_seconds", 30) == 0
        assert basics.get_timer_seconds(night.game, "voting_seconds", 120) == 45

        night.game.settings = ["not", "an", "object"]
        assert basics.get_timer_seconds(night.game, "voting_seconds", 120) == 120

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
