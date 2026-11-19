"""
The whole timer flow on the queue backend, with a fake sender.

``ONUW_TIMER_BACKEND = "vercel_queue"``: scheduling stores a row and publishes a
delayed ``{key, token}`` message; nothing stays in the process. The tests play
the part of the Vercel subscriber (``queue_worker.handle_message``): they deliver
messages by hand, early, late, twice, stale, and check what the game does.
"""

import asyncio
import importlib
import sys
import types
import uuid
from datetime import timedelta
from types import SimpleNamespace
from typing import Any
from unittest.mock import AsyncMock, patch

from django.urls import reverse
from django.utils import timezone

import pytest

from apps.core.models import Lobby, LobbyMember
from apps.onuw import host, presence, queue_worker, services, timers
from apps.onuw.models import Game, Phase, PlayerRole, ScheduledTimer, SocketPresence
from tests.onuw.test_night_windows import Night, _Recorder

pytestmark = [pytest.mark.uses_timers, pytest.mark.django_db(transaction=True)]

ROLES = {
    "wolf": "Werewolf",
    "seer": "Seer",
    "robber": "Robber",
    "villager": "Villager",
}
CENTER = ["Villager", "Tanner", "Hunter"]


class Queue:
    """The fake Vercel queue: every sent message, delivered by the tests."""

    def __init__(self) -> None:
        self.sent: list[tuple[str, dict[str, Any], float]] = []

    def __call__(self, topic: str, payload: dict[str, Any], delay: float) -> None:
        self.sent.append((topic, payload, delay))

    def for_key(self, key: str) -> list[tuple[dict[str, Any], float]]:
        return [(p, d) for _, p, d in self.sent if p["key"] == key]

    def make_due(self, key: str) -> None:
        """Pretend the message's delay has passed."""
        ScheduledTimer.objects.filter(key=key).update(
            due_at=timezone.now() - timedelta(seconds=1)
        )

    def deliver(self, key: str, which: int = -1) -> str:
        payload = self.for_key(key)[which][0]
        return queue_worker.handle_message(payload)


@pytest.fixture
def queue(settings):
    settings.ONUW_TIMER_BACKEND = "vercel_queue"
    fake = Queue()
    previous = timers.set_queue_sender(fake)
    yield fake
    timers.set_queue_sender(previous)


@pytest.fixture
def night(queue, django_capture_on_commit_callbacks):
    def build(roles=ROLES, **settings) -> Night:
        merged = {
            "roles": {},
            "night_min_window_seconds": 0,
            "night_doppelganger_window_seconds": 0,
            "night_wave_seconds": 30,
            **settings,
        }
        return Night(
            roles, CENTER, merged, _Recorder(), [], django_capture_on_commit_callbacks
        )

    return build


def key_of(n: Night, suffix: str) -> str:
    return f"{n.game.id}:{suffix}"


# ── a night window ───────────────────────────────────────────────────────────


