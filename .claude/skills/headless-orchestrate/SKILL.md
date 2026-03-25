---
name: headless-orchestrate
description: Automate the full spec-kitty lifecycle after /spec-kitty.specify — plans, generates tasks, implements, reviews, and merges, all via headless claude -p sessions.
---

# Headless Spec-Kitty Orchestration

Drive an entire feature from spec to merged code autonomously. After the user runs `/spec-kitty.specify`, this script handles everything else: planning, task breakdown, analysis, implementation, review, acceptance, and merge — all via headless `claude -p` sessions.

## When to Use

After `/spec-kitty.specify` has created a spec.md and you want the rest done without interactive sessions.

Also works if you've already completed some phases (e.g., plan.md already exists) — the `spec-kitty next` state machine picks up where you left off.

## Prerequisites

- A feature with at least `spec.md` in `kitty-specs/*/`
- `claude` CLI available and authenticated
- `spec-kitty` CLI available
- `jq` available (for JSON parsing)

## How It Works

The orchestration runs in two stages:

### Stage 1: Planning (via `spec-kitty next` loop)

The script calls `spec-kitty next --agent claude` repeatedly. Each call returns the next planning action (plan, tasks-outline, tasks-packages, tasks-finalize) with a prompt file. The script feeds each prompt to a headless `claude -p` session, reports success, and advances to the next step. This continues until the state machine reaches the `implement` phase.

```
spec.md → [plan] → [tasks-outline] → [tasks-packages] → [tasks-finalize] → WPs ready
```

### Stage 2: Implementation (via `orchestrator-api list-ready` polling)

Each round, `orchestrator-api list-ready` returns WPs whose dependencies are all `done`. The orchestrator implements and reviews those WPs, then polls again. This repeats until no WPs remain.

```
planned → [implement-wp.sh] → for_review → [review-wp.sh] → done
                                                ↓ (rejected)
                                              planned → retry...
```

### Analysis Gate

Between planning and implementation, `/spec-kitty.analyze` runs. If CRITICAL or HIGH issues are found, the **same session** continues with `--resume` to fix them in-place. Re-analyzes to confirm. Aborts if issues persist after 2 attempts.

## Configuration

All via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `FEATURE_SLUG` | auto-detected | Feature to orchestrate |
| `PLANNING_MODEL` | `opus` | Model for planning steps |
| `IMPL_MODEL` | `sonnet` | Model for implementation |
| `REVIEW_MODEL` | `sonnet` | Model for review |
| `ANALYZE_MODEL` | `opus` | Model for analysis gate |
| `PLANNING_BUDGET` | `5.00` | Max USD per planning session |
| `IMPL_BUDGET` | `10.00` | Max USD per implementation session |
| `REVIEW_BUDGET` | `5.00` | Max USD per review session |
| `MAX_RETRIES` | `2` | Retries after review rejection |
| `PARALLEL` | `false` | Run WPs within a round in parallel |

## Running

From the repo root:

```bash
# Basic (sequential, auto-detect feature)
.claude/skills/headless-orchestrate/scripts/orchestrate.sh

# With options
PARALLEL=true IMPL_BUDGET=15.00 .claude/skills/headless-orchestrate/scripts/orchestrate.sh

# Explicit feature
.claude/skills/headless-orchestrate/scripts/orchestrate.sh 002-night-phase
```

## What Claude Should Do

When the user invokes `/headless-orchestrate`:

1. Confirm the feature slug with the user
2. Ask if they want parallel execution or sequential (default: sequential)
3. Ask about budget caps if they have concerns
4. Run the script with `run_in_background` and `QUIET=true` to suppress stdout:
   ```bash
   QUIET=true bash .claude/skills/headless-orchestrate/scripts/orchestrate.sh FEATURE_SLUG
   ```

### CRITICAL: Protecting Your Context Window

The script writes all progress to a log file. Do NOT let verbose output into your context:

