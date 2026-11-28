# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""The branches Vercel deploys from (tool/promote_live.py): they move only when what they
serve changed, only to a merged commit whose required checks passed, server before app,
only forward, and never below the rollback floor.

Each promise has a deliberate break here that it must catch. No network: git runs on a
throwaway repository, and GitHub's check runs and the server's health are a fake.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import contextlib
import importlib.util
import io
import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[3]
SCRIPT = REPO / "tool" / "promote_live.py"
RULESET = REPO / "docs" / "dev" / "main-ruleset.json"
REQUIRED = [
    c["context"]
    for r in json.loads(RULESET.read_text())["rules"]
    if r["type"] == "required_status_checks"
    for c in r["parameters"]["required_status_checks"]
]


def load(root: Path):
    spec = importlib.util.spec_from_file_location("promote_live", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.ROOT = root
    return module


class FakeGitHubAndServer:
    """GitHub's check runs for any commit, and the server's /api/health/."""

    def __init__(self, test):
        self.test = test
        # name -> list of (id, status, conclusion, app slug); every required check green
        self.runs = {
            n: [(1, "completed", "success", "github-actions")] for n in REQUIRED
        }
        self.serving = None  # None: the server serves what live-server holds
        self.health_calls = 0
        self.checks_status = 200

    def __call__(self, url, headers):
        if "/check-runs" in url:
            runs = [
                {"id": i, "name": n, "status": s, "conclusion": c, "app": {"slug": app}}
                for n, rows in self.runs.items()
                for i, s, c, app in rows
            ]
            return self.checks_status, {"check_runs": runs}
        if url.endswith("/api/health/"):
            self.health_calls += 1
            commit = (
                self.serving(self.health_calls)
                if callable(self.serving)
                else self.test.promote.remote_head("live-server")
            )
            return 200, {"status": "ok", "commit": commit}
        raise AssertionError(f"unexpected request {url}")


class PromoteLive(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        self.remote = base / "remote.git"
        self.root = base / "work"
        subprocess.run(
            ["git", "init", "-q", "--bare", "-b", "main", str(self.remote)], check=True
        )
        subprocess.run(
            ["git", "clone", "-q", str(self.remote), str(self.root)],
            check=True,
            capture_output=True,
        )
        self.git("config", "user.email", "t@t")
        self.git("config", "user.name", "t")
        self.promote = load(self.root)
        # the throwaway main carries the real ruleset: the checks waited for are its own
        self.floor = self.merge({"docs/dev/main-ruleset.json": RULESET.read_text()})
        self.promote.FLOOR = self.floor
        self.merge({"backend/apps/a.py": "1", "frontend/lib/a.dart": "1"})
        self.fake = FakeGitHubAndServer(self)
        self.promote.fetch_json = self.fake
        self.now = 0.0
        self.promote.clock = lambda: self.now
        self.promote.sleep = self.advance
        env = {"GITHUB_REPOSITORY": "o/r", "GH_TOKEN": "t", "GITHUB_OUTPUT": ""}
        patcher = mock.patch.dict(os.environ, env)
        patcher.start()
        self.addCleanup(patcher.stop)

    def tearDown(self):
        self.tmp.cleanup()

    def advance(self, seconds):
        self.now += seconds

    def git(self, *args: str) -> str:
        return subprocess.run(
            ["git", "-C", str(self.root), *args],
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

    def merge(self, files: dict[str, str]) -> str:
        """A merge to main touching these files; returns its commit."""
        for name, text in files.items():
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "merge")
        self.git("push", "-q", "origin", "HEAD:main")
        return self.git("rev-parse", "HEAD")

    def live(self) -> dict[str, str]:
        return {
            side: self.promote.remote_head(branch)
            for side, (branch, _, _) in self.promote.SIDES.items()
        }

    def attempt(self, *argv: str) -> tuple[int, str]:
        """(exit code, everything said) of one promotion."""
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            code = self.promote.main(["--api", "https://server.test", *argv])
        return code, out.getvalue()

    def run_it(self) -> dict[str, str]:
        code, said = self.attempt()
        self.assertEqual(code, 0, said)
        return self.live()

    # ---- what moves (unchanged from before the gate) ----

    def test_the_first_run_makes_both_branches(self):
        head = self.git("rev-parse", "HEAD")
        self.assertEqual(self.run_it(), {"server": head, "app": head})

    def test_a_server_change_moves_only_the_server(self):
        first = self.run_it()
        head = self.merge({"backend/apps/a.py": "2"})
        self.assertEqual(self.run_it(), {"server": head, "app": first["app"]})

    def test_an_app_change_moves_only_the_app(self):
        first = self.run_it()
        head = self.merge({"frontend/lib/a.dart": "2"})
        self.assertEqual(self.run_it(), {"server": first["server"], "app": head})

    def test_tests_docs_and_tooling_move_nothing(self):
        first = self.run_it()
        self.merge(
            {
                "backend/tests/test_a.py": "x",
                "backend/CLAUDE.md": "x",
                "frontend/test/a_test.dart": "x",
                "frontend/test_screens/a.dart": "x",
                "frontend/README.md": "x",
                "docs/a.md": "x",
                "tool/a.py": "x",
                ".github/workflows/a.yml": "x",
                "contract_samples/a.json": "x",
            }
        )
        self.assertEqual(self.run_it(), first)

    def test_what_a_build_reads_moves_its_side(self):
        for name, side in (
            ("backend/pyproject.toml", "server"),
            ("backend/vercel.json", "server"),
            ("backend/apps/core/migrations/0099_x.py", "server"),
            ("frontend/pubspec.yaml", "app"),
            ("frontend/assets/a.png", "app"),
            ("frontend/vercel.json", "app"),
            ("frontend/tool/vercel_build.sh", "app"),
        ):
            before = self.run_it()
            head = self.merge({name: name + "changed"})
            after = self.run_it()
            self.assertEqual(after[side], head, name)
            other = "app" if side == "server" else "server"
            self.assertEqual(after[other], before[other], name)

    def test_a_missed_run_is_made_up_by_the_next(self):
        first = self.run_it()
        self.merge({"backend/apps/a.py": "2"})  # its run was cancelled: nothing moved
        head = self.merge({"docs/a.md": "x"})  # this merge ships nothing itself
        self.assertEqual(self.run_it(), {"server": head, "app": first["app"]})

    def test_an_older_run_arriving_late_does_not_move_a_branch_back(self):
        self.run_it()
        older = self.merge({"backend/apps/a.py": "2"})
        newer = self.merge({"backend/apps/a.py": "3"})
        self.run_it()  # the newer merge's run got there first
        self.git("checkout", "-q", older)
        code, said = self.attempt()
        self.assertEqual(code, 0, said)
        self.assertEqual(self.promote.remote_head("live-server"), newer)
        self.assertIn("already past", said)

    def test_a_dry_run_moves_nothing_and_asks_nobody(self):
        self.promote.fetch_json = None  # any request would raise
        code, said = self.attempt("--dry-run")
        self.assertEqual(code, 0, said)
        self.assertEqual(self.promote.remote_head("live-server"), "")
        self.assertIn("would move", said)

    # ---- 1. only a green main goes live ----

    def test_a_red_check_on_main_moves_nothing_and_says_which(self):
        first = self.run_it()
        self.merge({"backend/apps/a.py": "2", "frontend/lib/a.dart": "2"})
        name = REQUIRED[-1]
        self.fake.runs[name] = [(2, "completed", "failure", "github-actions")]
        code, said = self.attempt()
        self.assertEqual(code, 1)
        self.assertEqual(self.live(), first)
        self.assertIn("main is red", said)
        self.assertIn(f"{name} (failure)", said)
        self.assertIn("new merge to main", said)  # what fixes it

    def test_every_required_check_is_waited_for_none_by_name_here(self):
        """Each check the ruleset requires, missing on its own, holds the release."""
        first = self.run_it()
        self.merge({"backend/apps/a.py": "2"})
        everything = dict(self.fake.runs)
        for name in REQUIRED:
            with self.subTest(check=name):
                self.fake.runs = {n: r for n, r in everything.items() if n != name}
                code, said = self.attempt("--checks-wait", "60")
                self.assertEqual(code, 1)
                self.assertEqual(self.live(), first)
                self.assertIn(name, said)
                self.assertIn("still not done", said)

    def test_checks_still_running_are_waited_for_then_it_moves(self):
        self.run_it()
        head = self.merge({"backend/apps/a.py": "2"})
        name = REQUIRED[0]
        self.fake.runs[name] = [(2, "in_progress", None, "github-actions")]
        before = self.now
        real = self.promote.check_runs

        def finishing(sha):
            if self.now - before >= 90:
                self.fake.runs[name] = [(3, "completed", "success", "github-actions")]
            return real(sha)

        self.promote.check_runs = finishing
        self.assertEqual(self.run_it()["server"], head)
        self.assertGreaterEqual(self.now - before, 90)

    def test_a_check_that_never_finishes_times_out_saying_what_is_missing(self):
        first = self.run_it()
        self.merge({"backend/apps/a.py": "2"})
        self.fake.runs[REQUIRED[0]] = [(2, "queued", None, "github-actions")]
        code, said = self.attempt("--checks-wait", "600")
        self.assertEqual(code, 1)
        self.assertEqual(self.live(), first)
        self.assertGreaterEqual(self.now, 600)
        self.assertIn("after 10 minutes", said)
        self.assertIn(REQUIRED[0], said)

    def test_a_green_check_posted_by_anything_but_github_actions_does_not_count(self):
        first = self.run_it()
        self.merge({"backend/apps/a.py": "2"})
        self.fake.runs[REQUIRED[0]] = [(9, "completed", "success", "someone-elses-app")]
        code, _ = self.attempt("--checks-wait", "60")
        self.assertEqual(code, 1)
        self.assertEqual(self.live(), first)

    def test_a_re_run_that_passed_replaces_the_failure(self):
        self.run_it()
        head = self.merge({"backend/apps/a.py": "2"})
        self.fake.runs[REQUIRED[0]] = [
            (5, "completed", "failure", "github-actions"),
            (6, "completed", "success", "github-actions"),
        ]
        self.assertEqual(self.run_it()["server"], head)

    def test_when_github_cannot_list_the_checks_nothing_moves(self):
        first = self.run_it()
        self.merge({"backend/apps/a.py": "2"})
        self.fake.checks_status = 403
        code, said = self.attempt()
        self.assertEqual(code, 1)
        self.assertEqual(self.live(), first)
        self.assertIn("checks: read", said)

    # ---- 2. the server goes first ----

    def test_when_both_change_the_app_moves_only_once_the_server_serves_the_commit(
        self,
    ):
        first = self.run_it()
        head = self.merge({"backend/apps/a.py": "2", "frontend/lib/a.dart": "2"})
        seen = []

        def slow_build(calls):
            # what live-app holds at each look: it must not move before the server serves
            seen.append(self.promote.remote_head("live-app"))
            return head if calls >= 3 else first["server"]

        self.fake.serving = slow_build
        self.fake.health_calls = 0
        self.assertEqual(self.run_it(), {"server": head, "app": head})
        self.assertEqual(seen, [first["app"]] * 3)

    def test_a_server_that_never_serves_its_commit_keeps_the_old_app(self):
        first = self.run_it()
        head = self.merge({"backend/apps/a.py": "2", "frontend/lib/a.dart": "2"})
        self.fake.serving = lambda calls: first["server"]  # the build failed in Vercel
        code, said = self.attempt("--health-wait", "300")
        self.assertEqual(code, 1)
        self.assertEqual(self.live(), {"server": head, "app": first["app"]})
        self.assertIn("never goes live ahead of its", said)
        self.assertIn("Instant Rollback", said)

    def test_an_app_change_waits_for_a_server_that_is_not_serving_its_branch(self):
        """The promise is about what serves, not about this run: a server whose last
        build never arrived holds back an app-only change too."""
        first = self.run_it()
        self.merge({"frontend/lib/a.dart": "2"})
        self.fake.serving = lambda calls: "0" * 40  # serving something older
        code, _ = self.attempt("--health-wait", "60")
        self.assertEqual(code, 1)
        self.assertEqual(self.live(), first)

    # ---- 3. only forward ----

    def test_a_live_branch_moved_off_to_the_side_is_refused_and_nothing_moves(self):
        first = self.run_it()
        self.git("checkout", "-q", "-b", "side", first["server"])
        stray = self.merge_on_branch({"backend/apps/a.py": "by hand"})
        self.git("push", "-q", "-f", "origin", f"{stray}:refs/heads/live-server")
        self.git("checkout", "-q", "main")
        self.merge({"backend/apps/a.py": "2", "frontend/lib/a.dart": "2"})
        code, said = self.attempt()
        self.assertEqual(code, 1)
        self.assertEqual(self.live(), {"server": stray, "app": first["app"]})
        self.assertIn("not in the history", said)
        self.assertIn("only the release job moves the live branches", said)

    def merge_on_branch(self, files):
        for name, text in files.items():
            (self.root / name).write_text(text)
        self.git("commit", "-q", "-am", "by hand")
        return self.git("rev-parse", "HEAD")

    # ---- 4. never below the floor ----

    def test_a_commit_without_the_floor_is_refused_even_by_hand(self):
        self.run_it()
        self.git("checkout", "-q", "-b", "later", "main")
        self.promote.FLOOR = self.merge_on_branch({"backend/apps/a.py": "floor"})
        self.git("checkout", "-q", "main")
        head = self.merge({"backend/apps/a.py": "2"})  # does not contain the new floor
        for argv in ((), ("--skip-waits",)):
            with self.subTest(argv=argv):
                code, said = self.attempt(*argv)
                self.assertEqual(code, 1)
                self.assertNotEqual(self.promote.remote_head("live-server"), head)
                self.assertIn("older than the rollback floor", said)
                self.assertIn("roll forward", said)

    def test_the_real_floor_is_the_commit_that_took_is_ready_out_of_the_model(self):
        floor = load(REPO).FLOOR
        self.assertRegex(floor, r"^[0-9a-f]{40}$")
        found = subprocess.run(
            ["git", "-C", str(REPO), "log", "-1", "--format=%s", floor],
            capture_output=True,
            text=True,
        )
        if found.returncode != 0:
            self.skipTest("a shallow checkout without the floor commit")
        self.assertIn("(#81)", found.stdout)
        ancestor = subprocess.run(
            ["git", "-C", str(REPO), "merge-base", "--is-ancestor", floor, "HEAD"]
        )
        shallow = subprocess.run(
            ["git", "-C", str(REPO), "rev-parse", "--is-shallow-repository"],
            capture_output=True,
            text=True,
        ).stdout.strip()
        if ancestor.returncode != 0 and shallow == "true":
            # GitHub's checkout is one commit deep: the floor can be there (a later fetch)
            # with the history between it and HEAD cut, so ancestry cannot be proved
            self.skipTest("a shallow checkout that cannot link the floor to HEAD")
        self.assertEqual(ancestor.returncode, 0)

    def test_the_docs_point_at_the_floor_in_the_code_and_repeat_no_commit(self):
        for doc in ("docs/dev/deploy-vercel.md", "docs/dev/status.md"):
            text = (REPO / doc).read_text()
            with self.subTest(doc=doc):
                self.assertIn("tool/promote_live.py", text)
                self.assertNotIn("e8f50b5", text)  # one place holds the floor: the code

    # ---- when the gate itself is broken ----

    def test_a_person_can_skip_the_waits_and_it_says_so_loudly(self):
        self.run_it()
        head = self.merge({"backend/apps/a.py": "2", "frontend/lib/a.dart": "2"})
        self.fake.runs = {}  # GitHub lists nothing: the gate would wait for ever
        self.fake.serving = lambda calls: ""
        code, said = self.attempt("--skip-waits")
        self.assertEqual(code, 0, said)
        self.assertEqual(self.live(), {"server": head, "app": head})
        self.assertIn("WARNING", said)

    def test_the_decision_alone(self):
        v = self.promote.verdict
        h, o = "a" * 40, "b" * 40
        self.assertTrue(v("server", "", h, "new", [], True).move)
        self.assertTrue(v("server", o, h, "ahead", ["backend/x.py"], True).move)
        self.assertFalse(v("server", o, h, "ahead", [], True).move)
        self.assertFalse(v("server", h, h, "same", [], True).move)
        self.assertFalse(v("app", o, h, "behind", [], True).move)
        for rel, floor_ok in (("diverged", True), ("ahead", False), ("same", False)):
            with self.subTest(rel=rel, floor_ok=floor_ok):
                with self.assertRaises(self.promote.Refused):
                    v("server", o, h, rel, ["backend/x.py"], floor_ok)

    def test_every_refusal_says_what_fixes_it(self):
        text = SCRIPT.read_text()
        refusals = re.findall(r"raise Refused\(\s*(.*?)\)\n", text, re.S)
        self.assertGreaterEqual(len(refusals), 8)
        for r in refusals:
            with self.subTest(refusal=r[:60]):
                self.assertRegex(
                    r,
                    r"(?i)fix|run |pass |look|find out|roll forward|tries again|needs",
                )


if __name__ == "__main__":
    unittest.main()
