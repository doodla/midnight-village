"""tool/comment_rows.py: the no-comments fan-out's answers are checked by code, not trusted.

A row whose quotes are not at its line is dropped and its file sorted again; a comment
the change added that no row judged is missing; a deletion of a line that is always kept
becomes a keep; generated files are never sorted; --apply deletes only whole-line comments.
Each case runs in a throwaway repository with a base commit and a change on top.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import contextlib
import importlib.util
import io
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]

BASE = "def score(votes):\n    return len(votes)\n"
HEAD = (
    "# Guard file: the score is the vote count\n"
    "# ── Scoring ──\n"
    "def score(votes):\n"
    '    """Why: a tie counts every vote, the owner asked for it."""\n'
    "    # count the votes\n"
    "    return len(votes)  # noqa: PLR2004 the count is the rule\n"
)


def load():
    spec = importlib.util.spec_from_file_location(
        "comment_rows", REPO / "tool" / "comment_rows.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def row(line, comment, code, verdict, end=None):
    found = {"file": "game.py", "line": line, "comment": comment, "code": code}
    found.update(verdict=verdict, why="test")
    if end:
        found["end"] = end
    return found


class Answers(unittest.TestCase):
    def setUp(self):
        self.tool = load()
        self.dir = tempfile.TemporaryDirectory()
        root = Path(self.dir.name)
        self.git = lambda *a: subprocess.run(
            ["git", "-C", str(root), *a], capture_output=True, text=True, check=True
        ).stdout.strip()
        self.git("init", "-q")
        self.git("config", "user.email", "t@example.com")
        self.git("config", "user.name", "t")
        (root / "game.py").write_text(BASE)
        self.git("add", ".")
        self.git("commit", "-qm", "base")
        self.base = self.git("rev-parse", "HEAD")
        (root / "game.py").write_text(HEAD)
        (root / "parts.g.dart").write_text("// GENERATED CODE\n// a part\n")
        self.git("add", ".")
        self.git("commit", "-qm", "change")
        self.span = f"{self.base}..{self.git('rev-parse', 'HEAD')}"
        self.tool.ROOT = root
        self.root = root

    def tearDown(self):
        self.dir.cleanup()

    def run_tool(self, *argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = self.tool.main(list(argv))
        return code, out.getvalue()

    def answer(self, rows):
        path = self.root / "answer.txt"
        path.write_text("Sorted:\n" + "\n".join(json.dumps(r) for r in rows) + "\n")
        return str(path)

    def every_comment(self):
        return [
            row(1, "# Guard file", "def score(votes):", "delete"),
            row(2, "# ── Scoring ──", "def score(votes):", "delete"),
            row(4, '"""Why: a tie', "return len(votes)", "keep"),
            row(5, "# count the votes", "return len(votes)", "delete"),
            row(6, "# noqa", "return len(votes)", "delete"),
        ]

    def test_the_files_to_sort_are_the_added_comments_and_never_generated_ones(self):
        code, out = self.run_tool("--files", "--range", self.span)
        self.assertEqual(code, 0)
        self.assertEqual(out.strip(), "game.py  comments added at lines 1, 2, 4, 5, 6")

    def test_a_row_quoting_a_comment_not_on_its_line_is_dropped_and_sorted_again(self):
        rows = self.every_comment()
        rows[3] = row(4, "# count the votes", "return len(votes)", "delete")
        code, out = self.run_tool("--range", self.span, self.answer(rows))
        self.assertEqual(code, 1)
        self.assertIn(
            "dropped: game.py: line 4: the comment it quotes is not on that line", out
        )
        self.assertIn("Sort again (one answer each): game.py", out)

    def test_a_row_quoting_code_that_is_not_near_is_dropped(self):
        rows = self.every_comment()
        rows[1] = row(2, "# ── Scoring ──", "return everything()", "delete")
        code, out = self.run_tool("--range", self.span, self.answer(rows))
        self.assertEqual(code, 1)
        self.assertIn("the code it quotes is not near the comment", out)

    def test_code_below_a_banner_and_the_doc_comment_after_it_is_near(self):
        doc = [f"/// line {n} of the doc" for n in range(7)]
        text = ["// -----", "// The beat", "// -----", "", *doc, "int every = 2;"]
        (self.root / "beat.dart").write_text("\n".join(text) + "\n")
        rows = self.every_comment()
        found = {"file": "beat.dart", "line": 1, "end": 3, "comment": "// -----"}
        found.update(code="int every = 2;", verdict="delete", why="banner")
        docs = {"file": "beat.dart", "line": 5, "end": 11, "comment": "/// line 0"}
        docs.update(code="int every = 2;", verdict="keep", why="why")
        code, out = self.run_tool(
            "--base", self.base, self.answer(rows + [found, docs])
        )
        self.assertEqual(code, 0, out)
        self.assertIn("delete 3, keep 3, review 1", out)

    def test_a_comment_no_row_judged_is_missing(self):
        code, out = self.run_tool(
            "--range", self.span, self.answer(self.every_comment()[:4])
        )
        self.assertEqual(code, 1)
        self.assertIn("missing: game.py:6: no row judged this comment", out)

    def test_deleting_a_guard_marker_is_a_keep_and_a_suppression_a_review(self):
        code, out = self.run_tool(
            "--range", self.span, self.answer(self.every_comment())
        )
        self.assertEqual(code, 0, out)
        self.assertIn("delete 2, keep 2, review 1 (rows 5)", out)
        self.assertIn("game.py:1: delete -> keep: a Guard file marker", out)
        self.assertIn("game.py:6: delete -> review: a lint suppression", out)

    def test_apply_deletes_only_whole_line_comments_in_the_working_tree(self):
        rows = self.every_comment()
        rows[2] = row(4, '"""Why: a tie', "return len(votes)", "delete")
        code, out = self.run_tool("--base", self.base, "--apply", self.answer(rows))
        self.assertEqual(code, 0, out)
        self.assertIn("Deleted 2; delete by hand: ['game.py:4']", out)
        self.assertEqual(
            (self.root / "game.py").read_text().splitlines(),
            [HEAD.splitlines()[0], *HEAD.splitlines()[2:4], HEAD.splitlines()[5]],
        )


if __name__ == "__main__":
    unittest.main()
