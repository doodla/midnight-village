# Claude Development Architecture

Hooks and automation that enforce quality mechanically — agents don't need to remember these rules.

**Last updated:** 2026-03-28
**Update rule:** If you modify anything in `.claude/`, update this doc in the same commit.

## Hooks

### PreToolUse on Bash: Commit Gate (`pre-commit-gate.sh`)

Intercepts every `git commit` command and blocks unless:
1. `just check` passes (lint + format + typecheck)
2. `just test` passes (all tests)

Also blocks `--no-verify` — agents can't bypass the gate.

**Why:** Agents skip quality gates 5-15% of the time when relying on instructions alone. This makes skipping physically impossible.

### PreToolUse on Bash: CWD Reset (`settings.json`)

Appends `cd /Users/doodla/Code/midnight-village` to every Bash command.

**Why:** Agents `cd` into subdirectories and lose track. This resets after every command.

### PostToolUse on Edit|Write: Auto-format (`post-edit-format.sh`)

After any `.py` file is edited or written, runs `ruff format` and `ruff check --fix` silently.

**Why:** Formatting should never depend on the agent remembering. This runs automatically.

### Stop: Verify Done (`verify-done.sh`)

When Claude tries to end a session with uncommitted `.py` or `.dart` changes, runs `just test`. Blocks completion if tests fail.

Has a loop guard: if the stop hook already fired once (`stop_hook_active`), it passes through to prevent infinite loops.

**Why:** Prevents "I'm done" claims when tests are actually broken.

## What's Enforced vs Not

| Enforced (by hooks) | Not enforced (agent judgment) |
|---|---|
| `just check` + `just test` pass before commit | Which agents to spawn for a task |
| No `--no-verify` bypass | Plan quality and completeness |
| Python auto-formatted after edits | Code correctness beyond what tests cover |
| Tests pass before session ends (if code changed) | UX quality (requires playtesting) |
| CWD reset to project root after every command | Which review agents to run |

## Agents

13 specialized agents in `.claude/agents/`. Key design decisions:

- **Reviewers are read-only** — reviewers that can edit code fix issues silently instead of flagging them, hiding problems
- **Haiku for fast checks** — `devex-reviewer` and `yagni-reviewer` run on Haiku for speed (seconds, not minutes)
- **Implementation agents have full tool access** — `backend-developer`, `frontend-developer`, `test-writer`

Run `ls .claude/agents/` for the full list. Each agent file contains its description and configuration.

## Skills

Spec-kitty workflow skills in `.claude/skills/` manage the feature development lifecycle: specify → plan → tasks → implement → review → merge. Installed from the external [spec-kitty](https://github.com/Priivacy-ai/spec-kitty) tool.
