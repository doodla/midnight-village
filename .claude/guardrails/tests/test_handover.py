"""`just handover` (tool/handover.py): what it refuses, and what its file says.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import contextlib
import importlib.util
import io
import os
import subprocess
import tempfile
import unittest
import unittest.mock
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]


def load(root: Path):
    spec = importlib.util.spec_from_file_location(
        "handover", REPO / "tool" / "handover.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.ROOT = root
    return module


class Refusals(unittest.TestCase):
    """A remote with main, and a clone on the piece's branch."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        top = Path(self.tmp.name)
        self.remote, self.root = top / "remote.git", top / "work"
        seed = top / "seed"
        seed.mkdir()
        self.git(seed, "init", "-q", "-b", "main")
        (seed / "a.txt").write_text("one\ntwo\nthree\n")
        self.commit(seed, "main")
        self.git(top, "clone", "-q", "--bare", str(seed), str(self.remote))
        self.git(top, "clone", "-q", str(self.remote), str(self.root))
        self.git(self.root, "checkout", "-q", "-b", "piece")
        (self.root / "b.txt").write_text("the piece\n")
        self.commit(self.root, "the piece")
        self.tool = load(self.root)

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, where: Path, *args: str) -> str:
        return subprocess.run(
            [
                "git",
                "-C",
                str(where),
                "-c",
                "user.email=t@t",
                "-c",
                "user.name=t",
                *args,
            ],
            check=True,
            capture_output=True,
            text=True,
        ).stdout

    def commit(self, where: Path, message: str) -> None:
        self.git(where, "add", "-A")
        self.git(where, "commit", "-q", "-m", message)

    def push(self) -> None:
        self.git(self.root, "push", "-q", "-u", "origin", "piece")

    def test_committed_pushed_and_mergeable_is_ready(self):
        self.push()
        self.assertEqual(self.tool.not_ready(), [])

    def test_uncommitted_work_is_refused_and_named(self):
        self.push()
        (self.root / "left.txt").write_text("forgotten\n")
        problems = self.tool.not_ready()
        self.assertEqual(len(problems), 1)
        self.assertIn("left.txt", problems[0])
        self.assertIn("git add -A && git commit", problems[0])

    def test_a_branch_that_is_not_pushed_is_refused_with_the_command(self):
        problems = self.tool.not_ready()
        self.assertEqual(len(problems), 1)
        self.assertIn("git push -u origin piece", problems[0])

    def test_a_commit_made_after_the_push_is_refused(self):
        self.push()
        (self.root / "b.txt").write_text("the piece, fixed\n")
        self.commit(self.root, "a fixing pass")
        problems = self.tool.not_ready()
        self.assertEqual(len(problems), 1)
        self.assertIn("another commit", problems[0])

    def test_a_conflict_with_main_is_refused_and_names_the_file(self):
        (self.root / "a.txt").write_text("one\nTWO, the piece's\nthree\n")
        self.commit(self.root, "the piece edits a line")
        self.push()
        other = Path(self.tmp.name) / "other"
        self.git(Path(self.tmp.name), "clone", "-q", str(self.remote), str(other))
        (other / "a.txt").write_text("one\ntwo, as main now has it\nthree\n")
        self.commit(other, "main moves")
        self.git(other, "push", "-q", "origin", "main")
        problems = self.tool.not_ready()
        self.assertEqual(len(problems), 1)
        self.assertIn("a.txt", problems[0])
        self.assertIn("git merge origin/main", problems[0])

    def test_main_moving_without_a_conflict_is_not_a_refusal(self):
        self.push()
        other = Path(self.tmp.name) / "other"
        self.git(Path(self.tmp.name), "clone", "-q", str(self.remote), str(other))
        (other / "c.txt").write_text("elsewhere\n")
        self.commit(other, "main moves elsewhere")
        self.git(other, "push", "-q", "origin", "main")
        self.assertEqual(self.tool.not_ready(), [])

    def test_main_itself_is_not_a_piece(self):
        self.git(self.root, "checkout", "-q", "main")
        problems = self.tool.not_ready()
        self.assertIn("git switch -c", problems[0])

    def test_nothing_runs_when_it_refuses(self):
        said = io.StringIO()
        with contextlib.redirect_stderr(said):
            code = self.tool.main([str(Path(self.tmp.name) / "handover.md")])
        self.assertEqual(code, 1)
        self.assertIn("Nothing was run", said.getvalue())
        self.assertFalse((Path(self.tmp.name) / "handover.md").exists())


