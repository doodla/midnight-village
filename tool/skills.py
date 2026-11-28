"""Our own skills under .claude/skills/, told from third-party ones by the file itself.

A skill copied in from outside keeps its vendor's `metadata:` block in its front matter
(the flutter-* skills do); ours carry none. So there is no list: a skill of ours is
measured (tool/context_budget.py) and link-checked (tool/check_instruction_links.py)
from its first commit, and every file in its folder with it (a reviewer prompt beside it).
"""

import re

SKILLS = ".claude/skills/"


def front_matter(text: str) -> dict[str, str]:
    """The top-level `key: value` lines between the opening `---` lines."""
    m = re.match(r"---\s*\n(.*?)\n---", text, re.S)
    found = {}
    for line in m[1].splitlines() if m else []:
        key, sep, value = line.partition(":")
        if sep and key and not key[0].isspace():
            found[key.strip()] = value.strip()
    return found


def third_party(skill_md: str) -> bool:
    return "metadata" in front_matter(skill_md)


def invocable(skill_md: str) -> bool:
    """An agent can load it: not hidden from the model (`disable-model-invocation`)."""
    return front_matter(skill_md).get("disable-model-invocation", "") != "true"


def ours(paths: list[str], read) -> list[str]:
    """The Markdown files of `paths` that belong to our own skills; `read(path)` gives
    a file's text (None when it is not there)."""
    out = []
    for path in paths:
        if not (path.startswith(SKILLS) and path.endswith(".md")):
            continue
        folder = path[len(SKILLS) :].split("/", 1)[0]
        skill = read(f"{SKILLS}{folder}/SKILL.md")
        if skill is not None and not third_party(skill):
            out.append(path)
    return out
