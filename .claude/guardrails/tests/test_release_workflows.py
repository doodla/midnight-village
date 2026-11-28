# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""The release's own rules, beside the merge wall's (test_workflows.py):

- the rulesets on the live branches (docs/dev/rulesets/): the rehearsal is the real rule
  aimed at a scratch branch and nothing else, the rule names exactly the branches
  tool/promote_live.py moves, and its one way through is the release job's key;
- the rehearsal workflow and tool/rehearse_live_rule.py, whose PASS and FAIL must mean
  what they say (each verdict has a deliberate break here);
- the release job and the rehearsal read the key from the one environment `live`.

Run with: python3 .claude/guardrails/tests/test_release_workflows.py
"""

import importlib.util
import json
import re
import subprocess
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[3]
RULESETS = ROOT / "docs" / "dev" / "rulesets"
WORKFLOWS = ROOT / ".github" / "workflows"


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tool" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def code_of(path):
    return "\n".join(l.split("#", 1)[0] for l in path.read_text().splitlines())


def ruleset(name):
    return json.loads((RULESETS / name).read_text())


class Rulesets(unittest.TestCase):
    def live_refs(self):
        sides = load("promote_live").SIDES
        return sorted(f"refs/heads/{branch}" for branch, _, _ in sides.values())

    def test_both_steps_cover_exactly_the_branches_the_release_job_moves(self):
        for name in ("live-branches-step1.json", "live-branches-step2.json"):
            with self.subTest(ruleset=name):
                r = ruleset(name)
                self.assertEqual(
                    sorted(r["conditions"]["ref_name"]["include"]), self.live_refs()
                )
                self.assertEqual(r["conditions"]["ref_name"]["exclude"], [])
                self.assertEqual(r["enforcement"], "active")
                self.assertEqual(r["target"], "branch")

    def test_step_one_lets_nobody_delete_or_rewind_not_even_the_key(self):
        r = ruleset("live-branches-step1.json")
        self.assertEqual(
            sorted(x["type"] for x in r["rules"]), ["deletion", "non_fast_forward"]
        )
        self.assertEqual(r["bypass_actors"], [])

    def test_step_two_lets_only_the_key_move_them(self):
        r = ruleset("live-branches-step2.json")
        self.assertEqual(
            r["rules"],
            [
                {
                    "type": "update",
                    "parameters": {"update_allows_fetch_and_merge": False},
                }
            ],
        )
        self.assertEqual(
            r["bypass_actors"],
            [{"actor_id": None, "actor_type": "DeployKey", "bypass_mode": "always"}],
        )

    def test_the_rehearsal_is_the_real_rule_on_a_scratch_branch_and_nothing_else(self):
        real, rehearsal = (
            ruleset("live-branches-step2.json"),
            ruleset("live-rehearsal.json"),
        )
        self.assertEqual(
            rehearsal["conditions"]["ref_name"]["include"],
            ["refs/heads/live-rehearsal"],
        )
        for key in set(real) | set(rehearsal):
            if key in ("name", "conditions"):
                continue
            with self.subTest(key=key):
                self.assertEqual(rehearsal.get(key), real.get(key))
        self.assertEqual(load("rehearse_live_rule").BRANCH, "live-rehearsal")

    def test_the_owners_steps_are_short_plain_and_name_real_files(self):
        text = (RULESETS / "README.md").read_text()
        steps = text.split("## The owner's steps", 1)[1].split("\n## ", 1)[0]
        numbered = re.findall(r"(?m)^\d+\. .*(?:\n   .*)*", steps)
        self.assertGreaterEqual(len(numbered), 5)
        self.assertLess(len(" ".join(numbered).split()), 120)
        for name in re.findall(r"`([\w./-]+\.(?:json|sh))`", steps):
            with self.subTest(file=name):
                self.assertTrue(
                    (RULESETS / name).is_file() or (ROOT / name).is_file(), name
                )


class TheKey(unittest.TestCase):
    """The key is read only by jobs that run on main, from the one environment."""

    def test_only_the_release_and_its_rehearsal_read_it_and_both_from_live(self):
        readers = []
        for wf in sorted(WORKFLOWS.glob("*.yml")):
            code = code_of(wf)
            names = set(re.findall(r"secrets\.(\w+)", code))
            if not names:
                continue
            readers.append(wf.name)
            with self.subTest(workflow=wf.name):
                self.assertEqual(names, {"LIVE_DEPLOY_KEY"})
                self.assertRegex(code, r"(?m)^    environment: live\s*$")
                self.assertRegex(
                    code, r"(?m)^    if:\s*github\.ref == 'refs/heads/main'\s*$"
                )
                self.assertNotRegex(code, r"(?m)^  pull_request(_target)?:")
        self.assertEqual(readers, ["deployed-check.yml", "live-rehearsal.yml"])

    def test_the_rehearsal_runs_only_by_hand_and_runs_the_script(self):
        code = code_of(WORKFLOWS / "live-rehearsal.yml")
        self.assertRegex(code, r"(?m)^on:\s*\n  workflow_dispatch:\s*$")
        self.assertNotRegex(code, r"(?m)^  (push|schedule|pull_request):")
        self.assertIn("python3 tool/rehearse_live_rule.py", code)
        self.assertIn("ssh-key: ${{ secrets.LIVE_DEPLOY_KEY }}", code)
        self.assertRegex(code, r"timeout-minutes:\s*\d+")


def pushed(code, err=""):
    return subprocess.CompletedProcess([], code, "", err)


RULE_REFUSAL = "remote: error: GH013: Repository rule violations found for refs/heads/live-rehearsal."


class Rehearsal(unittest.TestCase):
    """PASS means the rule holds; each way it could lie is a break here."""

    def setUp(self):
        self.tool = load("rehearse_live_rule")

    def run_with(self, key_result, token_results):
        said = []
        tokens = iter(token_results)
        with (
            mock.patch.dict("os.environ", {"HAS_KEY": "true"}),
            mock.patch.object(
                self.tool,
                "git",
                return_value=subprocess.CompletedProcess([], 0, "c0ffee\n", ""),
            ),
        ):
            code = self.tool.rehearse(
                key=lambda src: key_result
                if src and not src.startswith("+")
                else pushed(0),
                token=lambda src: next(tokens),
                say=said.append,
            )
        return code, "\n".join(said)

    def test_the_rule_holding_is_pass(self):
        code, said = self.run_with(
            pushed(0), [pushed(1, RULE_REFUSAL), pushed(1, RULE_REFUSAL)]
        )
        self.assertEqual(code, 0, said)
        self.assertEqual(said.count("PASS  "), 3)
        self.assertIn("import docs/dev/rulesets/live-branches-step2.json now", said)

    def test_a_rule_that_stops_the_release_job_is_fail(self):
        code, said = self.run_with(
            pushed(1, RULE_REFUSAL), [pushed(1, RULE_REFUSAL)] * 2
        )
        self.assertEqual(code, 1)
        self.assertIn("FAIL  1.", said)
        self.assertIn("Do NOT import the real rule", said)

    def test_no_rule_at_all_is_fail(self):
        code, said = self.run_with(pushed(0), [pushed(0), pushed(0)])
        self.assertEqual(code, 1)
        self.assertIn("FAIL  2.", said)
        self.assertIn("FAIL  3.", said)

    def test_a_refusal_for_another_reason_is_not_taken_for_the_rule(self):
        code, said = self.run_with(
            pushed(0),
            [pushed(128, "fatal: Authentication failed"), pushed(1, RULE_REFUSAL)],
        )
        self.assertEqual(code, 1)
        self.assertIn("not by the rule", said)

    def test_without_the_key_it_fails_and_says_where_the_key_goes(self):
        said = []
        with mock.patch.dict("os.environ", {"HAS_KEY": "false"}):
            self.assertEqual(self.tool.rehearse(say=said.append), 1)
        self.assertIn("LIVE_DEPLOY_KEY", said[0])
        self.assertIn("environment 'live'", said[0])


if __name__ == "__main__":
    unittest.main()
