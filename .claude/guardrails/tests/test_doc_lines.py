"""tool/doc_lines.py: long lines of the notes are reflowed without changing a word.

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
import re
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]


def load():
    spec = importlib.util.spec_from_file_location("doc_lines", REPO / "tool" / "doc_lines.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def words(text: str) -> str:
    """The text as Markdown reads it across line breaks: quote marks at a line's
    start dropped, whitespace collapsed."""
    lines = [re.sub(r"^(\s*>\s?)+", "", line) for line in text.split("\n")]
    return re.sub(r"\s+", " ", " ".join(lines)).strip()


SENTENCE = "The board never scrolls (`ScreenFrame(fitsHeight: true)`) and is laid out by `BoardLayout.solve`. "
LONG = SENTENCE * 8


class Reflow(unittest.TestCase):
    def setUp(self):
        self.tool = load()

    def test_every_tracked_note_keeps_every_word_in_order(self):
        for path in self.tool.tracked():
            before = (REPO / path).read_text()
            after = self.tool.reflowed(before)
            self.assertEqual(words(before), words(after), path)

    def test_a_long_paragraph_is_one_sentence_to_a_line(self):
        after = self.tool.reflowed(LONG.strip())
        lines = after.split("\n")
        self.assertEqual(len(lines), 8)
        self.assertTrue(all(line.endswith(".") for line in lines))
        self.assertLessEqual(max(map(len, lines)), self.tool.LIMIT)

    def test_a_list_item_goes_on_under_its_own_text(self):
        after = self.tool.reflowed("- **The night board**: " + LONG.strip())
        lines = after.split("\n")
        self.assertTrue(lines[0].startswith("- **The night board**: "))
        self.assertTrue(all(line.startswith("  ") and not line.startswith("   ") for line in lines[1:]))

    def test_a_quote_stays_a_quote_on_every_line(self):
        after = self.tool.reflowed("> " + LONG.strip())
        self.assertTrue(all(line.startswith("> ") for line in after.split("\n")))

    def test_tables_code_headings_and_short_lines_are_left_alone(self):
        text = "\n".join(
            [
                "# " + "A heading " * 40,
                "| a | " + "cell " * 80 + "|",
                "```",
                "x = '" + "long " * 80 + "'",
                "```",
                "A short line. Another sentence.",
            ]
        )
        self.assertEqual(self.tool.reflowed(text), text)

    def test_a_break_never_falls_inside_a_code_span_a_link_or_brackets(self):
        span = "`" + "a b " * 30 + "`"
        link = "[" + "some words " * 12 + "](docs/a file.md)"
        after = self.tool.reflowed(f"{LONG}{span} then {link} and ({'in brackets ' * 20}).")
        self.assertIn(span, after)
        self.assertIn(link, after)
        self.assertIn("(" + "in brackets " * 20 + ")", after)

    def test_no_new_line_starts_a_list_a_heading_or_a_quote(self):
        text = LONG + "then - not a list item. " + "1. not a numbered one either. " + "# not a heading. " + LONG
        after = self.tool.reflowed(text.strip())
        for line in after.split("\n")[1:]:
            self.assertIsNone(self.tool.STARTS.match(line), line)

    def test_reflowing_twice_changes_nothing_more(self):
        once = self.tool.reflowed("- " + LONG.strip())
        self.assertEqual(self.tool.reflowed(once), once)

    def test_a_long_line_is_found_and_one_that_cannot_be_broken_is_not(self):
        self.assertEqual(self.tool.long_lines(LONG.strip()), [(1, len(LONG.strip()))])
        url = "https://example.org/" + "a" * 300
        self.assertEqual(self.tool.long_lines(url), [])


if __name__ == "__main__":
    unittest.main()
