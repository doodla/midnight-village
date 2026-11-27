"""tool/path_without.py: a PATH that lacks some tools, so a check runs as GitHub's job runs it.

`just test-guardrails` runs without Flutter and Dart because GitHub's "Backend Checks" job has
neither; a guardrail test that needs one passed on a builder's machine and failed only there.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tool"))
import path_without  # noqa: E402


class TheTool(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.bin = self.tmp / "bin"
        self.other = self.tmp / "other"
        for folder in (self.bin, self.other):
            folder.mkdir()
        for folder, name in (
            (self.bin, "flutter"),
            (self.bin, "keep"),
            (self.other, "also"),
        ):
            (folder / name).write_text("#!/bin/sh\necho " + name + "\n")
            (folder / name).chmod(0o755)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def path(self, *names):
        return path_without.path_without(
            list(names),
            os.pathsep.join([str(self.bin), str(self.other)]),
            self.tmp / "scratch",
        )

    def test_the_tool_is_gone_and_its_neighbours_stay_where_they_were(self):
        new = self.path("flutter")
        self.assertIsNone(shutil.which("flutter", path=new))
        self.assertIsNotNone(shutil.which("keep", path=new))
        self.assertIsNotNone(shutil.which("also", path=new))
        first, second = new.split(os.pathsep)
        self.assertNotEqual(
            first, str(self.bin), "the folder with the tool is replaced"
        )
        self.assertEqual(second, str(self.other), "a folder without it is left alone")

    def test_a_missing_tool_is_missing_not_a_failing_stand_in(self):
        with self.assertRaises(FileNotFoundError):
            subprocess.run(["flutter"], env={"PATH": self.path("flutter")})

    def test_nothing_to_remove_changes_nothing(self):
        self.assertEqual(
            self.path("nope"), os.pathsep.join([str(self.bin), str(self.other)])
        )


class TheRecipe(unittest.TestCase):
    def test_guardrail_tests_run_without_flutter_and_dart(self):
        text = (ROOT / "justfile").read_text()
        recipe = text[text.index("\ntest-guardrails:") :].split("\n\n")[0]
        self.assertEqual(
            len(re.findall(r'PATH="\$\(tool/path_without\.py flutter dart\)"', recipe)),
            2,
            recipe,
        )


if __name__ == "__main__":
    unittest.main()
