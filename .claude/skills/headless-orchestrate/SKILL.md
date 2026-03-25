---
name: headless-orchestrate
description: Automate the full spec-kitty work package lifecycle using headless claude -p invocations. Drives all planned WPs through implement → review → done, then accepts and merges the feature.
---

# Headless Spec-Kitty Orchestration

Drive all remaining work packages to completion autonomously via `claude -p` headless sessions. Each WP goes through: implement → review → (retry if rejected) → done. After all WPs are done, the feature is accepted and merged.

## When to Use

After `/spec-kitty.tasks` has generated work packages and you want to execute them all without interactive sessions.

## Prerequisites

- spec-kitty tasks exist (`kitty-specs/*/tasks/WP*.md`)
- `claude` CLI available and authenticated
- `spec-kitty` CLI available
- `jq` available (for JSON parsing)

## How It Works

The orchestration runs as a bash script that spawns **separate headless `claude -p` sessions** for each implementation and review. Each session is fresh — it gets the full WP prompt from spec-kitty and runs autonomously.

### Lifecycle Per WP

```
planned → [implement-wp.sh] → for_review → [review-wp.sh] → done
                                                ↓ (rejected)
                                              planned → retry...
```

### Dependency-Driven Execution

WPs are grouped into **waves** based on their dependency graph. A WP only starts when all its dependencies are `done`. Independent WPs within a wave can optionally run in parallel.

### Analysis Gate

Before any implementation begins, `/spec-kitty.analyze` runs. If CRITICAL or HIGH issues are found, the **same session** continues with `--continue` to fix them in-place (it already has full context of what was wrong). Re-analyzes to confirm. Aborts if issues persist after 2 attempts.

## Configuration

All via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `FEATURE_SLUG` | auto-detected | Feature to orchestrate |
| `IMPL_MODEL` | `sonnet` | Model for implementation |
| `REVIEW_MODEL` | `sonnet` | Model for review |
| `ANALYZE_MODEL` | `opus` | Model for analysis gate |
| `IMPL_BUDGET` | `10.00` | Max USD per implementation session |
| `REVIEW_BUDGET` | `5.00` | Max USD per review session |
| `MAX_RETRIES` | `2` | Retries after review rejection |
| `MAX_IMPL_TURNS` | `30` | Max agentic turns for implementation |
| `MAX_REVIEW_TURNS` | `15` | Max agentic turns for review |
| `PARALLEL` | `false` | Run WPs within a wave in parallel |

## Running

From the repo root:

```bash
# Basic (sequential, auto-detect feature)
.claude/skills/headless-orchestrate/scripts/orchestrate.sh

# With options
PARALLEL=true IMPL_BUDGET=15.00 .claude/skills/headless-orchestrate/scripts/orchestrate.sh

# Explicit feature
.claude/skills/headless-orchestrate/scripts/orchestrate.sh 001-frontend-design-system-and-architecture
```

## What Claude Should Do

When the user invokes `/headless-orchestrate`:

1. Confirm the feature and WP count with the user
2. Ask if they want parallel execution or sequential (default: sequential)
3. Ask about budget caps if they have concerns
4. Run the script with `run_in_background` or with output piped to a log file:
   ```bash
   bash .claude/skills/headless-orchestrate/scripts/orchestrate.sh 2>&1 | tail -1
   ```
5. **Do NOT dump full script output into the conversation** — it will poison your context. Instead, check progress via `spec-kitty agent tasks status` and read the log file at `logs/orchestration-*.log` for details.
6. Report progress at wave boundaries by reading the log tail
7. If the script fails, diagnose from the log file in `logs/`

## Scripts

All scripts are in `.claude/skills/headless-orchestrate/scripts/`:

| Script | Purpose |
|--------|---------|
| `lib.sh` | Shared utilities (logging, locking, wave computation, JSON parsing) |
| `orchestrate.sh` | Main loop: preflight → analyze → waves → accept → merge |
| `analyze.sh` | Analysis gate with same-session fix loop via `--continue` |
| `implement-wp.sh` | Implements a single WP via `claude -p` in its worktree |
| `review-wp.sh` | Reviews a single WP via `claude -p` with strict reviewer persona |

## Resumability

The script reads state from `spec-kitty agent tasks list-tasks --json` on every invocation. WPs already in `done` are skipped. Stuck WPs in `doing` (from a previous crashed run) are reset to `planned`. This means you can kill the script and re-run it safely.

## Parallel Safety

When `PARALLEL=true`, multiple `claude -p` sessions run in separate worktrees (no code conflicts). Spec-kitty state mutations (move-task, mark-status) are serialized via file locking to prevent git auto-commit conflicts on the main branch.

## Context Management

**CRITICAL**: The orchestration script produces verbose output (each `claude -p` session can output thousands of lines). Do NOT let this flood your conversation context.

- Run the script in the background or pipe to log only
- Check progress via `spec-kitty agent tasks status` (compact kanban view)
- Read the tail of the log file for details: `tail -20 .claude/skills/headless-orchestrate/logs/orchestration-*.log`
- Only read full output when diagnosing a failure

## Cost Estimation

Rough per-WP costs with Sonnet (default):
- Implementation: $1-5 depending on complexity
- Review: $0.50-2
- Total per WP: ~$2-7
- 6 WPs: ~$12-42

With Opus (set `IMPL_MODEL=opus REVIEW_MODEL=opus`):
- Implementation: $3-15
- Review: $1-5
- 6 WPs: ~$30-120

Use `IMPL_BUDGET` and `REVIEW_BUDGET` to cap per-session spending.
