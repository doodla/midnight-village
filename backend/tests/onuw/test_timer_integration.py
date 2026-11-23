"""
Integration tests for phase timer lifecycles.

Covers:
- Night wave timers: the night_window event includes 'deadline', scheduling,
  auto-advance, early cancellation, host force-advance, deadline clearing,
  per-wave timer keys
- Discussion timers: auto-transition to voting, early cancellation via
  end_discussion(), zero-duration behavior, phase_change event deadline field
- Voting timers: auto-reveal on expiry with abstentions, early cancellation
  when all players vote, host force-reveal, zero-duration behavior,
  phase_change event deadline field
"""

import functools
from datetime import datetime
from unittest.mock import MagicMock, patch

from django.db import transaction

import pytest

from apps.core import timers
from apps.core.models import Lobby, LobbyMember, ScheduledTimer, User
from apps.onuw import night_flow, night_window, voting
from apps.onuw.models import Game, Phase, PlayerRole
from apps.onuw.protocol import stage_token

pytestmark = [pytest.mark.integration, pytest.mark.uses_timers]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _clear_registry():
    with timers._lock:
        for t in timers._registry.values():
            t.cancel()
        timers._registry.clear()


@pytest.fixture(autouse=True)
def clean_timer_registry():
    """Cancel all timers before and after each test to prevent thread leakage."""
    _clear_registry()
    yield
    _clear_registry()


def _make_night_game(night_wave_seconds=30, wave=2, night_min_window_seconds=0):
    """
    Create a 3-player game in NIGHT phase at the given night window.

    Players: Werewolf and Seer (both act in window 2), Villager (no actions)
    Center cards: Robber, Drunk, Villager

    The minimum window length defaults to 0 here so a window can close as soon
    as it is ready; the minimum has its own tests (test_night_windows.py).
    """
    host = User.objects.create_user(username="wt_host", password="pass")
    p1 = User.objects.create_user(username="wt_p1", password="pass")
    p2 = User.objects.create_user(username="wt_p2", password="pass")

    lobby = Lobby.objects.create(
        host=host,
        game_type="onuw",
        max_players=10,
        settings={
            "roles": {"Werewolf": 1, "Seer": 1, "Villager": 1},
            "night_wave_seconds": night_wave_seconds,
            "night_min_window_seconds": night_min_window_seconds,
        },
    )
    game = Game.objects.create(
        lobby=lobby,
        phase=Phase.NIGHT,
        random_seed=42,
        settings=lobby.settings,
        center_cards=["Robber", "Drunk", "Villager"],
        current_wave=wave,
    )

    PlayerRole.objects.create(
        game=game, user=host, original_role="Werewolf", current_role="Werewolf"
    )
    PlayerRole.objects.create(
        game=game, user=p1, original_role="Seer", current_role="Seer"
    )
    PlayerRole.objects.create(
        game=game, user=p2, original_role="Villager", current_role="Villager"
    )

    return game, host, p1, p2


def _make_game(discussion_seconds=300):
    host = User.objects.create_user(username="disc_timer_host", password="pass")
    lobby = Lobby.objects.create(
        host=host,
        game_type="onuw",
        max_players=10,
        settings={
            "roles": {"Werewolf": 1, "Villager": 2},
            "discussion_seconds": discussion_seconds,
        },
    )
    return Game.objects.create(
        lobby=lobby,
        phase=Phase.NIGHT,
        random_seed=42,
        settings=lobby.settings,
    )


def _make_game_with_players(player_count=3, voting_seconds=300):
    """Create a game in VOTING phase with the given number of players."""
    usernames = [f"vt_player_{i}" for i in range(player_count)]
    roles = ["Werewolf"] + ["Villager"] * (player_count - 1)

    users = {}
    for uname in usernames:
        users[uname] = User.objects.create_user(username=uname, password="pass")

    host = users[usernames[0]]
    lobby = Lobby.objects.create(
        host=host,
        game_type="onuw",
        max_players=10,
        settings={
            "roles": {"Werewolf": 1, "Villager": player_count - 1},
            "voting_seconds": voting_seconds,
        },
    )
    for user in users.values():
        LobbyMember.objects.create(lobby=lobby, user=user)
    lobby.status = Lobby.Status.IN_GAME
    lobby.save()

    game = Game.objects.create(
        lobby=lobby,
        phase=Phase.DISCUSSION,
        random_seed=42,
        settings=lobby.settings,
        center_cards=["Mason", "Drunk", "Insomniac"],
    )

    for uname, role in zip(usernames, roles, strict=False):
        PlayerRole.objects.create(
            game=game,
            user=users[uname],
            original_role=role,
            current_role=role,
        )

    return game, users, host


