"""
Waiting for the memory backend's timer threads, for ``uses_timers`` tests.

A timer thread runs its job INSIDE the transaction that claims and deletes the
row (``timers.fire``), so whatever the job records (a list it appends to, a
mock it calls) is visible before that transaction commits: a test that waits
for the job's effect and then looks at the table can still see the row. Wait
for the thread itself instead: once it has ended, its transaction has committed
or rolled back, and any thread it armed in its place (an early message, a retry)
is followed too. Never wait a fixed time or poll a side effect.
"""

import threading
import time

from apps.core import timers

# Only a hung thread gets near this; a healthy one ends in milliseconds.
TIMEOUT_SECONDS = 30.0


def armed(key: str) -> threading.Timer:
    """The thread registered for ``key`` now (fails if there is none)."""
    with timers._lock:
        thread = timers._registry.get(key)
    assert thread is not None, f"no timer thread is armed for {key!r}"
    return thread


def settle(key: str, timeout: float = TIMEOUT_SECONDS) -> None:
    """Return once no thread for ``key`` is waiting or running.

    Joins the registered thread, then whatever thread replaced it while it ran
    (``_thread_fire`` re-arms an early or failed firing), until the registered
    one has ended. A key with no thread returns at once.
    """
    end = time.monotonic() + timeout
    while True:
        with timers._lock:
            thread = timers._registry.get(key)
        if thread is None:
            return
        join(thread, max(0.0, end - time.monotonic()))
        with timers._lock:
            if timers._registry.get(key) is thread:
                return


def join(thread: threading.Thread, timeout: float = TIMEOUT_SECONDS) -> None:
    """Wait for one thread to end (a cancelled timer ends without running)."""
    thread.join(timeout)
    assert not thread.is_alive(), f"timer thread still running after {timeout}s"
