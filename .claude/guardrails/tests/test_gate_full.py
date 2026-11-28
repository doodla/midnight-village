"""What `just gate-full` says it runs is what it runs, and one recipe name means one thing.

- Every required GitHub check (read from the workflows and the ruleset by
  tool/github_checks.py) is either run by gate-full's full steps or named in
  GATE_FULL_SKIPS, and every name there is a real check: the docs never have to
  say which checks gate-full leaves out, the gate prints it.
- A recipe of backend/ or frontend/ that also exists at the root is only the root's
  way to run it: `just check` or `just test` never means something else in a folder.
- A name a folder had on main never falls back to the root's recipe of that name: it stays
  as a stub in the folder's `renamed` group (the rename table), which fails saying the new name.
- A part of the backend suite runs without the coverage floor it can never reach.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
import json
import re
import subprocess
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
GATE = REPO / ".claude/hooks/lib/gate.sh"
# A recipe GitHub runs -> the full steps that run all of it here.
SAME_AS = {
    "test": {"test-backend", "test-guardrails"},
    "test-widgets": {"flutter-test"},
    "flutter-test-golden": {"flutter-test"},
}


def github_checks():
    spec = importlib.util.spec_from_file_location(
        "github_checks", REPO / "tool/github_checks.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def full_recipes() -> set[str]:
    text = GATE.read_text()
    steps = re.findall(r'^\s*\w+:(?:full|\*)\) steps="([^"]+)"', text, re.M)
    return {m for s in steps for m in re.findall(r"just ([\w-]+)", s)}


def skips() -> set[str]:
    return set(
        re.search(r'^GATE_FULL_SKIPS="([^"]*)"', GATE.read_text(), re.M)[1].split("|")
    )


def recipes(justfile: str) -> dict:
    out = subprocess.run(
        ["just", "--justfile", str(REPO / justfile), "--dump", "--dump-format", "json"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    return json.loads(out)["recipes"]


class GateFullIsWhatItSays(unittest.TestCase):
    def test_every_required_check_runs_in_gate_full_or_is_named_as_skipped(self):
        ran, skipped = full_recipes(), skips()
        for check in github_checks().required_checks(REPO):
            if check.name in skipped:
                continue
            for recipe, _ in check.recipes:
                self.assertTrue(
                    recipe in ran or SAME_AS.get(recipe, {None}) <= ran,
                    f"{check.name} runs `just {recipe}`, which gate-full does not:"
                    f" add it to a full step in {GATE.name}, or its check to GATE_FULL_SKIPS",
                )

    def test_every_skip_is_a_real_check(self):
        names = {c.name for c in github_checks().required_checks(REPO)}
        for name in skips():
            self.assertIn(
                name,
                names,
                f"GATE_FULL_SKIPS names '{name}', which is no required check",
            )


def renamed(recipe: dict) -> bool:
    return {"group": "renamed"} in recipe.get("attributes", [])


def fallback_justfiles() -> list[str]:
    """Every tracked folder justfile that falls back to the root's for a name it lacks."""
    listed = subprocess.run(
        ["git", "-C", str(REPO), "ls-files", "*justfile"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.split()
    found = []
    for path in listed:
        if path == "justfile":
            continue
        dump = subprocess.run(
            ["just", "--justfile", str(REPO / path), "--dump", "--dump-format", "json"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        if json.loads(dump)["settings"]["fallback"]:
            found.append(path)
    return found


def recipes_at_base(path: str) -> set[str] | None:
    """The recipe names `path` had on the main this change was built on (None: no base)."""
    spec = importlib.util.spec_from_file_location(
        "root_recipes", REPO / "tool/root_recipes.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    base = module.change_base(REPO)
    if base is None:
        return None
    return module.recipes_at(base, path)


class OneNameOneMeaning(unittest.TestCase):
    def test_a_renamed_name_fails_in_its_old_folder_and_names_the_new_one(self):
        # The rename table is the folder's `renamed` group: no list here beside it.
        seen = 0
        for path in fallback_justfiles():
            folder = str(Path(path).parent)
            mine = recipes(path)
            for old, recipe in mine.items():
                if not renamed(recipe):
                    continue
                seen += 1
                new = re.search(r"renamed: just ([\w-]+)", json.dumps(recipe["body"]))
                self.assertIsNotNone(
                    new, f"{path}: renamed `{old}` does not say its new name"
                )
                self.assertIn(
                    new[1],
                    mine,
                    f"{path}: `{old}` is renamed to `{new[1]}`, which is no recipe there",
                )
                self.assertFalse(
                    renamed(mine[new[1]]),
                    f"{path}: `{old}` is renamed to another old name",
                )
                run = subprocess.run(
                    [
                        "just",
                        "--justfile",
                        str(REPO / path),
                        "--working-directory",
                        str(REPO / folder),
                        old,
                        "x",
                    ],
                    capture_output=True,
                    text=True,
                )
                self.assertNotEqual(
                    run.returncode, 0, f"`cd {folder} && just {old}` passes"
                )
                self.assertEqual(
                    (run.stdout + run.stderr).strip(),
                    f"renamed: just {new[1]}",
                    f"`cd {folder} && just {old}` must say only where it went",
                )
        self.assertGreater(seen, 0, "no folder justfile has a `renamed` group")

    def test_no_name_a_folder_had_falls_back_to_the_roots_recipe(self):
        for path in fallback_justfiles():
            before = recipes_at_base(path)
            if before is None:
                self.skipTest("no main to compare with")
            gone = sorted(before - set(recipes(path)))
            self.assertEqual(
                gone,
                [],
                f"{path} had {gone} on main and no longer has them: with fallback on, the old"
                " name now runs the root's recipe of that name. Keep each as a stub in the"
                " folder's `renamed` group (`renamed: just <new name>`, exit 1).",
            )

    def test_a_folders_recipe_at_the_root_only_runs_that_recipe(self):
        top = recipes("justfile")
        for folder in ("backend", "frontend"):
            for name, recipe in recipes(f"{folder}/justfile").items():
                if (
                    name.startswith("_")
                    or name == "default"
                    or name not in top
                    or renamed(recipe)
                ):
                    continue
                body = json.dumps(top[name]["body"])
                self.assertRegex(
                    body,
                    rf'"{folder}_just"\]\], " {re.escape(name)}[ "]',
                    f"`just {name}` means one thing in {folder}/ and another at the root:"
                    f" rename the {folder} one (`tool/root_recipes.py --fix` adds its root line)",
                )

    def test_part_of_the_backend_suite_runs_without_the_coverage_floor(self):
        dry = subprocess.run(
            [
                "just",
                "--justfile",
                str(REPO / "backend/justfile"),
                "--working-directory",
                str(REPO / "backend"),
                "--dry-run",
                "test-backend",
                "tests/x.py",
            ],
            capture_output=True,
            text=True,
        )
        self.assertIn("--no-cov tests/x.py", dry.stderr + dry.stdout)


if __name__ == "__main__":
    unittest.main()
