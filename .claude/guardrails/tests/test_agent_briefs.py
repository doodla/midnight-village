"""The agent definitions send every builder and reviewer through the one entry.

A builder starts from `just brief` and ends with `just handover`; a reviewer starts
from the hand-over file and the brief, and a must-fix carries rerunnable evidence.
No definition types a number the code holds (a width, a phone count) or tells its
reader to open every picture: those went stale or cost the most context before.
The agents are read from .claude/agents/ (no list here): a new one joins by its
description ("Implements" or "review").

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import re
import unittest
from pathlib import Path

AGENTS = Path(__file__).resolve().parents[2] / "agents"
STALE = [
    (
        re.compile(r"\b\d{3}( wide|x\d{3}|, \d{3})"),
        "a screen size typed by hand (the code holds them)",
    ),
    (
        re.compile(r"\b(two|three|four|five) phones\b", re.I),
        "a phone count typed by hand",
    ),
    (
        re.compile(r"(look at|open) every (picture|before/after)", re.I),
        "every picture opened one by one",
    ),
    (
        re.compile(r"read the README of the part", re.I),
        "a README read whole instead of the brief",
    ),
]


def agents() -> dict[str, tuple[str, str]]:
    found = {}
    for path in sorted(AGENTS.glob("*.md")):
        text = path.read_text()
        description = re.search(r"^description: (.*)$", text, re.M)[1]
        found[path.name] = (description, text)
    return found


class TheOneEntry(unittest.TestCase):
    def test_a_builder_starts_from_its_brief_and_hands_over_with_handover(self):
        builders = [n for n, (d, _) in agents().items() if d.startswith("Implements")]
        self.assertTrue(builders)
        for name in builders:
            text = agents()[name][1]
            self.assertIn("just brief", text, f"{name}: no `just brief`")
            self.assertIn("just handover", text, f"{name}: no `just handover`")

    def test_a_reviewer_starts_from_the_hand_over_file_and_asks_for_evidence(self):
        reviewers = [n for n, (d, _) in agents().items() if "review of a" in d]
        self.assertTrue(reviewers)
        for name in reviewers:
            description, text = agents()[name]
            self.assertIn(
                "hand-over file", description, f"{name}: not given the hand-over file"
            )
            self.assertIn("just brief", text, f"{name}: no `just brief`")
            self.assertRegex(
                text,
                r"evidence a builder\s+can rerun",
                f"{name}: a must-fix needs rerunnable evidence",
            )

    def test_no_definition_types_what_the_code_holds_or_opens_every_picture(self):
        for name, (_, text) in agents().items():
            for pattern, why in STALE:
                found = pattern.search(text)
                self.assertIsNone(
                    found, f".claude/agents/{name}: '{found and found[0]}': {why}"
                )


if __name__ == "__main__":
    unittest.main()
