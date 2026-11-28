"""tool/context_budget.py: what an agent must read is measured and may not grow past
its limit (under it on main: may not pass it; over it on main: may not grow).

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]


def load():
    spec = importlib.util.spec_from_file_location(
        "context_budget", REPO / "tool" / "context_budget.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class TheRule(unittest.TestCase):
    def setUp(self):
        self.tool = load()

    def judge(self, count, was):
        now = {"brief 09": (count, 100, "")}
        before = {} if was is None else {"brief 09": (was, 100, "")}
        return self.tool.judge(now, before)

    def test_under_the_limit_passes_whatever_main_had(self):
        self.assertEqual(self.judge(100, None), [])
        self.assertEqual(self.judge(90, 300), [])

    def test_passing_the_limit_fails(self):
        (problem,) = self.judge(101, 100)
        self.assertIn("past its limit of 100", problem)
        (new,) = self.judge(101, None)
        self.assertIn("past its limit", new)

    def test_over_on_main_may_stay_or_shrink_but_not_grow(self):
        self.assertEqual(self.judge(300, 300), [])
        self.assertEqual(self.judge(250, 300), [])
        (problem,) = self.judge(301, 300)
        self.assertIn("already over its limit", problem)


class WhatCountsAsToRead(unittest.TestCase):
    def setUp(self):
        self.tool = load()

    def test_a_sentence_wrapped_over_lines_that_says_read_brings_its_paths(self):
        text = (
            "Before you start, read `CLAUDE.md` and the README of the part you\n"
            "change (`tool/brief.py`, `docs/README.md`). Game rules: `docs/specs/index.md`.\n"
        )
        found = self.tool.named_reads("x.md", text)
        self.assertIn("CLAUDE.md", found)
        self.assertIn("docs/README.md", found)
        self.assertNotIn("docs/specs/index.md", found)  # a pointer, not "read"
        self.assertIn(
            "tool/brief.py", found
        )  # any tracked text file it says to read counts

    def test_a_list_item_ends_a_sentence(self):
        found = self.tool.sentences("- read this\n- `docs/README.md` here\n")
        self.assertEqual(found, ["- read this", "- `docs/README.md` here"])

    def test_a_section_runs_to_the_next_heading_of_its_rank(self):
        text = "# A\n## B\nb\n### C\nc\n## D\nd\n"
        self.assertEqual(self.tool.section_at(text, 2), "## B\nb\n### C\nc")

    def in_a_repo(self, files: dict[str, bytes], ignored: str = ""):
        """A throwaway git repository holding `files` (staged), read through DOCS."""
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        root = Path(scratch.name)
        subprocess.run(["git", "init", "-q", str(root)], check=True)
        (root / ".gitignore").write_text(ignored)
        for name, data in files.items():
            (root / name).parent.mkdir(parents=True, exist_ok=True)
            (root / name).write_bytes(data)
        subprocess.run(["git", "-C", str(root), "add", "-A"], check=True)
        docs = self.tool.DOCS
        was = (docs.root, docs.ref, docs._listing)
        docs.root, docs.ref, docs._listing = root, None, None
        self.addCleanup(lambda: setattr(docs, "root", was[0]) or docs.use(was[1]))

    def test_a_text_file_told_to_be_read_whole_counts_like_markdown(self):
        rules = ("Never do the wrong thing. " * 1800).encode()  # about 11.5k tokens
        self.in_a_repo({"backend/RULES.txt": rules, "backend/RULES.md": rules})
        for name in ("backend/RULES.txt", "backend/RULES.md"):
            text = f"- Fix the cause; read `{name}` whole.\n"
            problems: list[str] = []
            self.assertEqual(self.tool.named_reads("CLAUDE.md", text, problems), [name])
            self.assertEqual(problems, [])
            self.assertGreater(self.tool.tokens(self.tool.DOCS.text(name)), 11_000)

    def test_a_named_read_that_is_not_text_or_not_tracked_fails(self):
        self.in_a_repo(
            {"art.png": b"\x89PNG\0\0binary", "build/out.md": b"x"}, ignored="build/\n"
        )
        problems: list[str] = []
        text = "Read `art.png` and `build/out.md` first.\n"
        self.assertEqual(self.tool.named_reads("CLAUDE.md", text, problems), [])
        self.assertEqual(len(problems), 2)
        self.assertIn("`art.png`, which is not text", problems[0] + problems[1])
        self.assertIn("`build/out.md`, which is not tracked", problems[0] + problems[1])

    def test_the_real_tree_is_measured_for_every_role(self):
        found = self.tool.measure()
        for role in self.tool.ROLES:
            self.assertTrue(any(k.startswith(role + ",") for k in found), role)
        self.assertIn("the instruction surface", found)


if __name__ == "__main__":
    unittest.main()
