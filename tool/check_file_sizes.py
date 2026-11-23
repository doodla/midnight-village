#!/usr/bin/env python3
"""Fails when a source file is too long to hold in one read.

A file over LIMIT lines is where an agent (or a person) gets lost: it cannot be
read whole, a change to one part risks another, and two branches that touch it
collide. So:

- a source file may not pass LIMIT lines;
- the files that already do are listed in tool/file_size_ceilings.txt with the
  size they had when listed. Each may shrink freely but not grow past that
  ceiling: split it instead (or, when it truly must grow first, raise its line
  in that file in the same commit, where a reviewer sees it);
- a listed file that is back under LIMIT, or gone, is reported (not failed), so
  its line can be removed;
- a line that ends `until YYYY-MM-DD` is an allowance: that file may grow (a
  piece of work is in the middle of it). The date is a promise, not a trap: the
  check never starts failing because a day passed. After the date it says so on
  every run, and the line is then re-recorded without `until`.

Checked: backend/apps (not migrations), frontend/lib (not generated code),
.claude/hooks, .claude/guardrails (not tests) and tool. Tests are not checked.

Run by `just check` (the working tree), by the commit gate with --staged (what
is being committed) and by `just gate-full`. `--write` rewrites the ceilings
file from what is there now (use it only to add a file on purpose).

usage: tool/check_file_sizes.py [--staged] [--write]
"""

import datetime
import re
import subprocess
import sys
from pathlib import Path

LIMIT = 600
ROOT = Path(__file__).resolve().parents[1]
CEILINGS = ROOT / "tool" / "file_size_ceilings.txt"
HEADER = """\
# Source files over 600 lines, with the size each had when it was listed
# (tool/check_file_sizes.py). A file may shrink freely; it may not grow past
# its number: split it. Remove a line once its file is under 600.
# `until YYYY-MM-DD`: that file may grow until then (work in the middle of it).
"""


def checked(path: str) -> bool:
    if path.endswith((".g.dart", ".freezed.dart")):
        return False
    if path.startswith("backend/apps/"):
        return path.endswith(".py") and "/migrations/" not in path
    if path.startswith("frontend/lib/"):
        return path.endswith(".dart")
    if path.startswith(".claude/guardrails/"):
        return path.endswith(".py") and "/tests/" not in path
    if path.startswith((".claude/hooks/", "tool/")):
        return path.endswith((".py", ".sh"))
    return False


def git(*args: str) -> bytes:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args], capture_output=True, check=True
    ).stdout


def line_counts(staged: bool) -> dict[str, int]:
    """Lines of every checked file: as staged for the commit, or as on disk."""
    listing = ["ls-files", "-z", "--cached"]
    if not staged:
        listing += ["--others", "--exclude-standard"]
    counts = {}
    for name in sorted(set(git(*listing).decode().split("\0"))):
        if not name or not checked(name):
            continue
        if staged:
            try:
                data = git("show", f":{name}")
            except subprocess.CalledProcessError:
                continue
        else:
            path = ROOT / name
            if not path.is_file():
                continue
            data = path.read_bytes()
        counts[name] = data.count(b"\n") + (
            1 if data and not data.endswith(b"\n") else 0
        )
    return counts


def read_ceilings(staged: bool) -> dict[str, tuple[int, str]]:
    """{path: (ceiling, allowance end date or "")} from the ceilings file."""
    try:
        if staged:
            text = git("show", ":tool/file_size_ceilings.txt").decode()
        else:
            text = CEILINGS.read_text()
    except (subprocess.CalledProcessError, OSError):
        return {}
    ceilings = {}
    for line in text.splitlines():
        m = re.fullmatch(r"(\d+) (\S+)(?: until (\d{4}-\d{2}-\d{2}))?", line.strip())
        if m:
            ceilings[m.group(2)] = (int(m.group(1)), m.group(3) or "")
    return ceilings


def main(argv: list[str]) -> int:
    staged = "--staged" in argv
    counts = line_counts(staged)
    if "--write" in argv:
        kept = {p: u for p, (_, u) in read_ceilings(staged=False).items() if u}
        big = {p: n for p, n in counts.items() if n > LIMIT or p in kept}
        lines = [
            f"{n} {p}" + (f" until {kept[p]}" if p in kept else "")
            for p, n in sorted(big.items(), key=lambda kv: (-kv[1], kv[0]))
        ]
        # the comment lines at the top of the list are kept as they are
        try:
            head = "".join(
                line + "\n" for line in CEILINGS.read_text().splitlines() if line.startswith("#")
            )
        except OSError:
            head = ""
        CEILINGS.write_text((head or HEADER) + "\n".join(lines) + "\n")
        print(f"wrote {len(lines)} ceilings to {CEILINGS.relative_to(ROOT)}")
        return 0
    ceilings = read_ceilings(staged)
    today = datetime.date.today().isoformat()
    problems, notes = [], []
    for path, lines in counts.items():
        ceiling, until = ceilings.get(path, (None, ""))
        if until:
            continue  # an allowance: it may grow while its piece of work is in it
        if ceiling is None and lines > LIMIT:
            problems.append(
                f"{path} is {lines} lines, over the {LIMIT}-line limit: split it into parts"
                " that can each be read whole."
            )
        elif ceiling is not None and lines > ceiling:
            problems.append(
                f"{path} grew to {lines} lines; it is already over the limit and listed at"
                f" {ceiling} in tool/file_size_ceilings.txt: move something out of it, do not add to it."
            )
    for path, (_, until) in ceilings.items():
        if until:
            if today > until:
                notes.append(
                    f"{path}: its allowance to grow ended on {until}. Re-record its line in"
                    " tool/file_size_ceilings.txt at its size now, without `until` (or remove it)."
                )
        elif path not in counts:
            notes.append(f"{path} is listed in tool/file_size_ceilings.txt but is gone: remove its line.")
        elif counts[path] <= LIMIT:
            notes.append(
                f"{path} is down to {counts[path]} lines: remove its line from tool/file_size_ceilings.txt."
            )
    for note in notes:
        print(f"note: {note}")
    for problem in problems:
        print(problem, file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
