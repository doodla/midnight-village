"""A pull request that adds words a player reads says so (tool/words_added.py).

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]


def load():
    spec = importlib.util.spec_from_file_location("words_added", REPO / "tool" / "words_added.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class WordsAdded(unittest.TestCase):
    def setUp(self):
        self.tool = load()

    def test_a_word_is_a_piece_with_a_letter_and_a_gap_is_not(self):
        count = self.tool.count
        self.assertEqual(count("Ready to vote"), 3)
        self.assertEqual(count("{d} of {n} locked"), 2)
        self.assertEqual(count("14 s"), 1)
        self.assertEqual(count("{name}"), 0)
        self.assertEqual(count("Ready ✓"), 1)
        self.assertEqual(count(""), 0)

    def test_a_class_with_more_words_is_named_with_the_keys_that_grew(self):
        was = {"TalkCopy": {"ready": "Ready", "headline": "The village wakes"}}
        now = {"TalkCopy": {"ready": "Ready to vote", "headline": "The village wakes"}}
        (item,) = self.tool.grown(was, now)
        self.assertEqual((item["name"], item["added"]), ("TalkCopy", 2))
        self.assertEqual(item["keys"], [("ready", "Ready", "Ready to vote")])

    def test_fewer_words_or_the_same_number_needs_nothing(self):
        was = {"TalkCopy": {"ready": "Ready to vote", "wait": "One moment"}}
        self.assertEqual(self.tool.grown(was, {"TalkCopy": {"ready": "Ready", "wait": "One moment"}}), [])
        # a line reworded to the same length, and words moved between two keys
        self.assertEqual(self.tool.grown(was, {"TalkCopy": {"ready": "Vote when ready", "wait": "One moment"}}), [])
        self.assertEqual(self.tool.grown(was, {"TalkCopy": {"ready": "Ready", "wait": "One moment to vote"}}), [])

    def test_a_new_class_and_a_new_key_count_as_added(self):
        (item,) = self.tool.grown({}, {"ScanCopy": {"close": "Close"}})
        self.assertEqual((item["name"], item["added"]), ("ScanCopy", 1))
        self.assertEqual(item["keys"], [("close", "", "Close")])

    def test_the_line_names_the_class_and_gives_a_reason(self):
        said = self.tool.explained
        self.assertTrue(said("TalkCopy", "## Words added\n- TalkCopy: the button says what it does now\n"))
        self.assertTrue(said("TalkCopy", "Words added\n- `TalkCopy`: the owner asked on 23 November\n"))
        self.assertFalse(said("TalkCopy", "Words added\n- TalkCopy: ok\n"))
        self.assertFalse(said("TalkCopy", "Words added\n- VoteCopy: the lock says its name now\n"))

    def test_the_copy_on_main_has_not_grown_against_itself(self):
        now = self.tool.by_class(self.tool.all_copy())
        self.assertEqual(self.tool.grown(now, now), [])
        self.assertGreater(len(now), 15, "the copy classes were found")


if __name__ == "__main__":
    unittest.main()
