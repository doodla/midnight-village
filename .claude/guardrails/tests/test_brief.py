"""`just brief <screen>` (tool/brief.py): the facts come from the sources, word for word.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]

SPEC = """\
## 3. Screens

### Per-screen sheet

**08 Talk**
- **Copy:** "Ready to vote".

**09 Vote**
- **One thing:** pick a player.
- The voter's own row is never shown.

**10 and 11: the end board** (one screen)
- **Pass:** "Who won."

### Banners and errors

Not part of any screen.
"""

FEEDBACK = """\
# What the owner said

## 23 November 2026, a play-through (spoken, verbatim)

- "On 09 I could not tell my vote was locked."
- The talk timer felt long. 9 of us played.
- Took 09 November 2026 off the list.

## 21 November 2026, from the live lobby

- "Start the game" should not look dead.
"""


def load():
    spec = importlib.util.spec_from_file_location("brief", REPO / "tool" / "brief.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class FromTheSources(unittest.TestCase):
    def setUp(self):
        self.tool = load()
        self.sections = self.tool.spec_sections(SPEC)
        self.states = ["08-talk", "09-vote", "09-vote-locked", "12-end-village", "06-night-board", "c-buttons"]

    def test_a_screens_section_is_its_block_word_for_word_and_no_more(self):
        line, block = self.sections["09"]
        self.assertEqual(line, 8)
        self.assertEqual(
            block,
            "**09 Vote**\n- **One thing:** pick a player.\n- The voter's own row is never shown.",
        )

    def test_a_section_for_two_screens_is_found_under_both_and_stops_at_a_heading(self):
        self.assertEqual(self.sections["10"], self.sections["11"])
        self.assertNotIn("Banners", self.sections["11"][1])

    def test_a_screen_is_named_by_number_by_digit_or_by_a_word_of_its_states(self):
        which = lambda asked: self.tool.which_screens(asked, self.states, self.sections)  # noqa: E731
        self.assertEqual(which("09"), ["09"])
        self.assertEqual(which("9"), ["09"])
        self.assertEqual(which("vote"), ["09"])
        self.assertEqual(which("nothing-like-it"), [])

    def test_a_spec_name_finds_its_numbers_and_its_states_not_a_common_word(self):
        found = self.tool.which_screens("end-board", self.states, self.sections)
        self.assertEqual(found, ["10", "11", "12"])  # not 06, the night BOARD

    def test_the_owners_lines_about_a_screen_come_with_their_date(self):
        said = self.tool.said_by_owner(FEEDBACK, ["09"], [])
        self.assertEqual(
            [(under[:16], line) for under, _, line in said],
            [("23 November 2026", '- "On 09 I could not tell my vote was locked."')],
        )

    def test_a_date_or_a_count_is_not_a_screen_number(self):
        said = self.tool.said_by_owner(FEEDBACK, ["09"], [])
        self.assertFalse(any("off the list" in line for _, _, line in said))

    def test_a_screens_name_finds_lines_that_do_not_say_its_number(self):
        said = self.tool.said_by_owner(FEEDBACK, ["08"], ["Talk"])
        self.assertTrue(any("talk timer" in line for _, _, line in said))

    def test_the_real_spec_has_a_section_for_every_screen_a_state_belongs_to(self):
        sections = self.tool.spec_sections((REPO / self.tool.SPEC).read_text())
        for number in ("01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11"):
            self.assertIn(number, sections, f"no per-screen section for {number}")


if __name__ == "__main__":
    unittest.main()
