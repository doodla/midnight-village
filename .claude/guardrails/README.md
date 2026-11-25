# Guardrails

Claude Code hooks that keep agents on track. Built for unattended auto-mode runs.

Every hook goes through `runner.py`. It runs the enabled rules from `config.toml`
and can only **deny**, **warn** (add context for the agent), or stay **silent**.
It never returns `allow` (that could skip auto mode's own permission checks) or
`ask` (nobody is there to answer).

## Rules

| Rule | Does |
|---|---|
| `subagent_model_effort` | Agent/Task calls and workflow `agent(...)` calls must pin `model` and `effort`, in the call or through an agent definition in `.claude/agents/`. The model must be one of `allowed_models` (default `opus`, `sonnet`; the config also lists `haiku` on trial; matched by family, so full ids work). Forks are blocked unless `allow_forks = true`. |

## Operating

- **Modes** (`config.toml`): `enforce` denies, `warn` tells the agent but lets the call through, `off` skips the rule. Start new rules in `warn`.
- **Allowed models**: edit `allowed_models` in `config.toml`. An entry matches any model name containing it, case-insensitively.
- **Rule crashes**: with `on_error = "closed"`, a crash is reported at the rule's mode: an `enforce` rule denies the call, a `warn` rule only warns. With `"open"`, the crash is only logged.
- **Runner crashes** (bad stdin, bad `config.toml`, Python older than 3.11 with no `tomllib`):
  the runner prints what broke to stderr and exits 2, which blocks the call.
  `GUARDRAILS_OFF=runner` lets a crashed runner through.
  If `python3` itself is missing, the shell fails and `onFailure: "block"` in `settings.json` is what blocks.
- **Escape hatch**: `GUARDRAILS_OFF=rule_a,rule_b` disables rules for a session.
- **Decision log**: every warn and deny is appended to `logs/decisions.jsonl` (gitignored), or to `$GUARDRAILS_LOG` if set.

## Adding a rule

1. Add `rules/<name>.py` with `EVENTS`, optional `TOOLS`, and `check(hook, opts) -> list[str]` (an empty list means fine).
2. Add `[rules.<name>]` to `config.toml`, starting with `mode = "warn"`.
3. Make sure `.claude/settings.json` routes that event and those tools to the runner. A test checks the PreToolUse matcher.
4. Add tests and run `just test-guardrails`.

`runner.render` only implements PreToolUse output (deny or context). Add the output shape for other events when the first rule for them arrives.