class TestANightWindowOnTheQueue:
    def test_opening_the_window_publishes_one_delayed_message_and_keeps_nothing_in_process(
        self, night, queue
    ):
        n = night()
        n.start()

        ((payload, delay),) = queue.for_key(key_of(n, "wave:2"))
        assert delay == 30
        assert set(payload) == {"key", "token"}
        assert (
            ScheduledTimer.objects.get(key=key_of(n, "wave:2")).token
            == payload["token"]
        )
        assert timers._registry == {}

    def test_an_early_delivery_is_requeued_with_the_remaining_delay_and_changes_nothing(
        self, night, queue
    ):
        n = night()
        n.start()
        key = key_of(n, "wave:2")

        assert queue.deliver(key) == "requeued"

        assert n.refresh().phase == Phase.NIGHT
        again = queue.for_key(key)
        assert len(again) == 2
        assert again[1][0] == again[0][0]  # same key and token
        assert 28 <= again[1][1] <= 31  # the remaining time (rounded up)
        assert ScheduledTimer.objects.filter(key=key).exists()

    def test_the_delivery_when_due_closes_the_window_and_the_game_moves_on(
        self, night, queue
    ):
        n = night()
        n.start()
        n.post("wolf", "see_team")
        key = key_of(n, "wave:2")
        queue.make_due(key)

        assert queue.deliver(key) == "ran"

        assert n.refresh().phase == Phase.DISCUSSION
        assert not ScheduledTimer.objects.filter(key=key).exists()
        # The talk's own timer was published through the same path.
        ((_, delay),) = queue.for_key(key_of(n, "discussion"))
        assert delay == 300

    def test_a_duplicate_delivery_does_nothing_more(self, night, queue):
        n = night()
        n.start()
        key = key_of(n, "wave:2")
        queue.make_due(key)
        queue.deliver(key)
        n.refresh()
        log_after = list(n.game.night_actions_log)
        sent_after = len(queue.sent)

        assert queue.deliver(key) == "stale"

        assert n.refresh().phase == Phase.DISCUSSION
        assert n.game.night_actions_log == log_after
        assert len(queue.sent) == sent_after

    def test_a_message_for_a_window_that_already_closed_early_does_nothing(
        self, night, queue
    ):
        n = night()
        n.start()
        key = key_of(n, "wave:2")
        n.post("wolf", "see_team")
        n.post("seer", "skip")
        n.post("robber", "skip")  # everyone is done: closes now, cancels the timer
        assert n.refresh().phase == Phase.DISCUSSION
        queue.make_due(key)

        assert queue.deliver(key) == "stale"
        assert n.refresh().phase == Phase.DISCUSSION

    def test_the_minimum_length_close_replaces_the_deadline_message_and_the_old_one_is_stale(
        self, night, queue
    ):
        n = night(night_min_window_seconds=8)
        n.start()
        key = key_of(n, "wave:2")
        n.post("wolf", "see_team")
        n.post("seer", "skip")
        n.post("robber", "skip")
        first, second = (m[0] for m in queue.for_key(key))
        assert n.refresh().phase == Phase.NIGHT  # held for the minimum
        assert first["token"] != second["token"]

        assert timers.fire(first["key"], first["token"]).status == "stale"
        queue.make_due(key)
        assert queue.deliver(key) == "ran"
        assert n.refresh().phase == Phase.DISCUSSION

    def test_the_host_closing_the_window_leaves_the_queued_message_harmless(
        self, night, queue
    ):
        n = night()
        n.start()
        key = key_of(n, "wave:2")
        n.host_close_window()
        assert n.refresh().phase == Phase.DISCUSSION
        queue.make_due(key)

        assert queue.deliver(key) == "stale"


class TestDoppelgangerWindowOnTheQueue:
    @pytest.mark.parametrize("acted", [False, True])
    def test_window_one_is_one_message_of_exactly_its_fixed_length_whatever_she_did(
        self, night, queue, acted
    ):
        n = night(
            {"d": "Doppelganger", "s": "Seer", "w": "Werewolf", "v": "Villager"},
            night_doppelganger_window_seconds=10,
        )
        n.start()
        if acted:
            n.post("d", "peek_player", {"player_id": n.users["s"].id})

        messages = queue.for_key(key_of(n, "wave:1"))

        assert [d for _, d in messages] == [10]  # one message, same length either way
        assert n.refresh().current_wave == 1


# ── the vote ─────────────────────────────────────────────────────────────────


class TestAVoteOnTheQueue:
    def _voting(self, night, queue):
        n = night(voting_seconds=120)
        n.start()
        n.host_close_window()
        n.client.force_authenticate(user=n.host)
        n.client.post(
            reverse("onuw:end-discussion", kwargs={"game_id": str(n.game.id)})
        )
        assert n.refresh().phase == Phase.VOTING
        return n

    def vote(self, n, voter, target):
        n.client.force_authenticate(user=n.users[voter])
        return n.client.post(
            reverse("onuw:vote", kwargs={"game_id": str(n.game.id)}),
            {"target_player_id": n.users[target].id},
            format="json",
        )

    def test_the_deadline_message_reveals_the_votes_with_abstentions(
        self, night, queue
    ):
        n = self._voting(night, queue)
        key = key_of(n, "voting")
        assert [d for _, d in queue.for_key(key)] == [120]
        self.vote(n, "seer", "wolf")
        queue.make_due(key)

        assert queue.deliver(key) == "ran"

        assert n.refresh().phase == Phase.RESULTS
        assert n.game.results["winning_teams"]

    def test_everyone_voting_reveals_at_once_and_the_queued_message_is_then_stale(
        self, night, queue
    ):
        n = self._voting(night, queue)
        key = key_of(n, "voting")
        for voter, target in (
            ("wolf", "seer"),
            ("seer", "wolf"),
            ("robber", "wolf"),
            ("villager", "wolf"),
        ):
            self.vote(n, voter, target)
        assert n.refresh().phase == Phase.RESULTS
        queue.make_due(key)

        assert queue.deliver(key) == "stale"
        assert n.refresh().phase == Phase.RESULTS


