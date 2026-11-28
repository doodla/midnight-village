# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
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

AFTER_MERGE (deployed-check.yml) is not part of the wall either: it tests the deployment a
merge makes, so it can only run after it. Its rules (WorkflowAfterMerge): every push to main
with no paths filter, never on a pull request, never a required check, no write permission,
no secret, and it runs tool/deployed_check.py against the same two addresses the Android
build uses.

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
AFTER_MERGE = ["deployed-check.yml"]
# Watches main's own runs and keeps the one "main is red" issue: not a check on anything.
WATCHING = ["main-red.yml"]
WORKFLOWS = [
    w for w in ALL_WORKFLOWS if w.name not in PUBLISHING + AFTER_MERGE + WATCHING
]
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


def needed_parts(text):
    """{job id of a part: job id of the gate that needs it}, for one workflow."""
    parts = {}
    for gate, body in jobs_of(text).items():
        m = re.search(r"^    needs:\s*\[([^\]]*)\]", body, re.M)
        if m:
            for part in (p.strip() for p in m.group(1).split(",")):
                if part:
                    parts[part] = gate
    return parts


def job_names():
    """The check name of every job that stands for itself; a matrix job's
    `${{ matrix.x }}` is filled in for each value. A job another job `needs` is a
    part of that job: the required check is the one that needs it (`Gates` holds
    such a job to failing unless every part ran and passed)."""
    names = []
    for wf in WORKFLOWS:
        parts = needed_parts(wf.read_text())
        for job_id, text in jobs_of(wf.read_text()).items():
            if job_id in parts:
                continue
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


class Gates(unittest.TestCase):
    """A required check that stands for other jobs passes only when each of them
    ran and passed. A job whose need failed is SKIPPED unless it says `always()`,
    and GitHub counts a skipped required check as passed."""

    def gates(self):
        for wf in WORKFLOWS:
            jobs = jobs_of(wf.read_text())
            for part, gate in needed_parts(wf.read_text()).items():
                yield wf.name, part, gate, jobs

    def test_there_is_a_gate_and_its_parts_exist(self):
        found = list(self.gates())
        self.assertTrue(found)
        for name, part, gate, jobs in found:
            self.assertIn(
                part, jobs, f"{name}: {gate} needs {part}, which is not a job"
            )

    def test_a_gate_always_runs_and_passes_only_on_success_of_every_part(self):
        for name, part, gate, jobs in self.gates():
            body = "\n".join(l.split("#", 1)[0] for l in jobs[gate].splitlines())
            self.assertRegex(
                body,
                r"(?m)^    if:\s*\$\{\{\s*always\(\)\s*\}\}\s*$",
                f"{name}: {gate}",
            )
            # the parts' combined result is read, and only "success" passes:
            # "failure", "cancelled" and "skipped" (a part that did not run) do not
            self.assertIn(f"needs.{part}.result", body, f"{name}: {gate}")
            self.assertRegex(body, r'\[ "\$\w+" = "success" \]', f"{name}: {gate}")
            self.assertNotIn("continue-on-error", body)
            self.assertNotRegex(body, r"\|\|\s*true")

    def test_a_part_cannot_pass_by_being_allowed_to_fail(self):
        for name, part, gate, jobs in self.gates():
            self.assertNotIn("continue-on-error", jobs[part], f"{name}: {part}")

    def test_the_widget_tests_parts_cover_the_whole_suite(self):
        text = (ROOT / ".github" / "workflows" / "flutter-tests.yml").read_text()
        (total,) = set(
            re.findall(r"just test-widgets \$\{\{ matrix\.part \}\} (\d+)", text)
        )
        (listed,) = re.findall(
            r"part: \[([\d, ]+)\]", jobs_of(text)["widget-tests-part"]
        )
        self.assertEqual(
            [int(n) for n in listed.split(",")], list(range(1, int(total) + 1))
        )
        recipe = (ROOT / "frontend" / "justfile").read_text()
        self.assertIn("--total-shards", recipe)
        self.assertIn("--shard-index", recipe)


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

    def test_the_build_reads_and_only_the_publish_job_writes_with_no_code_of_others(
        self,
    ):
        """What is not ours (Java, Flutter, Gradle, packages) runs with a read token; the
        job that holds the write token runs only gh, on the file the build handed on."""
        top = self.code.split("\njobs:")[0]
        self.assertRegex(top, r"(?m)^permissions:\s*\n  contents: read\s*$")
        self.assertNotIn("write", top)
        jobs = jobs_of(self.code)
        self.assertEqual(sorted(jobs), ["build", "publish"])
        build, publish = jobs["build"], jobs["publish"]
        self.assertRegex(build, r"(?m)^    permissions:\s*\n      contents: read\s*$")
        self.assertNotIn("write", build)
        self.assertIn("persist-credentials: false", build)
        self.assertIn("tool/build_android.sh", build)
        self.assertRegex(
            publish, r"(?m)^    permissions:\s*\n      contents: write\s*$"
        )
        self.assertRegex(publish, r"(?m)^    needs: \[build\]")
        used = re.findall(r"uses:\s*(\S+)@", publish)
        self.assertEqual(used, ["actions/download-artifact"])
        self.assertNotIn("flutter", publish)
        for job in jobs.values():
            self.assertRegex(job, r"(?m)^    name:\s*\S")
            self.assertRegex(job, r"(?m)^    timeout-minutes:\s*\d+")

    def test_the_job_publishes_only_from_main(self):
        for job in jobs_of(self.text).values():
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
        # The single-page rewrite stays; Vercel answers redirects before rewrites.
        (rewrite,) = cfg["rewrites"]
        self.assertEqual(rewrite["destination"], "/index.html")
        # Which paths it takes (app routes only; a removed picture is a 404) is
        # judged on what Vercel compiles from the file: frontend/tool/web_smoke/
        # routes.test.cjs, run by "Web page smoke".


