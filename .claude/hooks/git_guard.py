"""PreToolUse hook on Bash: keeps the git hooks in charge of commits.

The checks themselves run in git's own hooks (.claude/hooks/git/), on what git
is really about to commit. This hook only makes sure they cannot be skipped:

- a command that commits runs with `core.hooksPath` = `.claude/hooks/git`
  (from the clone's config, or `-c core.hooksPath=.claude/hooks/git` on the
  command); otherwise it is blocked. The guard does not write the setting
  itself: in an isolated worktree that shared setting is the person's call
  (`tool/setup_env.sh` sets it);
- no `--no-verify`, no `-n` on commit, no other value for core.hooksPath, no
  `GIT_*=` variables on the command line, no HUSKY / SKIP style hook switches;
- cherry-pick and revert only with `--no-commit` and no rebase or am: git runs
  no commit hooks for the commits they make (merge, or commit the result);
- a command that commits gets a Bash timeout of at least 600000 ms or runs in
  the background, because the gate runs the suites (a few minutes) inside it.

Reads the hook JSON on stdin; exit 2 with the reasons on stderr blocks.
Tested by .claude/hooks/test_gate_routing.sh.
"""

import json
import re
import shlex
import subprocess
import sys
from pathlib import Path

HOOKS_PATH = ".claude/hooks/git"
MIN_TIMEOUT_MS = 600000
# git options before the subcommand that take a separate value
GLOBAL_WITH_VALUE = {
    "-C",
    "-c",
    "--git-dir",
    "--work-tree",
    "--namespace",
    "--exec-path",
    "--super-prefix",
    "--config-env",
}
# commit options that take a separate value (so the value is not read as a flag)
COMMIT_WITH_VALUE = {
    "-m",
    "--message",
    "-F",
    "--file",
    "-C",
    "--reuse-message",
    "-c",
    "--reedit-message",
    "-t",
    "--template",
    "--author",
    "--date",
    "--cleanup",
    "--fixup",
    "--squash",
    "--trailer",
    "--pathspec-from-file",
}
COMMITTING = {"commit", "merge", "pull"}
SEPARATORS = {"&&", "||", ";", "|", "&", "(", ")", "\n"}


def git_calls(command):
    """(subcommand, args) for each `git ...` in the command, best effort."""
    try:
        lex = shlex.shlex(command, posix=True, punctuation_chars=";&|()")
        lex.whitespace_split = True
        tokens = list(lex)
    except ValueError:
        tokens = command.split()
    calls, i = [], 0
    while i < len(tokens):
        if Path(tokens[i]).name != "git":
            i += 1
            continue
        i += 1
        while i < len(tokens) and tokens[i].startswith("-"):
            i += 2 if tokens[i] in GLOBAL_WITH_VALUE else 1
        if i >= len(tokens):
            break
        sub, args = tokens[i], []
        i += 1
        while i < len(tokens) and tokens[i] not in SEPARATORS:
            args.append(tokens[i])
            i += 1
        calls.append((sub, args))
    return calls


def commit_skips_hooks(args):
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--":
            break
        if a in COMMIT_WITH_VALUE:
            i += 2
            continue
        if re.fullmatch(r"-[a-zA-Z]+", a):
            flags = a[1:]
            # in a cluster, letters after one that takes a value are that value
            for j, ch in enumerate(flags):
                if ch == "n":
                    return True
                if ch in "mFCct":
                    break
        i += 1
    return False


def problems_with(command, tool_input):
    out = []
    if re.search(r"--no-verify\b", command):
        out.append("--no-verify skips the commit gate: fix the failing checks instead.")
    # any mention of core.hooksPath that is not the right value (or a plain read)
    for m in re.finditer(r"core\.hookspath(\s*=\s*|\s+)?(\S*)", command, re.I):
        value = m.group(2).strip("'\"")
        if value not in (HOOKS_PATH, "") and not value.startswith(("&", ";", "|")):
            out.append(f"core.hooksPath must be `{HOOKS_PATH}`, not `{value}`.")
        elif value == "" and re.search(r"--unset|--remove-section", command):
            out.append(f"core.hooksPath must stay `{HOOKS_PATH}`.")
    if re.search(r"(^|[\s;&|(])(export\s+)?GIT_[A-Z_]+=", command):
        out.append(
            "GIT_* variables on the command line can redirect git past its hooks; drop them."
        )
    if re.search(
        r"(^|[\s;&|(])(export\s+)?(HUSKY|SKIP|PRE_COMMIT_ALLOW_NO_CONFIG)=", command
    ):
        out.append("hook switches (HUSKY, SKIP, ...) are not allowed.")
    commits = False
    for sub, args in git_calls(command):
        if sub == "commit" and commit_skips_hooks(args):
            out.append("`git commit -n` skips the commit gate.")
        if sub in ("cherry-pick", "revert") and not (
            {"-n", "--no-commit", "--abort", "--quit"} & set(args)
        ):
            out.append(
                f"git runs no commit hooks for `git {sub}`: use `git {sub} --no-commit`, then `git commit`."
            )
        if sub in ("rebase", "am") and not ({"--abort", "--quit"} & set(args)):
            out.append(f"git runs no commit hooks for `git {sub}`: merge instead.")
        if sub in COMMITTING and not (
            {"--abort", "--quit", "--ff-only", "-h"} & set(args)
        ):
            commits = True
    if commits and not tool_input.get("run_in_background"):
        try:
            timeout = int(tool_input.get("timeout") or 0)
        except (TypeError, ValueError):
            timeout = 0
        if timeout < MIN_TIMEOUT_MS:
            out.append(
                f"a commit runs the gate's suites (a few minutes): give this Bash call "
                f"timeout {MIN_TIMEOUT_MS} or run_in_background."
            )
    return out, commits


def hooks_path_problem(cwd, command):
    """Why a commit from cwd would not run the git hooks, or None."""
    top = subprocess.run(
        ["git", "-C", cwd, "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
    )
    if top.returncode != 0:
        return None
    root = top.stdout.strip()
    if not (Path(root) / HOOKS_PATH / "pre-commit").is_file():
        return None  # a checkout from before the git hooks: nothing to enforce
    cur = subprocess.run(
        ["git", "-C", root, "config", "core.hooksPath"], capture_output=True, text=True
    ).stdout.strip()
    if cur == HOOKS_PATH or re.search(r"-c\s*['\"]?core\.hooksPath=" + re.escape(HOOKS_PATH), command):
        return None
    return (f"core.hooksPath is {('`' + cur + '`') if cur else 'not set'}, so git would skip the commit "
            f"gate: run `tool/setup_env.sh` (or `git config core.hooksPath {HOOKS_PATH}`) in the "
            f"checkout, or ask the person to; for one command, `git -c core.hooksPath={HOOKS_PATH} commit ...`.")


def main():
    data = json.load(sys.stdin)
    tool_input = data.get("tool_input") or {}
    command = tool_input.get("command") or ""
    if not re.search(r"git|GIT_|HUSKY|SKIP=", command):
        return 0
    problems, commits = problems_with(command, tool_input)
    if commits:
        p = hooks_path_problem(data.get("cwd") or ".", command)
        if p:
            problems.append(p)
    if problems:
        print("BLOCKED: " + " ".join(problems), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # a broken guard blocks, it never waves a command through
        print(f"BLOCKED: .claude/hooks/git_guard.py failed: {e!r}", file=sys.stderr)
        sys.exit(2)
