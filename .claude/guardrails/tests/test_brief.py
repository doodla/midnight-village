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

    def test_a_state_says_what_its_fixture_did(self):
        widgets = {
            "06-night-board": ["NightBoard", "FaceDownCard"],
            "06-night-board-follow-up": ["NightBoard", "FaceDownCard", "HeldFace", "RoleHead", "_Words"],
            "06-night-board-x1.6": ["NightBoard", "FaceDownCard"],
            "03b-role-sheet": ["SheetScaffold"],
        }
        kit = {"NightBoard", "FaceDownCard", "HeldFace", "RoleHead", "SheetScaffold"}
        line = lambda s: self.tool.state_line(s, sorted(widgets), widgets, kit)  # noqa: E731
        self.assertEqual(line("06-night-board"), "06-night-board")
        held = line("06-night-board-follow-up")
        self.assertIn("HELD", held)
        self.assertIn("beyond 06-night-board: HeldFace, RoleHead", held)
        self.assertNotIn("_Words", held)
        self.assertIn("text x1.6", line("06-night-board-x1.6"))
        self.assertIn("SHEET", line("03b-role-sheet"))

    def test_a_parked_fault_is_printed_whole_with_the_constant_it_names(self):
        parked = (
            "const _over =\n    'its story lies over Ready '\n    '(a long story)';\n\n"
            "const notYetSwept = <String, String>{\n"
            "  '06-night-board-follow-up':\n      \"the copied role's card lies over the names \"\n"
            "      'while it asks for a pick',\n"
            "  '08-talk-held-tanner': _over,\n};\n"
        )
        (whole,) = self.tool.parked_faults(parked, ["06-night-board-follow-up"])
        self.assertIn("while it asks for a pick", whole)
        (named,) = self.tool.parked_faults(parked, ["08-talk-held-tanner"])
        self.assertIn("its story lies over Ready", named)
        self.assertIn("(a long story)", named)

    def test_a_rule_about_a_part_is_found_by_its_words_with_the_list_under_it(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            self.tool.ROOT = Path(tmp)
            doc = Path(tmp) / "spec.md"
            doc.write_text(
                "## 2. Cues\n\n**The held-face frame** is the same on every face:\n"
                "- Always the same fixed size.\n- Drawn above the touch point, never under the thumb.\n\n"
                "Nothing about it here.\n"
            )
            ((where, text),) = self.tool.part_rules("HeldFace", [doc])
        self.assertEqual(where, "spec.md:3")
        self.assertIn("Drawn above the touch point, never under the thumb.", text)

    def test_the_real_spec_has_a_section_for_every_screen_a_state_belongs_to(self):
        sections = self.tool.spec_sections((REPO / self.tool.SPEC).read_text())
        for number in ("01", "02", "03", "04", "05", "06", "07", "08", "09", "10"):
            self.assertIn(number, sections, f"no per-screen section for {number}")


class Quoted(unittest.TestCase):
    """A line that names a screen is quoted with the paragraph or list item it
    sits in: the sentence after it is often the rule."""

    def setUp(self):
        self.tool = load()

    def test_the_sentence_after_the_one_that_names_the_screen_comes_with_it(self):
        feedback = "## 23 November\n\n- The names are too small on 09.\n  A name must never be cut.\n- Something about 04.\n"
        said = self.tool.said_by_owner(feedback, ["09"], [])
        self.assertEqual(
            [line for _, _, line in said],
            ["- The names are too small on 09. A name must never be cut."],
        )

    def test_a_block_is_quoted_once_however_many_of_its_lines_match(self):
        feedback = "## A day\n\nOn 09 the bar is thin.\nAlso on 09 the seal is late.\n"
        said = self.tool.said_by_owner(feedback, ["09"], [])
        self.assertEqual(len(said), 1)
        self.assertIn("the seal is late", said[0][2])

    def test_a_long_block_is_cut_around_the_line_and_says_so(self):
        lines = ["- The board (06) opens the list."] + [f"  Sentence {n}." for n in range(1, 12)]
        lines[6] = "  On 09 the slip lifts."
        text, last = self.tool.quoted(lines, 6)
        self.assertTrue(text.startswith("[...] Sentence 5."), text)
        self.assertIn("On 09 the slip lifts. Sentence 7. Sentence 8.", text)
        self.assertTrue(text.endswith("[...]"), text)
        self.assertEqual(last, 8)

    def test_a_list_item_stops_at_the_next_item_and_a_paragraph_at_a_blank_line(self):
        lines = ["- one about 09.", "  its rule.", "- another item.", "", "A paragraph."]
        self.assertEqual(self.tool.quoted(lines, 0)[0], "- one about 09. its rule.")
        self.assertEqual(self.tool.quoted(lines, 4)[0], "A paragraph.")


class Areas(unittest.TestCase):
    """`just brief <area>`: every row of the table still points at something."""

    def setUp(self):
        self.areas = load().tool("brief_areas")

    def test_every_glob_of_every_area_matches_a_file(self):
        for name, area in self.areas.AREAS.items():
            for pattern in [*area["files"], *area["tests"]]:
                self.assertTrue(
                    self.areas.files_of([pattern]),
                    f"{name}: nothing matches {pattern} any more",
                )

    def test_every_rule_is_still_where_the_row_says(self):
        for name, area in self.areas.AREAS.items():
            for document, kind, start in area["rules"]:
                self.assertIsNotNone(
                    self.areas.rule_text(document, kind, start),
                    f"{name}: {document} has no {kind} starting '{start}'",
                )

    def test_every_model_folder_is_there(self):
        for name, area in self.areas.AREAS.items():
            if area["model"]:
                self.assertTrue((REPO / area["model"]).is_dir(), name)

    def test_a_bullet_is_printed_whole_and_a_section_stops_at_the_next(self):
        line, bullet = self.areas.rule_text("frontend/CLAUDE.md", "bullet", "No waits.")
        self.assertIn("never", bullet)
        self.assertEqual(bullet.count("- **"), 1)
        _, section = self.areas.rule_text(
            "backend/CLAUDE.md", "section", "Deploy-safe changes"
        )
        self.assertEqual(sum(l.startswith("## ") for l in section.splitlines()), 1)

    def test_a_brief_names_files_tests_and_who_else(self):
        text = self.areas.brief("copy", lambda files: {"someone": sorted(files)[:1]})
        for part in ("## The rules that bite here", "## Files", "## Tests", "someone:"):
            self.assertIn(part, text)

    def test_a_long_list_is_a_line_a_folder(self):
        paths = [f"a/b/f{i}.py" for i in range(60)]
        self.assertEqual(self.areas.listed(paths, lambda p: p), "   60 files  a/b/")


if __name__ == "__main__":
    unittest.main()
