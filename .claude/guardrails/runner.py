#!/usr/bin/env python3
"""Single entry point for every guardrail hook.

Reads the hook input on stdin, runs each enabled rule that applies to the
event and tool, logs what fired, and prints the hook's JSON decision.

Agents run in auto mode, so the runner only ever denies, warns, or stays
silent. It never returns "allow" (that could skip auto mode's own permission
checks) or "ask" (nobody is there to answer).

Config: config.toml next to this file. Per rule:
  mode     = "enforce" | "warn" | "off"
  on_error = "closed" (a crash is reported at the rule's mode: denied in
             enforce, a warning in warn) | "open" (the crash is only logged)
Escape hatch: GUARDRAILS_OFF=rule_a,rule_b disables rules for one session;
GUARDRAILS_OFF=runner also lets a crashed runner through (default: a crash blocks, exit 2).
"""
import datetime
import importlib
import json
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

LOG_PATH = Path(os.environ.get("GUARDRAILS_LOG") or HERE / "logs" / "decisions.jsonl")


def load_config(path=HERE / "config.toml"):
    import tomllib  # Python 3.11+; imported here so a missing module is reported by main()

    with open(path, "rb") as f:
        return tomllib.load(f)


def disabled_by_env():
    return {r.strip() for r in os.environ.get("GUARDRAILS_OFF", "").split(",") if r.strip()}


def applies(rule, event, tool):
    if event not in rule.EVENTS:
        return False
    return not getattr(rule, "TOOLS", None) or tool in rule.TOOLS


def evaluate(hook, config):
    """Run the rules and return (denials, warnings, records) for this hook input."""
    event = hook.get("hook_event_name")
    tool = hook.get("tool_name")
    off = disabled_by_env()
    denials, warnings, records = [], [], []

    for name, opts in config.get("rules", {}).items():
        mode = opts.get("mode", "warn")
        if mode == "off" or name in off:
            continue
        try:
            rule = importlib.import_module(f"rules.{name}")
            if not applies(rule, event, tool):
                continue
            problems = rule.check(hook, opts)
        except Exception as e:  # noqa: BLE001 - a rule bug must not take down the runner
            problems = [f"guardrail rule {name} crashed: {type(e).__name__}: {e}"]
            if opts.get("on_error", "closed") == "open":
                records.append({"rule": name, "action": "error_open", "problems": problems})
                continue
        if not problems:
            continue
        message = f"[{name}] " + "\n".join(problems)
        if mode == "enforce":
            denials.append(message)
            action = "deny"
        else:
            warnings.append(message)
            action = "warn"
        records.append({"rule": name, "action": action, "problems": problems})

    return denials, warnings, records


def render(event, denials, warnings):
    """Build the hook's stdout JSON, or None to stay silent."""
    if event != "PreToolUse":
        # Add other events' output shapes here when the first rule for them arrives.
        return None
    out = {"hookEventName": event}
    if denials:
        out["permissionDecision"] = "deny"
        out["permissionDecisionReason"] = "Blocked by guardrails:\n" + "\n\n".join(denials)
    if warnings:
        out["additionalContext"] = "Guardrail warnings:\n" + "\n\n".join(warnings)
    if len(out) == 1:
        return None
    return {"hookSpecificOutput": out}


def log(hook, records):
    if not records:
        return
    try:
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        with open(LOG_PATH, "a") as f:
            for r in records:
                f.write(json.dumps({
                    "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(),
                    "session_id": hook.get("session_id"),
                    "permission_mode": hook.get("permission_mode"),
                    "event": hook.get("hook_event_name"),
                    "tool": hook.get("tool_name"),
                    **r,
                }) + "\n")
    except OSError:
        pass  # logging must never change the decision


def run():
    hook = json.load(sys.stdin)
    denials, warnings, records = evaluate(hook, load_config())
    log(hook, records)
    out = render(hook.get("hook_event_name"), denials, warnings)
    if out:
        print(json.dumps(out))


def main():
    try:
        run()
    except Exception as e:  # noqa: BLE001 - config, import, stdin or Python-version problems
        if "runner" in disabled_by_env():
            return 0
        # Exit 2 blocks the tool call and Claude Code shows stderr to the agent. A broken
        # runner must never silently allow a spawn, and the message says how to fix it.
        print(
            f"Guardrails runner crashed ({type(e).__name__}: {e}) on python "
            f"{sys.version.split()[0]} (needs 3.11+ for tomllib). Subagent spawns are blocked "
            f"until it is fixed. Check .claude/guardrails/config.toml and runner.py; to bypass "
            f"for one session, start Claude Code with GUARDRAILS_OFF=runner.",
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
