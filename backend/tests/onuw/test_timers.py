"""
Unit and integration tests for the ONUW timer registry.

Unit tests cover the registry mechanics (schedule, cancel, cancel_all_for_game).
Integration tests cover the idempotent callback wrapper (requires DB + Game model).
"""

import threading
import time

import pytest

from apps.onuw import timers

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def clean_timer_registry():
    """
    Cancel all timers and clear the registry before and after each test.

    This prevents leaked timer threads from one test polluting another.
    """
    # Clear before test in case a previous test left debris.
    _clear_registry()
    yield
    # Clear after test.
    _clear_registry()


def _clear_registry():
    """Helper: cancel every timer in the registry and empty it."""
    with timers._lock:
        for t in timers._registry.values():
            t.cancel()
        timers._registry.clear()


# ---------------------------------------------------------------------------
# Unit tests — no DB required
# ---------------------------------------------------------------------------

pytestmark_unit = pytest.mark.unit


@pytest.mark.unit
class TestSchedule:
    def test_schedule_fires_callback(self):
        """A scheduled callback is invoked after the delay."""
        fired = threading.Event()
        timers.schedule("game:1:test", 0.05, fired.set)
        assert fired.wait(timeout=1.0), "Callback should have fired"

    def test_cancel_prevents_firing(self):
        """Cancelling a timer before it fires prevents the callback."""
        fired = threading.Event()
        timers.schedule("game:1:cancel_test", 0.5, fired.set)
        timers.cancel("game:1:cancel_test")
        assert not fired.wait(timeout=0.7), "Cancelled callback should not fire"

    def test_cancel_all_for_game(self):
        """cancel_all_for_game cancels all timers prefixed with the game id."""
        results: list[str] = []
        lock = threading.Lock()

        def record(name: str) -> None:
            with lock:
                results.append(name)

        timers.schedule("42:discussion", 0.5, record, "discussion")
        timers.schedule("42:voting", 0.5, record, "voting")
        timers.schedule(
            "99:other", 0.5, record, "other"
        )  # different game — must still fire

        timers.cancel_all_for_game(42)

        # Wait long enough for any surviving timers to fire.
        time.sleep(0.8)

        with lock:
            assert "discussion" not in results
            assert "voting" not in results
            assert "other" in results  # unaffected game still ran

    def test_double_cancel_is_safe(self):
        """Cancelling a key that does not exist raises no exception."""
        timers.cancel("nonexistent:key")  # must not raise

    def test_reschedule_replaces_existing(self):
        """Scheduling with an existing key cancels the old timer first."""
        first_fired = threading.Event()
        second_fired = threading.Event()

        timers.schedule("game:1:phase", 0.5, first_fired.set)
        # Immediately replace with a short-delay callback.
        timers.schedule("game:1:phase", 0.05, second_fired.set)

        assert second_fired.wait(timeout=1.0), "Second callback should fire"
        # Give extra time to confirm first never fired.
        assert not first_fired.wait(timeout=0.6), (
            "First callback should have been cancelled"
        )

    def test_cancel_removes_key_from_registry(self):
        """After cancel(), the key is no longer in the registry."""
        fired = threading.Event()
        timers.schedule("game:1:cleanup", 5.0, fired.set)
        timers.cancel("game:1:cleanup")
        with timers._lock:
            assert "game:1:cleanup" not in timers._registry

    def test_schedule_sets_daemon_flag(self):
        """Timer threads are daemonised so they don't block process exit."""
        timers.schedule("game:1:daemon_check", 5.0, lambda: None)
        with timers._lock:
            t = timers._registry["game:1:daemon_check"]
        assert t.daemon is True


# ---------------------------------------------------------------------------
# Integration tests — DB required
# ---------------------------------------------------------------------------


def _make_game(db, phase="discussion"):
    """Create a minimal Game instance for testing."""
    from apps.core.models import Lobby, User
    from apps.onuw.models import Game

    host = User.objects.create_user(username="timer_host", password="pass")
    lobby = Lobby.objects.create(
        host=host,
        game_type="onuw",
        max_players=10,
        settings={"roles": {"Werewolf": 2, "Villager": 3}},
    )
    return Game.objects.create(
        lobby=lobby,
        phase=phase,
        random_seed=42,
    )


@pytest.mark.django_db(transaction=True)
class TestIdempotentCallback:
    def test_idempotent_callback_noop_on_phase_change(self, db):
        """Callback is a no-op when the game phase has already advanced."""
        game = _make_game(db, phase="discussion")
        executed: list[bool] = []

        def _action(g):
            executed.append(True)

        callback = timers.make_idempotent_callback(game.id, "discussion", _action)

        # Advance phase before firing the callback.
        from apps.onuw.models import Game

        Game.objects.filter(id=game.id).update(phase="voting")

        callback()  # Should be a no-op — phase no longer matches.
        assert executed == [], "Action should not execute when phase has changed"

    def test_idempotent_callback_executes_on_matching_phase(self, db):
        """Callback executes when the game is still in the expected phase."""
        game = _make_game(db, phase="discussion")
        executed: list[bool] = []

        def _action(g):
            executed.append(True)

        callback = timers.make_idempotent_callback(game.id, "discussion", _action)
        callback()

        assert executed == [True], "Action should execute when phase matches"

    def test_idempotent_callback_noop_on_missing_game(self, db):
        """Callback is a no-op when the game no longer exists."""
        import uuid

        nonexistent_id = uuid.uuid4()
        executed: list[bool] = []

        def _action(g):
            executed.append(True)

        callback = timers.make_idempotent_callback(
            nonexistent_id, "discussion", _action
        )
        callback()  # Should not raise and should not execute action.

        assert executed == [], "Action should not execute for missing game"
