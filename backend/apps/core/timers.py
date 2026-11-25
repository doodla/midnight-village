"""
Durable, backend-neutral timers for ONUW.

A timer is a *named job with JSON parameters* due at a time, stored in a DB row
(``ScheduledTimer``: unique ``key``, random ``token``, ``due_at``, ``job``,
``params``). Callers use::

    timers.schedule(key, delay_seconds, job="night_window", params={...})
    timers.cancel(key) / timers.cancel_all_for_game(game_id)
    timers.is_scheduled(key)

and handlers register under a job name with ``@timers.job("name")``.

How a timer fires depends on the backend (setting ``ONUW_TIMER_BACKEND``):

* ``"memory"`` (default: dev, tests, the harness): a ``threading.Timer`` in this
  process carrying ``(key, token)``. Lost with the process, so start-up recovery
  re-derives or re-arms from the table (``recovery.recover_timers``).
* ``"vercel_queue"``: a delayed queue message ``{"key", "token"}``; nothing
  stays in this process, so any instance (the subscriber in
  ``apps/core/queue_worker.py``) may fire it. A queued message cannot be
  cancelled and delivery is at-least-once, which is why firing is guarded by
  the row.

Firing (``fire``) from any backend: lock the row, run only if it still exists
with the same token and is due (a little clock skew is tolerated), delete the
row in the SAME transaction that claims it, run the job in that transaction. A
stale token, a cancelled key or a duplicate delivery therefore does nothing and
two instances cannot both run a timer. The handlers' own phase / window checks
stay as a second guard.

All "now" comparisons use the DATABASE clock (``Now()``), never an instance
clock: ``due_at`` and ``scheduled_at`` are written with it and ``fire`` compares
against it, so instances with skewed clocks agree on what is due.

A row records whether its firing was handed to the backend (``published_at``:
set only after the queue send returned / the thread was armed). A row that was
never published, or whose message evidently never ran it, is repaired by
``sweep`` (re-publishing the SAME token: a duplicate is harmless because of the
claim), which the lazy ``/me/`` path calls for its game and a platform cron
calls for everything.

Key format: "{game_id}:discussion", "{game_id}:voting", "{game_id}:wave:{n}",
"{game_id}:grace:{user_id}", "lobby:{lobby_id}:host" and
"presence:{game|lobby}:{id}:{user_id}".
"""

import logging
import math
import threading
import time
import uuid
from collections.abc import Callable
from datetime import timedelta
from typing import Any, NamedTuple

from django.conf import settings
from django.db import connections, transaction
from django.db.models import F, Q
from django.db.models.functions import Now

logger = logging.getLogger(__name__)

# In-process threads of the memory backend (key -> Timer; the Timer's args hold
# (key, token)). Guarded by _lock.
_registry: dict[str, threading.Timer] = {}
_lock = threading.Lock()

# Job name -> handler(**params). Filled by @job at import of the handler modules.
JOBS: dict[str, Callable[..., None]] = {}

# A message may arrive this much before its row is due (clock skew between the
# instance that scheduled it and the one that fires it) and still run.
CLOCK_SKEW_SECONDS = 2.0

# Queue backend: a row this long past its due time whose message never ran it
# (lost, or its job kept failing) no longer counts as scheduled, so the lazy
# repair (recovery.ensure_timers) can re-create the timer.
OVERDUE_AFTER_SECONDS = 120.0
# A row that has not been published for this long is not "scheduled" (an
# instance died between the row and the send): sweep / the lazy repair publish it.
PUBLISH_GRACE_SECONDS = 5.0
# The sweep re-publishes a published row once it is this far past due...
SWEEP_OVERDUE_SECONDS = 5.0
# ...and at most this often per row.
SWEEP_REPUBLISH_EVERY_SECONDS = 30.0
# A failing job is retried: after this long, at most this many times in all.
RETRY_DELAY_SECONDS = 5.0
MAX_ATTEMPTS = 5

BACKEND_MEMORY = "memory"
BACKEND_QUEUE = "vercel_queue"
DEFAULT_QUEUE_TOPIC = "onuw-timers"


# ── Jobs ────────────────────────────────────────────────────────────────────


def job(name: str) -> Callable[[Callable[..., None]], Callable[..., None]]:
    """Register a handler for a job name: ``handler(**params)``."""

    def register(func: Callable[..., None]) -> Callable[..., None]:
        JOBS[name] = func
        return func

    return register