class TheFile(unittest.TestCase):
    """The hand-over file has one shape, and never says ready when it is not."""

    def write(self, results, shots, found=None, states=("09-vote",)):
        tool = load(REPO)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "out" / "handover.md"
            ready = tool.write(
                path,
                "piece",
                "a" * 40,
                2,
                ["frontend/lib/x.dart"],
                results,
                shots,
                list(states),
                "",
                found
                or {
                    "guards": [],
                    "words": [],
                    "specs": [],
                    "screen_code": [],
                    "owner_feedback": False,
                },
            )
            return ready, path.read_text()

    PASSED = {"ok": True, "seconds": 12, "what": "analyze", "again": True}
    FAILED = {
        "ok": False,
        "seconds": 40,
        "what": "the end-to-end harness",
        "again": True,
    }
    DRAWN = {
        "changed": ["09-vote"],
        "new": [],
        "missing": [],
        "sheets": ["/x/sheet-1.png"],
    }

    def test_every_section_is_there_in_order(self):
        ready, text = self.write([self.PASSED], self.DRAWN)
        self.assertTrue(ready)
        heads = [line for line in text.splitlines() if line.startswith("#")]
        self.assertEqual(
            [h.split(",")[0].split(" (")[0] for h in heads],
            [
                "# Hand-over: piece at aaaaaaaaa",
                "## Ready",
                "## Checks",
                "## Screens",
                "## For the pull request",
                "## Words",
                "## Spec and the owner's feedback",
                "## Changed files",
            ],
        )
        self.assertIn("**READY**", text)
        # the pictures come before anything else a reader could stop at
        self.assertLess(text.index("/x/sheet-1.png"), text.index("## Ready"))

    def test_a_failed_check_is_not_ready_and_is_named(self):
        ready, text = self.write([self.PASSED, self.FAILED], self.DRAWN)
        self.assertFalse(ready)
        self.assertIn("**NOT READY**", text)
        self.assertIn("| **FAILED** | 40 s | the end-to-end harness |", text)
        self.assertNotIn("unknown", text.lower())

    def test_a_state_that_could_not_be_drawn_is_not_ready(self):
        shots = {"changed": [], "new": [], "missing": ["09-vote"], "sheets": []}
        ready, text = self.write([self.PASSED], shots)
        self.assertFalse(ready)
        self.assertIn("FAILED to draw", text)

    def test_a_check_kept_from_an_earlier_run_says_so(self):
        kept = {**self.PASSED, "again": False}
        _, text = self.write([kept], self.DRAWN)
        self.assertIn("passed earlier on this same commit", text)

    def test_guards_words_and_a_missing_spec_are_spelled_out(self):
        found = {
            "guards": ["frontend/test/x/type_guard_test.dart"],
            "words": [("VoteCopy.lock", "Lock", "Lock my vote")],
            "specs": [],
            "screen_code": ["frontend/lib/features/game/vote.dart"],
            "owner_feedback": False,
        }
        _, text = self.write([self.PASSED], self.DRAWN, found)
        self.assertIn("- type_guard_test.dart: <why, in a sentence>", text)
        self.assertIn("| `VoteCopy.lock` | Lock | Lock my vote |", text)
        self.assertIn("**No spec file changed**", text)
        self.assertIn("owner-feedback.md` was not changed", text)


