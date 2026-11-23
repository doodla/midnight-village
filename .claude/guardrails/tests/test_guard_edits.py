# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""A pull request that edits a guard test says so (tool/guard_edits.py).

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SCRIPT = REPO / "tool" / "guard_edits.py"
GUARD = "// Guard file: a change here needs its line in the pull request.\nconst floor = 14;\n"


def load(root: Path):
    spec = importlib.util.spec_from_file_location("guard_edits", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.ROOT = root
    return module


class GuardEdits(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.email", "t@t")
        self.git("config", "user.name", "t")
        self.put("test/type_guard_test.dart", GUARD)
        self.put("test/plain_test.dart", "const x = 1;\n")
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "main")
        self.git("checkout", "-q", "-b", "change")
        self.check = load(self.root)
        self.addCleanup(os.environ.pop, "PR_BODY", None)

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args: str) -> None:
        subprocess.run(["git", "-C", str(self.root), *args], check=True, capture_output=True)

    def put(self, name: str, text: str) -> None:
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def run_check(self, body: str | None) -> int:
        if body is None:
            os.environ.pop("PR_BODY", None)
        else:
            os.environ["PR_BODY"] = body
        return self.check.main(["--base", "main"])

    def test_a_change_that_leaves_guards_alone_needs_nothing(self):
        self.put("test/plain_test.dart", "const x = 2;\n")
        self.assertEqual(self.run_check(""), 0)

    def test_an_edited_guard_fails_until_the_description_says_why(self):
        self.put("test/type_guard_test.dart", GUARD.replace("14", "12"))
        self.assertEqual(self.run_check("Small fix."), 1)
        self.assertEqual(self.run_check("Guards changed\n- type_guard_test.dart: ok"), 1)
        self.assertEqual(
            self.run_check(
                "## Guards changed\n- `type_guard_test.dart`: the clock gets its own role; other text keeps the floor\n"
            ),
            0,
        )

    def test_each_edited_guard_needs_its_own_line(self):
        self.put("test/other_guard_test.dart", GUARD)
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "a second guard")
        self.git("branch", "-f", "main")
        self.put("test/type_guard_test.dart", GUARD.replace("14", "12"))
        self.put("test/other_guard_test.dart", GUARD.replace("14", "10"))
        body = "- type_guard_test.dart: the clock gets its own role this time\n"
        self.assertEqual(self.run_check(body), 1)
        body += "- other_guard_test.dart: the same change, for the same reason\n"
        self.assertEqual(self.run_check(body), 0)

    def test_taking_the_guard_line_off_a_file_is_an_edit_of_a_guard(self):
        self.put("test/type_guard_test.dart", "const floor = 14;\n")
        self.assertEqual(self.run_check(""), 1)

    def test_a_new_guard_joins_without_a_line(self):
        self.put("test/new_guard_test.dart", GUARD)
        self.assertEqual(self.run_check(""), 0)

    def test_off_github_it_reminds_and_passes(self):
        self.put("test/type_guard_test.dart", GUARD.replace("14", "12"))
        self.assertEqual(self.run_check(None), 0)

    def test_this_repo_has_guards_and_the_check_runs_on_it(self):
        real = load(REPO)
        marked = [
            p
            for p in (REPO / "frontend" / "test").rglob("*_test.dart")
            if real.is_guard(p.read_text())
        ]
        self.assertGreater(len(marked), 5)


if __name__ == "__main__":
    unittest.main()