# ── the subscriber ───────────────────────────────────────────────────────────


class TestTheSubscriber:
    @pytest.mark.parametrize(
        "payload", [None, [], {}, {"key": "k"}, {"key": 1, "token": "t"}, "text"]
    )
    def test_a_malformed_message_is_ignored(self, queue, payload):
        assert queue_worker.handle_message(payload) == "invalid"

    def test_an_unknown_timer_is_stale_not_an_error(self, queue):
        assert queue_worker.handle_message({"key": "no:such", "token": "t"}) == "stale"

    def test_the_async_handler_runs_the_work_in_a_thread(self, queue):
        import asyncio

        timers.schedule(
            "game:1:async",
            0,
            "grace_expired",
            {"game_id": str(uuid.uuid4()), "user_id": 1},
        )
        # An unknown game: the job is a harmless no-op, the row is consumed.
        payload = queue.sent[0][1]

        result = asyncio.run(queue_worker.process(payload))

        assert result == "ran"
        assert not ScheduledTimer.objects.filter(key="game:1:async").exists()


class TestNothingHappensAtStartUp:
    def test_the_queue_backend_never_recovers_at_start_up(self, settings):
        from unittest.mock import patch

        settings.ONUW_TIMER_BACKEND = "vercel_queue"
        settings.ONUW_RECOVER_TIMERS_ON_START = True
        with patch("apps.onuw.services.recover_timers") as recover:
            services.run_startup_recovery()
        recover.assert_not_called()

    def test_importing_the_asgi_app_with_the_queue_backend_recovers_nothing(
        self, settings
    ):
        import importlib
        from unittest.mock import patch

        settings.ONUW_TIMER_BACKEND = "vercel_queue"
        settings.ONUW_RECOVER_TIMERS_ON_START = True
        import config.asgi

        with patch("apps.onuw.services.recover_timers") as recover:
            importlib.reload(config.asgi)
        recover.assert_not_called()

    def test_the_memory_backend_still_recovers_when_enabled(self, settings):
        import importlib
        from unittest.mock import patch

        settings.ONUW_TIMER_BACKEND = "memory"
        settings.ONUW_RECOVER_TIMERS_ON_START = True
        import config.asgi

        with patch("apps.onuw.services.recover_timers", return_value=0) as recover:
            importlib.reload(config.asgi)
        recover.assert_called_once()


# ── presence checks and heartbeats on the queue ─────────────────────────────


class TestPresenceChecksOnTheQueue:
    def test_a_long_lived_socket_costs_about_one_timer_write_per_staleness_period(
        self, night, queue
    ):
        from apps.onuw import presence

        n = night()
        n.start()
        user_id = n.users["seer"].id
        key = presence.check_key("game", n.game.id, user_id)

        with n.committed():
            services.register_connection(n.game.id, user_id, "chan-1")
        channel = "chan-1"
        for _ in range(10):  # ten heartbeats
            services.refresh_connection(n.game.id, user_id, channel)

        assert len(queue.for_key(key)) == 1  # the heartbeats wrote no timer

        # The check fires with a fresh row: it re-arms itself once.
        queue.make_due(key)
        assert queue.deliver(key) == "ran"
        assert len(queue.for_key(key)) == 2
        assert (
            ScheduledTimer.objects.filter(key=key).count() == 1
        )  # at most one pending

    def test_a_socket_that_died_silently_is_noticed_through_the_queue(
        self, night, queue
    ):
        from apps.onuw import presence
        from apps.onuw.models import PlayerRole, SocketPresence

        n = night()
        n.start()
        user_id = n.users["seer"].id
        key = presence.check_key("game", n.game.id, user_id)
        with n.committed():
            services.register_connection(n.game.id, user_id, "chan-2")
        SocketPresence.objects.update(last_seen=timezone.now() - timedelta(seconds=100))
        queue.make_due(key)

        assert queue.deliver(key) == "ran"

        assert not SocketPresence.objects.filter(user_id=user_id).exists()
        assert PlayerRole.objects.get(game=n.game, user_id=user_id).disconnected_at
        # The grace period for a night is now a queued message of its own.
        ((_, delay),) = queue.for_key(key_of(n, f"grace:{user_id}"))
        assert delay == 25

    def test_instances_dying_loses_nothing_the_next_one_can_fire_everything(
        self, night, queue
    ):
        """No in-process state: a fresh process (empty registry) fires the message."""
        n = night()
        n.start()
        key = key_of(n, "wave:2")
        timers._registry.clear()  # "the instance that scheduled it is gone"
        queue.make_due(key)

        assert queue.deliver(key) == "ran"
        assert n.refresh().phase == Phase.DISCUSSION


