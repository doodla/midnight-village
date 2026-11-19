"""
The durable timer table (apps/onuw/timers.py), whatever fires it.

Memory backend: real ``threading.Timer`` threads (``uses_timers``). Queue
backend: a fake sender records the ``{key, token}`` messages and the tests
deliver them by hand, as the Vercel subscriber would, including stale,
cancelled, duplicate, early and concurrent deliveries.
"""

import threading
import time
from datetime import timedelta
from typing import Any

from django.db import connections
from django.utils import timezone

import pytest

from apps.onuw import timers
from apps.onuw.models import ScheduledTimer

pytestmark = pytest.mark.uses_timers


@pytest.fixture(autouse=True)
def clean_registry():
    _clear_registry()
    yield
    _clear_registry()


def _clear_registry():
    with timers._lock:
        for t in timers._registry.values():
            t.cancel()
        timers._registry.clear()


@pytest.fixture
def ran():
    """A job that records each run; returns the list of recorded params."""
    calls: list[dict[str, Any]] = []
    timers.JOBS["test_record"] = lambda **params: calls.append(params)
    yield calls
    timers.JOBS.pop("test_record", None)


@pytest.fixture
def queue(settings):
    """The queue backend with a fake sender; yields the list of sent messages."""
    settings.ONUW_TIMER_BACKEND = "vercel_queue"
    sent: list[tuple[str, dict[str, Any], float]] = []
    previous = timers.set_queue_sender(
        lambda topic, payload, delay: sent.append((topic, payload, delay))
    )
    yield sent
    timers.set_queue_sender(previous)


# ── the table, with the memory backend ───────────────────────────────────────


@pytest.mark.django_db(transaction=True)
class TestMemoryBackend:
    def test_a_scheduled_job_runs_after_the_delay_with_its_params(self, ran):
        timers.schedule("game:1:test", 0.05, "test_record", {"n": 1})

        deadline = time.time() + 2
        while not ran and time.time() < deadline:
            time.sleep(0.02)

        assert ran == [{"n": 1}]
        assert not ScheduledTimer.objects.filter(key="game:1:test").exists()

    def test_cancel_prevents_the_job_and_removes_the_row(self, ran):
        timers.schedule("game:1:cancel", 0.3, "test_record", {})
        assert timers.is_scheduled("game:1:cancel")

        timers.cancel("game:1:cancel")

        assert not timers.is_scheduled("game:1:cancel")
        assert not ScheduledTimer.objects.filter(key="game:1:cancel").exists()
        time.sleep(0.5)
        assert ran == []

    def test_cancel_all_for_game_leaves_other_games_alone(self, ran):
        timers.schedule("42:discussion", 0.3, "test_record", {"who": "d"})
        timers.schedule("42:voting", 0.3, "test_record", {"who": "v"})
        timers.schedule("99:other", 0.3, "test_record", {"who": "o"})

        timers.cancel_all_for_game(42)
        time.sleep(0.6)

        assert ran == [{"who": "o"}]

    def test_cancelling_a_key_that_does_not_exist_is_safe(self):
        timers.cancel("nonexistent:key")

    def test_rescheduling_replaces_the_timer_and_the_old_one_never_runs(self, ran):
        timers.schedule("game:1:phase", 0.4, "test_record", {"which": "first"})
        timers.schedule("game:1:phase", 0.05, "test_record", {"which": "second"})

        time.sleep(0.8)

        assert ran == [{"which": "second"}]

    def test_threads_are_daemons(self, ran):
        timers.schedule("game:1:daemon", 5.0, "test_record", {})
        with timers._lock:
            assert timers._registry["game:1:daemon"].daemon is True

    def test_a_row_left_by_a_dead_process_is_not_scheduled_until_rearmed(self, ran):
        ScheduledTimer.objects.create(
            key="game:1:orphan",
            token="abc",
            job="test_record",
            params={"x": 1},
            due_at=timezone.now() - timedelta(seconds=5),
        )
        assert not timers.is_scheduled("game:1:orphan")  # no thread here

        assert timers.rearm_from_table() == 1
        assert timers.is_scheduled("game:1:orphan")
        deadline = time.time() + 2
        while not ran and time.time() < deadline:
            time.sleep(0.02)
        assert ran == [{"x": 1}]  # overdue: fired at once, row consumed

    def test_an_unknown_job_is_refused_up_front(self):
        with pytest.raises(ValueError):
            timers.schedule("game:1:bad", 1, "no_such_job", {})
        assert not ScheduledTimer.objects.filter(key="game:1:bad").exists()


# ── firing semantics (any backend) ───────────────────────────────────────────


