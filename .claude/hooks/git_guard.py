"""PreToolUse hook on Bash: keeps the git hooks in charge of commits.

The checks themselves run in git's own hooks (.claude/hooks/git/), on what git
is really about to commit. This hook stops the mistakes and shortcuts that
would skip them:

- a command that commits runs with `core.hooksPath` = `.claude/hooks/git`
  (from the clone's config, or `-c core.hooksPath=.claude/hooks/git` on the
  git call); otherwise it is blocked and told to run
  `.claude/hooks/session-start.sh`, which sets it (it also runs at the start of
  every session);
- no `--no-verify` (or a shortened spelling of it), no `-n` on commit, no other
  value for core.hooksPath (by `git config` or by `-c`), no alias or include set
  from the command, no `git config --edit`, no `GIT_*=` variable that redirects
  git, no HUSKY / SKIP / GATE_* switch on a git call, no `git commit-tree`;
- cherry-pick and revert only with `--no-commit` and no rebase or am: git runs
  no commit hooks for the commits they make (merge, or commit the result).

WHAT IT IS NOT. It is not a wall. It reads one Bash command as text, and a
reader of shell text can always be got round by someone who means to (a script
file, a `just` recipe, another program that calls git, a deleted hook file, a
worktree of a commit from before the hooks). The wall is GitHub: nothing
reaches main without every check green on the pull request. This hook exists so
that nobody skips the gate by habit or by accident, and so that it never gets
in the way of honest work.

So it reads the command the way the shell would, and judges what git is really
asked to do, not what the text happens to contain:

- only a `git` in command position counts, with its own arguments. The words
  of a commit message, a `grep` pattern, an `echo`, a comment or a here-document
  are not commands (`grep -rn -- --no-verify .` and `SKIP=slow pytest` go on);
- it looks inside what the shell would run: `bash -c '...'` (with other shell
  options too), `eval`, `trap`, `$(...)`, backticks, `$'...'` strings, a
  here-document fed to a shell, a shell function's body, the common wrappers
  (`env`, `command`, `exec`, `sudo`, `nohup`, `time`, `timeout`, `nice`,
  `xargs`, `find -exec`, `setsid`, `flock`), and a git alias from the clone;
- where it cannot read what a shell will run (a shell fed by a pipe or a
  here-string in a command that also names a committing git call), it blocks
  and says to run the git command directly.

The gate itself is fast (seconds: format, lint, types, analyze); GitHub runs the
suites. So a commit needs no long Bash timeout.

Reads the hook JSON on stdin; exit 2 with the reasons on stderr blocks.
Tested by .claude/guardrails/tests/test_git_guard.py (what is blocked and what
is not) and .claude/hooks/test_gate_routing.sh (against a real clone).
"""

import json
import re
import shlex
import subprocess
import sys
from pathlib import Path

# The reading of shell text is in shell_text.py, beside this file (a hook is run
# as a script, and the tests load it from here).
sys.path.insert(0, str(Path(__file__).resolve().parent))
from shell_text import (  # noqa: E402
    ASSIGNMENT,
    LIFTED,
    SHELLS,
    expand_ansi_strings,
    lift_substitutions,
    simple_commands,
    strip_heredocs,
)


