"""`just speed-verdict` and phone-frames' step checks, without a browser.

The verdict rule (tool/phone_frames/verdict.py) on fixed numbers, among them the rows
that fooled people: the noisy set-up row (about ±300 ms) and the pairs of press-1's
pull request (#207); the owner's sentence; the moments named by the script itself
(script.py); and the measured pass's checks (checks.py, moments.py), driven through a
fake page: a hold that showed nothing, a tap the page never got, a step that sent
nothing or ended elsewhere are lost (loud), never numbers.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import asyncio
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
FRAMES = ROOT / "tool" / "phone_frames"
sys.path.insert(0, str(FRAMES))
import checks  # noqa: E402
import moments  # noqa: E402
import script  # noqa: E402
import speed_verdict  # noqa: E402
import verdict  # noqa: E402

PILLOW = importlib.util.find_spec("PIL") is not None


class TheRule(unittest.TestCase):
    def test_the_noisy_setup_row_interleaved_is_level(self):
        # "Edit -> 03 set-up" in the four lab runs (3009 to 3383 ms for the same code).
        got = verdict.judge([3383, 3009], [3335, 3021])
        self.assertEqual(got["verdict"], "level")

    def test_a_drift_between_sessions_is_not_a_difference_once_interleaved(self):
        # The same four numbers, run as two sessions (A A, then B B), look separated;
        # interleaved (A B A B) they overlap. The tool interleaves; the rule sees that.
        self.assertEqual(
            verdict.judge([3009, 3021, 3383], [3335, 3050, 3020])["verdict"], "level"
        )

    def test_press_1_card_hold_is_better(self):
        got = verdict.judge([1315, 1187], [701, 668])
        self.assertEqual(got["verdict"], "better")
        self.assertEqual(got["gap_ms"], -566)
        self.assertEqual(
            got["base"],
            {"median": 1251, "min": 1187, "max": 1315, "runs": [1315, 1187]},
        )

    def test_press_1_night_pick_is_level_inside_its_own_spread(self):
        # Reported in #207 as "slightly worse, cause not proven".
        got = verdict.judge([830, 837], [872, 953])
        self.assertEqual(got["verdict"], "level")
        self.assertIn("inside the runs' own spread", got["why"])

    def test_one_slow_run_does_not_make_a_verdict(self):
        # "g3 Villager: 08 hold My night": one run of four was 260 ms off.
        got = verdict.judge([880, 905, 624], [600, 610, 590])
        self.assertEqual(got["verdict"], "level")

    def test_a_gap_under_the_floor_is_level_however_steady(self):
        got = verdict.judge([500, 502, 501], [520, 521, 522])
        self.assertEqual(got["verdict"], "level")
        self.assertIn("under the floor", got["why"])

    def test_a_clear_slowdown_is_worse(self):
        got = verdict.judge([500, 510, 505], [640, 650, 655])
        self.assertEqual(got["verdict"], "worse")
        self.assertEqual(got["gap_ms"], 145)

    def test_overlapping_runs_are_level(self):
        self.assertEqual(
            verdict.judge([500, 700, 600], [550, 650, 800])["verdict"], "level"
        )

    def test_one_run_a_side_is_no_verdict(self):
        with self.assertRaises(ValueError):
            verdict.judge([500], [400])


def run(values, lost=None, failed=None):
    return {"values": values, "lost": lost, "failed": failed}


HOLD = "g1 Drunk: 04 hold the card"
READY = "g1 Drunk: 04 Ready"
MOMENTS = [
    {"name": HOLD, "kind": "tap", "plain": "holding your card"},
    {"name": READY, "kind": "tap", "plain": "Ready on your card"},
]


class Comparing(unittest.TestCase):
    def test_a_lost_run_makes_its_moments_not_measured_with_the_reason(self):
        base = [run({HOLD: 1300, READY: 700}), run({HOLD: 1200, READY: 720})]
        lost = {"at": HOLD, "why": "nothing showed while it was held (1.6 s)"}
        head = [run({HOLD: 700, READY: 450}), run({}, lost=lost)]
        rows = verdict.compare(MOMENTS, base, head, 2)
        self.assertEqual([r["verdict"] for r in rows], ["not measured", "not measured"])
        self.assertIn("head: 1 of 2 runs measured it", rows[0]["why"])
        self.assertIn(
            "lost at 'g1 Drunk: 04 hold the card': nothing showed", rows[1]["why"]
        )

    def test_the_sentence_says_what_changed_and_that_the_rest_is_level(self):
        base = [run({HOLD: 1300, READY: 700}), run({HOLD: 1200, READY: 720})]
        head = [run({HOLD: 700, READY: 710}), run({HOLD: 690, READY: 705})]
        rows = verdict.compare(MOMENTS, base, head, 2)
        self.assertEqual(
            verdict.sentence(rows),
            "Holding your card answers about 0.6 s sooner; everything else is level.",
        )

    def test_the_sentence_when_nothing_moved(self):
        base = [run({HOLD: 1300, READY: 700}), run({HOLD: 1200, READY: 720})]
        rows = verdict.compare(MOMENTS, base, base, 2)
        self.assertEqual(
            verdict.sentence(rows),
            "No measurable difference: everything measured is level.",
        )

    def test_the_table_shows_median_and_range_per_side_and_the_rule_is_printed(self):
        base = [run({HOLD: 1300, READY: 700}), run({HOLD: 1200, READY: 720})]
        head = [run({HOLD: 700, READY: 710}), run({HOLD: 690, READY: 705})]
        text = verdict.table(verdict.compare(MOMENTS, base, head, 2), "main", "branch")
        self.assertIn("1250 (1200-1300)", text)
        self.assertIn("better", text)
        self.assertIn("by more than either side's own spread", verdict.RULE)


class TheScriptNamesItsMoments(unittest.TestCase):
    def test_the_list_comes_from_the_script_and_holds_every_timed_moment(self):
        names = [m["name"] for m in script.names(1) if m["kind"] in script.TIMED]
        self.assertIn(HOLD, names)
        self.assertEqual(sum(1 for m in script.names(1) if m["kind"] == "tap"), 16)

    def test_a_part_of_a_name_picks_its_moments_and_the_games_they_need(self):
        chosen, games = script.pick("hold the card", 1)
        self.assertEqual([m["name"] for m in chosen], [HOLD])
        self.assertEqual(games, 1)
        chosen, games = script.pick("g3 Villager: 04 Ready", 1)
        self.assertEqual(games, 3)

    def test_a_word_that_names_nothing_fails_and_lists_the_names(self):
        with self.assertRaises(LookupError) as caught:
            script.pick("hold the crad", 1)
        self.assertIn("no moment is named 'hold the crad'", str(caught.exception))
        self.assertIn(HOLD, str(caught.exception))

    def test_the_untimeable_night_ends_are_not_moments(self):
        # The phone acts last there: the talk comes with its own Swap.
        names = [m["name"] for m in script.names(3) if m["kind"] in script.TIMED]
        self.assertNotIn("g1 Drunk: night -> talk (window closes)", names)
        self.assertIn("g3 Villager: night -> talk (window closes)", names)

    def test_every_moment_has_plain_words_for_the_owner(self):
        for m in script.names(3):
            if m["kind"] in script.TIMED:
                self.assertNotEqual(script.plain(m["name"]), m["name"], m["name"])


class StepChecks(unittest.TestCase):
    def test_an_action_is_a_template_without_ids(self):
        url = "http://127.0.0.1:5/api/onuw/games/4ceb53ae-3813-4b34-b6b0-489d0e5183d3/ready/"
        self.assertEqual(checks.action("POST", url), "POST /onuw/games/{id}/ready/")
        self.assertEqual(
            checks.action("PATCH", "http://h/api/lobbies/76JFNC/"),
            "PATCH /lobbies/{code}/",
        )
        self.assertIsNone(checks.action("GET", url))

    def test_a_step_that_sent_nothing_is_lost_and_says_what_it_missed(self):
        why = checks.lost_actions("Ready", ["POST /onuw/games/{id}/ready/"], [])
        self.assertIn("it sent no POST /onuw/games/{id}/ready/", why)
        self.assertIn("Fix:", why)
        self.assertIsNone(checks.lost_actions("Ready", ["POST /x/"], ["POST /x/"]))

    def test_a_hold_must_show_something_while_held(self):
        self.assertFalse(checks.held_showed([(0.2, 0.01)], 3.5))
        self.assertFalse(checks.held_showed([(3.9, 0.4)], 3.5))  # only after letting go
        self.assertTrue(checks.held_showed([(1.2, 0.3)], 3.5))

    @unittest.skipUnless(PILLOW, "Pillow draws the pictures")
    def test_an_answer_elsewhere_is_lost_and_the_same_answer_is_not(self):
        from PIL import Image, ImageDraw

        def picture(word):
            img = Image.new("L", (120, 40), 230)
            ImageDraw.Draw(img).rectangle((10, 8, 10 + 9 * len(word), 30), fill=20)
            return img

        self.assertLessEqual(checks.differs(picture("Ready"), picture("Ready")), 0.01)
        share = checks.differs(picture("Ready"), picture("Look first"))
        self.assertGreater(share, checks.ANSWER_DIFF)
        self.assertIn(
            "is not where the map pass saw it", checks.lost_answer("Ready", share)
        )


class FakePage:
    """Enough of page_probe.Page for one measured tap."""

    def __init__(self, downs):
        self.shots, self.requests, self.sent, self.inflight = [], [], [], 0
        self.downs = downs
        page = self

        class Inner:
            async def evaluate(self, js, arg=None):
                if "touches" in js:
                    return page.downs
                if "performance.now() - l[0]" in js:
                    return 1e9  # no frame for ages: quiet
                return None

            async def screenshot(self, **_k):
                raise AssertionError("no answer to picture")

        self.page = Inner()

    async def screencast(self, on):
        return None

    async def base(self):
        return "screencast"

    async def now(self):
        return 1000.0

    async def origin(self):
        return 0.0

    async def touch(self, *a):
        return None

    async def changed(self, *a):
        return True


class Args:
    dump = False
    perf = ""


def measured_tap(downs, hold, expect):
    boxes = {HOLD: {"x": 10, "y": 10, "w": 50, "h": 50, "label": "Your card, hidden"}}
    boxes["_expect"] = {HOLD: expect}
    r = moments.Run(Args(), FakePage(downs), None, boxes, True)

    async def go():
        await r.tap(HOLD, "^Your card", ["Ready"], hold=hold)

    old = moments.asyncio.sleep

    async def no_wait(_s):
        return None

    moments.asyncio.sleep = no_wait
    try:
        asyncio.run(go())
    finally:
        moments.asyncio.sleep = old
    return r


class MeasuredSteps(unittest.TestCase):
    def test_a_hold_that_showed_nothing_while_held_is_lost_not_a_number(self):
        # The case that fooled us: a card hold that lost its race under CPU throttling.
        with self.assertRaises(moments.Lost) as caught:
            measured_tap(
                [["pointerdown", 1000.0]], 1.6, {"actions": [], "answer": None}
            )
        self.assertIn("the hold did not register", caught.exception.why)

    def test_a_tap_the_page_never_got_is_lost(self):
        with self.assertRaises(moments.Lost) as caught:
            measured_tap([], 0.07, {"actions": [], "answer": None})
        self.assertIn("never got the finger", caught.exception.why)

    def test_a_step_without_its_action_is_lost(self):
        expect = {"actions": ["POST /onuw/games/{id}/ready/"], "answer": None}
        old = checks.ACT_WAIT
        checks.ACT_WAIT = 0
        try:
            with self.assertRaises(moments.Lost) as caught:
                measured_tap([["pointerdown", 1000.0]], 0.07, expect)
        finally:
            checks.ACT_WAIT = old
        self.assertIn("it sent no POST", caught.exception.why)


class TheCommand(unittest.TestCase):
    def test_list_prints_the_scripts_moments_without_a_browser(self):
        done = subprocess.run(
            [sys.executable, str(FRAMES / "speed_verdict.py"), "--list"],
            capture_output=True,
            text=True,
            timeout=60,
        )
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn(HOLD, done.stdout)

    def test_an_unknown_moment_fails_before_anything_is_built(self):
        done = subprocess.run(
            [
                sys.executable,
                str(FRAMES / "speed_verdict.py"),
                "HEAD",
                "--moments",
                "nope",
            ],
            capture_output=True,
            text=True,
            timeout=60,
        )
        self.assertEqual(done.returncode, 2)
        self.assertIn("no moment is named 'nope'", done.stderr)

    def test_the_verdict_is_written_as_json_beside_the_table(self):
        rows = verdict.compare(
            MOMENTS,
            [run({HOLD: 1300, READY: 700}), run({HOLD: 1200, READY: 720})],
            [run({HOLD: 700, READY: 710}), run({HOLD: 690, READY: 705})],
            2,
        )
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "verdict.json"
            speed_verdict.write(
                path, {"rows": rows, "sentence": verdict.sentence(rows)}
            )
            got = json.loads(path.read_text())
        self.assertEqual(got["rows"][0]["verdict"], "better")
        self.assertTrue(got["sentence"].startswith("Holding your card"))

    def test_a_verdict_holds_every_slot_of_the_heavy_queue(self):
        """Nothing heavy may run beside a measurement: it waits until every slot is free."""
        with tempfile.TemporaryDirectory() as tmp:
            env = {k: v for k, v in os.environ.items() if k not in ("CI", "HEAVY_SLOT")}
            env.update(
                HEAVY_DIR=str(Path(tmp) / "q"), HEAVY_SLOTS="2", HEAVY_REPORT="0.2"
            )
            go, held = Path(tmp) / "go", Path(tmp) / "held"
            code = (
                f"import pathlib,time; pathlib.Path({str(held)!r}).write_text('x')\n"
                f"while not pathlib.Path({str(go)!r}).exists(): time.sleep(0.02)"
            )
            heavy = str(ROOT / "tool" / "heavy.py")
            other = subprocess.Popen(
                [
                    sys.executable,
                    heavy,
                    "--name",
                    "tests",
                    "--",
                    sys.executable,
                    "-c",
                    code,
                ],
                env=env,
            )
            verdict_run = subprocess.Popen(
                [
                    sys.executable,
                    str(FRAMES / "speed_verdict.py"),
                    "HEAD",
                    "--runs",
                    "2",
                ],
                env=env,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
                text=True,
            )
            try:
                status = ""
                for _ in range(500):
                    status = subprocess.run(
                        [sys.executable, heavy, "--status"],
                        env=env,
                        capture_output=True,
                        text=True,
                    ).stdout
                    if held.exists() and "waiting 1" in status:
                        break
                    time.sleep(0.02)
                # One slot of two was free: it holds that one and still waits, for all.
                self.assertIn("2 of 2 slots busy, 1 waiting", status)
                self.assertRegex(
                    status, r"waiting 1: `speed-verdict`.*alone: every slot"
                )
            finally:
                verdict_run.kill()
                verdict_run.wait()
                go.write_text("x")
                other.wait(timeout=20)

    def test_the_exit_code_is_the_measurements_not_the_verdicts(self):
        better = [{"verdict": "better"}, {"verdict": "worse"}, {"verdict": "level"}]
        self.assertEqual(speed_verdict.exit_code(better), 0)
        self.assertEqual(
            speed_verdict.exit_code(better + [{"verdict": "not measured"}]), 1
        )


if __name__ == "__main__":
    unittest.main()