# Modules that register jobs with @job. The core ones are always loaded; each
# game app adds its own from its AppConfig.ready() (register_job_module).
JOB_MODULES: list[str] = ["apps.core.host", "apps.core.presence"]


def register_job_module(module: str) -> None:
    """Register a module whose import defines timer jobs (idempotent)."""
    if module not in JOB_MODULES:
        JOB_MODULES.append(module)


def load_jobs() -> None:
    """Import every registered job module (idempotent)."""
    import importlib

    for module in JOB_MODULES:
        importlib.import_module(module)


def run_job(name: str, params: dict[str, Any] | None = None) -> None:
    """Run a registered job now (no row involved). A failing job RAISES: that
    is what makes ``fire`` roll back and keep the timer for a retry."""
    load_jobs()
    handler = JOBS.get(name)
    if handler is None:
        logger.error("Timer job %r is not registered; dropping it.", name)
        return
    handler(**(params or {}))


def run_job_quietly(name: str, params: dict[str, Any] | None = None) -> None:
    """``run_job`` that logs and swallows a failure (for tests' fake schedulers,
    which stand in for a timer thread that must never raise)."""
    try:
        run_job(name, params)
    except Exception:
        logger.exception("Timer job %s failed", name)


# ── Backend ─────────────────────────────────────────────────────────────────


def backend() -> str:
    return getattr(settings, "ONUW_TIMER_BACKEND", BACKEND_MEMORY)


def queue_topic() -> str:
    return getattr(settings, "ONUW_TIMER_QUEUE_TOPIC", DEFAULT_QUEUE_TOPIC)


def _send_to_vercel(topic: str, payload: dict[str, Any], delay_seconds: float) -> None:
    """The real sender: Vercel Queues (the package is imported only here)."""
    from asgiref.sync import async_to_sync

    # pyrefly: ignore [missing-import]
    from vercel.queue import send

    async_to_sync(send)(topic, payload, delay=max(0, math.ceil(delay_seconds)))


# Replaceable in tests: sender(topic, payload, delay_seconds).
_queue_sender: Callable[[str, dict[str, Any], float], None] = _send_to_vercel


def set_queue_sender(sender: Callable[[str, dict[str, Any], float], None] | None):
    """Swap the queue sender (tests); None restores the Vercel one."""
    global _queue_sender
    previous = _queue_sender
    _queue_sender = sender or _send_to_vercel
    return previous


def send_message(key: str, token: str, delay_seconds: float) -> None:
    """Publish one delayed ``{key, token}`` message (queue backend)."""
    from apps.core import server_timing

    began = time.perf_counter()
    _queue_sender(queue_topic(), {"key": key, "token": token}, delay_seconds)
    server_timing.note("queue", time.perf_counter() - began)


def _arm(key: str, token: str, delay_seconds: float) -> None:
    """Make something call ``fire(key, token)`` after the delay."""
    if backend() == BACKEND_QUEUE:
        send_message(key, token, delay_seconds)
        return
    _arm_thread(key, token, delay_seconds)


def _arm_thread(key: str, token: str, delay_seconds: float, attempt: int = 1) -> None:
    with _lock:
        old = _registry.get(key)
        if old is not None:
            old.cancel()
        timer = threading.Timer(delay_seconds, _thread_fire, args=(key, token, attempt))
        timer.daemon = True
        _registry[key] = timer
        timer.start()


def release_connections() -> None:
    """Close this thread's idle database connections.

    Used where nothing should stay open afterwards (timer threads, queue
    messages, presence heartbeats). A connection inside an atomic block (a test
    transaction, a caller's transaction) is left alone.
    """
    for conn in connections.all():
        if not conn.in_atomic_block:
            conn.close()


def _thread_fire(key: str, token: str, attempt: int = 1) -> None:
    """Entry point of a memory-backend timer thread.

    A job that raises left its row in place (``fire`` rolled back): try again
    after a short delay, a capped number of times, so a permanently failing job
    cannot spin. After the last attempt the row stays for the sweep / lazy repair.
    """
    try:
        result = fire(key, token)
        if result.status == "early":
            _arm_thread(key, token, result.remaining, attempt)
    except Exception:
        if attempt < MAX_ATTEMPTS:
            logger.exception("Timer %s failed (attempt %d); retrying", key, attempt)
            _arm_thread(key, token, RETRY_DELAY_SECONDS, attempt + 1)
        else:
            logger.exception(
                "Timer %s failed %d times; leaving it for the sweep", key, attempt
            )
    finally:
        release_connections()


