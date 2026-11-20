"""Check the subject line of the message in a `git commit` command.

Reads the whole shell command on stdin. Exit 0: the subject is fine, or there is
no message to check (an editor, --no-edit, -C/-c, a merge's own message). Exit 1:
prints why the subject does not follow `type(scope): description`.
Tested by .claude/hooks/test_gate_routing.sh.
"""

import re
import shlex
import sys
from pathlib import Path

TYPES = ("feat", "fix", "test", "refactor", "docs", "chore")
SUBJECT = re.compile(r"^(%s)(\([^()\s][^()]*\))?: \S" % "|".join(TYPES))
ALSO_OK = re.compile(r'^(Merge |Revert ")')
HEREDOC = re.compile(r"^\$\(cat <<-?\s*['\"]?(\w+)['\"]?\n(.*?)\n\s*\1\s*\n?\)$", re.S)


def message_parts(command):
    """Each message given with -m/--message/-F/--file, as text, in order."""
    try:
        tokens = shlex.split(command, posix=True)
    except ValueError:
        return None
    if "commit" not in tokens:
        return []
    tokens = tokens[tokens.index("commit") + 1 :]
    parts = []
    i = 0
    while i < len(tokens):
        t = tokens[i]
        nxt = tokens[i + 1] if i + 1 < len(tokens) else None
        if t in ("-m", "--message") and nxt is not None:
            parts.append(nxt)
            i += 2
            continue
        if t.startswith("--message="):
            parts.append(t.split("=", 1)[1])
        elif t.startswith("-m") and len(t) > 2 and not t.startswith("--"):
            parts.append(t[2:])
        elif re.fullmatch(r"-[a-zA-Z]*m", t) and nxt is not None:  # -am "msg"
            parts.append(nxt)
            i += 2
            continue
        elif t in ("-F", "--file") and nxt is not None:
            path = Path(nxt)
            parts.append(path.read_text() if path.is_file() else "")
            i += 2
            continue
        elif t in ("&&", ";", "||", "|"):
            break
        i += 1
    return parts


def subject_of(part):
    m = HEREDOC.match(part.strip())
    text = m.group(2) if m else part
    for line in text.splitlines():
        if line.strip():
            return line.strip()
    return ""


def heredoc_subject(command):
    """The first line of a `-m "$(cat <<'EOF' ... EOF)"` message, read from the raw
    command: shlex cannot parse quotes inside the heredoc's command substitution."""
    m = re.search(
        r"commit\b.*?(?:-m|--message)\s+\"?\$\(cat <<-?\s*['\"]?(\w+)['\"]?\n(.*?)\n\s*\1\b",
        command,
        re.S,
    )
    return subject_of(m.group(2)) if m else None


def main():
    command = sys.stdin.read()
    subject = heredoc_subject(command)
    if subject is None:
        parts = message_parts(command)
        if not parts:  # None: cannot parse the shell line; []: no message given
            return 0
        subject = subject_of(parts[0])
    if SUBJECT.match(subject) or ALSO_OK.match(subject):
        return 0
    print(
        f"BLOCKED: commit subject {subject!r} does not follow `type(scope): description` "
        f"(types: {', '.join(TYPES)}).",
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