@pytest.mark.django_db(transaction=True)
class TestFiring:
    def _row(self, key="game:1:x", due_in=0.0, token="tok", **params):  # noqa: S107
        return ScheduledTimer.objects.create(
            key=key,
            token=token,
            job="test_record",
            params=params,
            due_at=timezone.now() + timedelta(seconds=due_in),
        )

    def test_a_matching_due_token_runs_once_and_deletes_the_row(self, ran):
        self._row(n=1)

        first = timers.fire("game:1:x", "tok")
        second = timers.fire("game:1:x", "tok")  # a duplicate delivery

        assert first.status == "ran"
        assert second.status == "stale"
        assert ran == [{"n": 1}]
        assert not ScheduledTimer.objects.filter(key="game:1:x").exists()

    def test_a_stale_token_does_nothing_and_leaves_the_newer_timer(self, ran):
        self._row(token="new", n=2)

        result = timers.fire("game:1:x", "old")

        assert result.status == "stale"
        assert ran == []
        assert ScheduledTimer.objects.get(key="game:1:x").token == "new"

    def test_a_cancelled_key_does_nothing(self, ran):
        assert timers.fire("game:1:never", "tok").status == "stale"
        assert ran == []

    def test_an_early_delivery_is_reported_with_the_remaining_time_and_keeps_the_row(
        self, ran
    ):
        self._row(due_in=30)

        result = timers.fire("game:1:x", "tok")

        assert result.status == "early"
        assert 28 < result.remaining <= 30
        assert ran == []
        assert ScheduledTimer.objects.filter(key="game:1:x").exists()

    def test_a_little_clock_skew_is_tolerated(self, ran):
        self._row(due_in=timers.CLOCK_SKEW_SECONDS - 0.5)

        assert timers.fire("game:1:x", "tok").status == "ran"

    def test_forcing_runs_a_timer_that_is_not_due_and_matches_any_token(self, ran):
        self._row(due_in=3600, n=3)

        assert timers.fire("game:1:x", None, force=True).status == "ran"
        assert ran == [{"n": 3}]

    def test_two_concurrent_claims_run_the_job_exactly_once(self, ran):
        self._row(n=4)
        barrier = threading.Barrier(2)
        results: list[str] = []

        def claim():
            try:
                barrier.wait(timeout=10)
                results.append(timers.fire("game:1:x", "tok").status)
            finally:
                connections.close_all()

        threads = [threading.Thread(target=claim) for _ in range(2)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=30)

        assert sorted(results) == ["ran", "stale"]
        assert ran == [{"n": 4}]


# ── the queue backend with a fake sender ─────────────────────────────────────


@pytest.mark.django_db(transaction=True)
class TestQueueBackend:
    def test_schedule_stores_the_row_and_sends_one_delayed_message(self, queue, ran):
        timers.schedule("game:1:q", 30, "test_record", {"n": 5})

        row = ScheduledTimer.objects.get(key="game:1:q")
        assert queue == [("onuw-timers", {"key": "game:1:q", "token": row.token}, 30)]
        assert timers.is_scheduled("game:1:q")
        assert timers._registry == {}  # nothing stays in this process

    def test_the_message_runs_the_job_once_when_delivered_twice(self, queue, ran):
        timers.schedule("game:1:q", 0, "test_record", {"n": 5})
        payload = queue[0][1]

        first = timers.fire(payload["key"], payload["token"])
        again = timers.fire(payload["key"], payload["token"])

        assert (first.status, again.status) == ("ran", "stale")
        assert ran == [{"n": 5}]

    def test_rescheduling_makes_the_earlier_message_stale(self, queue, ran):
        timers.schedule("game:1:q", 0, "test_record", {"which": "first"})
        timers.schedule("game:1:q", 0, "test_record", {"which": "second"})
        first, second = (m[1] for m in queue)

        assert timers.fire(first["key"], first["token"]).status == "stale"
        assert timers.fire(second["key"], second["token"]).status == "ran"
        assert ran == [{"which": "second"}]

    def test_a_cancelled_timer_whose_message_still_arrives_does_nothing(
        self, queue, ran
    ):
        timers.schedule("game:1:q", 0, "test_record", {})
        payload = queue[0][1]

        timers.cancel("game:1:q")

        assert timers.fire(payload["key"], payload["token"]).status == "stale"
        assert ran == []

    def test_the_vercel_sender_rounds_the_delay_up_so_a_message_is_never_early(
        self, settings, monkeypatch
    ):
        """The real sender (vercel.queue imported lazily) with a fake package."""
        import sys
        import types

        sent: list[tuple[str, dict[str, Any], int]] = []

        async def send(topic, payload, delay=0):
            sent.append((topic, payload, delay))

        fake = types.ModuleType("vercel.queue")
        fake.send = send  # type: ignore[attr-defined]
        monkeypatch.setitem(sys.modules, "vercel", types.ModuleType("vercel"))
        monkeypatch.setitem(sys.modules, "vercel.queue", fake)
        settings.ONUW_TIMER_BACKEND = "vercel_queue"
        previous = timers.set_queue_sender(None)  # the real sender
        try:
            timers.send_message("game:1:q", "tok", 7.2)
            timers.send_message("game:1:q", "tok", 0.0)
        finally:
            timers.set_queue_sender(previous)

        assert sent == [
            ("onuw-timers", {"key": "game:1:q", "token": "tok"}, 8),
            ("onuw-timers", {"key": "game:1:q", "token": "tok"}, 0),
        ]


@pytest.mark.django_db(transaction=True)
class TestQueueBackendSafetyNets:
    def test_a_message_that_could_not_be_sent_leaves_no_row_behind(self, settings, ran):
        settings.ONUW_TIMER_BACKEND = "vercel_queue"

        def broken(topic, payload, delay):
            raise ConnectionError("queue down")

        previous = timers.set_queue_sender(broken)
        try:
            with pytest.raises(ConnectionError):
                timers.schedule("game:1:q", 5, "test_record", {})
        finally:
            timers.set_queue_sender(previous)

        assert not ScheduledTimer.objects.filter(key="game:1:q").exists()
        assert not timers.is_scheduled("game:1:q")  # so the lazy repair re-creates it

    def test_a_row_long_past_due_whose_message_never_ran_is_not_scheduled(
        self, queue, ran
    ):
        timers.schedule("game:1:q", 5, "test_record", {})
        assert timers.is_scheduled("game:1:q")

        ScheduledTimer.objects.update(
            due_at=timezone.now() - timedelta(seconds=timers.OVERDUE_AFTER_SECONDS + 5)
        )

        assert not timers.is_scheduled("game:1:q")