class WorkflowAfterMerge(unittest.TestCase):
    """The deployed check: runs after every merge, reads public addresses only."""

    def setUp(self):
        self.path = ROOT / ".github" / "workflows" / AFTER_MERGE[0]
        self.text = self.path.read_text()
        self.code = "\n".join(l.split("#", 1)[0] for l in self.text.splitlines())

    def test_exists_and_is_set_apart(self):
        self.assertIn(self.path, ALL_WORKFLOWS)
        self.assertNotIn(self.path, WORKFLOWS)

    def test_runs_on_every_push_to_main_and_by_hand_never_on_pull_requests(self):
        self.assertNotRegex(self.code, r"(?m)^  pull_request(_target)?:")
        self.assertRegex(self.code, r'(?m)^  push:\s*\n    branches: \["main"\]')
        self.assertRegex(self.code, r"(?m)^  workflow_dispatch:")
        # every merge deploys, so every merge is checked: no paths filter
        self.assertNotRegex(self.code, r"(?m)^\s*paths(-ignore)?:")

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

    def test_its_one_write_is_moving_the_live_branches_and_it_holds_no_secret(self):
        self.assertRegex(self.code, r"(?m)^permissions:\s*\n  contents: read\s*$")
        # the job may push (the two live branches); nothing else is granted
        self.assertEqual(re.findall(r"(?m)^\s+(\S+): write\b", self.code), ["contents"])
        self.assertNotIn("secrets.", self.code)
        self.assertNotRegex(self.code, r"\bgit push\b")  # only the script pushes
        script = (ROOT / "tool" / "promote_live.py").read_text()
        pushes = re.findall(r'"push",\s*"origin",\s*f?"([^"]+)"', script)
        self.assertEqual(pushes, ["{head}:refs/heads/{branch}"])
        self.assertEqual(
            sorted(re.findall(r'"(live-[a-z]+)"', script)), ["live-app", "live-server"]
        )

    def test_vercel_deploys_each_project_from_its_live_branch_only(self):
        for folder, branch in (("backend", "live-server"), ("frontend", "live-app")):
            config = json.loads((ROOT / folder / "vercel.json").read_text())
            self.assertEqual(
                config["git"]["deploymentEnabled"], {branch: True, "**": False}, folder
            )

    def test_its_one_job_has_a_name_a_time_limit_and_runs_only_on_main(self):
        jobs = jobs_of(self.text)
        self.assertEqual(len(jobs), 1)
        (job,) = jobs.values()
        self.assertRegex(job, r"(?m)^    name:\s*\S")
        self.assertRegex(job, r"(?m)^    timeout-minutes:\s*\d+")
        self.assertRegex(job, r"(?m)^    if:\s*github\.ref == 'refs/heads/main'\s*$")

    def test_moves_the_branches_then_checks_each_side_against_its_own_commit(self):
        self.assertTrue((ROOT / "tool" / "deployed_check.py").is_file())
        moved = self.code.index("tool/promote_live.py")
        checked = self.code.index("tool/deployed_check.py")
        self.assertLess(moved, checked)
        self.assertIn("steps.live.outputs.server", self.code)
        self.assertIn("steps.live.outputs.app", self.code)
        # the deal and a restart reach the other phones only by socket: the one
        # check that opens one against the live server stays switched on
        self.assertIn("--sockets", self.code)
        # ... and its timings are kept, so two merges can be compared
        self.assertIn("--timings deployed-timings.json", self.code)
        self.assertIn("path: deployed-timings.json", self.code)
        self.assertTrue((ROOT / "tool" / "deployed_sockets.py").is_file())
        android = (ROOT / ".github" / "workflows" / PUBLISHING[0]).read_text()
        for name in ("API_ORIGIN", "PUBLIC_ORIGIN"):
            (line,) = re.findall(rf"(?m)^  {name}: \S+$", self.code)
            self.assertIn(line, android)

    def test_the_promotion_can_see_mains_checks_the_server_and_the_floor(self):
        """tool/promote_live.py waits for main's checks (it needs `checks: read` and the
        token), for the server (it needs its address), and proves the floor (it needs the
        whole history); skipping the waits is a person's choice on a manual run only."""
        (job,) = jobs_of(self.text).values()
        self.assertRegex(job, r"(?m)^      checks: read\b")
        self.assertRegex(job, r"(?m)^          fetch-depth: 0\b")
        step = self.code[self.code.index("id: live") :].split("\n      - name:")[0]
        self.assertIn("GH_TOKEN: ${{ github.token }}", step)
        self.assertIn('tool/promote_live.py --api "$API_ORIGIN"', step)
        self.assertIn("inputs.skip_waits", step)
        self.assertRegex(
            self.code,
            r"(?m)^      skip_waits:\s*\n(?:        .*\n)*?        default: false",
        )

    def test_the_web_build_says_which_commit_it_is(self):
        build = (ROOT / "frontend" / "tool" / "vercel_build.sh").read_text()
        self.assertIn("build/web/commit.txt", build)
        self.assertIn("VERCEL_GIT_COMMIT_SHA", build)