- **When the background task completes:** Note the exit code only. IGNORE the stdout in the notification — it duplicates the log file.
- **To check progress mid-run:** Run `spec-kitty agent tasks status` (compact) or `tail -10 .claude/skills/headless-orchestrate/logs/orchestration-*.log`
- **To diagnose failures:** Run `tail -30 .claude/skills/headless-orchestrate/logs/orchestration-*.log` — NOT the full file
- **To check stderr from a failed claude -p session:** Run `tail -20 .claude/skills/headless-orchestrate/logs/WP01-impl.stderr` — NEVER `cat` the full file
- **NEVER read:** Full log files, full stderr files, or full claude -p output. Use `tail` with a line limit.

### Handling Exit Codes

| Exit code | Meaning | What to do |
|---|---|---|
| `0` | Success — feature merged | Run `tail -10` on the log to report completion and total cost |
| `10` | **Decision needed** — spec-kitty needs user input | Read `logs/decision-needed.json`, present the question, then resume (see below) |
| `1` | Failure | Run `tail -30` on the log and relevant `.stderr` files to diagnose |

### When the Script Pauses for a Decision (exit 10)

During planning, `spec-kitty next` may return a `decision_required` — a design question that cannot be answered autonomously (e.g., "should we use WebSockets or polling for real-time updates?").

When this happens:

1. Read the decision context (this file is small and safe to read fully):
   ```bash
   cat .claude/skills/headless-orchestrate/logs/decision-needed.json
   ```
2. Present the question and options to the user naturally in conversation
3. After the user answers, submit their answer to spec-kitty:
   ```bash
   spec-kitty next --agent claude --feature FEATURE_SLUG \
     --answer "USER_ANSWER" --decision-id "DECISION_ID"
   ```
4. Re-run the orchestration script — it will pick up where it left off:
   ```bash
   QUIET=true bash .claude/skills/headless-orchestrate/scripts/orchestrate.sh FEATURE_SLUG
   ```

The script is fully resumable. `spec-kitty next` returns the current state on every call, so re-running after a decision skips all completed planning steps automatically.

## Scripts

All scripts are in `.claude/skills/headless-orchestrate/scripts/`:

| Script | Purpose |
|--------|---------|
| `lib.sh` | Shared utilities (logging, locking, orchestrator-api wrappers) |
| `orchestrate.sh` | Main loop: plan → analyze → implement → review → accept → merge |
| `analyze.sh` | Analysis gate with same-session fix loop via `--resume` |
| `implement-wp.sh` | Implements a single WP via `claude -p` in its worktree |
| `review-wp.sh` | Reviews a single WP via `claude -p` with strict reviewer persona |

## Resumability

The script is resumable at every phase:
- **Planning:** `spec-kitty next` returns the current state, so re-running skips completed planning steps
- **Implementation:** `orchestrator-api list-ready` only returns WPs not yet done; stuck WPs are reset during preflight
- Kill the script and re-run it safely at any point

## Parallel Safety

When `PARALLEL=true`, multiple `claude -p` sessions run in separate worktrees (no code conflicts). Spec-kitty state mutations (move-task, mark-status) are serialized via file locking to prevent git auto-commit conflicts on the main branch.

## Context Management

**CRITICAL**: The orchestration script produces verbose output (each `claude -p` session can output thousands of lines). Do NOT let this flood your conversation context.

- Run the script in the background or pipe to log only
- Check progress via `spec-kitty agent tasks status` (compact kanban view)
- Read the tail of the log file for details: `tail -20 .claude/skills/headless-orchestrate/logs/orchestration-*.log`
- Only read full output when diagnosing a failure

## Cost Estimation

Rough costs (planning=Opus, impl/review=Sonnet):
- Planning (4 steps, Opus): ~$5-20
- Implementation per WP: $1-5
- Review per WP: $0.50-2
- Analysis gate: $1-3
- 6 WPs total: ~$15-50

With Opus (set all `*_MODEL=opus`):
- 6 WPs total: ~$40-150

Use `*_BUDGET` variables to cap per-session spending.
