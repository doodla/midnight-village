"""Subagents must pin an allowed model and an effort, explicitly or via their agent definition.

The top-tier model the main session runs on is too expensive for subagents, so
only the model families in `allowed_models` (config.toml; default opus, sonnet)
may be used. A model, alias or full id, is allowed when it contains one of those
words, case-insensitively. "haiku" is not allowed unless listed.

- Agent/Task calls: `model` and `effort` in the tool input, unless the
  subagent_type's definition sets them. The model actually used (the call's, else
  the definition's) must be allowed. Forks inherit the parent's model, so they are
  blocked unless `allow_forks = true`. Built-in types (general-purpose, Explore,
  Plan, ...) have no definition here, so they need `model` and `effort` in the call.
- Workflow scripts: each agent(...) call needs inline `model:` and `effort:`
  options, unless its inline `agentType:` names a definition that sets them. An
  inline `model:` must be an allowed string literal; a variable or expression can't
  be checked and is a violation. Saved workflows run by `name` aren't checked (no
  script in the call).
"""
import os
import re

from agent_defs import definition

EVENTS = {"PreToolUse"}
TOOLS = {"Agent", "Task", "Workflow"}

FIELDS = ("model", "effort")
DEFAULT_ALLOWED = ("opus", "sonnet")
AGENT_CALL = re.compile(r"(?<![\w$.])agent\s*\(")
AGENT_TYPE = re.compile(r"""(["']?)\bagentType\1\s*:\s*(["'`])([^"'`]+)\2""")
MODEL_KEY = re.compile(r"(?<![\w$.])model\s*:")
# A model value that is a plain string literal followed by the end of the option.
MODEL_LITERAL = re.compile(r"""\s*(?:'([^'\\\n]*)'|"([^"\\\n]*)"|`([^`$\\]*)`)\s*(?=[,}\n)]|$)""")
HINT = "See 'Who does what' in docs/dev/running-the-work.md for how to choose."


def allowed_models(opts):
    return [str(m).lower() for m in opts.get("allowed_models", DEFAULT_ALLOWED)]


def is_allowed(model, opts):
    return isinstance(model, str) and any(a in model.lower() for a in allowed_models(opts))


def allowed_text(opts):
    return " or ".join(f"`{m}`" for m in allowed_models(opts))


def fork_problem(where, opts):
    return (
        f"{where}: forks are not allowed. A fork inherits the parent session's model, which is too "
        f"expensive for a subagent. Use a fresh agent instead: drop subagent_type \"fork\" and set "
        f"model to {allowed_text(opts)} (plus effort)."
    )


def check(hook, opts):
    tool = hook.get("tool_name")
    tool_input = hook.get("tool_input") or {}
    if tool in ("Agent", "Task"):
        return check_agent(tool, tool_input, hook, opts)
    if tool == "Workflow":
        return check_workflow(tool_input, hook, opts)
    return []


def check_agent(tool, tool_input, hook, opts):
    agent_type = tool_input.get("subagent_type")
    if agent_type == "fork":
        return [] if opts.get("allow_forks", False) else [fork_problem(f"{tool} call", opts)]
    pins = definition(agent_type, hook)
    model = tool_input.get("model") or pins.get("model")
    missing = [k for k in FIELDS if not tool_input.get(k) and k not in pins]
    problems = []
    if missing:
        extra = f" Allowed models: {allowed_text(opts)}." if "model" in missing else ""
        problems.append(f"{tool} call must set {' and '.join(missing)}.{extra} {HINT}")
    if model and not is_allowed(model, opts):
        source = "the call" if tool_input.get("model") else f"the agent definition of {agent_type!r}"
        problems.append(
            f"{tool} call would run on model {model!r} (from {source}), which is not allowed. "
            f"Set model to {allowed_text(opts)} in the call. {HINT}"
        )
    return problems