def write_token_problems(name, text):
    """What is wrong with the jobs of one workflow that hold a write token: an action not
    pinned by commit (a moved tag would run new code with that token), a pin without
    its version beside it, a checkout that keeps the token on disk in a job that never
    pushes with git."""
    code = "\n".join(l.split("#", 1)[0] for l in text.splitlines())
    everyone_writes = bool(re.search(r": write\b", code.split("\njobs:")[0]))
    problems = []
    raw_jobs = jobs_of(text)
    for job, body in jobs_of(code).items():
        if not (everyone_writes or re.search(r"(?m)^\s+[a-z-]+: write\b", body)):
            continue
        for ref in re.findall(r"uses:\s*(\S+)", body):
            if not ref.startswith("./") and not re.search(r"@[0-9a-f]{40}$", ref):
                problems.append(
                    f"{name} job {job} holds a write token and runs `{ref}`: pin it by commit,"
                    " `owner/action@<40-hex sha>  # vX.Y.Z` (the sha of the tag:"
                    " `git ls-remote --tags https://github.com/owner/action`)."
                )
        for line in raw_jobs.get(job, "").splitlines():
            if re.search(r"uses:\s*\S+@[0-9a-f]{40}", line) and not re.search(
                r"#\s*v\d", line
            ):
                problems.append(
                    f"{name} job {job}: say the version beside the pin: `{line.strip()}  # vX.Y.Z`."
                )
        pushes = re.search(r"\bgit push\b|tool/promote_live\.py", body)
        if (
            "actions/checkout@" in body
            and not pushes
            and "persist-credentials: false" not in body
        ):
            problems.append(
                f"{name} job {job} holds a write token and its checkout keeps it on disk"
                " for nothing: add `persist-credentials: false` under the checkout's `with:`."
            )
    return problems


