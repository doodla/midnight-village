# Claude Development Architecture

How the autonomous development system works, why each piece exists, and how they connect.

**Last updated:** 2026-03-26
**Update rule:** This document MUST be updated whenever agents, skills, hooks, or the orchestration workflow changes. If you modify anything in `.claude/`, update this doc in the same commit.

## The Problem

Building a multiplayer game solo requires wearing too many hats — backend, frontend, game logic, testing, security review, UX. AI agents can do the implementation work, but they have documented failure modes:

- **They skip quality gates** when not mechanically enforced
- **They claim "done" prematurely** — implementing the easy 80%, skipping the hard 20%
- **They lose context** after compaction or session restarts
- **They propagate wrong assumptions** across multiple tasks before anyone notices
- **They over-engineer** simple things and under-engineer complex things

This system addresses each failure mode with a specific mechanism.

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                 YOU (Product Owner)               │
│  Set direction, approve plans, playtest           │
└───────────────────┬─────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│            /orchestrate SKILL                     │
│  Runs in main conversation. Coordinates agents.   │
│  Manages .plan/ state. Picks tasks. Routes work.  │
├─────────────────────────────────────────────────┤
│  Challenger checkpoints at key decisions          │
└──┬──────┬──────┬──────┬──────┬──────┬───────────┘
   │      │      │      │      │      │
   ▼      ▼      ▼      ▼      ▼      ▼
┌─────┐┌─────┐┌─────┐┌─────┐┌─────┐┌─────────┐
│plan-││back-││front││test-││resea-││security- │
│ner  ││end- ││end- ││writ-││rcher││reviewer  │
│     ││dev  ││dev  ││er   ││     ││          │
└─────┘└─────┘└─────┘└─────┘└─────┘└─────────┘
   │      │      │      │      │      │
   └──────┴──────┴──────┴──────┴──────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│              MECHANICAL ENFORCEMENT               │
