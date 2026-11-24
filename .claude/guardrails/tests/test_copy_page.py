# Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
"""The copy page and the spec check (tool/copy_page.py).

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SCRIPT = REPO / "tool" / "copy_page.py"

COPY = """/// Words shared by several screens.
abstract final class CommonCopy {
  /// The cue's one word.
  static const hold = 'Hold';

  /// How many are ready.
  static const progress = Template('{d} of {n} ready');
  static const long =
      'A line that runs on; '
      "and it's in two pieces";
  static const again = TalkCopy.ready;
  static String named(String who) => 'Hello $who';
}

/// 08 Talk.
abstract final class TalkCopy {
  static const ready = 'Ready to vote';
}
"""


def load(root: Path):
    spec = importlib.util.spec_from_file_location("copy_page", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    module.ROOT = root
    module.COPY = root / "frontend" / "lib" / "design_system" / "copy"
    module.SPECS = root / "docs" / "specs" / "frontend"
    return module


class CopyPage(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.tool = load(self.root)
        self.tool.COPY.mkdir(parents=True)
        self.tool.SPECS.mkdir(parents=True)
        (self.tool.COPY / "copy.dart").write_text(COPY)

    def tearDown(self):
        self.tmp.cleanup()

    def spec(self, text: str) -> list[str]:
        (self.tool.SPECS / "play.md").write_text(text)
        return self.tool.check_spec(self.tool.all_copy())

    def test_the_page_has_every_key_with_its_words(self):
        page = self.tool.page(self.tool.all_copy())
        self.assertIn("| `CommonCopy.hold` | “Hold” | The cue's one word. |", page)
        self.assertIn("“{d} of {n} ready” e.g. “2 of 5 ready”", page)
        self.assertIn("“A line that runs on; ” · “and it's in two pieces”", page)
        self.assertIn("| `CommonCopy.again` | same as `TalkCopy.ready` |", page)
        self.assertIn("| `CommonCopy.named` | (put together in code) |", page)
        self.assertIn("## TalkCopy\n\n08 Talk.", page)

    def test_a_spec_that_names_what_exists_passes(self):
        self.assertEqual(
            self.spec("08 uses `TalkCopy` and its button is `TalkCopy.ready`.\n"), []
        )

    def test_a_key_that_is_gone_fails_with_the_line_that_names_it(self):
        problems = self.spec("First line.\nThe button is `TalkCopy.readyToVote`.\n")
        self.assertEqual(len(problems), 1)
        self.assertIn("play.md:2", problems[0])
        self.assertIn("`TalkCopy.readyToVote`", problems[0])

    def test_a_class_that_is_gone_fails(self):
        problems = self.spec("See `VoteCopy`.\n")
        self.assertIn("`VoteCopy`, which is not a copy class", problems[0])

    def test_words_in_quotes_and_other_backticks_are_nobodys_business(self):
        self.assertEqual(
            self.spec(
                'The button says "Ready to vote" (`PrimaryButton`, `just screens`).\n'
            ),
            [],
        )

    def play(self, section_three: str) -> list[str]:
        (self.tool.SPECS / "first-time-play.md").write_text(
            '## 2. Cues\n\nThe cue says "Hold".\n\n## 3. Screens\n\n'
            + section_three
            + '\n## 4. Server\n\nIt says "Hold" too.\n'
        )
        return self.tool.check_quotes(self.tool.all_copy())

    def test_a_quote_of_a_keys_words_in_section_three_fails_with_the_key(self):
        problems = self.play('Line 5\nThe button says "Ready to vote".\n')
        self.assertEqual(len(problems), 1)
        self.assertIn("first-time-play.md:8", problems[0])
        self.assertIn("name `TalkCopy.ready` instead", problems[0])

    def test_a_key_filled_in_is_still_its_words(self):
        self.assertIn("`CommonCopy.progress`", self.play('Pips "2 of 5 ready".\n')[0])
        self.assertIn(
            "`CommonCopy.progress`",
            self.play("Pips \u201c{d} of {n} ready\u201d.\n")[0],
        )

    def test_the_exact_key_wins_over_a_template_it_also_fits(self):
        self.assertIn("`CommonCopy.hold`", self.play('Say "Hold".\n')[0])

    def test_section_three_naming_keys_or_quoting_other_words_passes(self):
        self.assertEqual(
            self.play(
                'The button is `TalkCopy.ready`; the owner said "make it quieter".\n'
            ),
            [],
        )

    def test_words_outside_section_three_are_not_checked(self):
        self.assertEqual(self.play("No quotes here.\n"), [])

    def test_a_template_with_no_words_of_its_own_matches_only_itself(self):
        # "{name}." must not make every sentence of one word a quote of it
        self.assertEqual(self.play('Say "Hello." and "Cleo."\n'), [])

    def test_check_spec_command_runs_both_checks(self):
        (self.tool.SPECS / "first-time-play.md").write_text(
            '## 3. Screens\n\nSay "Hold", see `TalkCopy.gone`.\n'
        )
        problems = self.tool.check_spec(self.tool.all_copy())
        problems += self.tool.check_quotes(self.tool.all_copy())
        self.assertEqual(len(problems), 2)

    def test_this_repos_copy_is_read_and_its_specs_name_only_what_exists(self):
        real = load(REPO)
        classes = real.all_copy()
        names = {c["name"] for c in classes}
        self.assertTrue({"CommonCopy", "JoinCopy", "TalkCopy"} <= names)
        self.assertEqual(real.check_spec(classes), [])
        self.assertEqual(real.check_quotes(classes), [])


if __name__ == "__main__":
    unittest.main()