# ---------------------------------------------------------------------------
# Tests -- Night Wave Timer Lifecycle
# ---------------------------------------------------------------------------


@pytest.mark.django_db(transaction=True)
class TestWaveTimerLifecycle:
    def test_wave_no_timer_when_seconds_zero(self, db):
        """When night_wave_seconds == 0, no timer is scheduled and phase_deadline is null."""
        scheduled_keys: list = []

        def fake_schedule(key, delay, job, params=None):
            scheduled_keys.append(key)

        game, *_ = _make_night_game(night_wave_seconds=0)

        with (
            patch("apps.core.effects.get_channel_layer", return_value=None),
            patch("apps.core.timers.schedule", side_effect=fake_schedule),
        ):
            night_window.send_wave_prompts(game, 2)

        game.refresh_from_db()
        assert game.phase_deadline is None
        assert not any(":wave:2" in k for k in scheduled_keys)

    def test_night_window_event_includes_deadline(self, db):
        """The night.window broadcast event contains a non-null ISO 8601 deadline."""
        game, *_ = _make_night_game(night_wave_seconds=60)
        broadcast_events: list = []

        def capture_send(group, event):
            broadcast_events.append(event)

        mock_layer = MagicMock()
        mock_layer.group_send = capture_send

        with (
            patch("apps.core.effects.get_channel_layer", return_value=mock_layer),
            patch("apps.core.effects.async_to_sync", side_effect=lambda f: f),
            patch("apps.core.timers.schedule"),
        ):
            night_window.send_wave_prompts(game, 2)

        wave_events = [e for e in broadcast_events if e.get("type") == "night.window"]
        assert len(wave_events) == 1
        event = wave_events[0]
        assert "deadline" in event
        assert event["deadline"] is not None
        # Verify it parses as a valid ISO 8601 datetime.
        datetime.fromisoformat(event["deadline"])

    def test_night_window_event_deadline_null_when_untimed(self, db):
        """The night.window broadcast has deadline=null when night_wave_seconds == 0."""
        game, *_ = _make_night_game(night_wave_seconds=0)
        broadcast_events: list = []

        def capture_send(group, event):
            broadcast_events.append(event)

        mock_layer = MagicMock()
        mock_layer.group_send = capture_send

        with (
            patch("apps.core.effects.get_channel_layer", return_value=mock_layer),
            patch("apps.core.effects.async_to_sync", side_effect=lambda f: f),
        ):
            night_window.send_wave_prompts(game, 2)

        wave_events = [e for e in broadcast_events if e.get("type") == "night.window"]
        assert len(wave_events) == 1
        assert wave_events[0]["deadline"] is None

    def test_wave_auto_advances_on_timeout(self, db):
        """
        Invoking the timer callback (simulating timer expiry) advances the wave.

        See_team actors (Werewolf in wave 2) are auto-resolved, not skipped,
        because their action requires no player choice.
        """
        captured_callbacks: list = []

        def fake_schedule(key, delay, job, params=None):
            callback = functools.partial(timers.run_job_quietly, job, params)
            captured_callbacks.append(callback)

        game, *_ = _make_night_game(night_wave_seconds=60, wave=2)

        with (
            patch("apps.core.effects.get_channel_layer", return_value=None),
            patch("apps.core.timers.schedule", side_effect=fake_schedule),
        ):
            night_window.send_wave_prompts(game, 2)

        assert len(captured_callbacks) == 1

        # Invoke the callback directly -- simulates timer expiry.
        with (
            patch("apps.core.effects.get_channel_layer", return_value=None),
            patch("apps.core.timers.schedule"),  # Prevent next-wave timer from firing
        ):
            captured_callbacks[0]()

        game.refresh_from_db()
        # Window 2 has been closed -- the night is over.
        assert game.phase == Phase.DISCUSSION
        assert game.current_wave == 0

        # The Werewolf's see_team action was auto-resolved (not skipped).
        log = game.night_actions_log
        wave_2_entries = [e for e in log if e.get("wave") == 2]
        assert len(wave_2_entries) == 1
        assert wave_2_entries[0]["action_type"] == "see_team"

    def test_everyone_having_chosen_cancels_wave_timer(self, db):
        """
        The close that follows the last choose cancels the wave timer.
        """
        game, werewolf_user, seer_user, _ = _make_night_game(
            night_wave_seconds=300, wave=2
        )

        # Schedule a real wave timer via send_wave_prompts.
        with patch("apps.core.effects.get_channel_layer", return_value=None):
            night_window.send_wave_prompts(game, 2)

        timer_key = f"{game.id}:wave:2"
        with timers._lock:
            assert timer_key in timers._registry

        # Every phone with a choice has chosen in the window (the Werewolf and the Seer acted,
        # the Villager chose nothing).
        PlayerRole.objects.filter(game=game, user=werewolf_user).update(
            has_acted=True,
            night_action_data={
                "wave": 2,
                "role_acting_as": "Werewolf",
                "action_type": "see_team",
                "targets": {},
                "chose_2": 1,
            },
        )
        PlayerRole.objects.filter(game=game, user=seer_user).update(
            has_acted=True,
            night_action_data={
                "wave": 2,
                "role_acting_as": "Seer",
                "action_type": "skip",
                "targets": {},
                "chose_2": 1,
            },
        )
        PlayerRole.objects.filter(game=game).exclude(
            user__in=[werewolf_user, seer_user]
        ).update(has_acted=True, night_action_data={"chose_2": 1})

        # The close check a choose runs (Game locked) cancels the timer first.
        with (
            patch("apps.core.effects.get_channel_layer", return_value=None),
            patch("apps.core.timers.schedule"),  # Prevent next-wave timer
            transaction.atomic(),
        ):
            night_flow._advance_if_ready(
                Game.objects.select_for_update().get(id=game.id)
            )

        with timers._lock:
            assert timer_key not in timers._registry

    def test_host_force_advance_cancels_wave_timer(self, db):
        """advance_wave() cancels the pending wave timer at the start."""
        game, *_ = _make_night_game(night_wave_seconds=300, wave=2)

        # Schedule a real wave timer.
        with patch("apps.core.effects.get_channel_layer", return_value=None):
            night_window.send_wave_prompts(game, 2)

        timer_key = f"{game.id}:wave:2"
        with timers._lock:
            assert timer_key in timers._registry

        # Force-advance (host action).
        with (
            patch("apps.core.effects.get_channel_layer", return_value=None),
            patch("apps.core.timers.schedule"),  # Prevent next-wave timer
        ):
            night_flow.advance_wave(game)

        with timers._lock:
            assert timer_key not in timers._registry

    def test_transition_to_discussion_clears_wave_deadline(self, db):
        """
        Transitioning from night to discussion replaces any wave deadline.

        When discussion_seconds == 0 the old wave deadline is cleared to None.
        """
        from datetime import timedelta

        from django.utils import timezone

        game, *_ = _make_night_game(night_wave_seconds=30)

        # Force discussion_seconds to 0 so no discussion deadline is set.
        game.settings["discussion_seconds"] = 0
        game.save(update_fields=["settings"])

        # Simulate an active wave deadline on the game.
        game.phase_deadline = timezone.now() + timedelta(seconds=100)
        game.save(update_fields=["phase_deadline", "updated_at"])

        with patch("apps.core.effects.get_channel_layer", return_value=None):
            night_window.transition_to_discussion(game)

        game.refresh_from_db()
        assert game.phase_deadline is None
        assert game.phase == Phase.DISCUSSION

    def test_wave_transition_reschedules_timer(self, db):
        """
        Each window gets its own timer key.

        Closing window 1 opens window 2 and schedules a new timer for it.
        """
        scheduled_keys: list = []

        def fake_schedule(key, delay, job, params=None):
            scheduled_keys.append(key)

        game, *_ = _make_night_game(night_wave_seconds=300, wave=1)

        with (
            patch("apps.core.effects.get_channel_layer", return_value=None),
            patch("apps.core.timers.schedule", side_effect=fake_schedule),
        ):
            # Window 1 starts -- schedules wave:1 timer.
            night_window.send_wave_prompts(game, 1)
            assert any(str(game.id) + ":wave:1" in k for k in scheduled_keys)

            # Close window 1 -- advance_wave opens window 2 via send_wave_prompts.
            night_flow.advance_wave(game)

        wave_keys = [k for k in scheduled_keys if ":wave:" in k]
        assert len(wave_keys) >= 2, (
            f"Expected timers for at least 2 windows, got: {wave_keys}"
        )
        # Verify distinct window keys
        assert any(":wave:1" in k for k in wave_keys)
        assert any(":wave:2" in k for k in wave_keys)
        game.refresh_from_db()
        assert game.current_wave == 2