class WriteTokens(unittest.TestCase):
    """A job that holds a write token runs only code that cannot move under it, and keeps
    no token on disk that it does not use. Read from the files: no list of jobs here."""

    def test_every_job_with_a_write_token_holds_to_it(self):
        writers = 0
        for wf in ALL_WORKFLOWS:
            text = wf.read_text()
            writers += len(re.findall(r"(?m)^\s+[a-z-]+: write\b", text))
            with self.subTest(workflow=wf.name):
                self.assertEqual(write_token_problems(wf.name, text), [])
        self.assertGreaterEqual(writers, 3)

    def test_a_deliberate_break_is_caught_and_says_the_fix(self):
        broken = (
            "permissions:\n  contents: read\n"
            "jobs:\n"
            "  publish:\n"
            "    name: Publish\n"
            "    permissions:\n      contents: write\n"
            "    steps:\n"
            "      - uses: actions/checkout@v4\n"
            "      - uses: some/action@0123456789012345678901234567890123456789\n"
            "  tests:\n"
            "    name: Tests\n"
            "    steps:\n"
            "      - uses: actions/checkout@v4\n"
        )
        problems = write_token_problems("x.yml", broken)
        self.assertEqual(len(problems), 3, problems)  # tests reads only: not judged
        self.assertIn("pin it by commit", problems[0])
        self.assertIn("say the version", problems[1])
        self.assertIn("persist-credentials: false", problems[2])


class WorkflowMainIsRed(unittest.TestCase):
    """Main's own runs are watched, and one issue says when main is red."""

    def setUp(self):
        self.path = ROOT / ".github" / "workflows" / WATCHING[0]
        self.text = self.path.read_text()
        self.code = "\n".join(l.split("#", 1)[0] for l in self.text.splitlines())
        spec = __import__("importlib.util").util.spec_from_file_location(
            "main_red", ROOT / "tool" / "main_red.py"
        )
        self.tool = __import__("importlib.util").util.module_from_spec(spec)
        spec.loader.exec_module(self.tool)

    def test_exists_and_is_set_apart(self):
        self.assertIn(self.path, ALL_WORKFLOWS)
        self.assertNotIn(self.path, WORKFLOWS)

    def test_it_watches_every_workflow_that_runs_on_main_by_its_real_name(self):
        named = re.search(r"workflows: \[(.*?)\]", self.code).group(1)
        watched = re.findall(r'"([^"]+)"', named)
        runs_on_main = []
        for wf in ALL_WORKFLOWS:
            text = wf.read_text()
            if wf.name in WATCHING or wf.name in PUBLISHING:
                continue
            if re.search(r'(?m)^  push:\s*\n    branches: \["main"\]', text):
                runs_on_main.append(re.search(r"(?m)^name:\s*(.+?)\s*$", text).group(1))
        self.assertEqual(sorted(watched), sorted(runs_on_main))
        self.assertEqual(sorted(self.tool.WATCHED), sorted(watched))

    def test_it_runs_only_after_mains_own_runs_never_on_a_pull_request(self):
        self.assertNotRegex(self.code, r"(?m)^  pull_request(_target)?:")
        self.assertNotRegex(self.code, r"(?m)^  push:")
        self.assertRegex(self.code, r'(?m)^    branches: \["main"\]')
        self.assertIn("github.event.workflow_run.event == 'push'", self.code)

    def test_its_one_write_is_the_issue_and_it_holds_no_secret(self):
        writes = re.findall(r"(?m)^\s+([a-z-]+): write", self.code)
        self.assertEqual(writes, ["issues"])
        self.assertNotIn("secrets.", self.code)

    def test_is_not_a_required_check(self):
        ruleset = json.loads((ROOT / "docs" / "dev" / "main-ruleset.json").read_text())
        rules = {r["type"]: r.get("parameters", {}) for r in ruleset["rules"]}
        required = [
            c["context"]
            for c in rules["required_status_checks"]["required_status_checks"]
        ]
        for name in re.findall(r"(?m)^    name:\s*(.+?)\s*$", self.text):
            self.assertNotIn(name, required)

    def test_one_issue_opens_on_the_first_failure_and_closes_when_all_is_green(self):
        decide = self.tool.decide
        self.assertEqual(decide("failure", False, False), "open")
        self.assertEqual(decide("failure", True, False), "add")
        self.assertEqual(decide("success", True, True), "close")
        # one workflow passing while another is still red does not close it
        self.assertEqual(decide("success", True, False), "nothing")
        self.assertEqual(decide("success", False, True), "nothing")
        self.assertEqual(decide("cancelled", False, False), "nothing")


if __name__ == "__main__":
    unittest.main()
