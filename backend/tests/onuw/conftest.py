"""Shared fixtures for the ONUW tests.

``make_night`` builds a ``Night`` (see test_night_windows.py): a game driven through
the real service and API layers, with channel-layer sends and timer scheduling
recorded (``night.recorder``, ``night.scheduled``) instead of run, and every
on-commit callback run as it would be after a real commit.
"""

import functools
from typing import Any
from unittest.mock import patch

import pytest

from apps.core import timers
from tests.onuw.test_night_windows import Night, _Recorder


@pytest.fixture
def make_night(db, django_capture_on_commit_callbacks):
    """Factory for a Night; channel layer and timers are recorded, not run."""
    recorder = _Recorder()
    scheduled: list[tuple[str, float, Any]] = []

    def fake_schedule(key, delay, job, params=None):
        # Record the timer; calling the callback runs the job as a firing would.
        scheduled.append(
            (key, delay, functools.partial(timers.run_job_quietly, job, params))
        )

    mock_layer = type("Layer", (), {"group_send": recorder.group_send})()
    with (
        patch("apps.core.effects.get_channel_layer", return_value=mock_layer),
        patch("apps.core.effects.async_to_sync", side_effect=lambda f: f),
        patch("apps.core.timers.schedule", side_effect=fake_schedule),
    ):

        def factory(
            roles: dict[str, str],
            center: list[str] | None = None,
            **settings: Any,
        ) -> Night:
            merged = {
                "roles": {},
                "night_min_window_seconds": 0,
                "night_doppelganger_window_seconds": 0,
                **settings,
            }
            return Night(
                roles,
                center or ["Villager", "Tanner", "Hunter"],
                merged,
                recorder,
                scheduled,
                django_capture_on_commit_callbacks,
            )

        yield factory