# ── a failing job keeps its timer ────────────────────────────────────────────


def _fail_once(real, error="transient"):
    """Wrap ``real`` so its first call raises and later calls really run."""
    calls: list[int] = []

    def flaky(*args, **kwargs):
        calls.append(1)
        if len(calls) == 1:
            raise RuntimeError(error)
        return real(*args, **kwargs)

    flaky.calls = calls  # type: ignore[attr-defined]
    return flaky


class TestAFailingJobKeepsItsTimer:
    """Real jobs, really failing: the row survives and the redelivery succeeds."""

    def test_a_night_window_that_fails_to_close_is_closed_by_the_redelivery(
        self, night, queue
    ):
        n = night()
        n.start()
        key = key_of(n, "wave:2")
        queue.make_due(key)
        flaky = _fail_once(services.advance_wave)

        with patch("apps.onuw.services.advance_wave", side_effect=flaky):
            with pytest.raises(RuntimeError, match="transient"):
                queue.deliver(key)
            assert ScheduledTimer.objects.filter(key=key).exists()  # kept
            assert n.refresh().phase == Phase.NIGHT  # nothing half-done
            assert queue.deliver(key) == "ran"  # the same message, redelivered

        assert n.refresh().phase == Phase.DISCUSSION
        assert not ScheduledTimer.objects.filter(key=key).exists()
        assert len(flaky.calls) == 2

    def test_a_vote_that_fails_to_reveal_is_revealed_by_the_redelivery(
        self, night, queue
    ):
        n = night(voting_seconds=120)
        n.start()
        n.host_close_window()
        n.client.force_authenticate(user=n.host)
        n.client.post(
            reverse("onuw:end-discussion", kwargs={"game_id": str(n.game.id)})
        )
        key = key_of(n, "voting")
        queue.make_due(key)
        flaky = _fail_once(services.reveal_votes)

        with patch("apps.onuw.services.reveal_votes", side_effect=flaky):
            with pytest.raises(RuntimeError):
                queue.deliver(key)
            assert ScheduledTimer.objects.filter(key=key).exists()
            assert n.refresh().phase == Phase.VOTING
            assert queue.deliver(key) == "ran"

        assert n.refresh().phase == Phase.RESULTS

    def test_a_presence_check_that_fails_still_notices_the_dead_socket_next_time(
        self, night, queue
    ):
        n = night()
        n.start()
        user_id = n.users["seer"].id
        key = presence.check_key("game", n.game.id, user_id)
        with n.committed():
            services.register_connection(n.game.id, user_id, "chan-f")
        SocketPresence.objects.update(last_seen=timezone.now() - timedelta(seconds=100))
        queue.make_due(key)
        flaky = _fail_once(services.check_game_presence)

        with patch("apps.onuw.services.check_game_presence", side_effect=flaky):
            with pytest.raises(RuntimeError):
                queue.deliver(key)
            assert ScheduledTimer.objects.filter(key=key).exists()
            assert SocketPresence.objects.filter(user_id=user_id).exists()  # untouched
            assert queue.deliver(key) == "ran"

        assert not SocketPresence.objects.filter(user_id=user_id).exists()
        assert PlayerRole.objects.get(game=n.game, user_id=user_id).disconnected_at

    def test_a_grace_expiry_that_fails_is_retried(self, night, queue):
        n = night()
        n.start()
        user_id = n.users["seer"].id
        with n.committed():
            services.register_connection(n.game.id, user_id, "chan-g")
        with n.committed():
            services.unregister_connection(n.game.id, user_id, "chan-g")
        key = key_of(n, f"grace:{user_id}")
        n.post("wolf", "see_team")
        n.post("robber", "skip")
        assert n.refresh().phase == Phase.NIGHT  # still inside the Seer's grace
        PlayerRole.objects.filter(game=n.game, user_id=user_id).update(
            disconnected_at=timezone.now() - timedelta(seconds=40)
        )
        queue.make_due(key)
        flaky = _fail_once(services._evaluate_presence)

        with patch("apps.onuw.services._evaluate_presence", side_effect=flaky):
            with pytest.raises(RuntimeError):
                queue.deliver(key)
            assert ScheduledTimer.objects.filter(key=key).exists()
            assert queue.deliver(key) == "ran"

        assert n.refresh().phase == Phase.DISCUSSION  # went on without the Seer

    def test_a_host_handover_that_fails_is_retried(self, night, queue):
        n = night()
        n.start()
        code = Lobby.objects.get(pk=n.game.lobby_id).code
        wolf, seer = n.users["wolf"].id, n.users["seer"].id
        with n.committed():
            host.register_lobby_connection(code, wolf, "chan-w")
            host.register_lobby_connection(code, seer, "chan-s")
        with n.committed():
            host.unregister_lobby_connection(code, wolf, "chan-w")
        LobbyMember.objects.filter(lobby_id=n.game.lobby_id, user_id=wolf).update(
            disconnected_at=timezone.now() - timedelta(seconds=120)
        )
        key = f"lobby:{n.game.lobby_id}:host"
        queue.make_due(key)
        flaky = _fail_once(host._hand_over_if_due)

        with patch("apps.onuw.host._hand_over_if_due", side_effect=flaky):
            with pytest.raises(RuntimeError):
                queue.deliver(key)
            assert ScheduledTimer.objects.filter(key=key).exists()
            assert queue.deliver(key) == "ran"

        assert Lobby.objects.get(pk=n.game.lobby_id).acting_host_id == seer


