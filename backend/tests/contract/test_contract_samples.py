"""The committed contract samples are what the server sends today.

``contract_samples/`` (repo root) holds real response bodies and socket events,
recorded by playing the games in ``scenarios.py`` (then the speed summaries of
``observe_scenarios.py``) through the real views,
services and consumer handlers. The app's tests build their fixtures from those
files, so they can only claim states the server can produce. This test records
everything again in memory and fails if a committed file differs, is missing
or is no longer produced: a change to any payload shows up as a reviewed diff
of the samples.

Regenerate with ``just samples`` (backend or repo root), which runs this test
with ``UPDATE_CONTRACT_SAMPLES=1``: it then writes the files instead of
comparing.
"""

from __future__ import annotations

import difflib
import json
import os
from pathlib import Path
from typing import Any

import pytest
from repo_files import checkout_files

from .observe_scenarios import observe_samples
from .recorder import recording
from .scenarios import record_all

# uses_timers: the recorder keeps real timer rows (it arms no thread).
pytestmark = [pytest.mark.contract, pytest.mark.django_db, pytest.mark.uses_timers]

SAMPLES_DIR = Path(__file__).resolve().parents[3] / "contract_samples"
REGENERATE = "Run `just samples` (in backend/ or the repo root) and review the diff."
SHOWN = 5  # files whose difference is printed in full


def _text(payload: Any) -> str:
    return json.dumps(payload, indent=2, ensure_ascii=False) + "\n"


def _committed() -> dict[str, str]:
    """The server's samples. ``app/`` holds what the APP sends (recorded by the app's
    own tests, e.g. ``field_summary_test.dart``), not the server's: not compared here."""
    return {
        path.relative_to(SAMPLES_DIR).as_posix(): path.read_text(encoding="utf-8")
        for path in checkout_files(SAMPLES_DIR, suffixes=(".json",))
        if path.relative_to(SAMPLES_DIR).parts[0] != "app"
    }


def _write(expected: dict[str, str]) -> None:
    for name in _committed().keys() - expected.keys():
        (SAMPLES_DIR / name).unlink()
    for name, text in expected.items():
        path = SAMPLES_DIR / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")


def _differences(expected: dict[str, str], actual: dict[str, str]) -> list[str]:
    problems = [f"missing: {n}" for n in sorted(expected.keys() - actual.keys())]
    problems += [f"no longer sent: {n}" for n in sorted(actual.keys() - expected)]
    for name in sorted(expected.keys() & actual.keys()):
        if expected[name] != actual[name]:
            diff = difflib.unified_diff(
                actual[name].splitlines(),
                expected[name].splitlines(),
                f"committed/{name}",
                f"server/{name}",
                lineterm="",
                n=2,
            )
            problems.append("\n".join(list(diff)[:40]))
    return problems


def test_committed_samples_match_what_the_server_sends(
    django_capture_on_commit_callbacks: Any,
) -> None:
    with recording(django_capture_on_commit_callbacks) as run:
        record_all(run)
        observe_samples(run)
    expected = {name: _text(p) for name, p in run.recorder.rendered().items()}

    if os.environ.get("UPDATE_CONTRACT_SAMPLES"):
        _write(expected)
        return

    problems = _differences(expected, _committed())
    assert not problems, (
        f"contract_samples/ is out of date with the server: {len(problems)} "
        f"file(s) differ. {REGENERATE}\n\n"
        + "\n\n".join(problems[:SHOWN])
        + (f"\n\n... and {len(problems) - SHOWN} more" if len(problems) > SHOWN else "")
    )
