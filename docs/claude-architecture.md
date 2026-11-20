# Claude Development Architecture

Hooks and automation that enforce quality mechanically — agents don't need to remember these rules.

**Last updated:** 2026-11-20
**Update rule:** If you modify anything in `.claude/`, update this doc in the same commit.

## Hooks

### PreToolUse on Agent|Task|Workflow: Subagent Model Guardrail (`guardrails/runner.py`)

Blocks any subagent spawn that is not explicitly on an allowed model. The main session's top-tier model is too expensive for subagents, so only Opus and Sonnet are allowed.

- `model` and `effort` must be pinned, in the call or by the agent's `.claude/agents/*.md` frontmatter. The call's model wins over the definition's; whichever applies must be allowed.
- Allowed means the model name (alias or full id) contains an entry of `allowed_models` in `.claude/guardrails/config.toml` (`["opus", "sonnet"]`). `haiku` and `inherit` are blocked.
- `subagent_type: "fork"` is blocked (`allow_forks = false`): a fork inherits the main model. The message says to spawn a fresh opus/sonnet agent.
- Built-in types (general-purpose, Explore, Plan, ...) have no definition, so the call must carry the model.
- Workflow scripts: every `agent(...)` needs an inline `model:` string literal that is allowed. A variable or expression is a violation.
- Failure: a crash in the runner (bad stdin or config, Python < 3.11) prints the cause to stderr and exits 2, which blocks. `onFailure: "block"` covers a missing `python3`. Bypass for one session with `GUARDRAILS_OFF=runner`; a single rule with `GUARDRAILS_OFF=subagent_model_effort`.

**Change the allowed models:** edit `allowed_models` in `.claude/guardrails/config.toml`, and keep every `.claude/agents/*.md` `model:` inside it (a test checks this).

**Add a rule:** add `rules/<name>.py` (`EVENTS`, optional `TOOLS`, `check(hook, opts) -> list[str]`), a `[rules.<name>]` section in `config.toml` starting at `mode = "warn"`, route its tool in the `settings.json` matcher, add tests. Details in `.claude/guardrails/README.md`. Tests: `just test-guardrails` (also run by root `just test`).

**Why:** Cost control that depends on the agent remembering to pick a cheaper model does not hold. Ported from the planroom project's guardrails; its `context_restore` rule is not used here.

### PreToolUse on Bash: Commit Gate (`pre-commit-gate.sh`)

Intercepts every `git commit` command. Inspects staged files to determine which checks to run:
- **Backend files** (anything not under `frontend/`): runs `just check` + `just test` from `backend/`
- **Frontend files** (under `frontend/`): runs `just analyze` + `just format-check` + `just test` from `frontend/`
- **Both**: runs both sets of checks, reports all failures

Also blocks `--no-verify` — agents can't bypass the gate.

**Why:** Agents skip quality gates 5-15% of the time when relying on instructions alone. This makes skipping physically impossible. Selective checking avoids running frontend tests on backend-only commits and vice versa.

### PreToolUse on Bash: CWD Reset (`settings.json`)

Appends `cd /Users/doodla/Code/midnight-village` to every Bash command.

**Why:** Agents `cd` into subdirectories and lose track. This resets after every command.

### PostToolUse on Edit|Write: Auto-format (`post-edit-format.sh`)

After any `.py` or `.dart` file is edited or written, auto-formats silently:
- **Python**: `ruff format` + `ruff check --fix`
- **Dart**: `dart format`

**Why:** Formatting should never depend on the agent remembering. This runs automatically.

### Stop: Verify Done (`verify-done.sh`)

When Claude tries to end a session with uncommitted code changes, runs the appropriate tests:
- **Uncommitted `.py` files**: runs backend `just test`
- **Uncommitted `.dart` files**: runs frontend `just test`
- **Both**: runs both, reports all failures
- **Docs-only changes**: no block

Has a loop guard: if the stop hook already fired once (`stop_hook_active`), it passes through to prevent infinite loops.

**Why:** Prevents "I'm done" claims when tests are actually broken.

## What's Enforced vs Not

| Enforced (by hooks) | Not enforced (agent judgment) |
|---|---|
| Backend/frontend checks pass before commit (scoped to what changed) | Which agents to spawn for a task |
| No `--no-verify` bypass | Plan quality and completeness |
| Python and Dart auto-formatted after edits | Code correctness beyond what tests cover |
| Backend/frontend tests pass before session ends (scoped to what changed) | UX quality (requires playtesting) |
| CWD reset to project root after every command | Which review agents to run |
| Subagents pinned to Opus or Sonnet with an effort, no forks | Which of the two, and which effort |

## Agents

Specialized agents in `.claude/agents/`. Each pins `model:` (opus or sonnet) and `effort:` in its frontmatter, which the guardrail requires. Key design decisions:

- **Reviewers are read-only** — reviewers that can edit code fix issues silently instead of flagging them, hiding problems
- **Opus for developers and reviewers, Sonnet for docs and lookups** — Haiku is not allowed
- **Implementation agents have full tool access** — `backend-developer`, `frontend-developer`, `test-writer`

Run `ls .claude/agents/` for the full list. Each agent file contains its description and configuration.

## Skills

Spec-kitty workflow skills in `.claude/skills/` manage the feature development lifecycle: specify → plan → tasks → implement → review → merge. Installed from the external [spec-kitty](https://github.com/Priivacy-ai/spec-kitty) tool.
