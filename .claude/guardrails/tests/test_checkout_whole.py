"""A fresh checkout works as it stands, and gives the same answers as GitHub.

Three things have each stopped builders: a shell script with a syntax error that
nothing ran before it merged, a lint or type tool taken from PATH instead of
uv.lock (another version, other findings), and a worktree with no backend/.env.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import re
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
LOCKED_TOOLS = ("ruff", "pyrefly")


def tracked(*patterns: str) -> list[Path]:
    out = subprocess.run(
        ["git", "-C", str(REPO), "ls-files", "--cached", "--others",
         "--exclude-standard", "--", *patterns],
        capture_output=True, text=True, check=True,
    ).stdout
    return [REPO / line for line in out.splitlines() if (REPO / line).is_file()]


class ShellScripts(unittest.TestCase):
    def test_every_shell_script_parses(self):
        scripts = tracked("*.sh", ".claude/hooks/git/*")
        self.assertGreater(len(scripts), 5)
        for script in scripts:
            done = subprocess.run(
                ["bash", "-n", str(script)], capture_output=True, text=True
            )
            self.assertEqual(
                done.returncode, 0, f"{script.relative_to(REPO)}: {done.stderr}"
            )


class LockedTools(unittest.TestCase):
    """`uv run ruff` in a checkout whose venv has no ruff quietly runs the one on
    PATH. `uv run --group lint ruff` always runs the one in uv.lock."""

    def lines(self):
        files = [REPO / "justfile", REPO / "backend" / "justfile"]
        files += tracked(".claude/hooks/*.sh", ".claude/hooks/lib/*.sh",
                         ".claude/hooks/git/*", "tool/*.sh")
        for path in files:
            for number, line in enumerate(path.read_text().splitlines(), 1):
                if line.lstrip().startswith("#"):
                    continue
                yield path.relative_to(REPO), number, line

    def test_lint_and_type_tools_come_from_the_lock(self):
        seen = 0
        for path, number, line in self.lines():
            for tool in LOCKED_TOOLS:
                if re.search(rf"\buv run\b.*\b{tool}\b", line):
                    seen += 1
                    self.assertRegex(
                        line,
                        rf"\buv run --group lint {tool}\b",
                        f"{path}:{number}: write `uv run --group lint {tool}`",
                    )
                elif re.match(rf"\s*{tool}\s", line):
                    self.fail(f"{path}:{number}: `{tool}` from PATH; use `uv run --group lint {tool}`")
        self.assertGreaterEqual(seen, 5)


class EnsureEnv(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name) / "my-work tree"
        (self.root / "tool").mkdir(parents=True)
        (self.root / "backend").mkdir()
        script = self.root / "tool" / "ensure_env.sh"
        script.write_text((REPO / "tool" / "ensure_env.sh").read_text())
        script.chmod(0o755)
        (self.root / "backend" / ".env.example").write_text(
            (REPO / "backend" / ".env.example").read_text()
        )
        self.env = self.root / "backend" / ".env"

    def tearDown(self):
        self.tmp.cleanup()

    def run_it(self, *args):
        return subprocess.run(
            [str(self.root / "tool" / "ensure_env.sh"), *args],
            capture_output=True, text=True,
        )

    def test_a_fresh_checkout_gets_an_env_named_after_its_folder(self):
        self.assertEqual(self.run_it().returncode, 0)
        text = self.env.read_text()
        self.assertIn("DB_NAME=mv_my_work_tree\n", text)
        self.assertIn("DB_USER=postgres\n", text)
        self.assertNotIn("DJANGO_SETTINGS_MODULE", text)

    def test_an_existing_env_is_left_alone(self):
        self.env.write_text("DB_NAME=mine\nDB_USER=me\n")
        self.assertEqual(self.run_it().returncode, 0)
        self.assertEqual(self.env.read_text(), "DB_NAME=mine\nDB_USER=me\n")

    def test_a_given_name_is_set_and_the_rest_kept(self):
        self.env.write_text("DB_NAME=old\nDB_USER=me\nDJANGO_SETTINGS_MODULE=x\n")
        self.assertEqual(self.run_it("mv_board").returncode, 0)
        self.assertEqual(self.env.read_text(), "DB_NAME=mv_board\nDB_USER=me\n")

    def test_names_a_test_run_could_not_use_are_refused(self):
        for bad in ("test_x", "a" * 41, "has-dash", "1abc"):
            done = self.run_it(bad)
            self.assertEqual(done.returncode, 2, bad)
            self.assertFalse(self.env.exists(), bad)


if __name__ == "__main__":
    unittest.main()
