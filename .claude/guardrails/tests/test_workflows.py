"""The GitHub workflows are the merge wall, so they are held to four things:

- every `just <recipe>` a workflow runs is a recipe of the root, backend or frontend
  justfile (a renamed recipe fails here, not on the first pull request after);
- no `paths` / `paths-ignore` filter: a required check that never starts stays
  "pending" forever and blocks the merge;
- every job has a `name:` (the name is what branch protection requires) and
  `timeout-minutes` (a hung job must end, not hold a merge);
- the required checks in docs/dev/main-ruleset.json are exactly the jobs' names (a
  renamed or added job fails here until the ruleset file is updated).

One workflow is not part of the wall: PUBLISHING (android-download.yml) builds the Android
app's download on pushes to main. It is held to its own rules (WorkflowPublishing): never on a
pull request, never a required check, `contents: write` on its one job only, a paths filter
(it is not required, so a filter cannot block a merge). It still has to name only real recipes.

No YAML library: the workflows are plain enough to read by indentation.
Run with: python3 .claude/guardrails/tests/test_workflows.py
"""

import json
import re
import shutil
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PUBLISHING = ["android-download.yml"]
ALL_WORKFLOWS = sorted((ROOT / ".github" / "workflows").glob("*.yml"))
# The merge wall's workflows: every pull request runs them, their jobs are the required checks.
WORKFLOWS = [w for w in ALL_WORKFLOWS if w.name not in PUBLISHING]
JUSTFILES = ["justfile", "backend/justfile", "frontend/justfile"]


def recipes():
    names = set()
    for j in JUSTFILES:
        out = subprocess.run(
            [
                "just",
                "--justfile",
                str(ROOT / j),
                "--working-directory",
                str(ROOT),
                "--summary",
            ],
            capture_output=True,
            text=True,
            check=True,
        ).stdout
        names.update(out.split())
    return names


def jobs_of(text):
    """{job id: its text}: the blocks one level under the top-level `jobs:`."""
    m = re.search(r"^jobs:\s*\n", text, re.M)
    body = text[m.end() :] if m else ""
    parts = re.split(r"^  ([A-Za-z0-9_-]+):\s*$", body, flags=re.M)
    return {parts[i]: parts[i + 1] for i in range(1, len(parts) - 1, 2)}


@unittest.skipUnless(shutil.which("just"), "just is not installed")
class WorkflowRecipes(unittest.TestCase):
    def test_every_recipe_a_workflow_runs_exists(self):
        known = recipes()
        self.assertTrue(WORKFLOWS, "no workflows found")
        for wf in ALL_WORKFLOWS:
            for n, line in enumerate(wf.read_text().splitlines(), 1):
                code = line.split("#", 1)[0]
                for m in re.finditer(r"(?:^|[\s\"'`(])just\s+([a-z][a-z0-9_-]*)", code):
                    self.assertIn(
                        m.group(1),
                        known,
                        f"{wf.name}:{n} runs `just {m.group(1)}`, which is not a recipe",
                    )


def job_names():
    """Every job's check name; a matrix job's `${{ matrix.x }}` is filled in for each value."""
    names = []
    for wf in WORKFLOWS:
        for text in jobs_of(wf.read_text()).values():
            m = re.search(r"^    name:\s*(.+?)\s*$", text, re.M)
            if not m:
                continue
            name = m.group(1)
            axis = re.search(r"\$\{\{\s*matrix\.(\w+)\s*\}\}", name)
            if not axis:
                names.append(name)
                continue
            values = re.search(rf"^\s+{axis.group(1)}:\s*\[(.*?)\]", text, re.M).group(
                1
            )
            for v in (v.strip() for v in values.split(",")):
                names.append(re.sub(r"\$\{\{\s*matrix\.\w+\s*\}\}", v, name))
    return names


class RulesetMatchesWorkflows(unittest.TestCase):
    def test_required_checks_are_exactly_the_jobs(self):
        ruleset = json.loads((ROOT / "docs" / "dev" / "main-ruleset.json").read_text())
        rules = {r["type"]: r.get("parameters", {}) for r in ruleset["rules"]}
        required = [
            c["context"]
            for c in rules["required_status_checks"]["required_status_checks"]
        ]
        self.assertEqual(sorted(required), sorted(job_names()))
        self.assertEqual(ruleset["enforcement"], "active")
        self.assertEqual(ruleset["bypass_actors"], [])
        self.assertFalse(
            rules["required_status_checks"]["strict_required_status_checks_policy"]
        )
        self.assertEqual(rules["pull_request"]["allowed_merge_methods"], ["squash"])
        self.assertIn("non_fast_forward", rules)
        self.assertIn("deletion", rules)


