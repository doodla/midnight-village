"""Reads a Bash command as the shell would, for the git guard (git_guard.py).

Text in, simple commands out: here-documents taken out, `$'...'` strings
expanded, `$(...)` and backtick spans lifted to be read apart, line ends
marked, and the words of each simple command. Nothing here knows about git.
"""

import re
import shlex
from pathlib import Path

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
ASSIGNMENT = re.compile(r"([A-Za-z_]\w*)=")
LIFTED = "lifted-7f3a"  # stands for a `$(...)` or backtick span whose body is read apart
NEWLINE = "<<line-end-7f3a>>"  # stands for an unquoted line end while lexing
SEPARATORS = {"&&", "||", ";", "|", "&", "(", ")", ";;", "|&"}
SHELLS = {"bash", "sh", "zsh", "dash", "ksh"}


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
