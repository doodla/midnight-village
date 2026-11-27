"""The heavy queue (tool/heavy.py): a counting queue that never lets a child hold a slot.

Every test has its own state folder (`HEAVY_DIR`), so none touches the real queue.
Waits are for a thing to happen (a file to appear, a process to be gone), never for time.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HEAVY = ROOT / "tool" / "heavy.py"
sys.path.insert(0, str(ROOT / "tool"))
import heavy  # noqa: E402


def until(condition, what, seconds=20.0):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        if condition():
            return
        time.sleep(0.02)
    raise AssertionError(f"never happened: {what}")


class Queue(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.env = {
            **{
                k: v
                for k, v in os.environ.items()
                if k not in ("CI", "HEAVY_SLOT", "HEAVY_SAY_FD")
            },
            "HEAVY_DIR": str(self.tmp / "state"),
            "HEAVY_SLOTS": "2",
            "HEAVY_REPORT": "0.2",
            "HEAVY_SAMPLE": "0.1",
        }
        self.started = []

    def tearDown(self):
        for process in self.started:
            if process.poll() is None:
                process.kill()
            process.wait()
        shutil.rmtree(self.tmp, ignore_errors=True)

    def start(self, *command, name="job", env=None):
        """heavy running `command`, not waited for."""
        process = subprocess.Popen(
            [sys.executable, str(HEAVY), "--name", name, "--", *command],
            env={**self.env, **(env or {})},
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        self.started.append(process)
        return process

    def holder(self, name):
        """A job that holds its slot until `<name>.go` exists, and says when it has it."""
        go, held = self.tmp / f"{name}.go", self.tmp / f"{name}.held"
        code = f"import pathlib,time; pathlib.Path({str(held)!r}).write_text('x')\nwhile not pathlib.Path({str(go)!r}).exists(): time.sleep(0.02)"
        return self.start(sys.executable, "-c", code, name=name), held, go

    def status(self):
        done = subprocess.run(
            [sys.executable, str(HEAVY), "--status"],
            env=self.env,
            capture_output=True,
            text=True,
        )
        return done.stdout

    def test_only_as_many_run_at_once_as_there_are_slots(self):
        a, a_held, a_go = self.holder("a")
        b, b_held, b_go = self.holder("b")
        until(
            lambda: a_held.exists() and b_held.exists(), "two jobs hold the two slots"
        )
        c, c_held, c_go = self.holder("c")
        until(lambda: "waiting 1" in self.status(), "the third waits")
        self.assertFalse(c_held.exists(), "the third ran with both slots held")
        out = self.status()
        self.assertIn("2 of 2 slots busy, 1 waiting", out)
        self.assertIn("`a`", out)
        self.assertIn("`c`", out)
        a_go.write_text("x")
        until(c_held.exists, "the third runs when a slot is free")
        for go in (b_go, c_go):
            go.write_text("x")
        for process in (a, b, c):
            self.assertEqual(process.wait(timeout=20), 0)

    def test_the_line_is_first_come_first_served(self):
        self.env["HEAVY_SLOTS"] = "1"
        a, a_held, a_go = self.holder("a")
        until(a_held.exists, "a holds the slot")
        b, b_held, b_go = self.holder("b")
        until(lambda: "waiting 1" in self.status(), "b waits")
        c, c_held, c_go = self.holder("c")
        until(lambda: "waiting 2" in self.status(), "c waits behind b")
        a_go.write_text("x")
        until(b_held.exists, "b is next")
        self.assertFalse(c_held.exists())
        b_go.write_text("x")
        until(c_held.exists, "then c")
        c_go.write_text("x")

    def test_waiting_says_where_it_stands_at_once_and_does_not_poll(self):
        self.env["HEAVY_SLOTS"] = "1"
        a, a_held, a_go = self.holder("a")
        until(a_held.exists, "a holds the slot")
        b = self.start("true", name="b")
        until(lambda: "waiting 1" in self.status(), "b waits")
        a_go.write_text("x")
        _, said = b.communicate(timeout=20)
        self.assertRegex(said, r"number 1 in line")
        self.assertIn("`a`", said)
        self.assertIn("run_in_background", said)

    def test_the_exit_code_is_the_commands(self):
        done = self.start(sys.executable, "-c", "raise SystemExit(7)")
        self.assertEqual(done.wait(timeout=20), 7)

    def test_a_command_that_leaves_a_daemon_holds_no_slot_and_the_daemon_is_stopped(
        self,
    ):
        self.env["HEAVY_SLOTS"] = "1"
        marker = self.tmp / "pid"
        done = self.start("bash", "-c", f"sleep 300 & echo $! > {marker}; sleep 0.2")
        _, said = done.communicate(timeout=20)
        self.assertEqual(done.returncode, 0)
        self.assertIn("left 1 process", said)
        pid = int(marker.read_text())
        until(
            lambda: not Path(f"/proc/{pid}").exists()
            or "Z" in Path(f"/proc/{pid}/stat").read_text().split(")")[1][:3],
            "the daemon is gone",
        )
        # and the slot is free at once
        queue = heavy.Queue(self.tmp / "state", 1)
        self.assertEqual(queue.holders(), [])

    def test_a_slot_is_released_when_heavy_is_killed_and_its_command_dies_with_it(self):
        self.env["HEAVY_SLOTS"] = "1"
        marker = self.tmp / "pid"
        process = self.start("bash", "-c", f"echo $$ > {marker}; exec sleep 300")
        until(lambda: marker.exists() and marker.stat().st_size > 0, "the command started")
        pid = int(marker.read_text())
        process.send_signal(signal.SIGKILL)
        process.wait(timeout=20)
        until(lambda: not Path(f"/proc/{pid}").exists(), "the command is gone")
        self.assertEqual(heavy.Queue(self.tmp / "state", 1).holders(), [])

    def test_ctrl_c_reaches_the_whole_command(self):
        marker = self.tmp / "pid"
        process = self.start("bash", "-c", f"sleep 300 & echo $! > {marker}; wait")
        until(lambda: marker.exists() and marker.stat().st_size > 0, "started")
        pid = int(marker.read_text())
        process.send_signal(signal.SIGINT)
        process.wait(timeout=20)
        until(
            lambda: not Path(f"/proc/{pid}").exists(), "the background part is gone too"
        )

    def test_a_command_run_inside_a_slot_runs_at_once(self):
        """A recipe that calls a recipe must not wait for the slot its parent holds."""
        self.env["HEAVY_SLOTS"] = "1"
        a, a_held, a_go = self.holder("a")
        until(a_held.exists, "a holds the only slot")
        inner = self.start("echo", "ran", env={"HEAVY_SLOT": "1"})
        out, _ = inner.communicate(timeout=20)
        self.assertEqual(out.strip(), "ran")
        a_go.write_text("x")

    def test_a_command_run_inside_a_slot_gets_the_variable(self):
        done = self.start("printenv", "HEAVY_SLOT")
        out, _ = done.communicate(timeout=20)
        self.assertEqual(out.strip(), "1")

    def test_on_github_nothing_queues(self):
        self.env["HEAVY_SLOTS"] = "1"
        a, a_held, a_go = self.holder("a")
        until(a_held.exists, "a holds the only slot")
        done = self.start("echo", "ran", env={"CI": "true"})
        out, _ = done.communicate(timeout=20)
        self.assertEqual(out.strip(), "ran")
        a_go.write_text("x")

    def test_peak_memory_and_time_are_kept_and_shown(self):
        code = (
            "import pathlib,time\n"
            "b = bytearray(300 * 2**20); b[::4096] = b'x' * len(b[::4096])\n"
            "time.sleep(0.6)"
        )
        done = self.start(sys.executable, "-c", code, name="big")
        _, said = done.communicate(timeout=30)
        self.assertRegex(said, r"peak memory \d\.\d GB")
        rows = [
            json.loads(line)
            for line in (self.tmp / "state" / "history.jsonl").read_text().splitlines()
        ]
        self.assertEqual(rows[-1]["name"], "big")
        self.assertGreater(rows[-1]["peak_mb"], 250)
        self.assertIn("`big`", self.status())

    def test_a_dead_waiter_does_not_hold_up_the_line(self):
        self.env["HEAVY_SLOTS"] = "1"
        a, a_held, a_go = self.holder("a")
        until(a_held.exists, "a holds the slot")
        b = self.start("true", name="b")
        until(lambda: "waiting 1" in self.status(), "b waits")
        b.send_signal(signal.SIGKILL)
        b.wait(timeout=20)
        c, c_held, c_go = self.holder("c")
        a_go.write_text("x")
        until(c_held.exists, "c runs although b died in the line")
        c_go.write_text("x")


class Counting(unittest.TestCase):
    def test_slots_follow_the_memory_the_machine_has(self):
        heavy.memory_mb, saved = (lambda: 15000), heavy.memory_mb
        try:
            os.environ.pop("HEAVY_SLOTS", None)
            self.assertEqual(
                heavy.slot_count(),
                min(heavy.MAX_SLOTS, (15000 - heavy.HEADROOM_MB) // heavy.JOB_PEAK_MB),
            )
            heavy.memory_mb = lambda: 4000
            self.assertEqual(
                heavy.slot_count(), 1, "a small machine still runs one at a time"
            )
            heavy.memory_mb = lambda: 64000
            self.assertEqual(heavy.slot_count(), heavy.MAX_SLOTS)
        finally:
            heavy.memory_mb = saved

    def test_the_slot_count_can_be_set(self):
        os.environ["HEAVY_SLOTS"] = "5"
        try:
            self.assertEqual(heavy.slot_count(), 5)
        finally:
            del os.environ["HEAVY_SLOTS"]


class Wrapping(unittest.TestCase):
    def test_a_light_recipe_is_not_queued_and_a_heavy_one_is(self):
        for light in (
            ["just", "check"],
            ["just", "analyze"],
            ["just", "format-check"],
            ["just", "test-guardrails"],
        ):
            self.assertEqual(heavy.wrap(light, "x"), light)
        for big in (
            ["just", "test"],
            ["flutter", "test", "a_test.dart"],
            ["just", "test-harness"],
            ["python3", "tool/piece_screens.py"],
        ):
            wrapped = heavy.wrap(big, "a step")
            self.assertEqual(wrapped[-len(big) :], big)
            self.assertIn("heavy.py", wrapped[1])
            self.assertEqual(wrapped[wrapped.index("--name") + 1], "a step")


class EveryHeavyRecipeUsesIt(unittest.TestCase):
    """A helper cannot forget the queue: a recipe that runs a test suite, a build or the
    harness goes through tool/heavy.py by itself (inside another heavy command it runs at
    once), so a new heavy recipe fails here until it does."""

    HEAVY_WORDS = re.compile(
        r"(^|\s)(flutter (test|drive|build (web|apk))|dart run build_runner build|uv run pytest|pytest|"
        r"tool/run_harness\.sh|tool/phone_frames/run\.sh|tool/phone_timing/run\.sh|"
        r"tool/web_smoke/run\.sh|tool/scene_web_check\.sh|tool/check_release_has_no_debug\.sh)\b"
    )

    def test_each_command_that_is_heavy_goes_through_the_queue(self):
        missing = []
        for name in ("justfile", "frontend/justfile", "backend/justfile"):
            lines = (ROOT / name).read_text().splitlines()
            logical, carry = [], ""
            for line in lines:
                carry += line.rstrip("\\") if line.rstrip().endswith("\\") else line
                if not line.rstrip().endswith("\\"):
                    logical.append(carry)
                    carry = ""
            for text in logical:
                if not text.startswith((" ", "\t")) or text.lstrip().startswith("#"):
                    continue
                words = text.strip()
                for part in re.split(r"\|\||&&|;", words):
                    part = part.strip().removeprefix("@")
                    if self.HEAVY_WORDS.search(" " + part) and "heavy.py" not in part:
                        # a command that only names the thing (an echo, a comment, a path to read)
                        if part.startswith(("echo", "#", "python3 tool/", "just ", "{")):
                            continue
                        missing.append(f"{name}: {part[:90]}")
        self.assertEqual(
            missing, [], "these commands are heavy and do not use tool/heavy.py"
        )

    def test_the_recipes_the_helpers_run_most_use_it(self):
        """piece-check and handover queue each heavy step themselves; the rest are recipes."""
        for tool in ("piece_check.py", "handover.py"):
            self.assertIn("heavy.wrap(", (ROOT / "tool" / tool).read_text(), tool)
        root = (ROOT / "justfile").read_text()
        self.assertRegex(root, r"(?m)^heavy \*args:\n    @tool/heavy\.py \{\{args\}\}")
        self.assertIn("tool/heavy.py -- tool/phone_frames/run.sh", root)


class NothingStartsABackendItDoesNotStop(unittest.TestCase):
    """A script that boots the backend (`harness-serve`) in the background must give it a
    process group of its own and stop the whole group on any exit: killing one pid left
    `runserver` up (phone-frames until #200, phone-timing until now)."""

    def test_every_script_that_boots_the_backend_stops_its_group(self):
        scripts = [
            path
            for folder in ("tool", "frontend/tool")
            for path in (ROOT / folder).rglob("*.sh")
            if "harness-serve" in path.read_text()
        ]
        names = {p.name for p in scripts}
        self.assertTrue({"run_harness.sh", "run.sh"} <= names, names)
        for path in scripts:
            text = path.read_text()
            self.assertIn("set -m", text, f"{path.name}: the backend needs a group of its own")
            self.assertRegex(text, r'kill -TERM -- "-\$backend', f"{path.name}: stop the group")
            self.assertRegex(text, r"kill -KILL -- ", f"{path.name}: and kill it after a grace")
            self.assertRegex(text, r"trap [^\n]*EXIT", f"{path.name}: on any exit")

    def test_no_script_starts_a_server_in_a_subshell_it_then_kills_by_pid(self):
        text = (ROOT / "frontend" / "tool" / "scene_web_check.sh").read_text()
        self.assertNotIn('(cd "$WEB" && python3 -m http.server', text)


if __name__ == "__main__":
    unittest.main()
