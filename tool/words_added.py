#!/usr/bin/env python3
"""A pull request that adds words a player reads says so, and why.

The game teaches by doing and says little. Each screen used to have a pinned
number of words; a change that needed a word raised the number (seven times),
and two changes could each fit and together not. There is no number now.

Every copy key (frontend/lib/design_system/copy/) is compared with the main the
change was built on (tool/change_base.py). When a copy class has MORE words than
it had, the pull request's description must hold a line for it:

    Words added
    - TalkCopy: the button now says what it does, the owner asked on 23 November

Fewer words, or the same number, needs nothing. On GitHub (`PR_BODY` is set) a
missing line fails the check; locally it prints the line the description will
need, with the words before and after, and passes.

A word is a piece with a letter in it; a `{gap}` filled when the line is shown
is not one. The shapes a line must keep (a headline's length, a button's, a
sentence's) are held by copy_budget_test.dart, whatever this counts.

usage: tool/words_added.py [--base <ref>]
"""

import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from change_base import change_base  # noqa: E402
from copy_page import COPY, all_copy, parse  # noqa: E402

MIN_REASON = 10
GAP = re.compile(r"\{\w+\}")


def count(text: str) -> int:
    return sum(1 for piece in GAP.sub(" ", text).split() if re.search(r"[^\W\d_]", piece))


def by_class(classes: list[dict]) -> dict[str, dict[str, str]]:
    """{copy class: {key: its words as one text}}."""
    return {
        item["name"]: {m["name"]: " · ".join(m["words"]) for m in item["members"]}
        for item in classes
    }


def copy_at(base: str) -> dict[str, dict[str, str]]:
    """The copy as it was at `base`."""
    folder = str(COPY.relative_to(ROOT))
    names = subprocess.run(
        ["git", "-C", str(ROOT), "ls-tree", "-r", "--name-only", base, "--", folder],
        capture_output=True, text=True,
    ).stdout.split()
    with tempfile.TemporaryDirectory() as scratch:
        for name in names:
            shown = subprocess.run(
                ["git", "-C", str(ROOT), "show", f"{base}:{name}"],
                capture_output=True, text=True, errors="replace",
            ).stdout
            (Path(scratch) / Path(name).name).write_text(shown)
        return by_class(
            [item for path in sorted(Path(scratch).glob("*.dart")) for item in parse(path) if item["members"]]
        )


def grown(was: dict[str, dict[str, str]], now: dict[str, dict[str, str]]) -> list[dict]:
    """[{name, added, keys: [(key, before, after)]}] for each class with more words."""
    found = []
    for name, keys in sorted(now.items()):
        before = was.get(name, {})
        added = sum(count(t) for t in keys.values()) - sum(count(t) for t in before.values())
        if added <= 0:
            continue
        changed = [
            (key, before.get(key, ""), text)
            for key, text in keys.items()
            if count(text) > count(before.get(key, ""))
        ]
        found.append({"name": name, "added": added, "keys": changed})
    return found


def explained(name: str, body: str) -> bool:
    return bool(re.search(rf"^\W*`?{re.escape(name)}`?\s*:\s*\S.{{{MIN_REASON - 1},}}", body, re.M))


def main(argv: list[str]) -> int:
    wanted = argv[argv.index("--base") + 1] if "--base" in argv else "origin/main"
    base = change_base(ROOT, wanted)
    if base is None:
        print(f"words added: no {wanted} to compare with; nothing checked.")
        return 0
    more = grown(copy_at(base), by_class(all_copy()))
    if not more:
        print("words added: no copy class has more words than it had.")
        return 0
    body = os.environ.get("PR_BODY")
    missing = []
    for item in more:
        said = body is not None and explained(item["name"], body)
        print(f"words added: {item['name']} +{item['added']}{'' if said else '  <- needs its line'}")
        for key, before, after in item["keys"]:
            print(f'    {key}: "{before}" -> "{after}"' if before else f'    {key} (new): "{after}"')
        if not said:
            missing.append(item["name"])
    if not missing:
        return 0
    needs = (
        "\nThe pull request's description needs a line per copy class, saying why it"
        " says more:\n\nWords added\n" + "".join(f"- {name}: <why, in a sentence>\n" for name in missing)
    )
    if body is None:
        print(needs + "(not on GitHub: this is a reminder, not a failure)")
        return 0
    if os.environ.get("GITHUB_ACTIONS"):
        for name in missing:
            print(f"::error title=Words added without a line::Add under 'Words added' in the pull request's description: - {name}: <why, in a sentence>")
    print(needs + "\nThe game says little: say why this screen says more. Editing the description runs this check again.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
