"""`just prove-guards`: a catch is a named test failing an assertion, never a crash; the list
only shrinks against main; a guard is proved by a run that saw it fail.

The three bogus breaks of the review of 28 November 2026 (scripts/fake_breaks.py) are the
first cases: each was counted as a kill, each is "broken" now.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tool"))

import breaks_rules  # noqa: E402
import breaks_verdict as v  # noqa: E402
import prove_guards as pg  # noqa: E402
from breaks_kit import Break  # noqa: E402

KILLER = "backend/tests/privacy/test_two_deals.py"


def junit(classname, kind, message):
    return (
        f'<testsuites><testsuite><testcase classname="{classname}" name="test_x">'
        f'<{kind} message="{message}">...</{kind}></testcase></testsuite></testsuites>'
    )


class ACatchIsAFailedAssertion(unittest.TestCase):
    def test_a_named_killer_failing_an_assertion_kills(self):
        status, failed, _ = v.backend(
            1,
            junit(
                "tests.privacy.test_two_deals",
                "failure",
                "AssertionError: seat 1 learns",
            ),
            [KILLER],
        )
        self.assertEqual((status, failed), ("killed", {KILLER}))

    def test_x1_an_import_error_inside_the_code_under_test_is_broken(self):
        status, _, why = v.backend(
            1,
            junit(
                "tests.privacy.test_two_deals",
                "failure",
                "ModuleNotFoundError: No module named 'apps.onuw.no_such_module_xyz'",
            ),
            [KILLER],
        )
        self.assertEqual(status, "broken")
        self.assertIn("crashed", why)

    def test_x2_a_command_that_cannot_run_is_broken(self):
        out = "ModuleNotFoundError: No module named 'no_such_module_xyz'"
        self.assertEqual(
            v.command(1, out, "<- needs its line", "tool/x.py")[0], "broken"
        )
        self.assertEqual(v.command(1, out, "", "tool/x.py")[0], "broken")
        self.assertEqual(
            v.command(1, "a <- needs its line", "<- needs its line", "tool/x.py")[0],
            "killed",
        )

    def test_x3_a_guardrail_that_errors_is_broken(self):
        out = "ERROR: test_a (test_file_sizes.Sizes.test_a)\n\nFAILED (errors=10)\n"
        self.assertEqual(
            v.guardrails(1, out, ".claude/guardrails/tests/test_file_sizes.py")[0],
            "broken",
        )
        good = "FAIL: test_a (test_file_sizes.Sizes.test_a)\n\nFAILED (failures=1)\n"
        self.assertEqual(
            v.guardrails(1, good, ".claude/guardrails/tests/test_file_sizes.py")[0],
            "killed",
        )

    def test_an_error_a_collection_failure_or_another_files_failure_is_broken(self):
        self.assertEqual(
            v.backend(1, junit("tests.privacy.test_two_deals", "error", "x"), [KILLER])[
                0
            ],
            "broken",
        )
        self.assertEqual(v.backend(2, None, [KILLER])[0], "broken")
        other = junit("tests.onuw.test_other", "failure", "AssertionError: x")
        self.assertEqual(v.backend(1, other, [KILLER])[0], "broken")

    def test_flutter_must_fail_an_expectation_and_build(self):
        self.assertEqual(
            v.flutter(1, "Error: Could not resolve the package", "f")[0], "broken"
        )
        self.assertEqual(v.flutter(1, "Some tests failed.", "f")[0], "broken")
        self.assertEqual(v.flutter(1, "Expected: <1>\n Actual: <2>", "f")[0], "killed")

    def test_a_pass_is_a_survivor(self):
        self.assertEqual(v.backend(0, None, [KILLER])[0], "survived")


class TheListOnlyShrinks(unittest.TestCase):
    BEFORE = {"names": ["a", "b"], "survives": ["b"], "debt": ["x.dart"]}

    def test_the_same_list_or_a_shorter_one_passes(self):
        now = {"names": ["a", "b", "c"], "survives": [], "debt": []}
        self.assertEqual(breaks_rules.shrink_problems(now, self.BEFORE, ""), [])

    def test_growth_and_loss_fail_unless_the_description_names_them(self):
        now = {"names": ["a"], "survives": ["a"], "debt": ["x.dart", "y.dart"]}
        found = breaks_rules.shrink_problems(now, self.BEFORE, "")
        self.assertEqual(len(found), 3)
        body = (
            "Guards changed\n- y.dart: moved its rule to a new test, later\n"
            "- a: the tool it guards is being rewritten\n- b: merged into the break a"
        )
        self.assertEqual(breaks_rules.shrink_problems(now, self.BEFORE, body), [])

    def test_the_lists_on_main_are_read_when_they_are_there(self):
        self.assertIsNone(breaks_rules.lists_at(None))


class AGuardIsProvedByARunThatSawItFail(unittest.TestCase):
    def test_naming_a_helper_its_tests_do_not_import_is_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "t.py").write_text("from tests.privacy.two_deals import x\n")
            ok = Break(
                name="ok",
                promise="atomicity",
                why="w",
                edits=(),
                tests=("t.py",),
                guards=("backend/tests/privacy/two_deals.py",),
            )
            bad = Break(
                name="bad",
                promise="atomicity",
                why="w",
                edits=(),
                tests=("t.py",),
                guards=("frontend/test/helpers/finger.dart",),
            )
            self.assertEqual(breaks_rules.helper_problems(ok, root), [])
            self.assertIn(
                "not its command's file", breaks_rules.helper_problems(bad, root)[0]
            )

    def test_a_guard_whose_breaks_ran_and_never_failed_in_it_is_unproved(self):
        m = Break(name="m", promise="atomicity", why="w", edits=(), tests=(KILLER,))
        ran = [{"name": "m", "status": "killed", "failed": set()}]
        self.assertEqual(pg.proved([m], ran), set())
        self.assertTrue(pg.unproved([m], {"m"}, set(), {KILLER}))
        self.assertEqual(pg.unproved([m], set(), set(), {KILLER}), [])  # not run: nothing said

    def test_a_skipped_flutter_break_fails_on_github(self):
        self.assertTrue(pg.can_run("backend"))


if __name__ == "__main__":
    unittest.main()
