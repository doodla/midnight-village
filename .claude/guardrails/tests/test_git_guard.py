# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""The Bash guard on git (.claude/hooks/git_guard.py): what it blocks and what it lets through.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from pathlib import Path

HOOKS = Path(__file__).resolve().parents[2] / "hooks"
sys.path.insert(0, str(HOOKS))

import git_guard  # noqa: E402

HEREDOC_MESSAGE = """git commit -q -F - <<'EOF'
docs(hooks): why the guard exists

Never run git commit --no-verify or git commit -n, and do not set
GIT_DIR=/tmp/x or core.hooksPath=/dev/null. $(git commit -n) `git rebase main`
EOF"""

# The usual ways a commit message is passed, with the things messages contain: quotes,
# an apostrophe, a numbered list, backticks, the very words the guard looks for.
MESSAGE = """fix(ui): the 6" layout; don't break it

a) one; b) `git rebase main` is refused; c) $(git commit -n) too
git commit --no-verify is refused now. GIT_DIR=/tmp/x SKIP=1 core.hooksPath=/dev/null
"""
MESSAGE_FORMS = [
    "git add . && git commit -F - <<'EOF'\n" + MESSAGE + "EOF",
    "git add -A\ngit commit -q -F - <<'EOF'\n" + MESSAGE + "EOF",
    "git commit -m \"$(cat <<'EOF'\n" + MESSAGE + "EOF\n)\"",
    "cd backend && git commit -am \"$(cat <<'EOF'\n" + MESSAGE + "EOF\n)\" && git status",
    "cat > /tmp/msg.txt <<'EOF'\n" + MESSAGE + "EOF\ngit commit -F /tmp/msg.txt",
    "bash x.sh && cat > docs/a.md <<'EOF'\n" + MESSAGE + "EOF",
    "python3 - <<'EOF'\nimport subprocess\nprint('git commit --no-verify')\nEOF\ngit status",
]

# Text that only mentions a skip: searched for, quoted, printed or commented. All go on.
ALLOWED = [
    *MESSAGE_FORMS,
    # found by the second review: blocked by mistake
    "bash <<'EOF'\ngit add -A\ngit commit -m \"fix: x\"\nEOF",
    "env PYTHONPATH=. pytest -k GIT_DIR && git status",
    "env -u GIT_DIR git status",
    "env SKIP=1 pytest; git status",
    "export GATE_BLOCK_TIMEOUT=5; git status",
    'git -C "$root" config core.hooksPath "$want"',
    'git config core.hooksPath "$(cat .hookspath)"',
    "git rebase --abort",
    "git am --abort",
    'git commit -m "docs: x"',
    'git commit -m "$MSG"',
    "git commit -m x -a",
    'git -C backend --no-pager commit -am "fix: y"',
    'git commit -m "no n flag here"',
    "git commit -m 'never use --no-verify'",
    "git commit -m 'docs: explain `git commit -n` and $(git rebase main)'",
    'git commit -m "docs: GIT_DIR=x and SKIP=1 are refused"',
    "git commit -m -n",
    HEREDOC_MESSAGE,
    "grep -rn -- --no-verify .claude",
    "grep -rn 'GIT_DIR=' .",
    'rg "git commit -n" docs',
    'echo "git commit --no-verify"',
    "echo git commit -n",
    "# git commit -n -m x\ngit status",
    "git status # then git commit -n",
    "SKIP=slow pytest tests",
    "HUSKY=0 npm test",
    "cat > notes.txt <<'EOF'\ngit commit -n -m x\nGIT_DIR=/tmp/x git status\nEOF",
    "git log --grep=--no-verify",
    "git log -n 5",
    "git merge -n main --ff-only",
    "git push --no-verify origin x",  # there is no pre-push hook to skip
    "git config --get core.hooksPath",
    "git config core.hooksPath",
    "git config core.hooksPath .claude/hooks/git",
    "git config user.name x",
    "git -c core.hooksPath=.claude/hooks/git commit -m x",
    "git -c user.name=x -c color.ui=never commit -m x",
    "GIT_PAGER=cat git log",
    "GIT_INDEX_FILE=/tmp/i git add -A && GIT_INDEX_FILE=/tmp/i git write-tree",
    "GIT_TERMINAL_PROMPT=0 GIT_AUTHOR_NAME=x git commit -m x",
    "git cherry-pick --no-commit abc123",
    "git revert --abort",
    "git rebase --abort",
    "git diff -- docs/git_guard.md",
    "bash -c 'git status && git log -n 3'",
    "bash scripts/run.sh",
    "ls .git && cat .gitignore",
    # found by the review of the first version: these were blocked and must not be
    "SKIP=slow pytest tests && git status",
    "HUSKY=0 npm test; git log -n 3",
    "GATE_BLOCK_TIMEOUT=5 .claude/hooks/test_gate_routing.sh && git status",
    "git commit -uno -m x",
    "git commit -m x -uno",
    "git config --get-regexp core.hooksPath .claude",
    "git config --get-all core.hooksPath",
    "git config --list",
    "git -c core.hooksPath=./.claude/hooks/git commit -m x",
    "git config core.hooksPath ./.claude/hooks/git",
    "git commit -m $'line one\\nline two'",
    "git commit -m $'never --no-verify'",
    'echo "<<EOF" && git status',
    "echo $((1<<4)) && git status",
    "curl -fsSL https://example.com/install.sh | bash",
    "echo 'ls -la' | bash",
    "git commit -s -m x",
    "git merge -s ours main --ff-only",
    "git stash && git stash pop",
    "git worktree add ../wt main",
    "function deploy { echo hi; }; deploy",
    "find . -name '*.py' -exec grep -l git {} +",
    "trap 'rm -f /tmp/x' EXIT; git status",
]

