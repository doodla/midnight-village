"""What `just gate-full` says it runs is what it runs, and one recipe name means one thing.

- Every required GitHub check (read from the workflows and the ruleset by
  tool/github_checks.py) is either run by gate-full's full steps or named in
  GATE_FULL_SKIPS, and every name there is a real check: the docs never have to
  say which checks gate-full leaves out, the gate prints it.
- A recipe of backend/ or frontend/ that also exists at the root is only the root's
  way to run it: `just check` or `just test` never means something else in a folder.
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


class OneNameOneMeaning(unittest.TestCase):
    def test_a_folders_recipe_at_the_root_only_runs_that_recipe(self):
        top = recipes("justfile")
        for folder in ("backend", "frontend"):
            for name in recipes(f"{folder}/justfile"):
                if name.startswith("_") or name == "default" or name not in top:
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
