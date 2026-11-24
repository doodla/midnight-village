"""tool/failed_tests.py: a red run's last lines name each failed test.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]


def load():
    spec = importlib.util.spec_from_file_location(
        "failed_tests", REPO / "tool" / "failed_tests.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def flutter_report(events: list[dict]) -> str:
    return "\n".join(json.dumps(e) for e in events) + "\nnot json at all\n"


class Flutter(unittest.TestCase):
    def read(self, events):
        with tempfile.TemporaryDirectory() as tmp:
            report = Path(tmp) / "report.jsonl"
            report.write_text(flutter_report(events))
            return load().flutter(report)

    def start(self, test_id, name):
        return {
            "type": "testStart",
            "test": {
                "id": test_id,
                "name": name,
                "url": "file:///x/frontend/test/a_test.dart",
                "line": 7,
            },
        }

    def test_a_failed_expectation_is_named_with_its_file_and_what_it_expected(self):
        found = self.read(
            [
                self.start(1, "it passes"),
                {"type": "testDone", "testID": 1, "result": "success"},
                self.start(2, "one and one is three"),
                {"type": "error", "testID": 2, "error": "Expected: <3>\n  Actual: <2>\n"},
                {"type": "testDone", "testID": 2, "result": "failure"},
            ]
        )
        self.assertEqual(
            found,
            [("test/a_test.dart:7", "one and one is three", "Expected: <3>  Actual: <2>")],
        )

    def test_what_a_widget_test_threw_is_read_from_what_it_printed(self):
        found = self.read(
            [
                self.start(3, "it throws"),
                {
                    "type": "print",
                    "testID": 3,
                    "message": "\u2550\u2550\u2561 EXCEPTION CAUGHT \u255e\u2550\u2550\n"
                    "The following StateError was thrown running a test:\n"
                    "Bad state: the stand-in is wrong\n",
                },
                {
                    "type": "error",
                    "testID": 3,
                    "error": "Test failed. See exception logs above.",
                },
                {"type": "testDone", "testID": 3, "result": "error"},
            ]
        )
        self.assertIn("Bad state: the stand-in is wrong", found[0][2])

    def test_a_long_value_is_said_by_what_differs(self):
        found = self.read(
            [
                self.start(4, "the event"),
                {
                    "type": "error",
                    "testID": 4,
                    "error": "Expected: {\n  'type': 'host_changed',\n}\n  Actual: {\n  'type': 'host_changed',\n  'rev': 7\n}\n   Which: has different length and has extra map key 'rev'\n",
                },
                {"type": "testDone", "testID": 4, "result": "failure"},
            ]
        )
        self.assertIn("Which: has different length and has extra map key 'rev'", found[0][2])

    def test_a_green_run_says_nothing(self):
        tool = load()
        self.assertEqual(tool.said([], on_github=True), "")


class Junit(unittest.TestCase):
    def test_a_failed_case_is_named_with_its_message(self):
        with tempfile.TemporaryDirectory() as tmp:
            report = Path(tmp) / "junit.xml"
            report.write_text(
                '<testsuites><testsuite>'
                '<testcase classname="tests.core.test_a" name="test_fine"/>'
                '<testcase classname="tests.core.test_a" name="test_sum">'
                '<failure message="AssertionError: sums are wrong">trace</failure>'
                "</testcase></testsuite></testsuites>"
            )
            found = load().junit(report)
        self.assertEqual(
            found, [("tests/core/test_a.py", "test_sum", "AssertionError: sums are wrong")]
        )


class Said(unittest.TestCase):
    FAILED = [("test/a_test.dart:7", "a, name: with marks", "50% wrong")]

    def test_the_list_ends_the_output_and_names_each_test(self):
        text = load().said(self.FAILED, on_github=False)
        self.assertIn("WHAT FAILED (1):", text)
        self.assertIn("a, name: with marks", text)
        self.assertNotIn("::error", text)

    def test_on_github_each_failed_test_is_one_annotation_line(self):
        text = load().said(self.FAILED, on_github=True)
        lines = [line for line in text.splitlines() if line.startswith("::error")]
        self.assertEqual(len(lines), 1)
        self.assertIn("50%25 wrong", lines[0])

    def test_a_missing_report_is_said_and_is_not_an_error(self):
        self.assertEqual(load().main(["flutter", "/nowhere/report.jsonl"]), 0)


if __name__ == "__main__":
    unittest.main()
