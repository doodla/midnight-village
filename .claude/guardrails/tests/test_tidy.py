# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""`just tidy` (tool/tidy.py) clears only what is finished, and never loses work.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SCRIPT = REPO / "tool" / "tidy.py"


def load(root: Path):
    spec = importlib.util.spec_from_file_location("tidy", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.ROOT = root
    return module


class Tidy(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name).resolve()
        self.remote = base / "remote.git"
        self.root = base / "main"
        self.trees = base / "trees"
        subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(self.remote)], check=True)
        subprocess.run(["git", "clone", "-q", str(self.remote), str(self.root)], check=True, capture_output=True)
        self.git("config", "user.email", "t@t")
        self.git("config", "user.name", "t")
        (self.root / "a.txt").write_text("a")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "first")
        self.git("push", "-q", "origin", "HEAD:main")
        self.tidy = load(self.root)

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args: str, cwd: Path | None = None) -> str:
        return subprocess.run(
            ["git", "-C", str(cwd or self.root), *args], check=True, capture_output=True, text=True
        ).stdout

    def worktree(self, branch: str, *, pushed: bool, merged: bool = False) -> Path:
        """A builder's worktree on `branch`, with build output in it."""
        folder = self.trees / branch
        self.git("worktree", "add", "-q", "-b", branch, str(folder))
        if pushed:
            self.git("push", "-q", "-u", "origin", branch, cwd=folder)
        if merged:  # a merged pull request deletes its branch on the remote
            self.git("push", "-q", "origin", "--delete", branch)
        for part in ("frontend/build/web", "backend/.venv/lib"):
            (folder / part).mkdir(parents=True)
            (folder / part / "big.bin").write_bytes(b"x" * 4096)
        (folder / ".gitignore").write_text("frontend/build/\nbackend/.venv/\n")
        self.git("add", ".gitignore", cwd=folder)
        self.git("commit", "-q", "-m", "ignore build output", cwd=folder)
        return folder

    def built(self, folder: Path) -> bool:
        return (folder / "frontend/build").exists() or (folder / "backend/.venv").exists()

    LATER = 4 * 3600  # seconds after now: every file here is "hours old"

    def run_it(self, *args: str, later: bool = False) -> None:
        import time

        now = time.time() + (self.LATER if later else 0)
        self.assertEqual(self.tidy.main([*args, "--quiet"], now=now), 0)

    def test_a_merged_branchs_worktree_loses_its_build_output_and_keeps_its_files(self):
        done = self.worktree("done", pushed=True, merged=True)
        self.run_it()
        self.assertFalse(self.built(done))
        self.assertTrue((done / "a.txt").is_file())

    def test_with_worktrees_a_merged_clean_one_is_removed(self):
        done = self.worktree("done", pushed=True, merged=True)
        self.run_it("--worktrees")
        self.assertFalse(done.exists())

    def test_uncommitted_work_is_never_removed_only_the_build_output(self):
        done = self.worktree("done", pushed=True, merged=True)
        (done / "notes.txt").write_text("not committed")
        self.run_it("--worktrees")
        self.assertEqual((done / "notes.txt").read_text(), "not committed")
        self.assertFalse(self.built(done))

    def test_a_helpers_worktree_never_pushed_under_its_name_keeps_everything_while_fresh(self):
        helper = self.worktree("worktree-agent-1", pushed=False)
        self.run_it("--worktrees")
        self.assertTrue(self.built(helper))

    def test_once_quiet_for_hours_it_loses_its_build_output_but_is_never_removed(self):
        helper = self.worktree("worktree-agent-1", pushed=False)
        self.run_it("--worktrees", later=True)
        self.assertFalse(self.built(helper))
        self.assertTrue((helper / "a.txt").is_file())

    def test_a_worktree_with_a_process_in_it_is_left_alone_however_quiet(self):
        helper = self.worktree("worktree-agent-1", pushed=False)
        running = subprocess.Popen(["sleep", "30"], cwd=helper / "frontend")
        try:
            self.run_it("--worktrees", later=True)
            self.assertTrue(self.built(helper))
        finally:
            running.kill()
            running.wait()

    def test_a_long_run_that_only_writes_build_output_does_not_count_as_source_changing(self):
        helper = self.worktree("worktree-agent-1", pushed=False)
        self.assertLess(self.tidy.last_change(helper), __import__("time").time() + 1)
        import os

        future = __import__("time").time() + 10 * 3600
        os.utime(helper / "frontend/build/web/big.bin", (future, future))
        self.run_it(later=True)  # the build file is "new", the source is hours old
        self.assertFalse(self.built(helper))

    def test_a_branch_still_on_the_remote_keeps_its_worktree(self):
        busy = self.worktree("busy", pushed=True)
        self.run_it("--worktrees", later=True)
        self.assertTrue(busy.exists())

    def test_a_dry_run_removes_nothing(self):
        done = self.worktree("done", pushed=True, merged=True)
        self.run_it("--worktrees", "--dry-run", later=True)
        self.assertTrue(self.built(done))

    def test_the_checkout_it_runs_from_is_never_touched(self):
        (self.root / "frontend/build").mkdir(parents=True)
        (self.root / "frontend/build/big.bin").write_bytes(b"x" * 4096)
        self.run_it("--worktrees", later=True)
        self.assertTrue((self.root / "frontend/build/big.bin").is_file())


if __name__ == "__main__":
    unittest.main()
