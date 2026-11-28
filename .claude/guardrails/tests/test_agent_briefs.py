"""The agent definitions send every builder and reviewer through the one entry.

A builder starts from `just brief` and ends with `just handover`; a reviewer starts
from the hand-over file and the brief, and a must-fix carries rerunnable evidence.
No definition types a number the code holds (a width, a phone count) or tells its
reader to open every picture: those went stale or cost the most context before.
A skill a definition names (`` `no-comments` skill``) is one of ours that its agent can
load: the agent lists `Skill` in its tools, and the skill is not hidden from the model.
The agents are read from .claude/agents/ (no list here): a new one joins by its
description ("Implements" or "review").

Run with: python3 -m unittest discover -s .claude/guardrails/tests
"""

import importlib.util
import re
import unittest
from pathlib import Path

AGENTS = Path(__file__).resolve().parents[2] / "agents"
SKILLS = AGENTS.parent / "skills"
NAMED_SKILL = re.compile(r"`([\w-]+)` skill")


def load_skills():
    spec = importlib.util.spec_from_file_location(
        "skills", AGENTS.parents[1] / "tool" / "skills.py"
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def skill_problems(definitions: dict[str, str], skills_dir: Path) -> list[str]:
    """Why a definition cannot load a skill it names: file:line, what, the fix."""
    rules = load_skills()
    problems = []
    for name, text in definitions.items():
        tools = re.search(r"^tools: (.*)$", text, re.M)
        listed = [t.strip() for t in tools[1].split(",")] if tools else []
        for n, line in enumerate(text.splitlines(), 1):
            for skill in NAMED_SKILL.findall(line):
                where = f".claude/agents/{name}:{n}: the `{skill}` skill"
                path = skills_dir / skill / "SKILL.md"
                if not path.is_file():
                    problems.append(
                        f"{where} is not there. Fix: name a skill in .claude/skills/"
                    )
                    continue
                body = path.read_text()
                if "Skill" not in listed:
                    problems.append(
                        f"{where} cannot be loaded. Fix: add Skill to its tools"
                    )
                if rules.third_party(body):
                    problems.append(
                        f"{where} is third-party. Fix: name one of our own skills"
                    )
                if not rules.invocable(body):
                    problems.append(
                        f"{where} is hidden from the model. Fix: drop"
                        " disable-model-invocation from its front matter"
                    )
    return problems


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


class SkillsTheyName(unittest.TestCase):
    def test_every_skill_a_definition_names_is_ours_and_it_can_load_it(self):
        definitions = {n: t for n, (_, t) in agents().items()}
        self.assertTrue(
            any(NAMED_SKILL.search(t) for t in definitions.values()),
            "no definition names a skill",
        )
        self.assertEqual(skill_problems(definitions, SKILLS), [])

    def test_a_definition_that_cannot_load_what_it_names_fails_with_the_fix(self):
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            skills = Path(tmp)
            for skill, front in (
                ("ours", ""),
                ("hidden", "disable-model-invocation: true\n"),
                ("vendor", "metadata:\n  model: m\n"),
            ):
                (skills / skill).mkdir()
                (skills / skill / "SKILL.md").write_text(
                    f"---\nname: {skill}\n{front}---\n"
                )
            body = "Use the `ours` skill, the `hidden` skill, the `vendor` skill, the `gone` skill.\n"
            problems = skill_problems(
                {
                    "no-tool.md": f"---\ntools: Read\n---\nUse the `ours` skill.\n",
                    "loads.md": f"---\ntools: Read, Skill\n---\n{body}",
                },
                skills,
            )
        self.assertEqual(
            problems,
            [
                ".claude/agents/no-tool.md:4: the `ours` skill cannot be loaded. Fix: add Skill to its tools",
                ".claude/agents/loads.md:4: the `hidden` skill is hidden from the model. Fix: drop"
                " disable-model-invocation from its front matter",
                ".claude/agents/loads.md:4: the `vendor` skill is third-party. Fix: name one of our own skills",
                ".claude/agents/loads.md:4: the `gone` skill is not there. Fix: name a skill in .claude/skills/",
            ],
        )


if __name__ == "__main__":
    unittest.main()