# ── The table ───────────────────────────────────────────────────────────────


def schedule(
    key: str,
    delay_seconds: float,
    job: str,
    params: dict[str, Any] | None = None,
) -> None:
    """Schedule (or replace) the timer under ``key``.

    Upserts the row with a fresh token (so any earlier thread / message for the
    key is now stale), then arms the backend. Callers run this after their
    transaction commits.
    """
    from apps.core.models import ScheduledTimer

    load_jobs()
    if job not in JOBS:
        raise ValueError(f"Unknown timer job: {job!r}")
    delay = max(0.0, float(delay_seconds))
    token = uuid.uuid4().hex
    ScheduledTimer.objects.update_or_create(
        key=key,
        defaults={
            "token": token,
            "job": job,
            "params": params or {},
            "due_at": Now() + timedelta(seconds=delay),
            "scheduled_at": Now(),
            "published_at": None,
        },
    )
    try:
        _arm(key, token, delay)
    except Exception:
        # Nothing will ever fire this row (the message could not be sent): drop
        # it, so the lazy repair sees the timer as missing and schedules it again.
        ScheduledTimer.objects.filter(key=key, token=token).delete()
        raise
    _mark_published(key, token)


def _mark_published(key: str, token: str) -> None:
    """Record that the firing was handed to the backend (set only after the send
    returned, so a crash in between leaves an unpublished row the sweep finds)."""
    from apps.core.models import ScheduledTimer

    ScheduledTimer.objects.filter(key=key, token=token).update(published_at=Now())


def _cancel_thread(key: str) -> None:
    with _lock:
        timer = _registry.pop(key, None)
        if timer is not None:
            timer.cancel()


def cancel(key: str) -> None:
    """Cancel the timer under ``key`` (no-op if there is none).

    Deleting the row is what cancels: a thread or queued message that still
    arrives finds no row and does nothing.
    """
    from apps.core.models import ScheduledTimer

    ScheduledTimer.objects.filter(key=key).delete()
    _cancel_thread(key)


def cancel_all_for_game(game_id: int | str) -> None:
    """Cancel every timer whose key starts with "{game_id}:"."""
    from apps.core.models import ScheduledTimer

    prefix = f"{game_id}:"
    ScheduledTimer.objects.filter(key__startswith=prefix).delete()
    with _lock:
        for key in [k for k in _registry if k.startswith(prefix)]:
            _registry.pop(key).cancel()


def _live_token(key: str) -> str | None:
    with _lock:
        timer = _registry.get(key)
        if timer is None or not timer.is_alive() or timer.finished.is_set():
            return None
        return timer.args[1]  # pyrefly: ignore [bad-index]


def _seconds(value) -> float:
    return value.total_seconds()


def is_scheduled(key: str) -> bool:
    """True if a timer is pending under ``key``.

    The row must exist. With the memory backend it must also be armed in THIS
    process (a row left by a dead process is not armed: start-up recovery, the
    sweep or the lazy repair re-arms it). With the queue backend the row must
    have been published (or be younger than ``PUBLISH_GRACE_SECONDS``: its send
    may be in flight) and not be more than ``OVERDUE_AFTER_SECONDS`` past due.
    """
    from apps.core.models import ScheduledTimer

    row = (
        ScheduledTimer.objects.filter(key=key)
        .annotate(
            since_scheduled=Now() - F("scheduled_at"), overdue=Now() - F("due_at")
        )
        .values("token", "published_at", "since_scheduled", "overdue")
        .first()
    )
    if row is None:
        return False
    if backend() == BACKEND_QUEUE:
        if (
            row["published_at"] is None
            and _seconds(row["since_scheduled"]) > PUBLISH_GRACE_SECONDS
        ):
            return False
        return _seconds(row["overdue"]) < OVERDUE_AFTER_SECONDS
    return _live_token(key) == row["token"]


class FireResult(NamedTuple):
    """Outcome of a firing: "ran", "stale" (nothing to do) or "early"."""

    status: str
    remaining: float = 0.0