│  Hooks run regardless of what the model decides   │
├─────────────────────────────────────────────────┤
│  SessionStart → bootstrap.sh (inject state)       │
│  PreToolUse   → pre-commit-gate.sh (block bad     │
│                  commits)                         │
│  PostToolUse  → post-edit-format.sh (auto-format) │
│  Stop         → verify-done.sh (tests must pass)  │
└─────────────────────────────────────────────────┘
```

## Why Each Piece Exists

### CLAUDE.md — Domain Knowledge

**What:** 121 lines encoding ONUW game mechanics, architectural principles, commands, and quality gates.

**Why:** Every agent inherits CLAUDE.md automatically. Without it, agents would need game rules explained in every prompt. With it, the `backend-developer` already knows about wave-based night phases, hidden information scoping, and the 12 ONUW roles before it writes a single line.

**Why not longer:** Research shows models follow ~150-200 instructions with reasonable consistency. The system prompt already consumes ~50. Keep CLAUDE.md under 150 lines or it gets ignored.

### Agents — Specialized Expertise

**What:** 13 agent definitions in `.claude/agents/`, each with a focused role, model selection, and tool restrictions.

| Agent | Model | Tools | Why This Config |
|-------|-------|-------|-----------------|
| `backend-developer` | Opus | All | Needs to write code, run tests |
| `frontend-developer` | Opus | All | Same |
| `test-writer` | Opus | All | Writes and runs tests |
| `planner` | Opus | No Edit | Creates plans, shouldn't touch code |
| `researcher` | Sonnet | No Edit/Write | Investigation only, fast + cheap |
| `security-reviewer` | Opus | No Edit/Write | Reviews code, shouldn't change it |
| `frontend-reviewer` | Opus | No Edit/Write | Same — review only |
| `backend-architect-reviewer` | Opus | All | Pre-existing, comprehensive review |
| `devex-reviewer` | Haiku | Read-only | Fast consistency check, seconds not minutes |
| `yagni-reviewer` | Haiku | Read-only | Fast simplicity check |
| `player-experience` | Sonnet | Read-only | UX review, doesn't need to edit |
| `challenger` | Opus (max effort) | Read-only | Catches process failures, needs deep reasoning |
| `monorepo-docs-architect` | Sonnet | All | Documentation work |

**Why these agents and not 15 or 5:**
- Implementation agents (3) cover the two stacks + tests. More would fragment context.
- Review agents (6) run in parallel on Haiku/Sonnet for speed. Cheap to run, expensive to skip.
- Planning/research (2) separate "what to build" from "how to build."
- Challenger (1) catches the meta-failures that code reviewers can't see.
- The critic role uses the built-in `socratic-architect` — no need for a custom agent.

**Why tool restrictions:** Reviewers that can edit code will fix issues silently instead of flagging them. This hides problems. Read-only reviewers are forced to surface issues explicitly.

### Skills — Workflow Coordination

**What:** 4 skills that run in the main conversation context.

| Skill | Purpose |
|-------|---------|
| `/orchestrate` | Main loop — assess state, pick round, coordinate agents, manage .plan/ |
| `/design-review` | Focused design review round with parallel reviewers |
| `/code-review` | Focused code review round with parallel reviewers |
| `/headless-orchestrate` | Drives all spec-kitty WPs to completion via headless `claude -p` sessions |

**Why skills and not agents:** Skills run in the main conversation, which is the only context that can spawn agents. An orchestrator-as-agent couldn't coordinate because agents can't spawn other agents. This is a hard constraint of Claude Code's architecture.

**`/headless-orchestrate` details:** Automates the full spec-kitty lifecycle after `/spec-kitty.specify` — planning, task breakdown, implementation, review, acceptance, and merge. Runs bash scripts that spawn separate `claude -p` processes. Stage 1 (planning) drives the `spec-kitty next` state machine through plan → tasks-outline → tasks-packages → tasks-finalize. Stage 2 (implementation) polls `orchestrator-api list-ready` and runs implement/review per WP. Uses Opus for planning and analysis (needs deeper reasoning), Sonnet for implementation/review (cost-effective). Features: analysis gate with same-session fix loop, POSIX-portable locking for parallel safety, automatic retry on review rejection, fully resumable. Scripts live in `.claude/skills/headless-orchestrate/scripts/`.

**Hardening (2026-03-26):** Several robustness fixes applied during the first real multi-WP orchestration run:
- **stderr isolation:** All `spec-kitty` CLI calls that capture output now redirect stderr to `$LOG_FILE` instead of `2>&1`. The original pattern caused spec-kitty warnings (e.g., constitution sync) to corrupt JSON output, breaking `jq` parsing. This was the root cause of spurious "invalid JSON" failures.
- **Infinite loop protection:** Phase 4 execution loop has `MAX_ROUNDS=50` and consecutive failure detection (3 all-fail rounds = abort). Prevents runaway loops when workspace creation fails repeatedly.
- **Bash 3.2 array safety:** Empty array expansions (`${IMPL_FAILED[@]}`, `${FAILED_WPS[@]}`) guarded with `${arr[@]+x}` pattern for macOS bash compatibility with `set -u`.
- **Orphan WP recovery:** Phase 3 preflight now handles WPs stranded in `for_review` or `approved` lanes from previous crashed runs — reviews orphans and transitions `approved` → `done`.
- **Feature slug propagation:** `--feature "$FEATURE_SLUG"` added to `implement-wp.sh` and `review-wp.sh` calls to `spec-kitty agent workflow`, preventing ambiguity when multiple features exist.
- **Constitution auto-sync:** Phase 0 preflight runs `spec-kitty constitution sync` automatically.
- **Known issue:** Spec-kitty worktree setup does not symlink `.kittify/constitution/` (filed as [spec-kitty#339](https://github.com/Priivacy-ai/spec-kitty/issues/339)). Workaround: the stderr isolation fix prevents the stale-hash warning from breaking JSON parsing.

**Why the challenger is in the skill, not a hook:** Hooks can't spawn agents — they can only run commands or prompts. The challenger needs to read files, understand context, and reason deeply. So it's an agent that the skill explicitly invokes at defined checkpoints.

### Hooks — Mechanical Enforcement

**What:** 4 shell scripts wired into Claude Code's lifecycle events.

| Hook | Event | What It Does | Why |
|------|-------|-------------|-----|
| `bootstrap.sh` | SessionStart | Reads STATUS.yaml + git log, injects into context | Models lose context after /clear and compaction. This mechanically recovers it. |
| `pre-commit-gate.sh` | PreToolUse (Bash) | Blocks `git commit` unless `just check` + `just test` pass. Blocks `--no-verify`. | Models skip quality gates. Documented in GitHub issues #20024, #18454. This makes skipping physically impossible. |
| `post-edit-format.sh` | PostToolUse (Edit\|Write) | Auto-formats Python with ruff after every edit | Formatting should never depend on the model remembering. |
| `verify-done.sh` | Stop | Blocks session end if tests fail and code changes exist | Models claim "done" prematurely. This catches it at the exit. |

**Why hooks over instructions:** Research finding: "Instructions are suggestions. Hooks are constraints." Models ignore CLAUDE.md instructions 5-15% of the time. Hooks fire 100% of the time. For quality gates, 95% compliance means broken builds.

### .plan/ — Persistent State

**What:** File-based state tracking that survives crashes, `/clear`, and context resets.

```
.plan/
├── STATUS.yaml        ← What's happening right now
├── BACKLOG.yaml       ← What's coming later (multiple milestones)
└── milestones/
    └── NNN-name/
        └── plan.yaml  ← Tasks with dependencies and acceptance criteria
