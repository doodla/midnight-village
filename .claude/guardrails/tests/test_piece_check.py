# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""`just piece-check` (tool/piece_check.py): which tests a change can reach.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SCRIPT = REPO / "tool" / "piece_check.py"


def load(root: Path):
    spec = importlib.util.spec_from_file_location("piece_check", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.ROOT = root
    return module


class FrontendTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name).resolve()
        self.check = load(self.root)
        self.put("frontend/pubspec.yaml", "name: game\n")
        # lib: a leaf widget, a screen that uses it through a part, another screen
        self.put("frontend/lib/kit/band.dart", "class Band {}\n")
        self.put("frontend/lib/talk/talk.dart", "part 'talk_view.dart';\n")
        self.put("frontend/lib/talk/talk_view.dart", "part of 'talk.dart';\nimport 'package:game/kit/band.dart';\n")
        self.put("frontend/lib/vote/vote.dart", "import 'dart:async';\nimport 'package:flutter/widgets.dart';\n")
        # tests
        self.put("frontend/test/talk_test.dart", "import 'package:game/talk/talk.dart';\n")
        self.put("frontend/test/vote_test.dart", "import 'package:game/vote/vote.dart';\nimport 'helpers/pump.dart';\n")
        self.put("frontend/test/helpers/pump.dart", "// reads nothing\n")
        self.put("frontend/test/samples_test.dart", "import 'helpers/samples.dart';\n")
        self.put("frontend/test/helpers/samples.dart", "const dir = '../contract_samples';\n")

    def tearDown(self):
        self.tmp.cleanup()

    def put(self, name: str, text: str) -> None:
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def picked(self, *changed: str, everything: bool = False) -> list[str]:
        tests, why_all = self.check.frontend_tests(list(changed), everything)
        self.assertEqual(why_all, "")
        return tests

    def test_a_leaf_reaches_the_tests_above_it_through_imports_and_parts(self):
        self.assertEqual(self.picked("frontend/lib/kit/band.dart"), ["test/talk_test.dart"])

    def test_only_the_nearest_tests_and_one_step_further_are_run(self):
        # app -> a -> b -> c -> band: a test on `c` is 2 away, on `b` 3, on the app 5
        self.put("frontend/lib/c.dart", "import 'kit/band.dart';\n")
        self.put("frontend/lib/b.dart", "import 'c.dart';\n")
        self.put("frontend/lib/a.dart", "import 'b.dart';\n")
        self.put("frontend/lib/app.dart", "import 'a.dart';\n")
        self.put("frontend/test/band_test.dart", "import 'package:game/kit/band.dart';\n")
        self.put("frontend/test/c_test.dart", "import 'package:game/c.dart';\n")
        self.put("frontend/test/b_test.dart", "import 'package:game/b.dart';\n")
        self.put("frontend/test/app_test.dart", "import 'package:game/app.dart';\n")
        near = self.picked("frontend/lib/kit/band.dart")
        self.assertEqual(near, ["test/band_test.dart", "test/c_test.dart"])
        far = self.picked("frontend/lib/kit/band.dart", everything=True)
        self.assertEqual(len(far), 5)

    def test_a_part_file_reaches_the_tests_of_its_library(self):
        self.assertEqual(self.picked("frontend/lib/talk/talk_view.dart"), ["test/talk_test.dart"])

    def test_a_test_helper_reaches_the_tests_that_use_it(self):
        self.assertEqual(self.picked("frontend/test/helpers/pump.dart"), ["test/vote_test.dart"])

    def test_a_changed_test_runs_itself(self):
        self.assertEqual(self.picked("frontend/test/vote_test.dart"), ["test/vote_test.dart"])

    def test_a_recorded_sample_reaches_the_tests_that_read_samples(self):
        self.assertEqual(
            self.picked("contract_samples/http/game/me.json"), ["test/samples_test.dart"]
        )

    def test_what_cannot_be_mapped_runs_everything_and_says_why(self):
        tests, why_all = self.check.frontend_tests(["frontend/pubspec.yaml"])
        self.assertEqual(tests, [])
        self.assertIn("pubspec.yaml", why_all)