HOOKS_PATH = ".claude/hooks/git"
MAX_DEPTH = 6  # shells inside shells inside aliases: stop reading, block

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
# options that take a separate value, per subcommand (so the value is not read as a flag)
MESSAGE_VALUES = {"-m", "--message", "-F", "--file"}
WITH_VALUE = {
    "commit": MESSAGE_VALUES
    | {
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
    },
    "merge": MESSAGE_VALUES
    | {"-s", "--strategy", "-X", "--strategy-option", "--into-name"},
    "pull": {"-s", "--strategy", "-X", "--strategy-option", "--depth", "--upload-pack"},
}
# commit's short options whose value may follow in the same cluster (`-mfoo`, `-uno`)
COMMIT_SHORT_WITH_VALUE = "mFCctuS"
CONFIG_WITH_VALUE = {
    "-f",
    "--file",
    "--blob",
    "--type",
    "--default",
    "--comment",
    "--value",
}
CONFIG_VERBS = {
    "set",
    "get",
    "unset",
    "list",
    "edit",
    "rename-section",
    "remove-section",
}
CONFIG_READS = {"--get", "--get-all", "--get-regexp", "--get-urlmatch", "--list", "-l"}
CONFIG_REMOVES = {"--unset", "--unset-all", "--remove-section", "--rename-section"}
COMMITTING = {"commit", "merge", "pull"}
NO_VERIFY_SUBS = {"commit", "merge", "pull", "am", "cherry-pick", "revert", "rebase"}
# what a `$VAR` in command position is treated as git for, when one of these follows it
GIT_VERBS = COMMITTING | {
    "rebase",
    "am",
    "cherry-pick",
    "revert",
    "config",
    "commit-tree",
}
SHELL_OPTS_WITH_VALUE = {"-o", "+o", "-O", "+O", "--rcfile", "--init-file"}
KEYWORDS = {
    *("if", "then", "else", "elif", "fi", "do", "done", "while", "until", "!", "{", "}"),
    *("time", "coproc"),
}
WRAPPERS = {
    *("env", "command", "exec", "sudo", "nohup", "timeout", "nice", "xargs", "stdbuf"),
    *("builtin", "setsid", "flock", "find", "ionice", "taskset", "watch"),
}
EXPORTERS = {"export", "declare", "typeset", "readonly"}
# git's own commands, which an alias cannot replace: no need to ask the clone about them
GIT_BUILTINS = {
    *("add", "am", "apply", "bisect", "blame", "branch", "checkout", "cherry-pick", "clean"),
    *("clone", "commit", "commit-tree", "config", "describe", "diff", "fetch", "grep", "init"),
    *("log", "ls-files", "ls-remote", "merge", "merge-base", "mv", "pull", "push", "rebase"),
    *("reflog", "remote", "reset", "restore", "rev-list", "rev-parse", "revert", "rm", "show"),
    *("stash", "status", "switch", "symbolic-ref", "tag", "update-ref", "worktree", "write-tree"),
}
# GIT_* variables that take git to another repository or another configuration, and so
# past this clone's hooks. The rest (GIT_INDEX_FILE, GIT_PAGER, GIT_AUTHOR_*, ...) do not.
GIT_ENV_REDIRECTS = re.compile(
    r"GIT_(DIR|WORK_TREE|COMMON_DIR|EXEC_PATH|NAMESPACE|CONFIG\w*)$"
)
SWITCH_ENV = re.compile(r"(HUSKY\w*|SKIP|PRE_COMMIT_\w+|GATE_\w+)$")
RUN_IT_DIRECTLY = "run the git command directly, on its own."


class Findings:
    def __init__(self, cwd):
        self.cwd = cwd
        self.problems = []
        self.commits = False  # a call that makes a commit was seen
        self.unhooked = (
            False  # ... and at least one of them did not name the hooks itself
        )
        self.exported_switches = []
        self.aliases = {}

    def add(self, text):
        if text not in self.problems:
            self.problems.append(text)


def redirecting_git_variable(name):
    return bool(GIT_ENV_REDIRECTS.match(name))


def flag_args(sub, args):
    """The arguments that are options, skipping the values of options that take one."""
    with_value = WITH_VALUE.get(sub, set())
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--":
            return
        if a in with_value:
            i += 2
            continue
        if a.startswith("-"):
            yield a
        i += 1


def is_no_verify(arg):
    return len(arg) >= len("--no-veri") and "--no-verify".startswith(arg)


def commit_skips_hooks(args):
    for a in flag_args("commit", args):
        if re.fullmatch(r"-[a-zA-Z]+", a):
            # in a cluster, letters after one that takes a value are that value
            for ch in a[1:]:
                if ch == "n":
                    return True
                if ch in COMMIT_SHORT_WITH_VALUE:
                    break
    return False


