# Claude Development Architecture

Hooks and automation that enforce quality mechanically — agents don't need to remember these rules.

**Last updated:** 2026-03-30
**Update rule:** If you modify anything in `.claude/`, update this doc in the same commit.

## Hooks

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

## Agents

13 specialized agents in `.claude/agents/`. Key design decisions:

- **Reviewers are read-only** — reviewers that can edit code fix issues silently instead of flagging them, hiding problems
- **Haiku for fast checks** — `devex-reviewer` and `yagni-reviewer` run on Haiku for speed (seconds, not minutes)
- **Implementation agents have full tool access** — `backend-developer`, `frontend-developer`, `test-writer`

Run `ls .claude/agents/` for the full list. Each agent file contains its description and configuration.

## Skills

Spec-kitty workflow skills in `.claude/skills/` manage the feature development lifecycle: specify → plan → tasks → implement → review → merge. Installed from the external [spec-kitty](https://github.com/Priivacy-ai/spec-kitty) tool.
