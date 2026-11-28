"""What the hand-over says about GitHub's required checks (tool/github_checks.py,
tool/lib_scans.py, and the steps and the file of tool/handover.py).

The checks are read from the workflow files and the ruleset, so nothing here pins the
list: a new job is read, a renamed one fails the ruleset test in test_workflows.py.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tool"))
import github_checks as gh  # noqa: E402
import lib_scans  # noqa: E402


def load_handover():
    spec = importlib.util.spec_from_file_location(
        "handover", ROOT / "tool" / "handover.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def passed(folder, *command):
    return {"ok": True, "folder": folder, "command": list(command)}


def failed(folder, *command):
    return {"ok": False, "folder": folder, "command": list(command)}


class ReadFromTheWorkflows(unittest.TestCase):
    def setUp(self):
        self.checks = {c.name: c for c in gh.required_checks(ROOT)}

    def test_every_required_check_is_found_with_something_to_run(self):
        self.assertEqual(sorted(self.checks), sorted(gh.required_names(ROOT)))
        for name, check in self.checks.items():
            self.assertTrue(check.recipes, f"{name} runs no recipe")

    def test_a_matrix_is_one_check_per_value_and_a_gate_holds_its_parts(self):
        self.assertEqual(
            self.checks["Screens strict at 360"].recipes,
            [("screens", ("360", "strict"))],
        )
        self.assertEqual(
            self.checks["Screens strict at 390"].recipes,
            [("screens", ("390", "strict"))],
        )
        parts = {
            args
            for name, args in self.checks["Widget Tests"].recipes
            if name == "test-widgets"
        }
        self.assertEqual(parts, {("1", "3"), ("2", "3"), ("3", "3")})

    def test_setup_and_after_failure_steps_are_not_checks(self):
        everything = {name for c in self.checks.values() for name, _ in c.recipes}
        self.assertNotIn("install", everything)
        self.assertNotIn("web-smoke-setup", everything)
        self.assertNotIn(
            "flutter-golden-report", everything
        )  # only after the golden tests failed

    def test_every_recipe_named_exists(self):
        if not shutil.which("just"):
            self.skipTest("just is not installed")
        known = set()
        for justfile in ("justfile", "backend/justfile", "frontend/justfile"):
            known |= set(
                subprocess.run(
                    ["just", "--justfile", str(ROOT / justfile), "--summary"],
                    capture_output=True,
                    text=True,
                    check=True,
                ).stdout.split()
            )
        known.add(
            "flutter-test"
        )  # the frontend's `test`, named apart from the backend's
        for check in self.checks.values():
            for name, _ in check.recipes:
                self.assertIn(name, known, check.name)

    def test_a_workflow_with_a_new_job_is_read(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / ".github" / "workflows").mkdir(parents=True)
            (root / "docs" / "dev").mkdir(parents=True)
            (root / "docs" / "dev" / "main-ruleset.json").write_text(
                '{"rules": [{"type": "required_status_checks", "parameters": {"required_status_checks":'
                ' [{"context": "Fresh Check"}]}}]}'
            )
            (root / ".github" / "workflows" / "x.yml").write_text(
                "name: X\njobs:\n  fresh:\n    name: Fresh Check\n    runs-on: ubuntu-latest\n"
                "    steps:\n      - name: Install just\n        uses: extractions/setup-just@v2\n"
                "      - name: Do it\n        run: just brand-new-recipe 7\n"
                "      - name: Pictures\n        if: failure()\n        run: just only-after-failure\n"
            )
            [check] = gh.required_checks(root)
            self.assertEqual(check.recipes, [("brand-new-recipe", ("7",))])


class WhatARunCovered(unittest.TestCase):
    def setUp(self):
        self.checks = gh.required_checks(ROOT)

    def rows(self, *results):
        return {r["name"]: r for r in gh.judge(self.checks, list(results))}

    def test_nothing_run_is_not_run_here_for_every_check(self):
        rows = self.rows()
        self.assertEqual({r["state"] for r in rows.values()}, {"NOT run here"})

    def test_the_golden_job_is_passed_by_its_own_recipe_and_by_nothing_less(self):
        self.assertEqual(
            self.rows(passed("frontend", "just", "flutter-test-golden"))[
                "Golden Tests"
            ]["state"],
            "passed",
        )
        only_scans = self.rows(
            passed("frontend", "flutter", "test", "--tags", "x", "a_test.dart")
        )
        self.assertEqual(only_scans["Golden Tests"]["state"], "NOT run here")

    def test_a_failed_golden_run_fails_that_check_and_only_that_one(self):
        rows = self.rows(
            failed("frontend", "just", "flutter-test-golden"),
            passed(".", "just", "check"),
        )
        self.assertEqual(rows["Golden Tests"]["state"], "FAILED")
        self.assertNotEqual(rows["Widget Tests"]["state"], "FAILED")

    def test_the_whole_frontend_suite_covers_widgets_and_goldens(self):
        rows = self.rows(passed("frontend", "just", "flutter-test"))
        self.assertEqual(rows["Widget Tests"]["state"], "passed")
        self.assertEqual(rows["Golden Tests"]["state"], "passed")
        # the backend's `just test` is another recipe with the same name
        self.assertNotEqual(rows["Backend Checks"]["state"], "passed")

    def test_the_nearest_files_are_only_part_of_the_widget_tests(self):
        rows = self.rows(passed("frontend", "flutter", "test", "a_test.dart"))
        self.assertEqual(rows["Widget Tests"]["state"], "partly")

    def test_screens_drawn_for_a_change_are_only_part_of_a_screens_check(self):
        rows = self.rows(
            passed(
                ".", sys.executable, "tool/piece_screens.py", "--both-widths", "x.dart"
            )
        )
        self.assertEqual(rows["Screens strict at 360"]["state"], "partly")
        self.assertEqual(rows["Screens strict at 390"]["state"], "partly")

    def test_a_check_with_several_recipes_is_passed_only_when_all_ran(self):
        rows = self.rows(
            passed("frontend", "just", "analyze"),
            passed("frontend", "just", "flutter-format-check"),
        )
        self.assertEqual(rows["Analyze and Format"]["state"], "partly")
        rows = self.rows(
            *[
                passed("frontend", "just", r)
                for r in ("analyze", "flutter-format-check", "gen-check")
            ]
        )
        self.assertEqual(rows["Analyze and Format"]["state"], "passed")

    def test_the_harness_is_its_own_check(self):
        rows = self.rows(passed(".", "just", "test-harness"))
        self.assertEqual(rows["End-to-end Harness"]["state"], "passed")


class TheFirstLine(unittest.TestCase):
    def rows(self, *results):
        return gh.judge(gh.required_checks(ROOT), list(results))

    def test_ready_says_how_many_of_githubs_checks_ran_here(self):
        rows = self.rows(
            passed("frontend", "just", "flutter-test-golden"),
            passed(".", "just", "test-harness"),
        )
        total = len(gh.required_names(ROOT))
        self.assertEqual(
            gh.headline(rows, True), f"READY (2 of {total} of GitHub's checks run here)"
        )

    def test_ready_is_never_said_when_a_step_failed_or_a_state_was_not_drawn(self):
        rows = self.rows(failed("frontend", "just", "flutter-test-golden"))
        self.assertTrue(gh.headline(rows, False).startswith("NOT READY"))
        self.assertTrue(
            gh.headline(rows, True).startswith("NOT READY"),
            "a failed check outweighs the rest",
        )

    def test_the_table_has_a_row_for_every_required_check(self):
        rows = self.rows()
        lines = gh.table(rows)
        self.assertEqual(len(lines), 2 + len(gh.required_names(ROOT)))
        self.assertTrue(all("NOT run here" in line for line in lines[2:]))


class TheScansAreFoundByWhatTheyDo(unittest.TestCase):
    def test_a_test_that_lists_a_tree_or_is_a_guard_is_a_scan_and_nothing_else_is(self):
        with tempfile.TemporaryDirectory() as tmp:
            test = Path(tmp) / "frontend" / "test" / "a"
            test.mkdir(parents=True)
            (test / "walks_test.dart").write_text(
                "void main() { for (final f in Directory('lib')\n    .listSync(recursive: true)) {} }\n"
            )
            (test / "guard_test.dart").write_text(
                "// Guard file: why\nvoid main() {}\n"
            )
            (test / "plain_test.dart").write_text("void main() { test('x', () {}); }\n")
            (test / "one_folder_test.dart").write_text(
                "void main() { Directory('lib/a').listSync(); }\n"
            )
            (test / "helper.dart").write_text(
                "// Guard file\nDirectory('lib').listSync(recursive: true);\n"
            )
            self.assertEqual(
                lib_scans.whole_lib_tests(Path(tmp)),
                ["test/a/guard_test.dart", "test/a/walks_test.dart"],
            )

    def test_the_scan_that_failed_github_is_among_them(self):
        found = lib_scans.whole_lib_tests(ROOT)
        self.assertIn("test/design_system/copy/widget_strings_test.dart", found)
        self.assertIn("test/design_system/skin/raw_values_test.dart", found)

    def test_every_test_in_the_app_that_walks_lib_is_found(self):
        top = ROOT / "frontend" / "test"
        found = set(lib_scans.whole_lib_tests(ROOT))
        for path in top.rglob("*_test.dart"):
            text = path.read_text()
            if "Directory('lib')" in text and "recursive: true" in text:
                self.assertIn(str(path.relative_to(ROOT / "frontend")), found)


class TheHandoverRunsThemToo(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.handover = load_handover()
        cls.piece = cls.handover.tool("piece_check")

    def names(self, *changed):
        return [
            what for what, _, _ in self.handover.steps_for(list(changed), self.piece)
        ]

    def test_a_change_to_the_apps_code_runs_the_goldens_and_every_scan(self):
        steps = self.handover.steps_for(
            ["frontend/lib/design_system/skin/x.dart"], self.piece
        )
        by_what = {what: command for what, _, command in steps}
        self.assertEqual(by_what["the golden tests"], ["just", "flutter-test-golden"])
        [scan] = [c for w, c in by_what.items() if "scan all of lib" in w]
        self.assertIn("test/design_system/copy/widget_strings_test.dart", scan)
        self.assertEqual(
            len([a for a in scan if a.endswith("_test.dart")]),
            len(lib_scans.whole_lib_tests(ROOT)),
        )

    def test_a_change_to_assets_runs_them_too(self):
        steps = self.names("frontend/assets/skins/x.png")
        # an asset can change any test: the whole suite runs, goldens and scans with it
        self.assertTrue(any(s.startswith("all frontend tests") for s in steps), steps)
        self.assertNotIn(
            "the golden tests", steps, "the whole suite already holds them"
        )

    def test_a_change_to_the_server_alone_does_not(self):
        steps = self.names("backend/apps/core/x.py")
        self.assertFalse(any("golden" in s or "scan" in s for s in steps), steps)

    def test_a_change_to_a_tool_alone_does_not(self):
        steps = self.names("tool/x.py")
        self.assertFalse(any("golden" in s or "scan" in s for s in steps), steps)

    def test_each_has_a_time_to_plan_by(self):
        for what, folder, command in self.handover.steps_for(
            ["frontend/lib/x.dart"], self.piece
        ):
            self.assertGreater(self.handover.guess(what, command, self.piece), 0, what)


class TheFile(unittest.TestCase):
    def write(self, results, rows, shots=None):
        handover = load_handover()
        shots = shots or {"changed": [], "new": [], "missing": [], "sheets": []}
        found = {
            "guards": [],
            "words": [],
            "specs": [],
            "screen_code": [],
            "owner_feedback": False,
        }
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "h.md"
            ready = handover.write(
                path,
                "piece",
                "a" * 40,
                0,
                ["frontend/lib/x.dart"],
                results,
                shots,
                [],
                "",
                found,
                rows,
            )
            return ready, path.read_text()

    def done(self, ok=True):
        return {
            "ok": ok,
            "seconds": 3,
            "what": "the golden tests",
            "again": True,
            "folder": "frontend",
            "command": ["just", "flutter-test-golden"],
        }

    def test_the_first_line_says_ready_with_how_much_of_githubs_wall_ran(self):
        rows = gh.judge(gh.required_checks(ROOT), [self.done()])
        ready, text = self.write([self.done()], rows)
        self.assertTrue(ready)
        total = len(rows)
        self.assertEqual(
            text.splitlines()[0].split("**")[1],
            f"READY (1 of {total} of GitHub's checks run here)",
        )
        self.assertIn("does not say GitHub will pass", text)
        self.assertIn("| Golden Tests | passed |", text)
        self.assertIn("| Release has no debug toolbar | NOT run here |", text)

    def test_a_failed_golden_run_is_not_ready_in_the_first_line_and_in_the_table(self):
        rows = gh.judge(gh.required_checks(ROOT), [self.done(ok=False)])
        ready, text = self.write([self.done(ok=False)], rows)
        self.assertFalse(ready)
        self.assertTrue(text.startswith("**NOT READY"))
        self.assertIn("| Golden Tests | **FAILED** |", text)

    def test_the_table_comes_after_the_pictures_and_before_the_checks(self):
        rows = gh.judge(gh.required_checks(ROOT), [self.done()])
        shots = {"changed": [], "new": [], "missing": [], "sheets": ["/x/sheet.png"]}
        _, text = self.write([self.done()], rows, shots)
        self.assertLess(
            text.index("/x/sheet.png"), text.index("## GitHub's required checks")
        )
        self.assertLess(
            text.index("## GitHub's required checks"), text.index("## Checks, run on")
        )


if __name__ == "__main__":
    unittest.main()
