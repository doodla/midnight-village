"""Two requests scheduling the same timer at the same moment.

It happens in play: a phone's socket closes while a stage change plans the same
player's grace timer. Both miss the row and both INSERT; the database refuses the
second (and logs a duplicate key error, the only trace). Neither caller may see
that: the later schedule wins and one row is left.
"""

import threading
from unittest.mock import patch

from django.db import connection

import pytest

from apps.core import timers
from apps.core.models import ScheduledTimer

pytestmark = [pytest.mark.integration, pytest.mark.django_db(transaction=True)]


@pytest.mark.uses_timers
def test_two_schedules_of_one_key_at_once_both_return_and_leave_one_row():
    timers.JOBS.setdefault("same_key_test_job", lambda **_: None)
    key = "game-1:grace:7"
    together = threading.Barrier(2, timeout=10)
    real_get = ScheduledTimer.objects.get_queryset().__class__.get
    errors: list[BaseException] = []

    def get_then_wait(self, *args, **kwargs):
        """Both threads look for the row before either creates it."""
        try:
            return real_get(self, *args, **kwargs)
        except ScheduledTimer.DoesNotExist:
            try:
                together.wait()
            except threading.BrokenBarrierError:
                pass
            raise

    def schedule(seconds: int) -> None:
        try:
            timers.schedule(key, seconds, "same_key_test_job", {"n": seconds})
        except BaseException as error:
            errors.append(error)
        finally:
            connection.close()

    try:
        with (
            patch.object(
                ScheduledTimer.objects.get_queryset().__class__, "get", get_then_wait
            ),
            patch(
                "apps.core.timers._arm"
            ),  # no thread or message: the row is the subject
        ):
            threads = [
                threading.Thread(target=schedule, args=(n,)) for n in (3600, 7200)
            ]
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join(timeout=20)
        assert errors == []
        rows = list(ScheduledTimer.objects.filter(key=key))
        assert len(rows) == 1
        assert rows[0].params["n"] in (3600, 7200)
        assert rows[0].published_at is not None  # the winner's token is the row's
    finally:
        timers.JOBS.pop("same_key_test_job", None)
        ScheduledTimer.objects.filter(key=key).delete()
