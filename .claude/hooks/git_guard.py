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
SEPARATORS = {"&&", "||", ";", "|", "&", "(", ")", ";;", "|&"}
NEWLINE = "<<line-end-7f3a>>"  # stands for an unquoted line end while lexing
LIFTED = "lifted-7f3a"  # stands for a `$(...)` or backtick span whose body is read apart
SHELLS = {"bash", "sh", "zsh", "dash", "ksh"}
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
ASSIGNMENT = re.compile(r"([A-Za-z_]\w*)=")
ANSI_ESCAPES = {
    "n": "\n",
    "t": "\t",
    "r": "\r",
    "\\": "\\",
    "'": "'",
    '"': '"',
    "a": "",
    "e": "",
}
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


def first_word(segment):
    """The command name of a simple command's text so far ('' when it has none yet)."""
    for word in segment.split():
        if not ASSIGNMENT.match(word):
            return Path(word.strip("'\"")).name
    return ""


def strip_heredocs(command):
    """The command without its here-document bodies, and the bodies the shell would run or expand.

    One pass, the way the shell reads: a `<<WORD` counts only outside quotes (but inside a
    `$(...)` that is itself inside quotes, which is how a commit message is usually passed),
    and its body is the lines after that line, up to WORD. Returns (text, bodies), bodies as
    ("script", text) when the command that owns the `<<` is a shell (its body is run), else
    ("expanded", text) under an unquoted WORD (the shell runs its $(...) and backticks);
    a body under a quoted WORD is only words and is dropped.
    """
    out, bodies, pending = [], [], []
    stack = [""]  # the quote we are in, per `$(` level: "", "'" or '"'
    cmd_start = 0  # where the current simple command starts in `out`
    owner, owner_of = "", -1  # that command's name, once known
    i, n = 0, len(command)
    while i < n:
        ch = command[i]
        ctx = stack[-1]
        if ctx == "'":
            if ch == "'":
                stack[-1] = ""
        elif ch == "\\" and i + 1 < n:
            out.append(ch)
            i += 1
            ch = command[i]
        elif command.startswith("$((", i):
            j = command.find("))", i)
            j = n if j < 0 else j + 2
            out.append(command[i:j])  # arithmetic: `<<` is a shift there
            i = j
            continue
        elif command.startswith("$(", i):
            stack.append("")
            out.append("$")
            i += 1
            ch = "("
            cmd_start = len(out) + 1
        elif ctx == '"':
            if ch == '"':
                stack[-1] = ""
        elif ch in "'\"":
            stack[-1] = ch
        elif ch == ")" and len(stack) > 1:
            stack.pop()
        elif command.startswith("<<", i) and not command.startswith("<<<", i) and command[i - 1 : i] != "<":
            m = re.compile(r"<<(-?)\s*(['\"\\]?)([A-Za-z_][\w.-]*)").match(command, i)
            if m:
                if owner_of != cmd_start or not owner:
                    owner, owner_of = first_word("".join(out[cmd_start:])), cmd_start
                runs = owner in SHELLS or owner in ("source", ".")
                pending.append((m.group(3), bool(m.group(1)), bool(m.group(2)), runs))
        elif ch == "\n":
            cmd_start = len(out) + 1
            if pending:
                out.append("\n")
                i += 1
                for word, dash, quoted, runs in pending:
                    body = []
                    while i < n:
                        end = command.find("\n", i)
                        end = n if end < 0 else end
                        line = command[i:end]
                        i = end + 1
                        if (line.lstrip("\t") if dash else line) == word:
                            break
                        body.append(line)
                    if runs:
                        bodies.append(("script", "\n".join(body)))
                    elif not quoted:
                        bodies.append(("expanded", "\n".join(body)))
                pending = []
                continue
        elif ch in ";&|(":
            cmd_start = len(out) + 1
        out.append(ch)
        i += 1
    return "".join(out), bodies