```

**Why files over conversation:** Conversation context is lossy — it gets compacted, cleared, or forgotten. Files on disk persist. Git history provides an audit trail. The bootstrap hook reads these files at every session start to reconstruct state.

**Why YAML:** Human-readable, agent-readable, git-diffable. No schema enforcement needed — the structure is simple enough that format errors are unlikely and recoverable.

## How the Rounds Work

### Vision Breakdown (direction → milestones)

```
User gives direction
  → Planner creates milestone breakdown
  → Challenger reviews for missing pieces
  → Critic (socratic-architect) challenges assumptions
  → User approves
  → .plan/ created with milestones
```

### Design Review (plan → approved plan)

```
Plan exists but not approved
  → Parallel reviewers check feasibility (critic, stack experts, test expert)
  → Gaps go back to planner
  → Challenger checks for hard-to-reverse decisions
  → Max 3 rounds
  → User approves
```

### Task Execution (approved plan → code)

```
Pick next task from plan.yaml
  → Spawn implementation agent (backend-dev, frontend-dev, test-writer)
  → Agent implements, runs checks
  → Code review with parallel reviewers
  → Fix cycle (max 3 rounds)
  → Hook enforces: just check + just test pass
  → Commit
  → Update plan.yaml
  → Next task
```

### Milestone Completion

```
All tasks complete
  → Challenger reviews: did we actually meet success criteria?
  → Re-plan next milestone from backlog (what we learned may change scope)
  → User informed: "Milestone done. Ready to playtest?"
```

## What Can Go Wrong (And What Catches It)

| Failure Mode | What Catches It |
|---|---|
| Model skips `just test` | Pre-commit hook blocks commit |
| Model uses `--no-verify` | Pre-commit hook blocks that too |
| Model says "done" with failing tests | Stop hook blocks session end |
| Model loses context after compaction | Bootstrap hook re-injects state |
| Model misses edge cases in plan | Challenger agent at plan approval |
| Model builds on wrong assumption | Challenger + design review round |
| Model claims victory on 80% completion | Challenger at milestone completion |
| Model adds unrequested features | YAGNI reviewer in code review |
| Model leaks hidden game info | Security reviewer in code review |
| Model over-engineers simple code | YAGNI reviewer + devex reviewer |
| .plan/ state drifts from reality | Bootstrap hook compares git vs STATUS.yaml |

## What's NOT Enforced (And Why)

- **Which agents to spawn** — Model judgment. The orchestrate skill provides guidance but the right agents depend on what changed.
- **Plan quality** — Can't mechanically verify a plan is good. That's why the challenger + critic exist.
- **Code correctness beyond tests** — Tests are the enforcement mechanism for correctness. If tests are thin, the system is blind. Test coverage is the most important investment.
- **UX quality** — Can't automate "does this feel good?" That's why the user playtests.
