"""
Integration tests for the night wave phase timer lifecycle.

Covers:
- wave_start event includes 'deadline' field
- Timer scheduling when night_wave_seconds > 0
- No timer when night_wave_seconds == 0
- Auto-advance wave when timer fires (non-actors skipped)
- Early cancellation when all actors submit
- Host force-advance cancels timer
- Deadline cleared when transitioning from night to discussion
- Wave transitions use correct per-wave timer keys
"""

from datetime import datetime
from unittest.mock import MagicMock, patch

import pytest

from apps.core.models import Lobby, User
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


# ---------------------------------------------------------------------------
# Tests
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

    def test_wave_auto_advances_when_timer_fires(self, db):
        """
        Invoking the timer callback (simulating timer expiry) advances the wave.

        Non-acting players are skipped by advance_wave.
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

        # Invoke the callback directly — simulates timer expiry.
        with (
            patch("apps.onuw.services.get_channel_layer", return_value=None),
            patch("apps.onuw.timers.schedule"),  # Prevent next-wave timer from firing
        ):
            captured_callbacks[0]()

        game.refresh_from_db()
        # Wave 2 has been processed — game moved to wave 3 or discussion.
        assert game.current_wave != 2

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

    def test_transition_to_discussion_clears_deadline(self, db):
        """
        Transitioning from night to discussion clears phase_deadline.

        The discussion-phase timer (WP02) sets its own deadline independently.
        """
        from datetime import timedelta

        from django.utils import timezone

        game, *_ = _make_night_game(night_wave_seconds=30)

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
            # Wave 2 starts — schedules wave:2 timer.
            services.send_wave_prompts(game, 2)
            assert any(str(game.id) + ":wave:2" in k for k in scheduled_keys)

            # Advance to wave 3 — advance_wave calls send_wave_prompts for wave 3.
            services.advance_wave(game)

        wave_keys = [k for k in scheduled_keys if ":wave:" in k]
        assert len(wave_keys) >= 2, (
            f"Expected timers for at least 2 waves, got: {wave_keys}"
        )
        # Verify distinct wave keys
        assert any(":wave:2" in k for k in wave_keys)
        assert any(":wave:3" in k for k in wave_keys)