class Plan(unittest.TestCase):
    def names(self, *changed: str) -> list[str]:
        return [what for what, _, _ in load(REPO).plan(list(changed))]

    def test_a_backend_change_runs_every_backend_test(self):
        steps = self.names("backend/apps/onuw/voting.py")
        self.assertTrue(any("all backend tests" in s for s in steps), steps)
        self.assertFalse(any("frontend" in s or s == "analyze" for s in steps), steps)

    def test_a_migration_adds_the_migration_tests(self):
        steps = self.names("backend/apps/core/migrations/0099_x.py")
        self.assertIn("the migration tests", steps)

    def test_a_docs_change_runs_only_the_checks(self):
        self.assertEqual(len(self.names("docs/dev/status.md")), 1)

    def test_a_tooling_change_runs_the_guardrail_tests(self):
        for path in ("tool/x.py", ".claude/hooks/x.sh", "justfile", ".github/workflows/x.yml"):
            self.assertIn("guardrail tests", self.names(path), path)

    def test_a_sample_reaches_both_sides(self):
        steps = self.names("contract_samples/http/game/me_x.json")
        self.assertTrue(any("backend" in s for s in steps), steps)
        self.assertTrue(any("frontend test files" in s for s in steps), steps)

    def test_a_changed_payload_or_harness_runs_the_end_to_end_harness(self):
        """The real app against the real server compares events exactly, and no
        import leads there: a server payload change went red on GitHub only."""
        for path in (
            "contract_samples/ws/host_changed.json",
            "frontend/test_e2e/api_lifecycle_test.dart",
            "frontend/tool/run_harness.sh",
        ):
            self.assertTrue(
                any("end-to-end harness" in s for s in self.names(path)), path
            )

    def test_a_change_with_no_payload_in_it_does_not_run_the_harness(self):
        for path in ("frontend/lib/x.dart", "backend/apps/core/x.py", "docs/x.md"):
            self.assertFalse(
                any("end-to-end harness" in s for s in self.names(path)), path
            )


if __name__ == "__main__":
    unittest.main()


class ScreensThatDrawAChange(unittest.TestCase):
    """tool/piece_screens.py: from each state's widgets to the states a file reaches."""

    def setUp(self):
        spec = importlib.util.spec_from_file_location(
            "piece_screens", REPO / "tool" / "piece_screens.py"
        )
        self.screens = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.screens)
        self.widgets = {
            "01-join": ["App", "JoinView", "PrimaryButton"],
            "02-table": ["App", "TableView", "PrimaryButton", "PlayerRow"],
            "08-talk": ["App", "TalkScreen", "PlayerRow"],
        }
        self.owner = {
            "App": {"frontend/lib/app.dart"},
            "JoinView": {"frontend/lib/join_view.dart"},
            "TableView": {"frontend/lib/table_view.dart"},
            "TalkScreen": {"frontend/lib/talk_screen.dart"},
            "PrimaryButton": {"frontend/lib/kit/button.dart"},
            "PlayerRow": {"frontend/lib/kit/player_row.dart"},
        }
        # the lobby's notifier draws nothing: the table's view and the app import it
        self.imported_by = {
            "frontend/lib/lobby_notifier.dart": {"frontend/lib/table_view.dart"},
            "frontend/lib/copy.dart": {
                "frontend/lib/join_view.dart",
                "frontend/lib/table_view.dart",
                "frontend/lib/talk_screen.dart",
            },
            "frontend/lib/join_view.dart": {"frontend/lib/app.dart"},
        }

    def states(self, *changed):
        return self.screens.states_for(
            list(changed), self.widgets, self.owner, self.imported_by
        )

    def test_a_widgets_file_reaches_the_states_that_draw_it_and_no_others(self):
        self.assertEqual(self.states("frontend/lib/join_view.dart"), ({"01-join"}, ""))
        self.assertEqual(
            self.states("frontend/lib/kit/player_row.dart"), ({"02-table", "08-talk"}, "")
        )

    def test_it_does_not_climb_to_the_app_which_every_state_draws(self):
        states, _ = self.states("frontend/lib/join_view.dart")
        self.assertNotIn("08-talk", states)

    def test_a_file_that_draws_nothing_is_followed_to_the_files_that_use_it(self):
        self.assertEqual(self.states("frontend/lib/lobby_notifier.dart"), ({"02-table"}, ""))
        states, _ = self.states("frontend/lib/copy.dart")
        self.assertEqual(states, {"01-join", "02-table", "08-talk"})

    def test_a_change_no_state_draws_renders_nothing(self):
        self.assertEqual(self.states("frontend/lib/unused.dart"), (set(), ""))
        self.assertEqual(self.states("backend/apps/onuw/voting.py"), (set(), ""))

    def test_what_cannot_be_mapped_renders_everything_and_says_why(self):
        for path in (
            "frontend/assets/skins/a.png",
            "frontend/test_screens/screen_catalogue.dart",
            "frontend/test/helpers/shell_setup.dart",
            "frontend/pubspec.yaml",
        ):
            states, why = self.states(path)
            self.assertIsNone(states, path)
            self.assertIn(path, why)

    def test_a_class_name_is_found_where_it_is_declared(self):
        found = self.screens.DECLARED.findall(
            "final class A {}\nabstract class B {}\nenum C { x }\nmixin D {}\n"
            "  class NotTopLevel {}\nextension type E(int i) {}\n"
        )
        self.assertEqual(found, ["A", "B", "C", "D", "E"])

    def test_many_states_are_rendered_at_one_width_unless_both_are_asked_for(self):
        many = self.screens.MANY
        self.assertEqual(self.screens.widths_for(many, False), (360, 390))
        self.assertEqual(self.screens.widths_for(many + 1, False), (390,))
        self.assertEqual(self.screens.widths_for(many + 1, True), (360, 390))

    def test_no_screens_drops_the_step_and_nothing_else(self):
        tool = load(REPO)
        with_screens = [w for w, _, _ in tool.plan(["frontend/lib/app.dart"])]
        without = [w for w, _, _ in tool.plan(["frontend/lib/app.dart"], screens=False)]
        self.assertEqual([w for w in with_screens if "screen states" not in w], without)
        self.assertEqual(len(with_screens), len(without) + 1)

    def test_the_plan_renders_screens_only_for_what_can_change_one(self):
        def steps(*changed):
            return [what for what, _, _ in load(REPO).plan(list(changed))]

        self.assertTrue(any("screen states" in s for s in steps("frontend/lib/app.dart")))
        self.assertFalse(any("screen states" in s for s in steps("frontend/test/a_test.dart")))
        self.assertFalse(any("screen states" in s for s in steps("backend/apps/core/views.py")))


