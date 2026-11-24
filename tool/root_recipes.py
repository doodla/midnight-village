#!/usr/bin/env python3
"""Every recipe of frontend/ and backend/ runs from the repo root under its name.

A recipe added in a folder needs one forward in the root justfile (the block
"Every recipe from the root"). This says which are missing and writes them.

It fails only for a recipe THIS change adds (compared with the main the change
was built on, tool/change_base.py): two pull requests that are each fine must
not make main fail for the next builder. A hole left by anything else is
printed, with the way to fill it, and does not fail.

usage: tool/root_recipes.py            what is missing; exit 1 if this change left it
       tool/root_recipes.py --fix      write the missing forwards into the justfile
"""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from change_base import change_base  # noqa: E402

FOLDERS = ("frontend", "backend")
BLOCK = "# --- Every recipe from the root ---"


def recipes(justfile: Path) -> dict[str, dict]:
    """{name: recipe} of a justfile's public recipes; {} when it cannot be read."""
    done = subprocess.run(
        ["just", "--justfile", str(justfile), "--dump", "--dump-format", "json"],
        capture_output=True, text=True,
    )
    if done.returncode != 0:
        return {}
    return {n: r for n, r in json.loads(done.stdout)["recipes"].items() if not r["private"]}


def recipes_at(base: str, path: str) -> set[str]:
    """The names a justfile had at `base` (empty when it was not there)."""
    shown = subprocess.run(
        ["git", "-C", str(ROOT), "show", f"{base}:{path}"], capture_output=True, text=True
    )
    if shown.returncode != 0:
        return set()
    with tempfile.TemporaryDirectory() as scratch:
        copy = Path(scratch) / "justfile"
        copy.write_text(shown.stdout)
        return set(recipes(copy))


def missing() -> dict[str, dict[str, dict]]:
    """{folder: {name: recipe}} for each folder recipe the root lacks."""
    root = recipes(ROOT / "justfile")
    return {
        folder: {
            name: recipe
            for name, recipe in sorted(recipes(ROOT / folder / "justfile").items())
            if name not in root and name != "default"
        }
        for folder in FOLDERS
    }


def forward(folder: str, name: str, recipe: dict) -> str:
    doc = (recipe.get("doc") or "").strip() or name
    return f"\n# ({folder}) {doc}\n{name} *args:\n    {{{{{folder}_just}}}} {name} {{{{args}}}}\n"


def added_here(holes: dict[str, dict[str, dict]]) -> list[str]:
    """The holes this change made: recipes its folder justfile did not have before."""
    base = change_base(ROOT)
    if base is None:
        return []
    return [
        f"{folder}/{name}"
        for folder, names in holes.items()
        for name in names
        if name not in recipes_at(base, f"{folder}/justfile")
    ]


def main(argv: list[str]) -> int:
    holes = missing()
    count = sum(len(names) for names in holes.values())
    if not count:
        return 0
    if "--fix" in argv:
        text = (ROOT / "justfile").read_text()
        if BLOCK not in text:
            print(f"root recipes: the root justfile has no '{BLOCK}' block to add to.", file=sys.stderr)
            return 1
        text = text.rstrip("\n") + "\n"
        for folder, names in holes.items():
            for name, recipe in names.items():
                text += forward(folder, name, recipe)
        (ROOT / "justfile").write_text(text)
        print(f"root recipes: added {count} to the root justfile.")
        return 0
    mine = added_here(holes)
    for folder, names in holes.items():
        for name in names:
            whose = "added by this change" if f"{folder}/{name}" in mine else "not this change's"
            print(f"root recipes: `just {name}` exists only in {folder}/ ({whose}).")
    print("  Fill them in: tool/root_recipes.py --fix   (it writes the forwards into the root justfile)")
    if mine:
        print("A recipe this change adds must run from the root too.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