def fire(key: str, token: str | None, *, force: bool = False) -> FireResult:
    """Claim the timer and run its job, at most once.

    ``token`` must match the row (``None`` matches any: the debug hook). Runs
    only when due, within the skew tolerance, unless ``force``. The row is
    deleted in the transaction that claims it and the job runs inside it, so a
    failing job leaves the timer for the next delivery.
    """
    from apps.core.models import ScheduledTimer

    with transaction.atomic():
        row = ScheduledTimer.objects.select_for_update().filter(key=key).first()
        if row is None or (token is not None and row.token != token):
            return FireResult("stale")
        remaining = _seconds_until_due(row.pk)
        if not force and remaining > CLOCK_SKEW_SECONDS:
            return FireResult("early", remaining)
        row.delete()
        _cancel_thread_if_other(key, row.token)
        run_job(row.job, row.params)
    return FireResult("ran")


def _seconds_until_due(pk: int) -> float:
    """Seconds until the row is due, by the database clock."""
    from apps.core.models import ScheduledTimer

    value = (
        ScheduledTimer.objects.filter(pk=pk)
        .annotate(remaining=F("due_at") - Now())
        .values_list("remaining", flat=True)
        .first()
    )
    return _seconds(value) if value is not None else 0.0


def _cancel_thread_if_other(key: str, token: str) -> None:
    """After claiming, drop a still-armed thread for the key (the debug hook
    fires early; the thread's own claim would find no row anyway)."""
    with _lock:
        timer = _registry.get(key)
        if (
            timer is not None
            and timer.args[1] == token  # pyrefly: ignore [bad-index]
            and not timer.finished.is_set()
        ):
            if threading.current_thread() is not timer:
                timer.cancel()
                _registry.pop(key, None)


def _scope(queryset, prefixes: tuple[str, ...] | None):
    if not prefixes:
        return queryset
    condition = Q()
    for prefix in prefixes:
        condition |= Q(key__startswith=prefix)
    return queryset.filter(condition)


def rearm_from_table(prefixes: tuple[str, ...] | None = None) -> int:
    """Memory backend: arm a thread for every stored timer (optionally only
    keys with these prefixes) that has none in this process; overdue ones fire
    at once. Returns how many were armed. After a restart derived plans
    (``recovery.recover_timers``) run first, so this only picks up what they do
    not know how to derive."""
    from apps.core.models import ScheduledTimer

    if backend() != BACKEND_MEMORY:
        return 0
    armed = 0
    rows = _scope(
        ScheduledTimer.objects.annotate(remaining=F("due_at") - Now()), prefixes
    )
    for row in rows:
        if _live_token(row.key) == row.token:
            continue
        _arm_thread(row.key, row.token, max(0.0, _seconds(row.remaining)))
        _mark_published(row.key, row.token)
        armed += 1
    return armed


def sweep(prefixes: tuple[str, ...] | None = None) -> int:
    """Repair timers whose firing was lost; returns how many were re-published.

    Queue backend: re-send the message, with the SAME token (a duplicate is
    harmless: the claim lets only one run), for (a) rows never published for
    more than ``PUBLISH_GRACE_SECONDS`` (the instance died between the row and
    the send, or the send failed) and (b) published rows more than
    ``SWEEP_OVERDUE_SECONDS`` past due whose message evidently never ran them
    (re-sent at most every ``SWEEP_REPUBLISH_EVERY_SECONDS`` per row). Memory
    backend: re-arm the threads this process does not have.

    Scoped to key prefixes for the lazy ``/me/`` path (one cheap query when
    nothing is wrong); unscoped for the platform cron.
    """
    from apps.core.models import ScheduledTimer

    if backend() != BACKEND_QUEUE:
        return rearm_from_table(prefixes)

    rows = _scope(
        ScheduledTimer.objects.annotate(
            since_scheduled=Now() - F("scheduled_at"),
            overdue=Now() - F("due_at"),
            since_published=Now() - F("published_at"),
        ),
        prefixes,
    ).filter(
        Q(
            published_at__isnull=True,
            since_scheduled__gt=timedelta(seconds=PUBLISH_GRACE_SECONDS),
        )
        | Q(
            overdue__gt=timedelta(seconds=SWEEP_OVERDUE_SECONDS),
            published_at__isnull=False,
            since_published__gt=timedelta(seconds=SWEEP_REPUBLISH_EVERY_SECONDS),
        )
    )
    sent = 0
    for row in rows:
        try:
            send_message(row.key, row.token, max(0.0, -_seconds(row.overdue)))
        except Exception:
            logger.exception("Could not re-publish timer %s", row.key)
            continue
        _mark_published(row.key, row.token)
        sent += 1
    return sent
