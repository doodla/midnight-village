"""A change is compared with the main it was built on, not with main as it is now
(tool/change_base.py). Main moving under a running check must not be blamed on the
change being checked.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
GUARD = "// Guard file: a change here needs its line in the pull request.\nconst floor = 14;\n"


def load(name: str, root: Path):
    spec = importlib.util.spec_from_file_location(name, REPO / "tool" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.ROOT = root
    return module


class ChangeBase(unittest.TestCase):
    """A remote with main, a clone on a branch, and main moving on afterwards."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        top = Path(self.tmp.name)
        self.remote, self.root = top / "remote", top / "work"
        self.remote.mkdir()
        self.git(self.remote, "init", "-q", "-b", "main")
        self.put(self.remote, "test/a_guard_test.dart", GUARD)
        self.put(self.remote, "test/other_guard_test.dart", GUARD)
        self.commit(self.remote, "main")
        self.git(top, "clone", "-q", str(self.remote), str(self.root))
        self.git(self.root, "checkout", "-q", "-b", "change")
        self.put(self.root, "lib/new.dart", "const x = 1;\n")
        self.commit(self.root, "the change")
        self.built_on = self.rev(self.root, "origin/main")
        # someone else's pull request merges: it edits a guard
        self.put(self.remote, "test/other_guard_test.dart", GUARD + "const more = 1;\n")
        self.commit(self.remote, "another change")
        self.git(self.root, "fetch", "-q", "origin")
        for name in ("GITHUB_EVENT_NAME", "PR_BODY"):
            self.addCleanup(os.environ.pop, name, None)
            os.environ.pop(name, None)

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, where: Path, *args: str) -> str:
        return subprocess.run(
            ["git", "-C", str(where), "-c", "user.email=t@t", "-c", "user.name=t", *args],
            check=True, capture_output=True, text=True,
        ).stdout

    def put(self, where: Path, name: str, text: str) -> None:
        path = where / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def commit(self, where: Path, message: str) -> None:
        self.git(where, "add", "-A")
        self.git(where, "commit", "-q", "-m", message)

    def rev(self, where: Path, ref: str) -> str:
        return self.git(where, "rev-parse", ref).strip()

    def test_a_branch_behind_main_is_compared_with_where_it_left(self):
        base = load("change_base", self.root).change_base(self.root)
        self.assertEqual(base, self.built_on)
        self.assertNotEqual(base, self.rev(self.root, "origin/main"))

    def test_a_guard_edited_on_main_meanwhile_is_not_this_changes_edit(self):
        os.environ["PR_BODY"] = "nothing about guards"
        self.assertEqual(load("guard_edits", self.root).main([]), 0)

    def test_on_a_pull_request_it_is_the_merge_commits_first_parent(self):
        """GitHub's checkout: a shallow merge of the branch into the main of that
        moment; main has moved again by the time the check fetches it."""
        merged_into = self.rev(self.root, "origin/main")
        self.git(self.root, "checkout", "-q", "--detach", "origin/main")
        self.git(self.root, "merge", "-q", "--no-ff", "-m", "merge", "change")
        merge = self.rev(self.root, "HEAD")
        self.git(self.root, "push", "-q", "origin", f"{merge}:refs/heads/pull-merge")
        self.put(self.remote, "test/a_guard_test.dart", GUARD + "const later = 2;\n")
        self.git(self.remote, "checkout", "-q", "main")
        self.commit(self.remote, "main moves while the check runs")
        shallow = Path(self.tmp.name) / "shallow"
        self.git(Path(self.tmp.name), "clone", "-q", "--depth=1", "--branch", "pull-merge",
                 self.remote.as_uri(), str(shallow))
        os.environ["GITHUB_EVENT_NAME"] = "pull_request"
        self.assertEqual(load("change_base", shallow).change_base(shallow), merged_into)
        os.environ["PR_BODY"] = "nothing about guards"
        self.assertEqual(load("guard_edits", shallow).main([]), 0)

    def test_the_changes_own_guard_edit_still_needs_its_line(self):
        self.put(self.root, "test/a_guard_test.dart", GUARD.replace("14", "12"))
        self.commit(self.root, "loosen")
        os.environ["PR_BODY"] = "nothing about guards"
        self.assertEqual(load("guard_edits", self.root).main([]), 1)
        os.environ["PR_BODY"] = "Guards changed\n- a_guard_test.dart: the clock needs a smaller floor\n"
        self.assertEqual(load("guard_edits", self.root).main([]), 0)

    def test_no_main_anywhere_is_nothing_to_compare_with(self):
        self.assertIsNone(load("change_base", self.root).change_base(self.root, "nowhere/main"))


if __name__ == "__main__":
    unittest.main()
