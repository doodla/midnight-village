"""Where the brief tools read documents from: the working tree, or one commit.

`just brief` reads the working tree. `tool/context_budget.py` measures the same
briefs on the main a change was built on, to hold each one to "may shrink, never
grow", so every document a brief quotes is read through `DOCS` and never opened
directly. Code (the widget trees, the files a brief lists) is not read here: the
budget counts the code lists by their caps (`capped`), not by their content.
"""

import fnmatch
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# A characters-to-tokens rate good enough for English prose and paths.
CHARS_PER_TOKEN = 4


def tokens(text: str) -> int:
    return len(text) // CHARS_PER_TOKEN


class Docs:
    """Documents of the working tree (ref None) or of one commit."""

    def __init__(self, root: Path = ROOT, ref: str | None = None):
        self.root, self.ref = root, ref
        self._listing: list[str] | None = None

    def raw(self, path: str) -> bytes | None:
        """The bytes of `path` (repo-relative), or None when it is not there."""
        if self.ref is None:
            file = self.root / path
            return file.read_bytes() if file.is_file() else None
        done = subprocess.run(
            ["git", "-C", str(self.root), "show", f"{self.ref}:{path}"],
            capture_output=True,
        )
        return done.stdout if done.returncode == 0 else None

    def read(self, path: str) -> str | None:
        """The text of `path` (repo-relative), or None when it is not there."""
        data = self.raw(path)
        return None if data is None else data.decode(errors="replace")

    def is_text(self, path: str) -> bool:
        """Whether `path` is there and is text a reader can take in (UTF-8, no NUL)."""
        data = self.raw(path)
        if data is None or b"\0" in data:
            return False
        try:
            data.decode()
        except UnicodeDecodeError:
            return False
        return True

    def use(self, ref: str | None) -> None:
        """Read from `ref` from now on (None: the working tree). In place, so every
        module that imported DOCS reads from there too."""
        self.ref, self._listing = ref, None

    def text(self, path: str) -> str:
        return self.read(path) or ""

    def files(self) -> list[str]:
        """Every file: tracked or new and not ignored (working tree), or in the commit."""
        if self._listing is None:
            if self.ref is None:
                args = ["ls-files", "-z", "--cached", "--others", "--exclude-standard"]
            else:
                args = ["ls-tree", "-r", "-z", "--name-only", self.ref]
            listed = subprocess.run(
                ["git", "-C", str(self.root), *args], capture_output=True
            ).stdout.decode(errors="replace")
            names = {n for n in listed.split("\0") if n}
            if self.ref is None:
                names = {n for n in names if (self.root / n).is_file()}
            self._listing = sorted(names)
        return self._listing

    def glob(self, pattern: str) -> list[str]:
        """Repo-relative files matching `pattern` (fnmatch: `*` crosses folders)."""
        return [p for p in self.files() if fnmatch.fnmatch(p, pattern)]


DOCS = Docs()


APP_RULES = "frontend/docs/app-rules.md"


def app_rules(already: str = "") -> list[str]:
    """The app's rules to quote in a brief: every bold phrase of APP_RULES (each rule
    is in bold there, whole), once each, leaving out those `already` quotes."""
    rules: list[str] = []
    for phrase in re.findall(r"\*\*(.+?)\*\*", DOCS.text(APP_RULES)):
        if f"**{phrase}**" in already:
            continue
        if "." not in phrase.split()[0]:  # a file name keeps its case
            phrase = phrase[:1].upper() + phrase[1:]
        if f"- {phrase}" not in rules:
            rules.append(f"- {phrase}")
    if not rules:
        return []
    head = f"## The app's rules ({APP_RULES}, where each has its section: read it before you touch what a rule is about)\n"
    return [head, *rules, ""]


def capped(
    lines: list[str], limit: int, more: str = "search for the rest"
) -> list[str]:
    """`lines` up to `limit` tokens, then one line that says what was left out.

    Every list a brief makes from code goes through this, so a brief cannot grow
    past its caps however large the code gets, and the budget can count a list by
    its cap without building it."""
    out, used = [], 0
    for at, line in enumerate(lines):
        cost = tokens(line) + 1
        if used + cost > limit:
            out.append(f"  ... and {len(lines) - at} more ({more}).")
            break
        out.append(line)
        used += cost
    return out
