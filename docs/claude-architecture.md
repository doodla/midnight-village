# Claude Code setup

What `.claude/` enforces, so agents do not have to remember it. Update this file in the same
commit as any change under `.claude/`.

## Hooks (`.claude/settings.json`; timeouts in seconds)

| Event | Script | Does |
|---|---|---|
| PreToolUse Agent, Task, Workflow | `guardrails/runner.py` | Blocks a subagent not pinned to `opus` or `sonnet` with an effort, and forks. |
| PreToolUse Bash | `hooks/pre-commit-gate.sh` | On `git commit`: blocks `--no-verify`, checks the subject (`type(scope): description`) and the instruction links, then runs the suites the staged paths need, in parallel. |
| PostToolUse Edit, Write | `hooks/post-edit-format.sh` | Formats the edited `.py` (ruff) or `.dart` file. |
| Stop | `hooks/verify-done.sh` | With uncommitted `.py`/`.dart` work, runs the tests of the parts it touches before the agent may stop. |

Gate routing (`hooks/lib/gate.sh`, tested by `hooks/test_gate_routing.sh`): `backend/**`
and `docs/specs/onuw/recommended-setups.md` run backend `just check` and `just test`;
`frontend/**` runs `just analyze`, `just format-check` and `just test`; `contract_samples/**`
runs both; `.claude/**` (not skills) runs `just test-guardrails`; Markdown, `docs/**` and `tool/**` run
no suite; anything else runs both. A suite that already passed on the same content (gate or
Stop hook, recorded in the git dir) is not run again. Each suite is cut off after 1500 s,
which blocks.

## Guardrails (`.claude/guardrails/`)

`runner.py` runs the rules in `config.toml` (deny or warn only). The one rule,
`subagent_model_effort`, keeps subagents off the main session's model for cost. Adding a
rule: `.claude/guardrails/README.md`. Tests: `just test-guardrails`, also run by root
`just test`.

## Agents (`.claude/agents/`, each pins model and effort)

| Agent | Model, effort | Tools |
|---|---|---|
| `backend-developer`, `frontend-developer` | opus, high | all |
| `backend-code-reviewer`, `frontend-code-reviewer` | opus, high | read-only |
| `player-experience` | opus, high | read-only |

Reviewers are read-only (`disallowedTools`) so they report instead of fixing quietly.

## Skills (`.claude/skills/`)

Twelve third-party `flutter-*` skills (Flutter's generic guides on animation, architecture,
layout, concurrency, HTTP and JSON, navigation, accessibility, state, macOS setup, testing,
theming, databases), mirrored in `.agents/skills/`. Nothing here depends on them; keep or
remove them is the owner's call.
