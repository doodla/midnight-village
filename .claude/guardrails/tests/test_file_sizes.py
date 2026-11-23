"""The file size check (tool/check_file_sizes.py): a change may not make a source file
longer than can be read whole, and may not add to one that already is. There is no
list to keep: the check compares with main.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SCRIPT = REPO / "tool" / "check_file_sizes.py"


def load(root: Path):
    """The script as a module that looks at `root` instead of this repo."""
    spec = importlib.util.spec_from_file_location("check_file_sizes", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.ROOT = root
    return module


class FileSizes(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.email", "t@t")
        self.git("config", "user.name", "t")
        self.check = load(self.root)
        self.limit = self.check.LIMIT
        os.environ["FILE_SIZE_BASE"] = "main"
        self.addCleanup(os.environ.pop, "FILE_SIZE_BASE", None)

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args: str) -> None:
        subprocess.run(["git", "-C", str(self.root), *args], check=True, capture_output=True)

    def write(self, name: str, lines: int) -> None:
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("x = 1\n" * lines)

    def on_main(self, files: dict[str, int]) -> None:
        """Commit these files on main, then start a branch for the change."""
        for name, lines in files.items():
            self.write(name, lines)
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "main")
        self.git("checkout", "-q", "-b", "change")

    def run_check(self, *args: str) -> int:
        return self.check.main(list(args))

    def test_a_new_file_at_the_limit_passes_and_one_line_more_fails(self):
        self.on_main({"tool/small.py": 1})
        self.write("backend/apps/onuw/night.py", self.limit)
        self.assertEqual(self.run_check(), 0)
        self.write("backend/apps/onuw/night.py", self.limit + 1)
        self.assertEqual(self.run_check(), 1)

    def test_a_file_under_the_limit_may_not_pass_it(self):
        self.on_main({"tool/a.py": self.limit - 10})
        self.write("tool/a.py", self.limit)
        self.assertEqual(self.run_check(), 0)
        self.write("tool/a.py", self.limit + 1)
        self.assertEqual(self.run_check(), 1)

    def test_a_long_file_may_stay_or_shrink_but_not_grow(self):
        self.on_main({"frontend/lib/big.dart": 900})
        self.assertEqual(self.run_check(), 0)  # left alone: nothing to edit anywhere
        self.write("frontend/lib/big.dart", 850)
        self.assertEqual(self.run_check(), 0)
        self.write("frontend/lib/big.dart", 901)
        self.assertEqual(self.run_check(), 1)

    def test_growth_is_measured_from_main_not_from_the_last_commit(self):
        """Small steps do not add up to a pass: every step is over main's size."""
        self.on_main({"frontend/lib/big.dart": 900})
        self.write("frontend/lib/big.dart", 901)
        self.git("commit", "-qam", "one more line")
        self.assertEqual(self.run_check(), 1)
        self.assertEqual(self.run_check("--staged"), 1)

    def test_a_long_file_that_is_renamed_is_compared_with_its_old_path(self):
        self.on_main({"frontend/lib/big.dart": 900})
        self.git("mv", "frontend/lib/big.dart", "frontend/lib/moved.dart")
        self.assertEqual(self.run_check("--staged"), 0)
        self.git("commit", "-qm", "move")
        self.assertEqual(self.run_check(), 0)
        self.write("frontend/lib/moved.dart", 905)
        self.assertEqual(self.run_check(), 1)

    def test_what_is_not_source_is_not_counted(self):
        self.on_main({"tool/small.py": 1})
        for name in (
            "frontend/lib/a.g.dart",
            "frontend/lib/a.freezed.dart",
            "backend/apps/core/migrations/0001_initial.py",
            "backend/tests/test_big.py",
            "frontend/test/big_test.dart",
            "docs/long.md",
            ".claude/guardrails/tests/test_long.py",
        ):
            self.write(name, 5000)
        self.assertEqual(self.run_check(), 0)

    def test_staged_reads_what_is_being_committed(self):
        self.on_main({"tool/small.py": 1})
        self.write("tool/long.py", 700)
        self.git("add", "tool/long.py")
        self.write("tool/long.py", 10)  # fixed on disk, but the long one is staged
        self.assertEqual(self.run_check(), 0)
        self.assertEqual(self.run_check("--staged"), 1)

    def test_without_that_base_the_change_is_compared_with_its_own_head(self):
        self.on_main({"tool/long.py": 700})
        os.environ["FILE_SIZE_BASE"] = "nowhere/main"
        self.assertEqual(self.run_check(), 0)
        self.write("tool/long.py", 701)
        self.assertEqual(self.run_check(), 1)

    def test_a_repository_with_no_commit_holds_every_file_to_the_limit(self):
        self.write("tool/long.py", 700)
        self.assertEqual(self.run_check(), 1)

    def test_this_repo_passes(self):
        os.environ.pop("FILE_SIZE_BASE", None)
        self.assertEqual(load(REPO).main([]), 0)


if __name__ == "__main__":
    unittest.main()