def check_config(args, found):
    """`git config ...`: nothing that moves, removes or hides the hooks."""
    flags, words, i = set(), [], 0
    while i < len(args):
        a = args[i]
        if a in CONFIG_WITH_VALUE:
            i += 2
            continue
        if a.startswith("-"):
            flags.add(a.split("=", 1)[0])
        else:
            words.append(a)
        i += 1
    verb = words.pop(0) if words and words[0] in CONFIG_VERBS else ""
    if verb == "edit" or flags & {"--edit", "-e"}:
        found.add(
            "`git config --edit` cannot be checked: use `git config <key> <value>` for the one value."
        )
        return
    if verb in ("get", "list") or flags & CONFIG_READS or not words:
        return
    removing = verb in ("unset", "remove-section", "rename-section") or bool(
        flags & CONFIG_REMOVES
    )
    key = words[0].lower()
    writing = (
        removing
        or verb == "set"
        or len(words) > 1
        or bool(flags & {"--add", "--replace-all"})
    )
    if key == "core" and removing:
        found.add(
            f"core.hooksPath must stay `{HOOKS_PATH}`: do not remove or rename the core section."
        )
    elif key == "core.hookspath" and writing:
        value = words[1] if len(words) > 1 else ""
        unknown = "$" in value or LIFTED in value  # the shell fills it in: not judged here
        if removing or (value.removeprefix("./") != HOOKS_PATH and not unknown):
            found.add(
                f"core.hooksPath must stay `{HOOKS_PATH}`"
                + (f", not `{value}`" if value and not removing else "")
                + ": `.claude/hooks/session-start.sh` sets it."
            )
    elif (
        (key.startswith("alias.") or key.startswith("include"))
        and writing
        and not removing
    ):
        found.add(
            f"`git config {words[0]}` can hide a way past the commit gate: run the git command"
            " itself instead of an alias or an included file."
        )


def alias_of(found, sub):
    if sub in GIT_BUILTINS or not re.fullmatch(r"[\w-]+", sub):
        return ""
    if sub not in found.aliases:
        found.aliases[sub] = read_alias(found.cwd, sub)
    return found.aliases[sub]


