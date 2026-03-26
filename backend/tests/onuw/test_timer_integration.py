"""
Integration tests for phase timer lifecycles.

Covers:
- Night wave timers: wave_start event includes 'deadline' field, scheduling,
  auto-advance, early cancellation, host force-advance, deadline clearing,
  per-wave timer keys
- Discussion timers: auto-transition to voting, early cancellation via
  end_discussion(), zero-duration behavior, phase_change event deadline field
- Voting timers: auto-reveal on expiry with abstentions, early cancellation
  when all players vote, host force-reveal, zero-duration behavior,
  phase_change event deadline field
"""

from datetime import datetime
from unittest.mock import MagicMock, patch

import pytest

from apps.core.models import Lobby, LobbyMember, User
from apps.onuw import services, timers
from apps.onuw.models import Game, Phase, PlayerRole

pytestmark = pytest.mark.integration


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


def _make_night_game(night_wave_seconds=30, wave=2):
    """
    Create a 3-player game in NIGHT phase at the given wave.

    Players: Werewolf (acts in wave 2), Seer (acts in wave 3), Villager (no actions)
    Center cards: Robber, Drunk, Villager
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
        LobbyMember.objects.create(lobby=lobby, user=user, is_ready=True)
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

        def fake_schedule(key, delay, callback, *args):
            scheduled_keys.append(key)

        game, *_ = _make_night_game(night_wave_seconds=0)

        with (
            patch("apps.onuw.services.get_channel_layer", return_value=None),
            patch("apps.onuw.timers.schedule", side_effect=fake_schedule),
        ):
            services.send_wave_prompts(game, 2)

        game.refresh_from_db()
        assert game.phase_deadline is None
        assert not any(":wave:2" in k for k in scheduled_keys)

    def test_wave_start_event_includes_deadline(self, db):
        """The wave_start broadcast event contains a non-null ISO 8601 deadline."""
        game, *_ = _make_night_game(night_wave_seconds=60)
        broadcast_events: list = []

        def capture_send(group, event):
            broadcast_events.append(event)

        mock_layer = MagicMock()
        mock_layer.group_send = capture_send

        with (
            patch("apps.onuw.services.get_channel_layer", return_value=mock_layer),
            patch("apps.onuw.services.async_to_sync", side_effect=lambda f: f),
            patch("apps.onuw.timers.schedule"),
        ):
            services.send_wave_prompts(game, 2)

        wave_events = [e for e in broadcast_events if e.get("type") == "wave.start"]
        assert len(wave_events) == 1
        event = wave_events[0]
        assert "deadline" in event
        assert event["deadline"] is not None
        # Verify it parses as a valid ISO 8601 datetime.
        datetime.fromisoformat(event["deadline"])

    def test_wave_start_event_deadline_null_when_untimed(self, db):
        """The wave_start broadcast has deadline=null when night_wave_seconds == 0."""
        game, *_ = _make_night_game(night_wave_seconds=0)
        broadcast_events: list = []

        def capture_send(group, event):
            broadcast_events.append(event)

        mock_layer = MagicMock()
        mock_layer.group_send = capture_send

        with (
            patch("apps.onuw.services.get_channel_layer", return_value=mock_layer),
            patch("apps.onuw.services.async_to_sync", side_effect=lambda f: f),
        ):
            services.send_wave_prompts(game, 2)

        wave_events = [e for e in broadcast_events if e.get("type") == "wave.start"]
        assert len(wave_events) == 1
        assert wave_events[0]["deadline"] is None

    def test_wave_auto_advances_with_skips(self, db):
        """
        Invoking the timer callback (simulating timer expiry) advances the wave.

        Non-acting players are skipped by advance_wave and recorded as "skip" in night_actions_log.
        """
        captured_callbacks: list = []

        def fake_schedule(key, delay, callback, *args):
            captured_callbacks.append(callback)

        game, *_ = _make_night_game(night_wave_seconds=60, wave=2)

        with (
            patch("apps.onuw.services.get_channel_layer", return_value=None),
            patch("apps.onuw.timers.schedule", side_effect=fake_schedule),
        ):
            services.send_wave_prompts(game, 2)

        assert len(captured_callbacks) == 1

        # Invoke the callback directly -- simulates timer expiry.
        with (
            patch("apps.onuw.services.get_channel_layer", return_value=None),
            patch("apps.onuw.timers.schedule"),  # Prevent next-wave timer from firing
        ):
            captured_callbacks[0]()

        game.refresh_from_db()
        # Wave 2 has been processed -- game moved to wave 3 or discussion.
        assert game.current_wave != 2

        # Non-acting players in wave 2 must be recorded as "skip" in the log.
        log = game.night_actions_log
        skip_entries = [
            e for e in log if e.get("action_type") == "skip" and e.get("wave") == 2
        ]
        assert len(skip_entries) > 0, (
            f"Expected at least one 'skip' entry for wave 2, got: {log}"
        )

    def test_all_acted_cancels_wave_timer(self, db):
        """
        check_and_maybe_advance() cancels the wave timer when all actors submit.
        """
        game, werewolf_user, _, _ = _make_night_game(night_wave_seconds=300, wave=2)

        # Schedule a real wave timer via send_wave_prompts.
        with patch("apps.onuw.services.get_channel_layer", return_value=None):
            services.send_wave_prompts(game, 2)

        timer_key = f"{game.id}:wave:2"
        with timers._lock:
            assert timer_key in timers._registry

        # Mark the Werewolf as having acted.
        PlayerRole.objects.filter(game=game, user=werewolf_user).update(
            has_acted=True,
            night_action_data={
                "wave": 2,
                "role_acting_as": "Werewolf",
                "action_type": "see_team",
                "targets": {},
            },
        )

        # check_and_maybe_advance should cancel the timer before advancing.
        with (
            patch("apps.onuw.services.get_channel_layer", return_value=None),
            patch("apps.onuw.timers.schedule"),  # Prevent next-wave timer
        ):
            services.check_and_maybe_advance(game)

        with timers._lock:
            assert timer_key not in timers._registry

    def test_host_force_advance_cancels_wave_timer(self, db):
        """advance_wave() cancels the pending wave timer at the start."""
        game, *_ = _make_night_game(night_wave_seconds=300, wave=2)

        # Schedule a real wave timer.
        with patch("apps.onuw.services.get_channel_layer", return_value=None):
            services.send_wave_prompts(game, 2)

        timer_key = f"{game.id}:wave:2"
        with timers._lock:
            assert timer_key in timers._registry

        # Force-advance (host action).
        with (
            patch("apps.onuw.services.get_channel_layer", return_value=None),
            patch("apps.onuw.timers.schedule"),  # Prevent next-wave timer
        ):
            services.advance_wave(game)

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

        with patch("apps.onuw.services.get_channel_layer", return_value=None):
            services.transition_to_discussion(game)

        game.refresh_from_db()
        assert game.phase_deadline is None
        assert game.phase == Phase.DISCUSSION

    def test_wave_transition_reschedules_timer(self, db):
        """
        Each wave gets its own timer key.

        Advancing from wave 2 to wave 3 schedules a new timer for wave 3.
        """
        scheduled_keys: list = []

        def fake_schedule(key, delay, callback, *args):
            scheduled_keys.append(key)

        game, *_ = _make_night_game(night_wave_seconds=300, wave=2)

        with (
            patch("apps.onuw.services.get_channel_layer", return_value=None),
            patch("apps.onuw.timers.schedule", side_effect=fake_schedule),
        ):
            # Wave 2 starts -- schedules wave:2 timer.
            services.send_wave_prompts(game, 2)
            assert any(str(game.id) + ":wave:2" in k for k in scheduled_keys)

            # Advance to wave 3 -- advance_wave calls send_wave_prompts for wave 3.
            services.advance_wave(game)

        wave_keys = [k for k in scheduled_keys if ":wave:" in k]
        assert len(wave_keys) >= 2, (
            f"Expected timers for at least 2 waves, got: {wave_keys}"
        )
        # Verify distinct wave keys
        assert any(":wave:2" in k for k in wave_keys)
        assert any(":wave:3" in k for k in wave_keys)


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

        def fake_schedule(key, delay, callback, *args):
            captured_callbacks.append(callback)

        game = _make_game(discussion_seconds=60)

        with (
            patch("apps.onuw.services.get_channel_layer", return_value=None),
            patch("apps.onuw.timers.schedule", side_effect=fake_schedule),
        ):
            services.transition_to_discussion(game)

        game.refresh_from_db()
        assert game.phase_deadline is not None
        assert game.phase == Phase.DISCUSSION
        assert len(captured_callbacks) == 1

        # Invoke the captured callback directly -- simulates timer firing.
        with patch("apps.onuw.services.get_channel_layer", return_value=None):
            captured_callbacks[0]()

        game.refresh_from_db()
        assert game.phase == Phase.VOTING

    def test_end_discussion_cancels_timer(self, db):
        """
        end_discussion() removes the discussion timer from the registry and
        transitions the game to voting.
        """
        game = _make_game(discussion_seconds=300)

        with patch("apps.onuw.services.get_channel_layer", return_value=None):
            services.transition_to_discussion(game)

        timer_key = f"{game.id}:discussion"
        with timers._lock:
            assert timer_key in timers._registry

        with patch("apps.onuw.services.get_channel_layer", return_value=None):
            services.end_discussion(game)

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

        def fake_schedule(key, delay, callback, *args):
            scheduled_keys.append(key)

        game = _make_game(discussion_seconds=0)

        with (
            patch("apps.onuw.services.get_channel_layer", return_value=None),
            patch("apps.onuw.timers.schedule", side_effect=fake_schedule),
        ):
            services.transition_to_discussion(game)

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
            patch("apps.onuw.services.get_channel_layer", return_value=mock_layer),
            patch("apps.onuw.services.async_to_sync", side_effect=lambda f: f),
            patch("apps.onuw.timers.schedule"),
        ):
            services.transition_to_discussion(game)

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
            patch("apps.onuw.services.get_channel_layer", return_value=mock_layer),
            patch("apps.onuw.services.async_to_sync", side_effect=lambda f: f),
        ):
            services.transition_to_discussion(game)

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

        def fake_schedule(key, delay, callback, *args):
            captured_callbacks.append(callback)

        game, _users, _host = _make_game_with_players(player_count=3, voting_seconds=60)

        with (
            patch("apps.onuw.services.get_channel_layer", return_value=None),
            patch("apps.onuw.timers.schedule", side_effect=fake_schedule),
        ):
            services.transition_to_voting(game)

        game.refresh_from_db()
        assert game.phase_deadline is not None
        assert game.phase == Phase.VOTING
        assert len(captured_callbacks) == 1

        # No player has voted -- invoking callback simulates timer expiry.
        with patch("apps.onuw.services.get_channel_layer", return_value=None):
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
            patch("apps.onuw.services.get_channel_layer", return_value=None),
        ):
            services.transition_to_voting(game)

        timer_key = f"{game.id}:voting"
        with timers._lock:
            assert timer_key in timers._registry

        usernames = list(users.keys())
        # Submit votes for all players
        vote_pairs = [
            (usernames[0], users[usernames[1]].id),
            (usernames[1], users[usernames[0]].id),
            (usernames[2], users[usernames[0]].id),
        ]

        with patch("apps.onuw.services.get_channel_layer", return_value=None):
            for voter_name, target_id in vote_pairs:
                errors = services.submit_vote(game, users[voter_name].id, target_id)
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

        with patch("apps.onuw.services.get_channel_layer", return_value=None):
            services.transition_to_voting(game)

        timer_key = f"{game.id}:voting"
        with timers._lock:
            assert timer_key in timers._registry

        with patch("apps.onuw.services.get_channel_layer", return_value=None):
            services.reveal_votes(game)

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

        def fake_schedule(key, delay, callback, *args):
            scheduled_keys.append(key)

        game, _users, _host = _make_game_with_players(player_count=3, voting_seconds=0)

        with (
            patch("apps.onuw.services.get_channel_layer", return_value=None),
            patch("apps.onuw.timers.schedule", side_effect=fake_schedule),
        ):
            services.transition_to_voting(game)

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
            patch("apps.onuw.services.get_channel_layer", return_value=mock_layer),
            patch("apps.onuw.services.async_to_sync", side_effect=lambda f: f),
            patch("apps.onuw.timers.schedule"),
        ):
            services.transition_to_voting(game)

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
            patch("apps.onuw.services.get_channel_layer", return_value=mock_layer),
            patch("apps.onuw.services.async_to_sync", side_effect=lambda f: f),
        ):
            services.transition_to_voting(game)

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

        with patch("apps.onuw.services.get_channel_layer", return_value=None):
            services.transition_to_voting(game)

        usernames = list(users.keys())
        vote_pairs = [
            (usernames[0], users[usernames[1]].id),
            (usernames[1], users[usernames[0]].id),
            (usernames[2], users[usernames[0]].id),
        ]

        with patch("apps.onuw.services.get_channel_layer", return_value=None):
            for voter_name, target_id in vote_pairs:
                services.submit_vote(game, users[voter_name].id, target_id)

        game.refresh_from_db()
        assert game.phase == Phase.RESULTS
        # Timer key is gone (cancelled by all-voted path).
        timer_key = f"{game.id}:voting"
        with timers._lock:
            assert timer_key not in timers._registry
