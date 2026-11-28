# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""No request and no timer job waits (CLAUDE.md: no added waits or minimum response times).

Every test runs under ``no_waits`` (``tests/conftest.py``, autouse): while the server
answers a request (Django's ``request_started`` to ``request_finished``) or runs a timer
job (``apps.core.timers.run_job``, the one runner every backend and every test's fake
scheduler calls), ``time.sleep`` and ``asyncio.sleep`` fail the test that made it, with
the file and line of the sleep. ``pytest.fail`` is not an ``Exception``, so no
``except Exception`` in the server can swallow it. Elsewhere (a socket's own heartbeat,
a test) they sleep as usual.

What it cannot see: a wait made another way (a busy loop, an ``Event.wait``), or a sleep
bound before the patch (``from time import sleep`` at import).
"""

from __future__ import annotations

import asyncio
import contextvars
import sys
import time
from collections.abc import Generator
from unittest.mock import patch

from django.core.signals import request_finished, request_started

import pytest

_ANSWERING: contextvars.ContextVar[str | None] = contextvars.ContextVar(
    "answering", default=None
)
_sleep = time.sleep
_async_sleep = asyncio.sleep


def _refuse(seconds: float) -> None:
    what = _ANSWERING.get()
    if what is None:
        return
    caller = sys._getframe(2)
    pytest.fail(
        f"{caller.f_code.co_filename.split('/backend/')[-1]}:{caller.f_lineno}: slept"
        f" {seconds} s while {what}. No added waits: every length is the table's"
        " setting (CLAUDE.md). Fix: take the sleep out."
    )


def _watched_sleep(seconds: float) -> None:
    _refuse(seconds)
    _sleep(seconds)


async def _watched_async_sleep(seconds: float, *args, **kwargs):
    _refuse(seconds)
    return await _async_sleep(seconds, *args, **kwargs)


def _started(**_kwargs) -> None:
    _ANSWERING.set("answering a request")


def _finished(**_kwargs) -> None:
    _ANSWERING.set(None)


@pytest.fixture(autouse=True)
def no_waits() -> Generator[None]:
    from apps.core import timers

    run_job = timers.run_job

    def watched_job(name, params=None):
        token = _ANSWERING.set(f"running the timer job {name!r}")
        try:
            return run_job(name, params)
        finally:
            _ANSWERING.reset(token)

    request_started.connect(_started, dispatch_uid="tests.waits.started")
    request_finished.connect(_finished, dispatch_uid="tests.waits.finished")
    token = _ANSWERING.set(None)
    try:
        with (
            patch("time.sleep", new=_watched_sleep),
            patch("asyncio.sleep", new=_watched_async_sleep),
            patch("apps.core.timers.run_job", new=watched_job),
        ):
            yield
    finally:
        _ANSWERING.reset(token)
        request_started.disconnect(dispatch_uid="tests.waits.started")
        request_finished.disconnect(dispatch_uid="tests.waits.finished")