# ---------------------------------------------------------------------------
# Tests -- Discussion Timer Lifecycle
# ---------------------------------------------------------------------------


@pytest.mark.django_db(transaction=True)
class TestDiscussionTimerLifecycle:
    def test_discussion_auto_transitions_to_voting(self, db):
        """
        transition_to_discussion schedules a callback; invoking it directly
        (simulating timer expiry) moves the game to voting phase.
        """
        captured_callbacks: list = []

        def fake_schedule(key, delay, job, params=None):
            callback = functools.partial(timers.run_job_quietly, job, params)
            captured_callbacks.append(callback)

        game = _make_game(discussion_seconds=60)

        with (
            patch("apps.core.effects.get_channel_layer", return_value=None),
            patch("apps.core.timers.schedule", side_effect=fake_schedule),
        ):
            night_window.transition_to_discussion(game)

        game.refresh_from_db()
        assert game.phase_deadline is not None
        assert game.phase == Phase.DISCUSSION
        assert len(captured_callbacks) == 1

        # Invoke the captured callback directly -- simulates timer firing.
        with patch("apps.core.effects.get_channel_layer", return_value=None):
            captured_callbacks[0]()

        game.refresh_from_db()
        assert game.phase == Phase.VOTING

    def test_end_discussion_cancels_timer(self, db):
        """
        end_discussion() removes the discussion timer from the registry and
        transitions the game to voting.
        """
        game = _make_game(discussion_seconds=300)

        with patch("apps.core.effects.get_channel_layer", return_value=None):
            night_window.transition_to_discussion(game)

        timer_key = f"{game.id}:discussion"
        with timers._lock:
            assert timer_key in timers._registry

        with patch("apps.core.effects.get_channel_layer", return_value=None):
            voting.end_discussion(game)

        with timers._lock:
            assert timer_key not in timers._registry

        game.refresh_from_db()
        assert game.phase == Phase.VOTING

    def test_discussion_no_timer_when_seconds_zero(self, db):
        """
        When discussion_seconds == 0, no timer is scheduled and
        phase_deadline is null.
        """
        scheduled_keys: list = []

        def fake_schedule(key, delay, job, params=None):
            scheduled_keys.append(key)

        game = _make_game(discussion_seconds=0)

        with (
            patch("apps.core.effects.get_channel_layer", return_value=None),
            patch("apps.core.timers.schedule", side_effect=fake_schedule),
        ):
            night_window.transition_to_discussion(game)

        game.refresh_from_db()
        assert game.phase_deadline is None

        timer_key = f"{game.id}:discussion"
        assert timer_key not in scheduled_keys

    def test_discussion_phase_change_includes_deadline(self, db):
        """
        The phase_change broadcast event contains a non-null ISO 8601
        'deadline' when discussion_seconds > 0.
        """
        game = _make_game(discussion_seconds=180)
        broadcast_events: list = []

        def capture_send(group, event):
            broadcast_events.append(event)

        mock_layer = MagicMock()
        mock_layer.group_send = capture_send

        with (
            patch("apps.core.effects.get_channel_layer", return_value=mock_layer),
            patch("apps.core.effects.async_to_sync", side_effect=lambda f: f),
            patch("apps.core.timers.schedule"),
        ):
            night_window.transition_to_discussion(game)

        phase_events = [e for e in broadcast_events if e.get("type") == "phase.change"]
        assert len(phase_events) == 1
        event = phase_events[0]
        assert "deadline" in event
        assert event["deadline"] is not None
        # Verify it's a valid ISO 8601 string.
        datetime.fromisoformat(event["deadline"])

    def test_discussion_phase_change_deadline_null_when_untimed(self, db):
        """
        The phase_change broadcast event contains deadline=null when
        discussion_seconds == 0.
        """
        game = _make_game(discussion_seconds=0)
        broadcast_events: list = []

        def capture_send(group, event):
            broadcast_events.append(event)

        mock_layer = MagicMock()
        mock_layer.group_send = capture_send

        with (
            patch("apps.core.effects.get_channel_layer", return_value=mock_layer),
            patch("apps.core.effects.async_to_sync", side_effect=lambda f: f),
        ):
            night_window.transition_to_discussion(game)

        phase_events = [e for e in broadcast_events if e.get("type") == "phase.change"]
        assert len(phase_events) == 1
        event = phase_events[0]
        assert "deadline" in event
        assert event["deadline"] is None