class OnlyOnThisCommit(unittest.TestCase):
    def setUp(self):
        # The steps here run at once, not in the machine's heavy queue: a speed verdict
        # holding every slot (or three suites) made these tests wait for it.
        patch = unittest.mock.patch.dict(os.environ, {"HEAVY_SLOT": "1"})
        patch.start()
        self.addCleanup(patch.stop)

    def test_a_run_killed_part_way_keeps_what_it_finished(self):
        """The first check is recorded the moment it ends, before the second
        starts: a kill during the second loses only the second."""
        import sys

        tool, piece = load(REPO), load(REPO).tool("piece_check")
        with tempfile.TemporaryDirectory() as tmp:
            kept = Path(tmp) / "checks.json"
            seen = Path(tmp) / "seen"
            first = ("first", ".", [sys.executable, "-c", "pass"])
            # the second step reads what is on disk while it runs
            second = (
                "second",
                ".",
                [
                    sys.executable,
                    "-c",
                    f"import shutil; shutil.copy({str(kept)!r}, {str(seen)!r})",
                ],
            )
            with contextlib.redirect_stdout(io.StringIO()):
                tool.run_checks([first, second], "a" * 40, piece, kept)
            self.assertIn(" ".join(first[2]), seen.read_text())

    def test_pictures_drawn_on_this_commit_are_not_drawn_again(self):
        pictures = load(REPO).tool("handover_pictures")
        drawn = []
        pictures.draw = (
            lambda checkout, states, w, h, out, what: drawn.append(what) or True
        )
        pictures.base_checkout = lambda base: Path("/nowhere")
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            real_run = pictures.subprocess.run
            pictures.subprocess.run = lambda *a, **k: type(
                "Done",
                (),
                {
                    "returncode": 0,
                    "stdout": '{"changed": [], "new": [], "missing": [], "sheets": []}',
                    "stderr": "",
                },
            )()
            try:
                for size in pictures.SIZES:
                    (out / "run-aaaaaaaaaaaa" / f"{size[0]}x{size[1]}").mkdir(
                        parents=True
                    )
                with contextlib.redirect_stdout(io.StringIO()):
                    pictures.pictures(["09-vote"], "base", out, "a" * 40)
                    first = len(drawn)
                    pictures.pictures(["09-vote"], "base", out, "a" * 40)
                    self.assertEqual(first, 4)
                    self.assertEqual(len(drawn), 4, "the second run drew nothing again")
                    # another commit, or other states, is drawn afresh
                    pictures.pictures(["09-vote", "08-talk"], "base", out, "a" * 40)
                    self.assertEqual(len(drawn), 8)
            finally:
                pictures.subprocess.run = real_run

    def test_a_step_that_passed_on_this_commit_is_not_run_again(self):
        import sys

        tool, piece = load(REPO), load(REPO).tool("piece_check")
        with tempfile.TemporaryDirectory() as tmp:
            kept = Path(tmp) / "checks.json"
            marker = Path(tmp) / "ran"
            step = (
                "a step",
                ".",
                [sys.executable, "-c", f"open({str(marker)!r}, 'a').write('x')"],
            )
            with contextlib.redirect_stdout(io.StringIO()):
                first = tool.run_checks([step], "a" * 40, piece, kept)
                second = tool.run_checks([step], "a" * 40, piece, kept)
            self.assertTrue(first[0]["again"] and first[0]["ok"])
            self.assertFalse(second[0]["again"])
            self.assertEqual(marker.read_text(), "x")

    def test_a_step_that_failed_is_run_again(self):
        import sys

        tool, piece = load(REPO), load(REPO).tool("piece_check")
        with tempfile.TemporaryDirectory() as tmp:
            kept = Path(tmp) / "checks.json"
            step = ("a step", ".", [sys.executable, "-c", "raise SystemExit(1)"])
            with contextlib.redirect_stdout(io.StringIO()):
                tool.run_checks([step], "a" * 40, piece, kept)
                again = tool.run_checks([step], "a" * 40, piece, kept)
            self.assertTrue(again[0]["again"])
            self.assertFalse(again[0]["ok"])


if __name__ == "__main__":
    unittest.main()
