"""
Integration tests for the discussion phase timer lifecycle.

Covers:
- Auto-transition to voting when the discussion timer expires
- Early cancellation via end_discussion()
- Zero-duration (untimed) discussion behavior
- phase_change event shape includes 'deadline' field
"""

from unittest.mock import MagicMock, patch

import pytest

from apps.core.models import Lobby, User
from apps.onuw import services, timers
from apps.onuw.models import Game, Phase

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


# ---------------------------------------------------------------------------
# Tests
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

        # Invoke the captured callback directly — simulates timer firing.
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
        from datetime import datetime

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
