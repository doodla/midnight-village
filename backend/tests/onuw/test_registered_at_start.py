"""What the game plugs into the shared machinery is in place in a FRESH process.

A presence scope or a driver that nothing registered is skipped in silence: a
phone whose socket died is never noticed, practice players stop acting. Test
modules import the game's modules themselves, so only a new interpreter shows
what a server instance really has after it starts.
"""

import os
import subprocess
import sys
from pathlib import Path

import pytest

pytestmark = pytest.mark.unit

BACKEND = Path(__file__).resolve().parents[2]
PROBE = """
import django
django.setup()
from apps.core import presence, timers
from apps.onuw import basics
timers.load_jobs()  # what every job run and every schedule does first
print(sorted(presence._SCOPES), basics.practice_driver is not None, sorted(timers.JOBS))
"""


def test_a_fresh_instance_has_the_games_scope_its_jobs_and_the_practice_driver():
    done = subprocess.run(  # noqa: S603 (this interpreter, a fixed script)
        [sys.executable, "-c", PROBE],
        cwd=BACKEND,
        env={**os.environ, "DJANGO_SETTINGS_MODULE": "config.settings.test"},
        capture_output=True,
        text=True,
        check=False,
    )
    assert done.returncode == 0, done.stderr[-2000:]
    out = done.stdout.strip()
    assert out.startswith("['game', 'lobby'] True "), out
    for job in ("presence_check", "grace_expired"):
        assert job in out, out
