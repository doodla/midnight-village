"""The Bash hook that refuses a sleep loop waiting for another job (.claude/hooks/poll_guard.py).

It must stop `until pgrep ...; do sleep; done` and its cousins, and nothing that is real work.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HOOKS = ROOT / ".claude" / "hooks"
sys.path.insert(0, str(HOOKS))

import poll_guard  # noqa: E402

BLOCKED = [
    "until pgrep -f flutter; do sleep 5; done; echo ok",
    "while pgrep -f 'flutter test' >/dev/null; do sleep 30; done",
    "while ! grep -q DONE run.log\ndo\n  sleep 10\ndone",
    "until [ -f /tmp/done.marker ]; do sleep 20; done",
    "until grep -q 'All tests passed' /tmp/out.log; do sleep 15; done; tail -5 /tmp/out.log",
    "bash -c 'while pgrep foo; do sleep 2; done'",
    "timeout 3000 bash -c 'until [ -f /tmp/x ]; do sleep 20; done'",
    "while kill -0 $PID 2>/dev/null; do sleep 5; done",
    "for i in $(seq 1 60); do pgrep -f flutter || break; sleep 10; done",
    "until just heavy --status | grep -q '0 of'; do sleep 30; done",
    "until gh run view 123 | grep -q completed; do sleep 30; done",
    "cd frontend && until ! pgrep -f 'flutter test'; do sleep 10; done && echo free",
    "eval 'while pgrep x; do sleep 1; done'",
]

# Real work, and words that only mention the pattern.
ALLOWED = [
    # waiting for a service just started to answer
    "until curl -sf localhost:8000/api/health/; do sleep 1; done",
    "for _ in $(seq 1 120); do curl -sf http://127.0.0.1:8000/api/health/ && break; sleep 1; done",
    "until curl -s localhost:3000 | grep -q html; do sleep 2; done",
    # no sleep, sleep alone, nothing looked at
    "sleep 5",
    "while true; do sleep 60; done",
    "while pgrep x; do echo still here; done",
    "pgrep -f flutter; sleep 2; echo done",
    "for f in a b c; do echo $f; done",
    "tail -f run.log",
    # only mentioned: a message, a search, a heredoc written to a file
    "git commit -m 'no more polling: until pgrep x; do sleep 30; done is blocked'",
    "echo 'until pgrep x; do sleep 1; done'",
    "grep -rn 'until pgrep' docs/ .claude/",
    "cat > docs/note.md <<'EOF'\nuntil pgrep x; do sleep 1; done\nEOF",
    "python3 - <<'EOF'\nwhile pgrep x:\n    sleep(1)\nEOF",
    "ls && pwd",
    "",
]


class WhatItStops(unittest.TestCase):
    def test_every_polling_loop_is_blocked(self):
        for command in BLOCKED:
            self.assertTrue(poll_guard.polls(command), command)

    def test_real_work_and_mere_mentions_go_on(self):
        for command in ALLOWED:
            self.assertFalse(poll_guard.polls(command), command)


def run_hook(command: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(HOOKS / "poll_guard.py")],
        input=json.dumps({"tool_name": "Bash", "tool_input": {"command": command}}),
        capture_output=True,
        text=True,
    )


class AsAHook(unittest.TestCase):
    def test_a_blocked_command_exits_2_and_says_what_to_do(self):
        done = run_hook("until pgrep -f flutter; do sleep 5; done")
        self.assertEqual(done.returncode, 2)
        self.assertIn("run_in_background", done.stderr)
        self.assertIn("end your turn", done.stderr)
        self.assertIn("just heavy --status", done.stderr)

    def test_an_allowed_command_exits_0_silently(self):
        done = run_hook("until curl -sf localhost:8000/api/health/; do sleep 1; done")
        self.assertEqual((done.returncode, done.stderr), (0, ""))

    def test_a_command_without_sleep_is_not_even_read(self):
        self.assertEqual(run_hook("echo hi").returncode, 0)

    def test_a_broken_input_never_stops_real_work(self):
        done = subprocess.run(
            [sys.executable, str(HOOKS / "poll_guard.py")],
            input="not json",
            capture_output=True,
            text=True,
        )
        self.assertEqual(done.returncode, 0)

    def test_it_is_registered_for_bash_next_to_the_git_guard(self):
        settings = json.loads((ROOT / ".claude" / "settings.json").read_text())
        bash = [
            hook["command"]
            for entry in settings["hooks"]["PreToolUse"]
            if entry["matcher"] == "Bash"
            for hook in entry["hooks"]
        ]
        self.assertTrue(any("poll_guard.py" in c for c in bash), bash)
        self.assertTrue(all("$CLAUDE_PROJECT_DIR" in c for c in bash), bash)


class TheRuleIsWhereHelpersRead(unittest.TestCase):
    """The waiting rule is said in the brief every helper starts from and in the running-the-work page."""

    RULE = "run_in_background"

    def test_an_area_brief_prints_it(self):
        # not a screen's brief: that one walks the app with Flutter, which GitHub's backend job lacks
        done = subprocess.run(
            [sys.executable, str(ROOT / "tool" / "brief.py"), "copy"],
            capture_output=True,
            text=True,
            cwd=ROOT,
        )
        self.assertEqual(done.returncode, 0, done.stderr[-300:])
        self.assertIn(self.RULE, done.stdout)
        self.assertIn("Never poll with a sleep loop", done.stdout)

    def test_a_screen_brief_prints_it_too(self):
        # read from the source, for the same reason: both briefs print brief_areas.WAITING
        source = (ROOT / "tool" / "brief.py").read_text()
        self.assertIn('tool("brief_areas").WAITING', source)
        self.assertIn(self.RULE, (ROOT / "tool" / "brief_areas.py").read_text())

    def test_the_running_the_work_page_says_it(self):
        text = (ROOT / "docs" / "dev" / "running-the-work.md").read_text()
        self.assertIn("a command that may take more than two minutes", text.lower())
        self.assertIn(self.RULE, text)
        self.assertIn("never poll with a sleep loop", text.lower())


if __name__ == "__main__":
    unittest.main()