class TestRetries:
    def test_the_memory_backend_retries_a_failed_job_after_a_short_delay(
        self, night, settings, monkeypatch
    ):
        import time

        settings.ONUW_TIMER_BACKEND = "memory"
        monkeypatch.setattr(timers, "RETRY_DELAY_SECONDS", 0.05)
        n = night()
        n.start()
        key = key_of(n, "wave:2")
        ScheduledTimer.objects.filter(key=key).update(
            due_at=timezone.now() - timedelta(seconds=1)
        )
        token = ScheduledTimer.objects.get(key=key).token
        flaky = _fail_once(services.advance_wave)

        with patch("apps.onuw.services.advance_wave", side_effect=flaky):
            timers._thread_fire(key, token)  # the timer thread's entry point
            deadline = time.time() + 5
            while time.time() < deadline and n.refresh().phase == Phase.NIGHT:
                time.sleep(0.05)

        assert n.refresh().phase == Phase.DISCUSSION
        assert len(flaky.calls) == 2

    def test_a_job_that_always_fails_is_retried_a_capped_number_of_times(
        self, night, settings, monkeypatch
    ):
        import time

        settings.ONUW_TIMER_BACKEND = "memory"
        monkeypatch.setattr(timers, "RETRY_DELAY_SECONDS", 0.02)
        monkeypatch.setattr(timers, "MAX_ATTEMPTS", 3)
        n = night()
        n.start()
        key = key_of(n, "wave:2")
        ScheduledTimer.objects.filter(key=key).update(
            due_at=timezone.now() - timedelta(seconds=1)
        )
        token = ScheduledTimer.objects.get(key=key).token
        calls: list[int] = []

        def always_fails(*_a, **_k):
            calls.append(1)
            raise RuntimeError("permanent")

        with patch("apps.onuw.services.advance_wave", side_effect=always_fails):
            timers._thread_fire(key, token)
            time.sleep(0.8)

        assert len(calls) == 3  # not a spin
        assert ScheduledTimer.objects.filter(key=key).exists()  # left for the sweep

    def test_the_subscriber_asks_the_queue_to_retry_a_failed_job_then_gives_up(
        self, monkeypatch
    ):
        class RetryAfter(Exception):  # noqa: N818
            def __init__(self, delay):
                self.delay = delay

        fake = types.ModuleType("vercel.queue")

        class Message:
            def __class_getitem__(cls, item):
                return cls

        fake.Message = Message  # type: ignore[attr-defined]
        fake.RetryAfter = RetryAfter  # type: ignore[attr-defined]
        fake.subscribe = lambda topic: (lambda func: func)  # type: ignore[attr-defined]
        monkeypatch.setitem(sys.modules, "vercel", types.ModuleType("vercel"))
        monkeypatch.setitem(sys.modules, "vercel.queue", fake)
        worker = importlib.reload(queue_worker)
        try:
            worker.process = AsyncMock(side_effect=RuntimeError("job failed"))

            def message(delivery_count):
                return SimpleNamespace(
                    payload={"key": "k", "token": "t"},
                    metadata=SimpleNamespace(delivery_count=delivery_count),
                )

            with pytest.raises(RetryAfter) as retry:
                asyncio.run(worker.handler(message(1)))
            assert retry.value.delay == worker.RETRY_AFTER_SECONDS
            # After the cap the message is dropped (the sweep repairs the row).
            assert asyncio.run(worker.handler(message(worker.MAX_DELIVERIES))) is None
        finally:
            monkeypatch.undo()
            importlib.reload(queue_worker)

    def test_retry_decision_is_capped(self):
        assert queue_worker.retry_decision(1) == queue_worker.RETRY_AFTER_SECONDS
        assert queue_worker.retry_decision(queue_worker.MAX_DELIVERIES) is None


