"""tool/check_instruction_links.py: a path is read where the document says, a section
named after a path is one of its headings, and every instruction file is read.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]


def load():
    spec = importlib.util.spec_from_file_location(
        "links", REPO / "tool/check_instruction_links.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class WhereTheDocumentSays(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tool = load()
        cls.tree = cls.tool.Tree(False)

    def ok(self, token, here):
        return self.tool.resolve(token, here, self.tree)

    def test_a_path_from_the_root_or_the_documents_folder_resolves(self):
        self.assertTrue(self.ok("frontend/docs/app-rules.md", "frontend"))
        self.assertTrue(self.ok("./docs/app-rules.md", "frontend"))
        self.assertTrue(self.ok("../tool/brief.py", "backend"))
        # a path with a folder in it is read from the root, where an agent works
        self.assertFalse(self.ok("docs/app-rules.md", "frontend"))

    def test_a_path_from_some_other_folder_does_not_and_the_fix_is_offered(self):
        self.assertFalse(self.ok("docs/app-rules.md", "docs/dev"))
        self.assertEqual(
            self.tool.suggestion("lib/design_system/README.md", "docs", self.tree),
            "frontend/lib/design_system/README.md",
        )

    def test_a_bare_name_is_in_the_documents_folder_or_names_one_file(self):
        self.assertTrue(self.ok("brief.py", "tool"))
        self.assertTrue(self.ok("context_budget.py", "docs"))  # one file of that name
        self.assertFalse(self.ok("no_such_file_anywhere.py", "docs"))

    def test_an_ignored_folder_counts(self):
        self.assertTrue(self.ok("frontend/build/", "docs"))

    def test_a_section_named_after_a_path_must_be_one_of_its_headings(self):
        with tempfile.TemporaryDirectory() as tmp:
            doc = Path(tmp) / "x.md"
            doc.write_text(
                'See `backend/CLAUDE.md`, "Rules that have bitten".\n'
                'See `backend/CLAUDE.md`, "Rules that never were".\n'
            )
            bad = self.tool.check([str(doc)], self.tree, set(), fix=False)
        self.assertEqual(len(bad), 1, bad)
        self.assertIn('no section "Rules that never were"', bad[0])

    def test_a_bare_path_in_prose_is_checked_when_it_starts_at_a_top_folder(self):
        line = (
            "See docs/dev/gone-a.md, and docs/dev/status.md; origin/main, a/b, "
            "frontend/lib/.../debug/ and `docs/dev/gone-b.md` [x](docs/dev/gone-c.md) are not bare."
        )
        self.assertEqual(
            self.tool.bare_paths(line, self.tree),
            ["docs/dev/gone-a.md", "docs/dev/status.md"],
        )
        with tempfile.TemporaryDirectory() as tmp:
            doc = Path(tmp) / "x.md"
            doc.write_text("See docs/dev/gone-a.md for it, and docs/dev/status.md.\n")
            bad = self.tool.check([str(doc)], self.tree, set(), fix=False)
        self.assertEqual(len(bad), 1, bad)
        self.assertIn("path `docs/dev/gone-a.md` does not exist", bad[0])

    def test_every_instruction_file_is_read_and_the_skills_are_not(self):
        files = self.tool.instruction_files(self.tree)
        for must in (
            "docs/specs/onuw/index.md",
            "docs/design/feel.md",
            "frontend/dart_test.yaml",
        ):
            self.assertIn(must, files)
        self.assertFalse([f for f in files if f.startswith(".claude/skills/")])


if __name__ == "__main__":
    unittest.main()
