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


if __name__ == "__main__":
    unittest.main()