# ── lost publications: the lazy repair and the sweep ─────────────────────────


def _row(
    key="other:1",
    published=True,
    scheduled_ago=60,
    due_in=-10,
    published_ago=60,
    **params,
):
    now = timezone.now()
    return ScheduledTimer.objects.create(
        key=key,
        token=uuid.uuid4().hex,
        job="grace_expired",
        params=params or {"game_id": str(uuid.uuid4()), "user_id": 1},
        due_at=now + timedelta(seconds=due_in),
        scheduled_at=now - timedelta(seconds=scheduled_ago),
        published_at=(now - timedelta(seconds=published_ago)) if published else None,
    )


class TestLostPublications:
    def test_a_row_that_was_never_published_is_not_scheduled_after_a_few_seconds(
        self, queue
    ):
        _row(published=False, scheduled_ago=60, due_in=30)
        assert not timers.is_scheduled("other:1")

    def test_a_row_being_published_right_now_still_counts(self, queue):
        _row(published=False, scheduled_ago=1, due_in=30)
        assert timers.is_scheduled("other:1")

    def test_the_sweep_republishes_an_unpublished_row_with_the_same_token(self, queue):
        row = _row(published=False, scheduled_ago=60, due_in=30)

        assert timers.sweep() == 1

        ((_topic, payload, delay),) = queue.sent
        assert payload == {"key": "other:1", "token": row.token}
        assert 28 <= delay <= 31  # the remaining time
        assert ScheduledTimer.objects.get(key="other:1").published_at is not None
        assert timers.sweep() == 0  # now published: left alone

    def test_the_sweep_republishes_an_overdue_row_once_and_never_runs_it_twice(
        self, night, queue
    ):
        n = night()
        n.start()
        key = key_of(n, "wave:2")
        ScheduledTimer.objects.filter(key=key).update(
            due_at=timezone.now() - timedelta(seconds=20),
            published_at=timezone.now() - timedelta(seconds=60),
        )
        original = queue.for_key(key)[0][0]
        queue.sent.clear()

        assert timers.sweep() == 1
        assert timers.sweep() == 0  # at most once per 30 s per row

        ((_, payload, delay),) = queue.sent
        assert payload == original  # same key, same token
        assert delay == 0
        # The original message and the re-publication both arrive: one run.
        assert queue_worker.handle_message(original) == "ran"
        assert queue_worker.handle_message(payload) == "stale"
        assert n.refresh().phase == Phase.DISCUSSION

    def test_a_row_only_slightly_overdue_is_left_to_its_message(self, night, queue):
        n = night()
        n.start()
        key = key_of(n, "wave:2")
        ScheduledTimer.objects.filter(key=key).update(
            due_at=timezone.now() - timedelta(seconds=1),
            published_at=timezone.now() - timedelta(seconds=60),
        )
        queue.sent.clear()

        assert timers.sweep() == 0

    def test_a_scoped_sweep_touches_only_that_games_timers(self, night, queue):
        n = night()
        n.start()
        mine = _row(key=f"{n.game.id}:discussion", published=False, due_in=30)
        other = _row(key="someone-else:1", published=False, due_in=30)
        queue.sent.clear()

        assert timers.sweep(services.timer_prefixes(n.game)) == 1

        assert [p["key"] for _, p, _ in queue.sent] == [mine.key]
        assert ScheduledTimer.objects.get(key=other.key).published_at is None

    def test_the_game_state_fetch_repairs_a_timer_that_was_never_published(
        self, night, queue
    ):
        n = night()
        n.start()
        key = key_of(n, "wave:2")
        ScheduledTimer.objects.filter(key=key).update(
            published_at=None, scheduled_at=timezone.now() - timedelta(seconds=60)
        )
        queue.sent.clear()
        n.client.force_authenticate(user=n.users["seer"])

        response = n.client.get(
            reverse("onuw:game-me", kwargs={"game_id": str(n.game.id)})
        )

        assert response.status_code == 200
        assert [p["key"] for _, p, _ in queue.sent] == [key]
        assert ScheduledTimer.objects.get(key=key).published_at is not None

    def test_the_sweep_repairs_a_game_nobody_is_polling(self, night, queue):
        n = night()
        n.start()
        key = key_of(n, "wave:2")
        ScheduledTimer.objects.filter(key=key).update(
            published_at=None, scheduled_at=timezone.now() - timedelta(seconds=60)
        )
        queue.sent.clear()

        assert timers.sweep() == 1
        payload = queue.sent[0][1]
        queue.make_due(key)
        assert queue_worker.handle_message(payload) == "ran"
        assert n.refresh().phase == Phase.DISCUSSION

    def test_the_memory_backend_sweep_re_arms_threads_this_process_lacks(
        self, settings
    ):
        settings.ONUW_TIMER_BACKEND = "memory"
        row = _row(key="mem:1", published=True, due_in=600)
        assert not timers.is_scheduled("mem:1")

        assert timers.sweep() == 1

        assert timers.is_scheduled("mem:1")
        assert ScheduledTimer.objects.get(pk=row.pk).published_at is not None