def expand_ansi_strings(text):
    """`$'...'` strings (outside other quotes) as ordinary quoted words, escapes decoded."""
    out, i, n = [], 0, len(text)
    single = double = False
    while i < n:
        ch = text[i]
        if single:
            single = ch != "'"
        elif double:
            if ch == "\\" and i + 1 < n:
                out.append(ch)
                i += 1
                ch = text[i]
            elif ch == '"':
                double = False
        elif ch == "\\" and i + 1 < n:
            out.append(ch)
            i += 1
            ch = text[i]
        elif ch == "$" and text[i + 1 : i + 2] == "'":
            j, word = i + 2, []
            while j < n and text[j] != "'":
                if text[j] == "\\" and j + 1 < n:
                    j += 1
                    m = re.match(r"x[0-9a-fA-F]{1,2}|[0-7]{1,3}|u[0-9a-fA-F]{1,4}", text[j:])
                    if m:
                        digits = m.group(0)
                        base = 8 if digits[0].isdigit() else 16
                        word.append(chr(int(digits.lstrip("xu") or "0", base)))
                        j += len(digits)
                        continue
                    word.append(ANSI_ESCAPES.get(text[j], text[j]))
                else:
                    word.append(text[j])
                j += 1
            out.append(shlex.quote("".join(word)))
            i = j + 1
            continue
        elif ch == "'":
            single = True
        elif ch == '"':
            double = True
        out.append(ch)
        i += 1
    return "".join(out)


def lift_substitutions(text):
    """(the text with each `$(...)` and backtick span replaced by a plain word, their bodies).

    The bodies are what the shell would run (those inside single quotes are only words and
    stay). Lifting them out first means a quote or a parenthesis inside one cannot confuse
    the reading of the command around it.
    """
    out, bodies, i, n = [], [], 0, len(text)
    single = double = False
    while i < n:
        ch = text[i]
        if single:
            single = ch != "'"
        elif ch == "\\" and i + 1 < n:
            out.append(ch)
            i += 1
            ch = text[i]
        elif ch == "'" and not double:
            single = True
        elif ch == '"':
            double = not double
        elif ch == "`":
            j = text.find("`", i + 1)
            j = n if j < 0 else j
            bodies.append(text[i + 1 : j])
            out.append(LIFTED)
            i = j + 1
            continue
        elif ch == "$" and text[i + 1 : i + 2] == "(":
            # to the matching parenthesis; a quoted one inside does not count
            depth, j, quote = 1, i + 2, ""
            while j < n and depth:
                c = text[j]
                if quote:
                    if c == "\\" and quote == '"':
                        j += 1
                    elif c == quote:
                        quote = ""
                elif c == "\\":
                    j += 1
                elif c in "'\"":
                    quote = c
                else:
                    depth += {"(": 1, ")": -1}.get(c, 0)
                j += 1
            bodies.append(text[i + 2 : j - 1 if not depth else j].strip("()"))
            out.append(LIFTED)
            i = j
            continue
        out.append(ch)
        i += 1
    return "".join(out), bodies


def mark_line_ends(text):
    """Unquoted line ends become a separator word; comments are dropped."""
    out, i, n = [], 0, len(text)
    single = double = False
    while i < n:
        ch = text[i]
        if single:
            single = ch != "'"
        elif double:
            if ch == "\\" and i + 1 < n:
                out.append(ch)
                i += 1
                ch = text[i]
            elif ch == '"':
                double = False
        elif ch == "\\" and i + 1 < n:
            if text[i + 1] == "\n":  # a continued line
                out.append(" ")
                i += 2
                continue
            out.append(ch)
            i += 1
            ch = text[i]
        elif ch == "'":
            single = True
        elif ch == '"':
            double = True
        elif ch == "#" and (i == 0 or text[i - 1] in " \t\n;&|("):
            while i < n and text[i] != "\n":
                i += 1
            continue
        elif ch == "\n":
            out.append(f" {NEWLINE} ")
            i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def simple_commands(text):
    """The words of each command the shell would run, in order."""
    try:
        lex = shlex.shlex(mark_line_ends(text), posix=True, punctuation_chars=";&|()")
        lex.whitespace_split = True
        lex.commenters = ""
        tokens = list(lex)
    except ValueError:  # an open quote: read it roughly, never skip it
        tokens = re.sub(r"([;&|()])", r" \1 ", text.replace("\n", f" {NEWLINE} ")).split()
    commands, current = [], []
    for tok in tokens:
        # `()` and the like arrive as one word of punctuation: a separator too
        if tok in SEPARATORS or tok == NEWLINE or (tok and not tok.strip(";&|()")):
            if current:
                commands.append(current)
            current = []
        else:
            current.append(tok)
    if current:
        commands.append(current)
    return commands


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
    except Exception as e:  # a broken guard blocks, it never waves a command through
        print(f"BLOCKED: .claude/hooks/git_guard.py failed: {e!r}", file=sys.stderr)
        sys.exit(2)
