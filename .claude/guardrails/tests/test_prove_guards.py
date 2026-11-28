# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""`just prove-guards` (tool/prove_guards.py): a guard counts only if a recorded break proves it bites.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tool"))

import breaks_app  # noqa: E402,F401  (each file of the harness is a guard this file holds)
import breaks_rules  # noqa: E402,F401
import breaks_server  # noqa: E402,F401
import breaks_tools  # noqa: E402,F401
import breaks_verdict  # noqa: E402,F401
import prove_guards as pg  # noqa: E402
from breaks_kit import Break, Edit, NoLongerApplies, apply_edit  # noqa: E402

CODE = """def a():
    x = 1
    return x


def b():
    x = 1
    return x
"""


def a_break(name="m", tests=("backend/tests/t.py",), survives="", promise="atomicity"):
    return Break(
        name=name, promise=promise, why="w", edits=(), tests=tests, survives=survives
    )


class AnEditLandsWhereItSays(unittest.TestCase):
    def test_it_changes_only_the_function_it_names(self):
        out = apply_edit(CODE, Edit("x.py", "x = 1", "x = 2", within="b"))
        self.assertIn("def a():\n    x = 1", out)
        self.assertIn("def b():\n    x = 2", out)

    def test_text_that_is_gone_fails_loudly(self):
        with self.assertRaises(NoLongerApplies):
            apply_edit(CODE, Edit("x.py", "y = 1", "y = 2", within="a"))

    def test_a_function_that_is_gone_fails_loudly(self):
        with self.assertRaises(NoLongerApplies):
            apply_edit(CODE, Edit("x.py", "x = 1", "x = 2", within="c"))

    def test_text_found_twice_fails_rather_than_guess(self):
        with self.assertRaises(NoLongerApplies):
            apply_edit(CODE, Edit("x.py", "x = 1", "x = 2"))

    def test_a_break_that_does_not_parse_is_refused(self):
        with self.assertRaises(NoLongerApplies):
            apply_edit(CODE, Edit("x.py", "x = 1", "x = (", within="a"))

    def test_a_marker_anchors_a_file_that_is_not_python(self):
        text = "one\nlabel: name\ntwo\nlabel: name\n"
        with self.assertRaises(NoLongerApplies):
            apply_edit(text, Edit("x.dart", "label: name", "label: 'x'"))
        out = apply_edit(
            text, Edit("x.dart", "label: name", "label: 'x'", within="two")
        )
        self.assertEqual(out, "one\nlabel: name\ntwo\nlabel: 'x'\n")

    def test_every_break_applies_to_the_tree_as_it_stands(self):
        for m in pg.BREAKS:
            texts = {}
            for edit in m.edits:
                text = texts.get(edit.path) or (REPO / edit.path).read_text()
                with self.subTest(name=m.name):
                    try:
                        texts[edit.path] = apply_edit(text, edit)
                    except NoLongerApplies as problem:
                        self.fail(f"{m.name} no longer applies: {problem}")


class EveryGuardHasABreak(unittest.TestCase):
    def problems(self, breaks, guards, debt=frozenset(), was_guard=None):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for path in {
                *guards,
                *(t.split("::")[0] for m in breaks for t in m.tests),
            }:
                (root / path).parent.mkdir(parents=True, exist_ok=True)
                (root / path).write_text("")
            return breaks_rules.list_problems(breaks, list(guards), debt, was_guard, root)

    def test_a_guard_that_kills_a_break_passes(self):
        self.assertEqual(self.problems([a_break()], ["backend/tests/t.py"]), [])

    def test_a_guard_with_no_break_fails_and_says_what_to_add(self):
        found = self.problems([a_break()], ["backend/tests/t.py", "backend/tests/g.py"])
        self.assertEqual(len(found), 1)
        self.assertIn("backend/tests/g.py is a guard with no recorded break", (found or [''])[0])
        self.assertIn("add a break", (found or [''])[0])

    def test_a_break_that_survives_proves_no_bite(self):
        found = self.problems([a_break(survives="later")], ["backend/tests/t.py"])
        self.assertIn("no recorded break", (found or [''])[0])

    def test_the_old_guards_are_listed_and_the_list_only_shrinks(self):
        guards = ["backend/tests/t.py", "backend/tests/old.py"]
        debt = frozenset({"backend/tests/old.py"})
        self.assertEqual(self.problems([a_break()], guards, debt, lambda p: True), [])
        found = self.problems([a_break()], guards, debt, lambda p: False)
        self.assertIn("NOT_YET_PROVED only shrinks", (found or [''])[0])
        bitten = self.problems(
            [a_break()], ["backend/tests/t.py"], frozenset({"backend/tests/t.py"})
        )
        self.assertIn("take it off NOT_YET_PROVED", (bitten or [''])[0])

    def test_a_break_naming_no_promise_fails(self):
        found = self.problems([a_break(promise="vibes")], ["backend/tests/t.py"])
        self.assertIn("no promise named 'vibes'", (found or [''])[0])

    def test_the_real_list_has_no_problem(self):
        base = pg.change_base(pg.ROOT, "origin/main")
        found = breaks_rules.list_problems(
            pg.BREAKS,
            breaks_rules.guard_files(),
            pg.NOT_YET_PROVED,
            breaks_rules.was_guard_on(base),
        )
        self.assertEqual(found, [])


class TheVerdict(unittest.TestCase):
    def test_killed_passes_survived_fails(self):
        self.assertIsNone(pg.verdict(a_break(), {"status": "killed"}))
        self.assertIn("SURVIVED", pg.verdict(a_break(), {"status": "survived"}))

    def test_a_known_survivor_that_is_killed_must_lose_its_mark(self):
        known = a_break(survives="later")
        self.assertIsNone(pg.verdict(known, {"status": "survived"}))
        self.assertIn(
            "take its `survives` mark off", pg.verdict(known, {"status": "killed"})
        )

    def test_a_broken_run_or_a_moved_anchor_is_a_failure(self):
        self.assertIn("broken", pg.verdict(a_break(), {"status": "broken"}))
        self.assertIn(
            "no longer applies",
            pg.verdict(a_break(), {"status": "no longer applies"}),
        )


class WhatAChangeReaches(unittest.TestCase):
    def test_a_change_under_a_promise_reaches_its_breaks_only(self):
        lock = a_break(name="lock", promise="atomicity")
        name = a_break(
            name="name", promise="names-in-full", tests=("frontend/test/x.dart",)
        )
        names = [
            m.name for m in pg.reached([lock, name], ["backend/apps/onuw/voting.py"])
        ]
        self.assertEqual(names, ["lock"])

    def test_a_change_to_a_killer_reaches_its_break(self):
        lock = a_break(name="lock", promise="atomicity")
        self.assertEqual(pg.reached([lock], ["backend/tests/t.py"]), [lock])
        self.assertEqual(pg.reached([lock], ["docs/dev/status.md"]), [])


if __name__ == "__main__":
    unittest.main()
