"""The file size check (tool/check_file_sizes.py): a source file may not pass the limit,
and one already over it may shrink but not grow.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
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
    module.CEILINGS = root / "tool" / "file_size_ceilings.txt"
    return module


class FileSizes(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        self.check = load(self.root)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, name: str, lines: int) -> None:
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("x = 1\n" * lines)

    def ceilings(self, text: str) -> None:
        self.write("tool/file_size_ceilings.txt", 0)
        (self.root / "tool" / "file_size_ceilings.txt").write_text(text)

    def run_check(self, *args: str) -> int:
        return self.check.main(list(args))

    def test_a_file_at_the_limit_passes_and_one_line_more_fails(self):
        self.write("backend/apps/onuw/night.py", self.check.LIMIT)
        self.assertEqual(self.run_check(), 0)
        self.write("backend/apps/onuw/night.py", self.check.LIMIT + 1)
        self.assertEqual(self.run_check(), 1)

    def test_a_listed_file_may_shrink_but_not_grow(self):
        self.ceilings("900 frontend/lib/big.dart\n")
        self.write("frontend/lib/big.dart", 900)
        self.assertEqual(self.run_check(), 0)
        self.write("frontend/lib/big.dart", 850)
        self.assertEqual(self.run_check(), 0)
        self.write("frontend/lib/big.dart", 901)
        self.assertEqual(self.run_check(), 1)

    def test_an_allowance_lets_a_file_grow_and_a_passed_date_never_fails(self):
        self.ceilings("700 frontend/lib/moving.dart until 2020-01-01\n")
        self.write("frontend/lib/moving.dart", 2000)

        self.assertEqual(self.run_check(), 0)  # the date is long past: said, never failed

        self.assertEqual(self.run_check("--write"), 0)  # re-recording keeps the allowance
        listed = self.check.read_ceilings(staged=False)
        self.assertEqual(listed, {"frontend/lib/moving.dart": (2000, "2020-01-01")})

    def test_what_is_not_source_is_not_counted(self):
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
        self.write("tool/long.py", 700)
        subprocess.run(["git", "-C", str(self.root), "add", "tool/long.py"], check=True)
        self.write("tool/long.py", 10)  # fixed on disk, but the long one is staged
        self.assertEqual(self.run_check(), 0)
        self.assertEqual(self.run_check("--staged"), 1)

    def test_write_lists_exactly_the_files_over_the_limit(self):
        self.write("tool/long.py", 700)
        self.write("tool/short.py", 20)
        self.assertEqual(self.run_check("--write"), 0)
        listed = self.check.read_ceilings(staged=False)
        self.assertEqual(listed, {"tool/long.py": (700, "")})
        self.assertEqual(self.run_check(), 0)

    def test_this_repo_passes_and_its_list_has_no_stale_line(self):
        real = load(REPO)
        self.assertEqual(real.main([]), 0)
        counts = real.line_counts(staged=False)
        for path, (ceiling, until) in real.read_ceilings(staged=False).items():
            with self.subTest(path=path):
                self.assertIn(path, counts, "listed but gone: remove its line")
                if until:
                    continue  # an allowance: free to grow or shrink while its work is in it
                self.assertGreater(counts[path], real.LIMIT, "under the limit now: remove its line")
                self.assertLessEqual(counts[path], ceiling)


if __name__ == "__main__":
    unittest.main()
