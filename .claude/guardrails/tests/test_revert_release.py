# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""The way back (tool/revert_release.py, `just revert-release`), rehearsed on a throwaway
repository: it makes a branch from main that undoes one merge, keeps the migrations the
live database has run, says which side redeploys, and pushes only when asked. It refuses
what would break the deploy-safe rules: a change at or below the floor, one not on main.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]


def load(root: Path, floor: str):
    spec = importlib.util.spec_from_file_location(
        "revert_release", REPO / "tool" / "revert_release.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.ROOT = root
    module.promote_live.ROOT = root
    module.promote_live.FLOOR = floor
    return module


class RevertRelease(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        self.remote, self.root = base / "remote.git", base / "work"
        subprocess.run(
            ["git", "init", "-q", "--bare", "-b", "main", str(self.remote)], check=True
        )
        subprocess.run(
            ["git", "clone", "-q", str(self.remote), str(self.root)],
            check=True,
            capture_output=True,
        )
        self.git("config", "user.email", "t@t")
        self.git("config", "user.name", "t")
        self.floor = self.merge(
            80, {"backend/apps/core/models.py": "class Lobby: pass\n"}
        )
        self.merge(81, {"backend/apps/core/views.py": "v = 1\n"})
        self.tool = load(self.root, self.floor)

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args: str) -> str:
        return subprocess.run(
            ["git", "-C", str(self.root), *args],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

    def merge(self, number: int, files: dict[str, str]) -> str:
        for name, text in files.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        self.git("add", "-A")
        self.git("commit", "-q", "-m", f"feat(x): change {number} (#{number})")
        self.git("push", "-q", "origin", "HEAD:main")
        return self.git("rev-parse", "HEAD")

    def revert(self, what: str, **kwargs) -> tuple[int, str]:
        said = []
        code = self.tool.revert(what, say=said.append, **kwargs)
        return code, "\n".join(said)

    def test_a_server_change_is_undone_on_a_new_branch_from_main(self):
        self.merge(90, {"backend/apps/core/views.py": "v = 2\n"})
        later = self.merge(91, {"docs/a.md": "x\n"})
        code, said = self.revert("90")
        self.assertEqual(code, 0, said)
        self.assertEqual(self.git("rev-parse", "--abbrev-ref", "HEAD"), "revert-90")
        self.assertEqual(
            self.git("rev-parse", "HEAD~1"), later
        )  # on top of main, nothing rewound
        self.assertEqual(
            (self.root / "backend/apps/core/views.py").read_text(), "v = 1\n"
        )
        self.assertIn(
            'fix(revert): undo 90, "feat(x): change 90 (#90)"',
            self.git("log", "-1", "--format=%s"),
        )
        self.assertIn("the server redeploys", said)
        self.assertIn("added no migration", said)
        self.assertIn("not crossed", said)
        self.assertIn("`git push -u origin revert-90`", said)
        self.assertIn("just revert-release 90 --push", said)  # never `#90` in a command
        self.assertIn("Instant Rollback", said)

    def test_it_says_which_side_redeploys(self):
        for number, files, side in (
            (92, {"frontend/lib/a.dart": "2\n"}, "the app redeploys"),
            (
                93,
                {"backend/apps/b.py": "1\n", "frontend/lib/b.dart": "1\n"},
                "live-server first, then live-app once the server serves it",
            ),
            (
                94,
                {"docs/b.md": "1\n", "backend/tests/test_b.py": "1\n"},
                "nothing live redeploys",
            ),
        ):
            with self.subTest(number=number):
                self.git("switch", "-q", "main")
                self.git("reset", "-q", "--hard", "origin/main")
                self.merge(number, files)
                code, said = self.revert(str(number))
                self.assertEqual(code, 0, said)
                self.assertIn(side, said)

    def test_the_migrations_the_live_database_ran_are_kept(self):
        migration = "backend/apps/core/migrations/0099_add_colour.py"
        self.merge(
            95,
            {
                migration: "# adds a column\n",
                "backend/apps/core/models.py": "class Lobby: colour = 1\n",
            },
        )
        code, said = self.revert("95")
        self.assertEqual(code, 0, said)
        self.assertTrue(
            (self.root / migration).is_file()
        )  # kept: the database has run it
        self.assertEqual(
            (self.root / "backend/apps/core/models.py").read_text(),
            "class Lobby: pass\n",
        )
        self.assertIn(migration, said)
        self.assertIn("two pushes", said)
        self.assertIn("never edit or delete", said)

    def test_nothing_is_pushed_unless_asked(self):
        self.merge(96, {"backend/apps/core/views.py": "v = 3\n"})
        self.assertEqual(self.revert("96")[0], 0)
        heads = self.git("ls-remote", "--heads", "origin")
        self.assertNotIn("revert-96", heads)
        self.git("switch", "-q", "main")
        self.merge(97, {"backend/apps/core/views.py": "v = 4\n"})
        code, said = self.revert("97", push=True)
        self.assertEqual(code, 0, said)
        heads = self.git("ls-remote", "--heads", "origin")
        self.assertIn("refs/heads/revert-97", heads)
        self.assertNotIn("live-", heads)

    def test_a_change_at_or_below_the_floor_is_refused(self):
        for what in ("80", self.floor[:10]):
            with self.subTest(what=what):
                code, said = self.revert(what)
                self.assertEqual(code, 1)
                self.assertIn("rollback floor", said)
                self.assertIn("Roll forward", said)
        self.assertEqual(self.git("rev-parse", "--abbrev-ref", "HEAD"), "main")

    def test_a_commit_not_on_main_is_refused(self):
        self.git("switch", "-q", "-c", "side")
        (self.root / "x.txt").write_text("x")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "chore: x")
        code, said = self.revert(self.git("rev-parse", "HEAD"))
        self.assertEqual(code, 1)
        self.assertIn("not on main", said)

    def test_a_change_later_work_builds_on_is_left_as_it_was(self):
        self.merge(98, {"backend/apps/core/views.py": "v = 5\n"})
        self.merge(99, {"backend/apps/core/views.py": "v = 6\n"})
        code, said = self.revert("98")
        self.assertEqual(code, 1)
        self.assertIn("does not revert cleanly", said)
        self.assertEqual(self.git("rev-parse", "--abbrev-ref", "HEAD"), "main")
        self.assertEqual(self.git("status", "--porcelain"), "")
        self.assertNotIn("revert-98", self.git("branch"))

    def test_a_dirty_working_tree_is_refused(self):
        (self.root / "backend/apps/core/views.py").write_text("unsaved\n")
        code, said = self.revert("81")
        self.assertEqual(code, 1)
        self.assertIn("working tree has changes", said)

    def test_the_recipe_exists(self):
        self.assertRegex(
            (REPO / "justfile").read_text(),
            r"(?m)^revert-release \*args:\s*\n\s+.*tool/revert_release\.py",
        )


if __name__ == "__main__":
    unittest.main()