class TestTheSweepEndpoint:
    URL = "/api/onuw/internal/sweep-timers/"

    def _client(self):
        from rest_framework.test import APIClient

        return APIClient()

    def test_it_refuses_without_the_secret(self, settings):
        settings.ONUW_CRON_SECRET = "s3cret"
        assert self._client().post(self.URL).status_code == 403
        assert self._client().get(self.URL).status_code == 403

    def test_it_refuses_a_wrong_secret(self, settings):
        settings.ONUW_CRON_SECRET = "s3cret"
        client = self._client()
        assert (
            client.post(self.URL, HTTP_AUTHORIZATION="Bearer nope").status_code == 403
        )
        assert client.post(self.URL, HTTP_AUTHORIZATION="s3cret").status_code == 403

    def test_it_refuses_everything_when_no_secret_is_configured(self, settings):
        settings.ONUW_CRON_SECRET = ""
        client = self._client()
        assert client.post(self.URL, HTTP_AUTHORIZATION="Bearer ").status_code == 403
        assert client.post(self.URL).status_code == 403

    def test_the_right_secret_sweeps_everything_by_get_or_post(self, queue, settings):
        settings.ONUW_CRON_SECRET = "s3cret"
        _row(key="a:1", published=False, due_in=30)
        _row(key="b:1", published=False, due_in=30)
        client = self._client()

        first = client.get(self.URL, HTTP_AUTHORIZATION="Bearer s3cret")
        second = client.post(self.URL, HTTP_AUTHORIZATION="Bearer s3cret")

        assert (first.status_code, first.data) == (200, {"republished": 2})
        assert (second.status_code, second.data) == (200, {"republished": 0})
        assert sorted(p["key"] for _, p, _ in queue.sent) == ["a:1", "b:1"]


# ── presence checks: locks and ordering ──────────────────────────────────────


