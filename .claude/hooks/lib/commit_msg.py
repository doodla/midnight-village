"""Check the subject of a commit message: `type(scope): description`.

Usage: commit_msg.py <message file> (what git hands the commit-msg hook).
Exit 0 when the subject is fine; exit 1 and say why when it is not.
Git's own subjects for merges and reverts, and fixup!/squash! subjects, pass.
Tested by .claude/hooks/test_gate_routing.sh.
"""

import re
import sys
from pathlib import Path

TYPES = ("feat", "fix", "test", "refactor", "docs", "chore")
SUBJECT = re.compile(r"^(%s)(\([^()\s][^()]*\))?: \S" % "|".join(TYPES))
ALSO_OK = re.compile(r'^(Merge |Revert "|fixup! |squash! |amend! )')


def subject_of(text):
    """The first line that is neither blank nor a git comment."""
    for line in text.splitlines():
        if line.strip() and not line.startswith("#"):
            return line.strip()
    return ""


def main(argv):
    if len(argv) != 2:
        print("usage: commit_msg.py <message file>")
        return 1
    subject = subject_of(Path(argv[1]).read_text(errors="replace"))
    if SUBJECT.match(subject) or ALSO_OK.match(subject):
        return 0
    print(
        f"BLOCKED: commit subject {subject!r} does not follow `type(scope): description` "
        f"(types: {', '.join(TYPES)})."
    )
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
