# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""The branches Vercel deploys from move only when what they serve changed
(tool/promote_live.py).

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SCRIPT = REPO / "tool" / "promote_live.py"


def load(root: Path):
    spec = importlib.util.spec_from_file_location("promote_live", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.ROOT = root
    return module


class PromoteLive(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        self.remote = base / "remote.git"
        self.root = base / "work"
        subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(self.remote)], check=True)
        subprocess.run(["git", "clone", "-q", str(self.remote), str(self.root)], check=True, capture_output=True)
        self.git("config", "user.email", "t@t")
        self.git("config", "user.name", "t")
        self.promote = load(self.root)
        self.merge({"backend/apps/a.py": "1", "frontend/lib/a.dart": "1"})

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args: str) -> str:
        return subprocess.run(
            ["git", "-C", str(self.root), *args], check=True, capture_output=True, text=True
        ).stdout.strip()

    def merge(self, files: dict[str, str]) -> str:
        """A merge to main touching these files; returns its commit."""
        for name, text in files.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "merge")
        self.git("push", "-q", "origin", "HEAD:main")
        return self.git("rev-parse", "HEAD")

    def run_it(self) -> dict[str, str]:
        self.assertEqual(self.promote.main([]), 0)
        return {
            side: self.promote.remote_head(branch)
            for side, (branch, _, _) in self.promote.SIDES.items()
        }

    def test_the_first_run_makes_both_branches(self):
        head = self.git("rev-parse", "HEAD")
        self.assertEqual(self.run_it(), {"server": head, "app": head})

    def test_a_server_change_moves_only_the_server(self):
        first = self.run_it()
        head = self.merge({"backend/apps/a.py": "2"})
        self.assertEqual(self.run_it(), {"server": head, "app": first["app"]})

    def test_an_app_change_moves_only_the_app(self):
        first = self.run_it()
        head = self.merge({"frontend/lib/a.dart": "2"})
        self.assertEqual(self.run_it(), {"server": first["server"], "app": head})

    def test_tests_docs_and_tooling_move_nothing(self):
        first = self.run_it()
        self.merge(
            {
                "backend/tests/test_a.py": "x",
                "backend/CLAUDE.md": "x",
                "frontend/test/a_test.dart": "x",
                "frontend/test_screens/a.dart": "x",
                "frontend/README.md": "x",
                "docs/a.md": "x",
                "tool/a.py": "x",
                ".github/workflows/a.yml": "x",
                "contract_samples/a.json": "x",
            }
        )
        self.assertEqual(self.run_it(), first)

    def test_what_a_build_reads_moves_its_side(self):
        for name, side in (
            ("backend/pyproject.toml", "server"),
            ("backend/vercel.json", "server"),
            ("backend/apps/core/migrations/0099_x.py", "server"),
            ("frontend/pubspec.yaml", "app"),
            ("frontend/assets/a.png", "app"),
            ("frontend/vercel.json", "app"),
            ("frontend/tool/vercel_build.sh", "app"),
        ):
            before = self.run_it()
            head = self.merge({name: name + "changed"})
            after = self.run_it()
            self.assertEqual(after[side], head, name)
            other = "app" if side == "server" else "server"
            self.assertEqual(after[other], before[other], name)

    def test_a_missed_run_is_made_up_by_the_next(self):
        first = self.run_it()
        self.merge({"backend/apps/a.py": "2"})  # its run was cancelled: nothing moved
        head = self.merge({"docs/a.md": "x"})  # this merge ships nothing itself
        self.assertEqual(self.run_it(), {"server": head, "app": first["app"]})

    def test_an_older_run_arriving_late_does_not_move_a_branch_back(self):
        self.run_it()
        older = self.merge({"backend/apps/a.py": "2"})
        newer = self.merge({"backend/apps/a.py": "3"})
        self.run_it()  # the newer merge's run got there first
        self.git("checkout", "-q", older)
        self.assertEqual(self.promote.main([]), 0)
        self.assertEqual(self.promote.remote_head("live-server"), newer)

    def test_a_dry_run_moves_nothing(self):
        self.assertEqual(self.promote.main(["--dry-run"]), 0)
        self.assertEqual(self.promote.remote_head("live-server"), "")


if __name__ == "__main__":
    unittest.main()