class TestPresenceCheckLocking:
    def test_a_healthy_game_check_takes_no_game_lock(self, night, queue):
        n = night()
        n.start()
        user_id = n.users["seer"].id
        with n.committed():
            services.register_connection(n.game.id, user_id, "chan-h")

        with patch(
            "apps.onuw.services._lock_game_and_player",
            side_effect=AssertionError("must not lock"),
        ):
            assert services.check_game_presence(n.game.id, user_id) is False

        key = presence.check_key("game", n.game.id, user_id)
        assert ScheduledTimer.objects.filter(key=key).exists()  # re-armed

    def test_a_healthy_lobby_check_takes_no_lobby_lock(self, night, queue):
        n = night()
        code = Lobby.objects.get(pk=n.game.lobby_id).code
        user_id = n.users["seer"].id
        with n.committed():
            host.register_lobby_connection(code, user_id, "chan-l")

        with patch("apps.onuw.host._lock", side_effect=AssertionError("must not lock")):
            assert host.check_lobby_presence(n.game.lobby_id, user_id) is False

    def test_host_handover_runs_only_after_the_presence_transaction_committed(
        self, night, queue
    ):
        from django.db import connection

        n = night()
        n.start()
        user_id = n.users["seer"].id
        key = presence.check_key("game", n.game.id, user_id)
        with n.committed():
            services.register_connection(n.game.id, user_id, "chan-c")
        SocketPresence.objects.update(last_seen=timezone.now() - timedelta(seconds=100))
        queue.make_due(key)
        seen: list[tuple[bool, bool]] = []

        def spy(game_id, uid, connected):
            seen.append((connection.in_atomic_block, connected))

        with patch("apps.onuw.host.game_presence_changed", side_effect=spy):
            assert queue.deliver(key) == "ran"

        assert seen == [(False, False)]  # called once, outside any transaction

    def test_a_presence_check_that_meets_a_deleted_lobby_does_nothing(
        self, night, queue
    ):
        n = night()
        n.start()
        Lobby.objects.filter(pk=n.game.lobby_id).update(status=Lobby.Status.WAITING)
        code = Lobby.objects.get(pk=n.game.lobby_id).code
        lobby_id, game_id = n.game.lobby_id, n.game.id
        seer = n.users["seer"].id
        with n.committed():
            host.register_lobby_connection(code, seer, "chan-d1")
            services.register_connection(game_id, seer, "chan-d2")
        SocketPresence.objects.update(last_seen=timezone.now() - timedelta(seconds=100))

        # The owner leaves: the lobby (and its game and sockets) go away.
        n.client.force_authenticate(user=n.host)
        from django.db import connection
        from django.test.utils import CaptureQueriesContext

        with CaptureQueriesContext(connection) as ctx:
            response = n.client.post(reverse("core:lobby-leave", kwargs={"code": code}))
        assert response.status_code == 200
        sqls = [q["sql"] for q in ctx.captured_queries]
        lock_at = next(
            i for i, q in enumerate(sqls) if "FOR UPDATE" in q and "core_lobby" in q
        )
        delete_at = next(
            i for i, q in enumerate(sqls) if q.startswith('DELETE FROM "core_lobby"')
        )
        assert lock_at < delete_at  # the lobby row is locked before anything is deleted

        # A check that was already queued now finds nothing and does nothing.
        assert host.check_lobby_presence(lobby_id, seer) is False
        assert services.check_game_presence(game_id, seer) is False
        assert not Game.objects.filter(pk=game_id).exists()


# ── the database clock ───────────────────────────────────────────────────────


class TestInstanceClockSkew:
    def test_an_instance_clock_hours_ahead_cannot_mark_a_live_player_gone(
        self, night, queue
    ):
        n = night()
        n.start()
        user_id = n.users["seer"].id
        with n.committed():
            services.register_connection(n.game.id, user_id, "chan-k")
        future = timezone.now() + timedelta(hours=3)

        with patch("django.utils.timezone.now", return_value=future):
            assert presence.connected_user_ids(game_id=n.game.id) == {user_id}
            assert services.check_game_presence(n.game.id, user_id) is False
        assert (
            PlayerRole.objects.get(game=n.game, user_id=user_id).disconnected_at is None
        )

    def test_an_instance_clock_hours_behind_cannot_keep_a_dead_socket_alive(
        self, night, queue
    ):
        n = night()
        n.start()
        user_id = n.users["seer"].id
        with n.committed():
            services.register_connection(n.game.id, user_id, "chan-k2")
        SocketPresence.objects.update(last_seen=timezone.now() - timedelta(seconds=100))
        past = timezone.now() - timedelta(hours=3)

        with patch("django.utils.timezone.now", return_value=past):
            assert presence.connected_user_ids(game_id=n.game.id) == set()

    def test_what_is_due_is_decided_by_the_database_clock_not_the_instances(
        self, night, queue
    ):
        n = night()
        n.start()
        key = key_of(n, "wave:2")
        token = ScheduledTimer.objects.get(key=key).token

        with patch(
            "django.utils.timezone.now",
            return_value=timezone.now() + timedelta(hours=3),
        ):
            assert timers.fire(key, token).status == "early"  # not due by the DB clock
        queue.make_due(key)
        with patch(
            "django.utils.timezone.now",
            return_value=timezone.now() - timedelta(hours=3),
        ):
            assert timers.fire(key, token).status == "ran"  # due by the DB clock