# Real attempts to commit past the gate, however they are wrapped. All are blocked.
BLOCKED = [
    # found by the second review: a quote in the message hid the flag after it
    "git commit -m \"$(cat <<'EOF'\nfix(ui): the 6\" layout\nEOF\n)\" --no-verify",
    "git commit -m \"$(cat <<'EOF'\nfix: \"don't\" break\nEOF\n)\" -n",
    "git commit -n -m \"$(cat <<'EOF'\n" + MESSAGE + "EOF\n)\"",
    "git add . && git commit --no-verify -F - <<'EOF'\n" + MESSAGE + "EOF",
    'bash <<<"git commit -n -m x"',
    "env SKIP=1 git commit -m x",
    "export HUSKY=0; git status; git commit -m x",
    "git rebase --continue",
    "git commit --no-verify -m x",
    "git commit --no-veri -m x",
    "git commit -m x --no-verif",
    "git commit -n -m x",
    "git commit -anm x",
    "git commit -m x -n",
    "git merge --no-verify main",
    "git pull --no-verify",
    "cd backend && git commit -n -m x",
    "git add -A; git commit -n -m x",
    "git status\ngit commit -n -m x",
    "git commit \\\n  -n -m x",
    "# a comment; then\ngit commit -n -m x",
    "bash -c 'git commit -n -m x'",
    'bash -c "git commit --no-verify -m x"',
    "bash -lc 'cd x && git commit -n -m y'",
    "sh -c \"bash -c 'git commit -n -m x'\"",
    "eval 'git commit -n -m x'",
    'eval "git commit" -n -m x',
    "echo $(git commit -n -m x)",
    'echo "$(git commit -n -m x)"',
    "echo `git commit -n -m x`",
    "x=$(git commit --no-verify -m x)",
    "(git commit -n -m x)",
    "{ git commit -n -m x; }",
    "if true; then git commit -n -m x; fi",
    "env git commit -n -m x",
    "env -i PATH=$PATH git commit -n -m x",
    "command git commit -n -m x",
    "sudo -u x git commit -n -m x",
    "timeout 60 git commit -n -m x",
    "nohup git commit -n -m x &",
    "echo msg | xargs git commit -n -m",
    "/usr/bin/git commit -n -m x",
    "bash <<'EOF'\ngit commit -n -m x\nEOF",
    "bash -s <<EOF\ngit commit --no-verify -m x\nEOF",
    "cat <<EOF\n$(git commit -n -m x)\nEOF",
    "git -c core.hooksPath=/dev/null commit -m x",
    "git -c core.hooksPath= commit -m x",
    "git -c core.hookspath=/tmp/h commit -m x",
    "git -ccore.hooksPath=/dev/null commit -m x",
    "git -c alias.ci='commit -n' ci -m x",
    "git -c include.path=/tmp/evil commit -m x",
    "git --config-env=core.hooksPath=NOHOOKS commit -m x",
    "git --exec-path=/tmp/fake commit -m x",
    "git config core.hooksPath /tmp/none",
    "git config core.hooksPath ''",
    "git config --unset core.hooksPath",
    "git config unset core.hooksPath",
    "git config set core.hooksPath /tmp/none",
    "git config --local core.hooksPath /dev/null",
    "git config --remove-section core",
    "git config alias.ci 'commit -n'",
    "git config --global include.path /tmp/evil",
    "GIT_COMMON_DIR=/tmp/other git commit -m x",
    "GIT_DIR=/tmp/other git commit -m x",
    "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/dev/null git commit -m x",
    "export GIT_CONFIG_GLOBAL=/tmp/cfg; git commit -m x",
    "env GIT_WORK_TREE=/tmp/x git status",
    "HUSKY=0 git commit -m x",
    "SKIP=all git commit -m x",
    "GATE_BLOCK_TIMEOUT=0 git commit -m x",
    "export SKIP=1 && git commit -m x",
    "git cherry-pick abc123",
    "git revert abc123",
    "git rebase main",
    "git am patch.mbox",
    "bash -c 'git rebase main'",
    # found by the review of the first version: these got through and must not
    "bash -cx 'git commit -n -m x'",
    "bash -o errexit -c 'git commit -n -m x'",
    "bash --norc -ec 'git commit --no-verify -m x'",
    "echo 'git commit -n -m x' | bash",
    "bash <<< 'git commit -n -m x'",
    "cat <<'EOF' | bash\ngit commit -n -m x\nEOF",
    "source /dev/stdin <<EOF\ngit commit -n -m x\nEOF",
    "bash < <(echo git commit -n -m x)",
    "git commit $'-n' -m x",
    "git commit $'--no-verify' -m x",
    "bash -c $'git commit -n -m x'",
    "echo $'\\'' ; git commit -n -m x # '",
    'echo "<<EOF"\ngit commit -n -m x',
    "cat <<END-OF-DOC\nwords\nEND-OF-DOC\ngit commit -n -m x",
    "echo $((1<<n))\ngit commit -n -m x",
    'echo "$(echo ")"; git commit -n -m x)"',
    'echo "$((git commit -n -m x) )"',
    "git commit -s -n -m x",
    "git commit -uno -n -m x",
    "git merge -S --no-verify main",
    "git pull -t --no-verify",
    "function f { git commit -n -m x; }; f",
    "f() { git commit -n -m x; }; f",
    "coproc git commit -n -m x",
    "trap 'git commit -n -m x' EXIT",
    "find . -maxdepth 0 -exec git commit -n -m x \\;",
    "setsid git commit -n -m x",
    "flock /tmp/l git commit -n -m x",
    "G=git; $G commit -n -m x",
    "read -r GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 <<< '1 core.hooksPath /dev/null'; "
    "export GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0; git commit -m x",
    "git update-ref HEAD $(git commit-tree $(git write-tree) -p HEAD -m x)",
    "GIT_EDITOR='sed -i /hooksPath/d' git config --edit; git commit -m x",
    "git config -e",
]