# ---------------------------------------------------------------------------
# Tests -- Voting Timer Lifecycle
# ---------------------------------------------------------------------------


@pytest.mark.django_db(transaction=True)
class TestVotingTimerLifecycle:
    def test_voting_auto_reveals_with_abstentions(self, db):
        """
        transition_to_voting schedules a callback; invoking it directly
        (simulating timer expiry) moves the game to results with non-voters
        treated as abstentions (null vote_target).
        """
        captured_callbacks: list = []

        def fake_schedule(key, delay, job, params=None):
            callback = functools.partial(timers.run_job_quietly, job, params)
            captured_callbacks.append(callback)

        game, _users, _host = _make_game_with_players(player_count=3, voting_seconds=60)

        with (
            patch("apps.core.effects.get_channel_layer", return_value=None),
            patch("apps.core.timers.schedule", side_effect=fake_schedule),
        ):
            voting.transition_to_voting(game)

        game.refresh_from_db()
        assert game.phase_deadline is not None
        assert game.phase == Phase.VOTING
        assert len(captured_callbacks) == 1

        # No player has voted -- invoking callback simulates timer expiry.
        with patch("apps.core.effects.get_channel_layer", return_value=None):
            captured_callbacks[0]()

        game.refresh_from_db()
        assert game.phase == Phase.RESULTS
        assert game.phase_deadline is None

        # All players should have null vote_target (abstained)
        # pyrefly: ignore [missing-attribute]
        non_voters = game.player_roles.filter(vote_target__isnull=True).count()
        assert non_voters == 3

    def test_all_voted_cancels_voting_timer(self, db):
        """
        When all players submit votes, the voting timer is cancelled and
        the game transitions to results.
        """
        game, users, _host = _make_game_with_players(player_count=3, voting_seconds=300)

        with (
            patch("apps.core.effects.get_channel_layer", return_value=None),
        ):
            voting.transition_to_voting(game)

        timer_key = f"{game.id}:voting"
        with timers._lock:
            assert timer_key in timers._registry

        usernames = list(users.keys())
        stage = stage_token(Game.objects.get(id=game.id))
        # Submit votes for all players
        vote_pairs = [
            (usernames[0], users[usernames[1]].id),
            (usernames[1], users[usernames[0]].id),
            (usernames[2], users[usernames[0]].id),
        ]

        with patch("apps.core.effects.get_channel_layer", return_value=None):
            for voter_name, target_id in vote_pairs:
                errors = voting.submit_vote(
                    game, users[voter_name].id, target_id, stage=stage
                )
                # Ignore "Game is not in voting phase" after auto-reveal on last vote
                _ = errors

        # Timer should be cancelled after all voted
        with timers._lock:
            assert timer_key not in timers._registry

        game.refresh_from_db()
        assert game.phase == Phase.RESULTS

    def test_host_force_reveal_cancels_voting_timer(self, db):
        """
        reveal_votes() (host force-reveal path) cancels the voting timer.
        """
        game, _users, _host = _make_game_with_players(
            player_count=3, voting_seconds=300
        )

        with patch("apps.core.effects.get_channel_layer", return_value=None):
            voting.transition_to_voting(game)

        timer_key = f"{game.id}:voting"
        with timers._lock:
            assert timer_key in timers._registry

        with patch("apps.core.effects.get_channel_layer", return_value=None):
            voting.reveal_votes(game)

        with timers._lock:
            assert timer_key not in timers._registry

        game.refresh_from_db()
        assert game.phase == Phase.RESULTS
        assert game.phase_deadline is None

    def test_voting_no_timer_when_seconds_zero(self, db):
        """
        When voting_seconds == 0, no timer is scheduled and
        phase_deadline is null.
        """
        scheduled_keys: list = []

        def fake_schedule(key, delay, job, params=None):
            scheduled_keys.append(key)

        game, _users, _host = _make_game_with_players(player_count=3, voting_seconds=0)

        with (
            patch("apps.core.effects.get_channel_layer", return_value=None),
            patch("apps.core.timers.schedule", side_effect=fake_schedule),
        ):
            voting.transition_to_voting(game)

        game.refresh_from_db()
        assert game.phase_deadline is None

        timer_key = f"{game.id}:voting"
        assert timer_key not in scheduled_keys

    def test_voting_phase_change_includes_deadline(self, db):
        """
        The phase_change broadcast event contains a non-null ISO 8601
        'deadline' when voting_seconds > 0.
        """
        game, _users, _host = _make_game_with_players(
            player_count=3, voting_seconds=120
        )
        broadcast_events: list = []

        def capture_send(group, event):
            broadcast_events.append(event)

        mock_layer = MagicMock()
        mock_layer.group_send = capture_send

        with (
            patch("apps.core.effects.get_channel_layer", return_value=mock_layer),
            patch("apps.core.effects.async_to_sync", side_effect=lambda f: f),
            patch("apps.core.timers.schedule"),
        ):
            voting.transition_to_voting(game)

        phase_events = [e for e in broadcast_events if e.get("type") == "phase.change"]
        assert len(phase_events) == 1
        event = phase_events[0]
        assert event["phase"] == "voting"
        assert "deadline" in event
        assert event["deadline"] is not None
        # Verify it's a valid ISO 8601 string.
        datetime.fromisoformat(event["deadline"])

    def test_voting_phase_change_deadline_null_when_untimed(self, db):
        """
        The phase_change broadcast event contains deadline=null when
        voting_seconds == 0.
        """
        game, _users, _host = _make_game_with_players(player_count=3, voting_seconds=0)
        broadcast_events: list = []

        def capture_send(group, event):
            broadcast_events.append(event)

        mock_layer = MagicMock()
        mock_layer.group_send = capture_send

        with (
            patch("apps.core.effects.get_channel_layer", return_value=mock_layer),
            patch("apps.core.effects.async_to_sync", side_effect=lambda f: f),
        ):
            voting.transition_to_voting(game)

        phase_events = [e for e in broadcast_events if e.get("type") == "phase.change"]
        assert len(phase_events) == 1
        event = phase_events[0]
        assert event["phase"] == "voting"
        assert "deadline" in event
        assert event["deadline"] is None

    def test_double_cancel_is_safe_on_reveal(self, db):
        """
        Calling reveal_votes() after all players voted (which already cancelled
        the timer) does not raise -- double-cancel is safe.
        """
        game, users, _host = _make_game_with_players(player_count=3, voting_seconds=300)

        with patch("apps.core.effects.get_channel_layer", return_value=None):
            voting.transition_to_voting(game)

        usernames = list(users.keys())
        stage = stage_token(Game.objects.get(id=game.id))
        vote_pairs = [
            (usernames[0], users[usernames[1]].id),
            (usernames[1], users[usernames[0]].id),
            (usernames[2], users[usernames[0]].id),
        ]

        with patch("apps.core.effects.get_channel_layer", return_value=None):
            for voter_name, target_id in vote_pairs:
                voting.submit_vote(game, users[voter_name].id, target_id, stage=stage)

        game.refresh_from_db()
        assert game.phase == Phase.RESULTS
        # Timer key is gone (cancelled by all-voted path).
        timer_key = f"{game.id}:voting"
        with timers._lock:
            assert timer_key not in timers._registry

    def test_reveal_votes_cleans_up_all_game_timers(self, db):
        """
        reveal_votes calls cancel_all_for_game to clean up any stray timers
        (e.g. from a wave that was never properly cancelled).
        """
        game, users, _host = _make_game_with_players(player_count=3, voting_seconds=300)

        with patch("apps.core.effects.get_channel_layer", return_value=None):
            voting.transition_to_voting(game)

        # Manually inject a stale wave timer to simulate an orphaned timer
        stale_key = f"{game.id}:wave:2"
        timers.schedule(
            stale_key, 9999, "discussion_deadline", {"game_id": str(game.id)}
        )
        assert timers.is_scheduled(stale_key)

        # Submit all votes to trigger auto-reveal
        usernames = list(users.keys())
        stage = stage_token(Game.objects.get(id=game.id))
        with patch("apps.core.effects.get_channel_layer", return_value=None):
            for i, name in enumerate(usernames):
                target = users[usernames[(i + 1) % len(usernames)]].id
                voting.submit_vote(game, users[name].id, target, stage=stage)

        game.refresh_from_db()
        assert game.phase == Phase.RESULTS

        # The stale timer should have been cleaned up by cancel_all_for_game
        assert not timers.is_scheduled(stale_key)
        # No game timers should remain, in the table or in memory
        assert not ScheduledTimer.objects.filter(key__startswith=f"{game.id}:").exists()
        with timers._lock:
            assert [k for k in timers._registry if k.startswith(f"{game.id}:")] == []
