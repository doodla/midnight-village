"""Every recipe runs from the repo root, and a root recipe runs from frontend/ and
backend/.

A builder spent calls finding out that `just gen-check` exists only in frontend/,
and "recipe not found" does not say where a recipe lives.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import json
import shutil
import subprocess
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]


def load():
    import importlib.util

    spec = importlib.util.spec_from_file_location("root_recipes", REPO / "tool" / "root_recipes.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def recipes(justfile: Path) -> dict:
    out = subprocess.run(
        ["just", "--justfile", str(justfile), "--dump", "--dump-format", "json"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return {n: r for n, r in json.loads(out)["recipes"].items() if not r["private"]}


@unittest.skipUnless(shutil.which("just"), "just is not installed")
class RecipesEverywhere(unittest.TestCase):
    def test_a_recipe_this_change_adds_must_be_at_the_root(self):
        """Only this change's own: a hole two other merges left between them is
        said by `just check`, and does not fail the next builder."""
        tool = load()
        holes = tool.missing()
        self.assertEqual(
            tool.added_here(holes),
            [],
            "a recipe this change adds runs only from its folder:"
            " run tool/root_recipes.py --fix",
        )

    def test_a_missing_forward_is_written_as_the_others_are(self):
        tool = load()
        line = tool.forward("frontend", "end-link-pictures", {"doc": "the end board's links"})
        self.assertEqual(
            line,
            "\n# (frontend) the end board's links\nend-link-pictures *args:\n"
            "    {{frontend_just}} end-link-pictures {{args}}\n",
        )

    def test_a_recipe_the_folder_already_had_is_not_this_changes(self):
        tool = load()
        tool.change_base = lambda root: "HEAD"
        had = sorted(tool.recipes_at("HEAD", "frontend/justfile"))[0]
        self.assertEqual(tool.added_here({"frontend": {had: {}}, "backend": {}}), [])
        self.assertEqual(
            tool.added_here({"frontend": {"brand-new-recipe": {}}, "backend": {}}),
            ["frontend/brand-new-recipe"],
        )

    def test_a_forward_passes_its_arguments_on(self):
        text = (REPO / "justfile").read_text()
        block = text[text.index("# --- Every recipe from the root ---") :]
        heads = [line for line in block.splitlines() if line and not line.startswith(("#", " "))]
        self.assertTrue(heads)
        for head in heads:
            name = head.split()[0].rstrip(":")
            self.assertIn(f"_just}}}} {name} {{{{args}}}}", block, name)

    def test_the_folders_fall_back_to_the_root(self):
        for folder in ("frontend", "backend"):
            text = (REPO / folder / "justfile").read_text()
            self.assertIn("set fallback := true", text, folder)

    def test_a_root_recipe_is_found_from_inside_a_folder(self):
        for folder in ("frontend", "backend"):
            done = subprocess.run(
                ["just", "--dry-run", "piece-check"],
                cwd=REPO / folder,
                capture_output=True,
                text=True,
            )
            self.assertEqual(done.returncode, 0, done.stderr)
            self.assertIn("tool/piece_check.py", done.stderr + done.stdout)


if __name__ == "__main__":
    unittest.main()
