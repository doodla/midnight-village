#!/usr/bin/env python3
"""PreToolUse hook for Bash: no sleep loop whose purpose is waiting for another job.

A helper that polls a queued job with `until ...; do sleep 30; done` spends a step on
every round (one spent 47 of 97). A command started with `run_in_background: true` wakes
the helper about two seconds after it exits, so there is nothing to poll for.

It stops one thing, and says what to do instead: an `until`, `while` or `for` loop with a
`sleep` in it that looks at another job (a process: pgrep, ps, kill -0; a log or marker
file: tail, grep, cat, test -f; the queue: heavy, flock; GitHub: gh). Left alone:

- a loop that waits for a service you started to answer (curl, wget, nc, /dev/tcp);
- a loop with no sleep, a sleep with no loop, and a loop that looks at nothing (`while true`);
- words that only mention these things (a message, a search pattern, a here-document):
  the command is read as the shell reads it (`shell_text.py`), and `bash -c '...'` is read inside.

Not a wall (a script file or another program can still loop): it is a reminder at the moment
the mistake is made. Tests: `.claude/guardrails/tests/test_poll_guard.py`.
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from shell_text import SHELLS, simple_commands, strip_heredocs

LOOPS = {"until", "while", "for"}
# Commands that look at another job's state.
PROBES = {
    "pgrep", "pidof", "ps", "kill", "tail", "grep", "egrep", "rg", "cat", "head", "test",
    "[", "[[", "ls", "stat", "wc", "jobs", "flock", "gh", "heavy", "heavy.py", "just",
    "pstree", "lsof",
}  # fmt: skip
# Commands that wait for a service that was just started: not another job.
SERVICE = {"curl", "wget", "nc", "ncat", "telnet", "http", "httpie"}
LEADERS = {
    "until",
    "while",
    "do",
    "then",
    "else",
    "elif",
    "!",
    "{",
    "time",
    "timeout",
    "exec",
    "nohup",
    "nice",
    "env",
}

MESSAGE = (
    "BLOCKED: this command only waits for another job (a sleep loop that looks at a"
    " process, a log or the queue). Do not poll. Start the job ONCE with the Bash tool's"
    " `run_in_background: true`, then end your turn: you are woken about two seconds"
    " after it exits. A queued heavy command says where it stands in its own output;"
    " `just heavy --status` shows who holds a slot and who waits. Your own work to do"
    " meanwhile is fine; waiting in a loop is not."
)


def name_of(words: list[str]) -> str:
    """The command name of one simple command, past `do`, `!`, `timeout 60` and the like."""
    for word in words:
        if (
            word in LEADERS
            or word.isdigit()
            or word.startswith("-")
            or "=" in word.split("/")[0]
        ):
            continue
        return Path(word).name
    return ""


def inner_text(words: list[str]) -> list[str]:
    """What a `bash -c '...'` (or eval) runs: its string, to be read like any command."""
    name = name_of(words)
    if name == "eval":
        return [w for w in words[words.index("eval") + 1 :]]
    if name in SHELLS and "-c" in words:
        at = words.index("-c") + 1
        return [words[at]] if at < len(words) else []
    return []


def polls(command: str, depth: int = 0) -> bool:
    text, _bodies = strip_heredocs(command)
    commands = simple_commands(text)
    names = [name_of(words) for words in commands]
    # each loop: from its keyword to the `done` that closes it (nested loops nest)
    stack: list[list[int]] = []
    found = False
    for at, (words, name) in enumerate(zip(commands, names)):
        first = words[0] if words else ""
        if first in LOOPS:
            stack.append([at])
        for opened in stack:
            opened.append(at)
        if name == "done" and stack:
            body = stack.pop()
            kinds = {names[i] for i in body}
            if "sleep" in kinds and kinds & PROBES and not kinds & SERVICE:
                found = True
        for inside in inner_text(words) if depth < 3 else []:
            if polls(inside, depth + 1):
                found = True
    return found


def main() -> int:
    data = json.load(sys.stdin)
    command = (data.get("tool_input") or {}).get("command") or ""
    if "sleep" not in command:
        return 0
    if polls(command):
        print(MESSAGE, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, KeyError, IndexError, TypeError, AttributeError) as e:  # a broken input
        print(
            f".claude/hooks/poll_guard.py failed ({e!r}); the command goes on.",
            file=sys.stderr,
        )
        sys.exit(0)