class WorkflowShape(unittest.TestCase):
    def test_no_path_filters(self):
        for wf in WORKFLOWS:
            text = "\n".join(l.split("#", 1)[0] for l in wf.read_text().splitlines())
            self.assertIsNone(
                re.search(r"^\s*paths(-ignore)?:", text, re.M),
                f"{wf.name} filters on paths: a required check that does not start blocks the merge",
            )

    def test_every_job_has_a_name_and_a_time_limit(self):
        for wf in WORKFLOWS:
            jobs = jobs_of(wf.read_text())
            self.assertTrue(jobs, f"{wf.name}: no jobs found")
            for job, text in jobs.items():
                self.assertRegex(
                    text, r"(?m)^    name:\s*\S", f"{wf.name} job {job} has no name"
                )
                self.assertRegex(
                    text,
                    r"(?m)^    timeout-minutes:\s*\d+",
                    f"{wf.name} job {job} has no timeout-minutes",
                )

    def test_job_names_are_unique(self):
        names = []
        for wf in WORKFLOWS:
            for text in jobs_of(wf.read_text()).values():
                m = re.search(r"^    name:\s*(.+?)\s*$", text, re.M)
                if m:
                    names.append(m.group(1))
        self.assertEqual(
            len(names), len(set(names)), f"two jobs share a name: {sorted(names)}"
        )

    def test_pull_requests_run_every_workflow(self):
        for wf in WORKFLOWS:
            self.assertRegex(
                wf.read_text(),
                r"(?m)^  pull_request:",
                f"{wf.name} does not run on pull requests",
            )


class WorkflowPublishing(unittest.TestCase):
    """The Android download: a publisher, not a check."""

    def setUp(self):
        self.path = ROOT / ".github" / "workflows" / PUBLISHING[0]
        self.text = self.path.read_text()
        self.code = "\n".join(l.split("#", 1)[0] for l in self.text.splitlines())

    def test_exists_and_is_set_apart(self):
        self.assertIn(self.path, ALL_WORKFLOWS)
        self.assertNotIn(self.path, WORKFLOWS)

    def test_runs_on_main_pushes_to_the_app_and_by_hand_never_on_pull_requests(self):
        self.assertNotRegex(self.code, r"(?m)^  pull_request(_target)?:")
        self.assertRegex(self.code, r'(?m)^  push:\s*\n    branches: \["main"\]')
        self.assertRegex(self.code, r'(?m)^    paths: \["frontend/\*\*"\]')
        self.assertRegex(self.code, r"(?m)^  workflow_dispatch:")

    def test_is_not_a_required_check(self):
        ruleset = json.loads((ROOT / "docs" / "dev" / "main-ruleset.json").read_text())
        rules = {r["type"]: r.get("parameters", {}) for r in ruleset["rules"]}
        required = [
            c["context"]
            for c in rules["required_status_checks"]["required_status_checks"]
        ]
        names = re.findall(r"(?m)^    name:\s*(.+?)\s*$", self.text)
        self.assertTrue(names)
        for name in names:
            self.assertNotIn(name, required)

    def test_writes_only_in_its_one_job(self):
        top = self.code.split("\njobs:")[0]
        self.assertRegex(top, r"(?m)^permissions:\s*\n  contents: read\s*$")
        self.assertNotIn("write", top)
        jobs = jobs_of(self.text)
        self.assertEqual(len(jobs), 1)
        (job,) = jobs.values()
        self.assertRegex(job, r"(?m)^    permissions:\s*\n      contents: write\s*$")
        self.assertRegex(job, r"(?m)^    name:\s*\S")
        self.assertRegex(job, r"(?m)^    timeout-minutes:\s*\d+")

    def test_the_job_publishes_only_from_main(self):
        (job,) = jobs_of(self.text).values()
        self.assertRegex(
            job, r"(?m)^    if:\s*github\.ref == 'refs/heads/main'\s*$"
        )

    def test_builds_with_the_script_and_publishes_the_one_asset(self):
        self.assertIn("tool/build_android.sh", self.code)
        self.assertIn("TAG: android-latest", self.code)
        self.assertIn("midnight-village.apk", self.code)
        # Never an empty release: upload under another name, then swap by the API.
        self.assertNotIn("--clobber", self.code)
        self.assertIn("midnight-village-new.apk", self.code)
        self.assertIn("-X PATCH", self.code)
        self.assertIn("-X DELETE", self.code)
        self.assertRegex(self.code, r"for attempt in 1 2 3")
        self.assertIn("app-arm64-v8a-release.apk", self.code)
        self.assertIn(
            "PUBLIC_ORIGIN: https://midnight-village-app-anthelion.vercel.app",
            self.code,
        )

    def test_vercel_redirects_the_short_address_to_the_asset(self):
        cfg = json.loads((ROOT / "frontend" / "vercel.json").read_text())
        (redirect,) = cfg["redirects"]
        self.assertEqual(redirect["source"], "/app")
        self.assertIs(redirect["permanent"], False)
        self.assertEqual(
            redirect["destination"],
            "https://github.com/doodla/midnight-village/releases/download/"
            "android-latest/midnight-village.apk",
        )
        # The single-page rewrite stays last; Vercel answers redirects before rewrites.
        self.assertEqual(
            cfg["rewrites"][-1], {"source": "/(.*)", "destination": "/index.html"}
        )


if __name__ == "__main__":
    unittest.main()