class GitGuard(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.repo = cls.tmp.name
        subprocess.run(["git", "init", "-q", cls.repo], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def problems(self, command):
        return git_guard.problems_with(command, self.repo)[0]

    def test_text_that_only_mentions_a_skip_goes_on(self):
        for command in ALLOWED:
            with self.subTest(command=command):
                self.assertEqual(self.problems(command), [])

    def test_a_real_skip_is_blocked_however_it_is_wrapped(self):
        for command in BLOCKED:
            with self.subTest(command=command):
                self.assertTrue(self.problems(command), "not blocked")

    def test_every_reason_says_what_to_do(self):
        for command in BLOCKED:
            for reason in self.problems(command):
                with self.subTest(command=command):
                    self.assertRegex(reason, r"instead|drop|must|use|run")

    def test_an_alias_in_the_clone_is_read_as_what_it_runs(self):
        with tempfile.TemporaryDirectory() as repo:
            subprocess.run(["git", "init", "-q", repo], check=True)
            for name, value in (("ci", "commit -n"), ("sh", "!git commit --no-verify"), ("st", "status -sb")):
                subprocess.run(["git", "-C", repo, "config", f"alias.{name}", value], check=True)
            self.assertTrue(git_guard.problems_with("git ci -m x", repo)[0])
            self.assertTrue(git_guard.problems_with("git sh -m x", repo)[0])
            self.assertEqual(git_guard.problems_with("git st", repo), ([], False))

    def test_it_knows_which_commands_commit(self):
        for command, commits in (
            ('git commit -m "docs: x"', True),
            ("cd x && git merge main", True),
            ("bash -c 'git pull'", True),
            ("git merge --ff-only main", False),
            ("git status", False),
            ("echo git commit", False),
        ):
            with self.subTest(command=command):
                self.assertEqual(git_guard.problems_with(command, self.repo)[1], commits)

    def test_a_commit_that_names_the_hooks_itself_needs_no_config(self):
        named = "git -c core.hooksPath=.claude/hooks/git commit -m x"
        self.assertEqual(git_guard.problems_with(named, self.repo), ([], False))
        # a comment that merely contains the words does not count
        commented = "git commit -m x # -c core.hooksPath=.claude/hooks/git"
        self.assertEqual(git_guard.problems_with(commented, self.repo), ([], True))
        both = named + " && git commit -m y"
        self.assertEqual(git_guard.problems_with(both, self.repo), ([], True))

    def test_the_file_says_what_it_is_not(self):
        doc = git_guard.__doc__
        self.assertIn("It is not a wall", doc)
        self.assertIn("The wall is GitHub", doc)

    def test_the_repos_own_git_lines_all_go_on(self):
        """Every line that names git in the recipes, the workflows and the scripts an
        agent runs: none is blocked. (test_gate_routing.sh is left out: its lines are
        the guard's own bad examples.)"""
        root = Path(__file__).resolve().parents[3]
        files = [root / "justfile", root / "backend" / "justfile", root / "frontend" / "justfile"]
        files += sorted((root / ".github" / "workflows").glob("*.yml"))
        files += sorted((root / "tool").glob("*.sh")) + sorted((root / "frontend" / "tool").glob("*.sh"))
        files += sorted((root / ".claude" / "hooks" / "git").iterdir())
        files += [p for p in sorted((root / ".claude" / "hooks").glob("*.sh")) if p.name != "test_gate_routing.sh"]
        files.append(root / ".claude" / "hooks" / "lib" / "gate.sh")
        lines = 0
        for path in files:
            for line in path.read_text().splitlines():
                line = line.strip().removeprefix("- run:").removeprefix("run:").strip()
                if "git" not in line or line.startswith("#"):
                    continue
                lines += 1
                with self.subTest(file=path.name, line=line):
                    self.assertEqual(self.problems(line), [])
        self.assertGreater(lines, 20)

    def test_odd_input_never_raises(self):
        import random

        rng = random.Random(7)
        pieces = ["git", "commit", "-n", "'", '"', "\\", "$(", ")", "`", "<<", "<<<", "EOF", "\n"]
        pieces += ["$'", ";", "&&", "|", "(", "{", "}", " ", "bash", "-c", "#", "=", "\x00", "é"]
        for _ in range(600):
            command = "".join(rng.choice(pieces) for _ in range(rng.randint(1, 40)))
            with self.subTest(command=command):
                git_guard.problems_with(command, self.repo)

    def test_big_input_costs_work_in_step_with_its_size(self):
        """No clock here (a loaded machine is slow, not wrong): the two places that once
        did the same work again for every word are counted instead."""
        # one owner lookup per command, however many `<<` it carries (it was one per `<<`)
        with mock.patch.object(git_guard, "first_word", wraps=git_guard.first_word) as owner:
            git_guard.problems_with("git status <<A " * 5000, self.repo)
        self.assertLessEqual(owner.call_count, 2)
        # git's own commands are never looked up as aliases, and another name only once
        with mock.patch.object(git_guard, "read_alias", wraps=git_guard.read_alias) as alias:
            git_guard.problems_with("git status; " * 2000 + "git st; " * 2000, self.repo)
        self.assertEqual([c.args[1] for c in alias.call_args_list], ["st"])
        # a here-document's body is dropped before words are split: none of it is lexed
        body = "git commit -n\n" * 60000
        with mock.patch.object(git_guard, "simple_commands", wraps=git_guard.simple_commands) as lexed:
            problems = git_guard.problems_with(f"cat > f <<'EOF'\n{body}EOF\ngit status", self.repo)
        self.assertEqual(problems, ([], False))
        self.assertLess(sum(len(c.args[0]) for c in lexed.call_args_list), 100)

    def test_an_open_quote_is_still_read(self):
        self.assertTrue(self.problems("git commit -n -m 'unfinished"))

    def test_shells_nested_too_deeply_are_blocked(self):
        command = "git commit -n"
        for _ in range(git_guard.MAX_DEPTH + 2):
            command = "eval " + git_guard.shlex.quote(command)
        self.assertTrue(self.problems(command))


if __name__ == "__main__":
    unittest.main()
