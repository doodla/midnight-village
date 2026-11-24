#!/usr/bin/env python3
"""The pictures of a hand-over (tool/handover.py): every screen state a change
reaches, drawn from this change and from main at a phone's two sizes, and the
contact sheets of the ones that changed (frontend/tool/handover_sheet.py).
"""

import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SIZES = ((412, 915), (360, 640))


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args],
        capture_output=True,
        text=True,
        errors="replace",
        check=check,
    )


def reached_states(changed: list[str], screens) -> tuple[list[str], str]:
    """(every catalogue state this change can reach, why when that is all of them)."""
    drawn = [c for c in changed if c.startswith("frontend/")]
    if not any(
        c.startswith(("frontend/lib/", "frontend/assets/", "frontend/test_screens/"))
        for c in drawn
    ):
        return [], ""
    widgets = screens.state_widgets()
    states, why_all = screens.states_for(
        drawn, widgets, screens.owners(), screens.importers()
    )
    return (sorted(widgets) if states is None else sorted(states)), why_all


def base_checkout(base: str) -> Path:
    """main, as this branch left it, checked out once and reused (as `just look`)."""
    held = ROOT / "frontend" / "build" / "look" / "base"
    at = subprocess.run(
        ["git", "-C", str(held), "rev-parse", "HEAD"], capture_output=True, text=True
    )
    if at.stdout.strip() != base:
        git("worktree", "remove", "--force", str(held), check=False)
        git("worktree", "prune", check=False)
        held.parent.mkdir(parents=True, exist_ok=True)
        git("worktree", "add", "-q", "--detach", str(held), base)
    look = "frontend/test_screens/look_test.dart"
    (held / look).write_text((ROOT / look).read_text())
    return held


def draw(
    checkout: Path, states: list[str], width: int, height: int, out: Path, what: str
) -> bool:
    out.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    # into a file, never a pipe: the test prints more than a pipe holds, and a
    # full pipe nobody reads stops the run for good
    log = out.parent / f"{out.name}.log"
    done = subprocess.Popen(
        [
            "flutter",
            "test",
            "test_screens/look_test.dart",
            "--reporter",
            "failures-only",
            "--dart-define=ENV=dev",
            f"--dart-define=LOOK_STATES={','.join(states)}",
            f"--dart-define=LOOK_WIDTH={width}",
            f"--dart-define=LOOK_HEIGHT={height}",
            f"--dart-define=LOOK_OUT={out}",
        ],
        cwd=checkout / "frontend",
        stdout=log.open("w"),
        stderr=subprocess.STDOUT,
    )
    while True:
        try:
            done.wait(timeout=30)
            break
        except subprocess.TimeoutExpired:
            print(
                f"   ... still drawing after {time.monotonic() - started:.0f} s: {what}",
                flush=True,
            )
    if done.returncode != 0:
        print(log.read_text(errors="replace")[-1500:], file=sys.stderr)
    return done.returncode == 0


def pictures(states: list[str], base: str, out: Path) -> dict:
    """Draws `states` from this change and from main at each size, then the sheets.
    {"changed": [...], "missing": [...], "sheets": [...], "new": [...]}"""
    run = out / "run"
    subprocess.run(["rm", "-rf", str(run)])
    held = base_checkout(base)
    for width, height in SIZES:
        size = f"{width}x{height}"
        print(
            f"== drawing {len(states)} states at {size}: this change, then main",
            flush=True,
        )
        draw(
            ROOT, states, width, height, run / size / "after", f"this change at {size}"
        )
        draw(held, states, width, height, run / size / "before", f"main at {size}")
    made = subprocess.run(
        [
            "uv",
            "run",
            "--quiet",
            "--with",
            "pillow",
            "python",
            "tool/handover_sheet.py",
            str(run),
            str(out),
            *states,
        ],
        cwd=ROOT / "frontend",
        capture_output=True,
        text=True,
    )
    if made.returncode != 0:
        print(made.stderr[-1500:], file=sys.stderr)
        return {"changed": [], "missing": states, "sheets": [], "new": []}
    return json.loads(made.stdout)