def read_alias(cwd, sub):
    try:
        got = subprocess.run(
            ["git", "-C", cwd, "config", "--get", f"alias.{sub}"],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    return got.stdout.strip() if got.returncode == 0 else ""


def check_git(tokens, found, depth, switches=()):
    """One `git ...` call: tokens are what follows the word git."""
    names_hooks = False
    i = 0
    while i < len(tokens) and tokens[i].startswith("-"):
        opt = tokens[i]
        value = tokens[i + 1] if i + 1 < len(tokens) else ""
        if opt == "-c" or (
            opt.startswith("-c") and "=" in opt and not opt.startswith("--")
        ):
            pair = value if opt == "-c" else opt[2:]
            key, _, val = pair.partition("=")
            key = key.lower()
            if key == "core.hookspath":
                if val.removeprefix("./") == HOOKS_PATH:
                    names_hooks = True
                else:
                    found.add(f"core.hooksPath must be `{HOOKS_PATH}`, not `{val}`.")
            elif key.startswith("alias.") or key.startswith("include"):
                found.add(
                    f"`-c {key}=` can hide a way past the commit gate: run the git command itself."
                )
        elif opt.split("=", 1)[0] in ("--config-env", "--exec-path") and (
            "=" in opt or opt == "--config-env"
        ):
            found.add(
                f"`{opt.split('=', 1)[0]}` can redirect git past its hooks: drop it."
            )
        i += 2 if opt in GLOBAL_WITH_VALUE else 1
    if i >= len(tokens):
        return
    sub, args = tokens[i], tokens[i + 1 :]

    alias = alias_of(found, sub)
    if alias:
        if depth >= MAX_DEPTH:
            found.add(f"the alias `{sub}` is too deep to read: {RUN_IT_DIRECTLY}")
        elif alias.startswith("!"):
            analyze(alias[1:] + " " + shlex.join(args), found, depth + 1)
        else:
            try:
                check_git(shlex.split(alias) + args, found, depth + 1, switches)
            except ValueError:
                found.add(f"the alias `{sub}` cannot be read: {RUN_IT_DIRECTLY}")
        return

    flags = set(flag_args(sub, args))
    if sub in NO_VERIFY_SUBS and any(is_no_verify(a) for a in flags):
        found.add("--no-verify skips the commit gate: fix the failing checks instead.")
    if sub == "commit" and commit_skips_hooks(args):
        found.add(
            "`git commit -n` skips the commit gate: fix the failing checks instead."
        )
    if sub == "config":
        check_config(args, found)
    if sub == "commit-tree":
        found.add("`git commit-tree` makes a commit no hook sees: use `git commit`.")
    stopping = {"--abort", "--quit"} & set(args)
    if sub in ("cherry-pick", "revert") and not (
        {"-n", "--no-commit"} & set(args) or stopping
    ):
        found.add(
            f"git runs no commit hooks for `git {sub}`: use `git {sub} --no-commit <commit>`, then"
            " `git commit` (in the middle of one: resolve, `git add`, then `git commit`)."
        )
    if sub in ("rebase", "am") and not stopping:
        found.add(
            f"git runs no commit hooks for `git {sub}`: merge instead"
            f" (in the middle of one: `git {sub} --abort`, then merge)."
        )
    if sub in COMMITTING and not (stopping or {"--ff-only", "-h"} & set(args)):
        if switches or found.exported_switches:
            names = ", ".join(sorted(set(switches) | set(found.exported_switches)))
            found.add(f"hook switches on a commit ({names}) are not allowed: drop them.")
        found.commits = True
        found.unhooked = found.unhooked or not names_hooks


def shell_script(args):
    """What a shell called with `args` runs: ("script", text), ("file", path) or ("stdin", "")."""
    has_c, i = False, 0
    while i < len(args):
        a = args[i]
        if a in SHELL_OPTS_WITH_VALUE:
            i += 2
            continue
        if a in ("-", "--"):
            i += 1
            continue
        if a == "<<<" and i + 1 < len(args):
            return ("script", args[i + 1])  # a here-string: its words are the script
        if a.startswith("<<<"):
            return ("script", a[3:])
        if a.startswith("<<"):
            return ("heredoc", "")  # its body is read as a script (strip_heredocs)
        if a.startswith(("<", ">")) or re.fullmatch(r"\d*[<>].*", a):
            return ("stdin", "")  # fed by a redirection
        if a.startswith(("-", "+")):
            has_c = has_c or (not a.startswith("--") and "c" in a[1:])
            i += 1
            continue
        return ("script", a) if has_c else ("file", a)
    return ("stdin", "")


def names_a_commit(text):
    """Whether the text names git and something that commits or reconfigures (a rough test)."""
    return bool(
        re.search(r"\bgit\b", text)
        and re.search(
            r"\b(commit|merge|pull|rebase|am|cherry-pick|revert|config)\b", text
        )
    )


def check_command(words, found, depth, whole):
    """One simple command: find what it really runs."""
    switches = []
    i = 0
    while i < len(words):
        w = words[i]
        name = Path(w).name
        m = ASSIGNMENT.match(w)
        if m:  # NAME=value in front of a command
            if redirecting_git_variable(m.group(1)):
                found.add(
                    f"`{m.group(1)}=` can point git at another repository or configuration,"
                    " past its hooks: drop it (use `git -C <dir>` to work in another folder)."
                )
            elif SWITCH_ENV.match(m.group(1)):
                switches.append(w)
            i += 1
            continue
        if w in KEYWORDS:
            i += 1
            continue
        if w == "function":  # function NAME { body }: the body is read as commands
            i += 2
            continue
        if name == "env":  # its own options and NAME=value, then the command it runs
            j = i + 1
            while j < len(words) and (words[j].startswith("-") or ASSIGNMENT.match(words[j])):
                m = ASSIGNMENT.match(words[j])
                if m and redirecting_git_variable(m.group(1)):
                    found.add(
                        f"`{m.group(1)}=` can point git at another repository or"
                        " configuration, past its hooks: drop it."
                    )
                elif m and SWITCH_ENV.match(m.group(1)):
                    switches.append(words[j])
                j += 2 if words[j] in ("-u", "--unset", "-C", "--chdir", "-S") else 1
            words, i = words[j:], 0
            continue
        if name in EXPORTERS or name == "read":
            for a in words[i + 1 :]:
                m = ASSIGNMENT.match(a) or re.fullmatch(r"([A-Za-z_]\w*)", a)
                if not m:
                    continue
                if redirecting_git_variable(m.group(1)):
                    found.add(
                        f"`{m.group(1)}` can point git at another repository or"
                        " configuration, past its hooks: drop it."
                    )
                elif SWITCH_ENV.match(m.group(1)) and name != "read":
                    found.exported_switches.append(m.group(1))
            return
        if name in WRAPPERS:
            # the wrapper's own options and values are skipped by looking for what it runs
            for j in range(i + 1, len(words)):
                inner = Path(words[j]).name
                if inner == "git" or inner in SHELLS or inner in ("eval", "trap"):
                    check_command(switches + words[j:], found, depth, whole)
                    return
            return
        names = [s.split("=", 1)[0] for s in switches]
        if name == "git":
            check_git(words[i + 1 :], found, depth, names)
        elif w.startswith("$") and words[i + 1 : i + 2] and words[i + 1] in GIT_VERBS:
            check_git(words[i + 1 :], found, depth, names)  # `$GIT commit ...`
        elif name == "eval":
            analyze(" ".join(words[i + 1 :]), found, depth + 1)
        elif name == "trap" and len(words) > i + 1:
            analyze(words[i + 1], found, depth + 1)
        elif name in SHELLS or name in ("source", "."):
            kind, text = (
                shell_script(words[i + 1 :])
                if name in SHELLS
                else ("file", " ".join(words[i + 1 :]))
            )
            if kind == "script":
                analyze(text, found, depth + 1)
            elif (kind == "stdin" or text.startswith("/dev/")) and names_a_commit(
                whole
            ):
                found.add(
                    "a shell fed its commands by a pipe or a redirection cannot be checked:"
                    f" {RUN_IT_DIRECTLY}"
                )
        return


def analyze(command, found, depth=0):
    if depth > MAX_DEPTH:
        found.add(f"this command nests shells too deeply to read: {RUN_IT_DIRECTLY}")
        return
    text, heredocs = strip_heredocs(command)
    outer, lifted = lift_substitutions(expand_ansi_strings(text))
    for words in simple_commands(outer):
        check_command(words, found, depth, command)
    for kind, body in heredocs:
        if kind == "script":
            analyze(body, found, depth + 1)
        else:
            lifted += lift_substitutions(body)[1]
    for inner in lifted:
        analyze(inner, found, depth + 1)


def problems_with(command, cwd="."):
    """(what is wrong with the command, whether it makes a commit that does not name the hooks)."""
    found = Findings(cwd)
    analyze(command, found)
    return found.problems, found.commits and found.unhooked


def hooks_path_problem(cwd):
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
    if cur == HOOKS_PATH:
        return None
    return (
        f"core.hooksPath is {('`' + cur + '`') if cur else 'not set'}, so git would skip the commit "
        f"gate: run `.claude/hooks/session-start.sh` (it sets core.hooksPath to `{HOOKS_PATH}`), "
        f"then commit again."
    )


def main():
    data = json.load(sys.stdin)
    tool_input = data.get("tool_input") or {}
    command = tool_input.get("command") or ""
    if "git" not in command and "GIT_" not in command:
        return 0
    cwd = data.get("cwd") or "."
    problems, commits = problems_with(command, cwd)
    if commits:
        p = hooks_path_problem(cwd)
        if p:
            problems.append(p)
    if problems:
        print("BLOCKED: " + " ".join(problems), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # noqa: BLE001 (a broken guard blocks and says so, it never waves a command through)
        print(f"BLOCKED: .claude/hooks/git_guard.py failed: {e!r}", file=sys.stderr)
        sys.exit(2)
