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
    def test_every_folder_recipe_is_at_the_root_under_the_same_name(self):
        root = recipes(REPO / "justfile")
        for folder in ("frontend", "backend"):
            missing = sorted(set(recipes(REPO / folder / "justfile")) - set(root) - {"default"})
            self.assertEqual(
                missing,
                [],
                f"{folder}/justfile has recipes the root justfile lacks: add to the root's"
                f' "Every recipe from the root" block:  <name> *args:  {{{{{folder}_just}}}} <name> {{{{args}}}}',
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