class NeverSilent(unittest.TestCase):
    """A builder's run "timed out at 500 s" having printed nothing: the plan says
    what it will cost before it starts, and a quiet step says it is alive."""

    def test_every_step_of_a_plan_has_a_guess_and_none_is_the_fallback(self):
        tool = load(REPO)
        changed = [
            "backend/apps/core/views.py",
            "backend/apps/core/migrations/0001_initial.py",
            "frontend/lib/app.dart",
            "frontend/pubspec.yaml",
            "contract_samples/http/x.json",
            "tool/piece_check.py",
        ]
        for what, _, command in tool.plan(changed):
            known = "frontend test files" in what or any(
                what.startswith(words) for words, _ in tool.GUESSES
            )
            self.assertTrue(known, f"no time guess for the step: {what}")
            self.assertGreater(tool.guess(what, command), 0)

    def test_a_selected_frontend_run_is_guessed_by_its_files(self):
        tool = load(REPO)
        few = tool.guess("3 frontend test files nearest the change", ["a_test.dart"] * 3)
        many = tool.guess("30 frontend test files nearest the change", ["a_test.dart"] * 30)
        self.assertGreater(many, few)

    def test_a_quiet_step_says_it_is_still_running(self):
        import contextlib
        import io
        import sys
        import time

        tool = load(REPO)
        tool.HEARTBEAT = 0.2
        said = io.StringIO()
        with contextlib.redirect_stdout(said):
            code = tool.run_aloud(
                [sys.executable, "-c", "import time; time.sleep(0.7)"],
                REPO, "a quiet step", time.monotonic(),
            )
        self.assertEqual(code, 0)
        self.assertIn("still running", said.getvalue())
        self.assertIn("a quiet step", said.getvalue())

    def test_a_failing_step_still_fails(self):
        import sys
        import time

        tool = load(REPO)
        code = tool.run_aloud([sys.executable, "-c", "raise SystemExit(3)"], REPO, "x", time.monotonic())
        self.assertEqual(code, 3)