def check_workflow(tool_input, hook, opts):
    script = tool_input.get("script")
    path = tool_input.get("scriptPath")
    if path:
        if not os.path.isabs(path) and hook.get("cwd"):
            path = os.path.join(hook["cwd"], path)
        try:
            with open(path) as f:
                script = f.read()
        except OSError:
            return []  # the Workflow tool reports a bad path itself
    if not script:
        return []

    code = mask(script)
    calls = []  # (where "agent" starts, where its "(" is, end of the call)
    for m in AGENT_CALL.finditer(code):
        start = m.end() - 1
        calls.append((m.start(), start, start + len(call_text(code, start))))

    problems = []
    pins = {}
    for name_at, start, end in calls:
        # Blank out nested agent(...) calls so their options can't satisfy this one.
        chars = list(code[start:end])
        for inner_at, _, inner_end in calls:
            if start < inner_at and inner_end <= end:
                for j in range(inner_at - start, inner_end - start):
                    if chars[j] != "\n":
                        chars[j] = " "
        call = "".join(chars)
        original = script[start:end]
        line = script.count("\n", 0, name_at) + 1
        snippet = " ".join(script[name_at:end].split())[:80]
        agent_type = inline_agent_type(original, call)
        if agent_type == "fork":
            if not opts.get("allow_forks", False):
                problems.append(fork_problem(f"line {line}", opts))
            continue
        if agent_type and agent_type not in pins:
            pins[agent_type] = definition(agent_type, hook)
        covered = pins.get(agent_type, {})
        missing = [k for k in FIELDS if k not in covered and not re.search(rf"\b{k}\s*:", call)]
        if missing:
            problems.append(f"line {line}: missing {', '.join(missing)} in {snippet}")
        inline = [(m.end(), original[m.end():]) for m in MODEL_KEY.finditer(call)]
        if inline:
            for _, rest in inline:
                lit = MODEL_LITERAL.match(rest)
                if not lit:
                    value = re.split(r"[,}\n]", rest, maxsplit=1)[0].strip()[:40]
                    problems.append(
                        f"line {line}: model must be a string literal such as {allowed_text(opts)}, "
                        f"not `{value}`, so it can be checked"
                    )
                    continue
                model = next(g for g in lit.groups() if g is not None)
                if not is_allowed(model, opts):
                    problems.append(f"line {line}: model {model!r} is not allowed (use {allowed_text(opts)})")
        elif covered.get("model") and not is_allowed(covered["model"], opts):
            problems.append(
                f"line {line}: agent definition {agent_type!r} runs on model {covered['model']!r}, "
                f"which is not allowed; pass model: {allowed_text(opts)} inline"
            )
    if not problems:
        return []
    return [
        "Every agent(...) call in a workflow script must pass inline `model:` "
        f"(a string literal, {allowed_text(opts)}) and `effort:` options "
        "(e.g. {model: 'sonnet', effort: 'low'}). Forks are not allowed.",
        *problems,
    ]


def inline_agent_type(original, masked):
    """Return the agentType option written as code in this call, ignoring prompt text."""
    for m in AGENT_TYPE.finditer(original):
        if not masked[m.start()].isspace():  # key is code, not text inside a string
            return m.group(3)
    return None


def mask(src):
    """Blank out comments and string/template text, keeping length and newlines.

    Code inside template ${...} is kept. This stops parens or `model:` inside
    prompts, and agent(...) inside comments, from confusing the checks.
    """
    out = list(src)
    stack = []  # '"', "'", '`', or '{' for code inside ${...}

    def blank(a, b):
        for j in range(a, min(b, len(src))):
            if out[j] != "\n":
                out[j] = " "

    i = 0
    while i < len(src):
        c = src[i]
        ctx = stack[-1] if stack else None
        if ctx in ('"', "'", "`"):
            if c == "\\":
                blank(i, i + 2)
                i += 2
                continue
            if c == ctx:
                stack.pop()
            elif ctx == "`" and src.startswith("${", i):
                stack.append("{")
                i += 2
                continue
            else:
                blank(i, i + 1)
        elif src.startswith("//", i):
            nl = src.find("\n", i)
            nl = len(src) if nl == -1 else nl
            blank(i, nl)
            i = nl
            continue
        elif src.startswith("/*", i):
            e = src.find("*/", i + 2)
            e = len(src) if e == -1 else e + 2
            blank(i, e)
            i = e
            continue
        elif c in ('"', "'", "`"):
            stack.append(c)
        elif c == "{" and ctx == "{":
            stack.append("{")
        elif c == "}" and ctx == "{":
            stack.pop()
        i += 1
    return "".join(out)


def call_text(code, start):
    """Return masked code from the opening paren at `start` to its match."""
    depth = 0
    for i in range(start, len(code)):
        if code[i] == "(":
            depth += 1
        elif code[i] == ")":
            depth -= 1
            if depth == 0:
                return code[start : i + 1]
    return code[start:]
