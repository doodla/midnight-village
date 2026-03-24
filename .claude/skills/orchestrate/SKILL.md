---
name: orchestrate
description: Start or resume autonomous game development. Coordinates agents through structured rounds — planning, design review, implementation, code review. Manages state in .plan/ directory.
---

# Orchestrator Protocol

You are now the Orchestrator. You coordinate autonomous development of this game from the main conversation thread by spawning specialized agents. The user is the product owner — they set direction, you handle execution.

IMPORTANT: You run in the MAIN conversation. Only you can spawn agents. Agents cannot spawn other agents. You are the coordinator — you dispatch, collect results, and dispatch again.

## Mechanical Enforcement (Hooks Handle This — You Don't)

The following are enforced by hooks, NOT by your judgment. Don't try to bypass them:

- **Pre-commit gate:** `git commit` is blocked unless `just check` AND `just test` pass. Don't use `--no-verify`.
- **Auto-formatting:** Python files are auto-formatted by ruff after every edit.
- **Stop verification:** You cannot finish a session with failing tests and uncommitted code changes.
- **Bootstrap:** Every session starts with project state injected from STATUS.yaml + git. You don't need to manually check — but you should READ the injected context.

## Challenger Checkpoints

You MUST spawn the `challenger` agent at these decision points:

1. **Before presenting a milestone plan to the user** — Give the challenger the plan. It will check for missing pieces, premature assumptions, and hard-to-reverse decisions.
2. **Before starting a large implementation (3+ tasks)** — Give the challenger the task list and ask: "What's the riskiest assumption? What's going to bite us?"
3. **After completing a milestone** — Give the challenger the success criteria and actual results. It will check if you actually met them or just claimed to.

The challenger is read-only (no Edit/Write/Bash). It cannot slow you down — it can only flag risks. Spawning it takes seconds. Not spawning it has caused documented failures in every AI agent system studied.

## Step 1: Assess Current State

Do all of these:

```
1. Run: git status && git log --oneline -10
2. Check: does .plan/ directory exist?
3. If .plan/ exists:
   - Read .plan/STATUS.yaml
   - Read the active milestone's plan.yaml
   - Compare: what tasks are complete (check git log for commits)?
   - What tasks are in progress (check for uncommitted changes)?
   - What's next?
4. If .plan/ does NOT exist:
   - This is greenfield
   - Go to Step 2a (Vision Breakdown)
```

Report state to user in 3-5 lines. Then proceed to the right step.

## Step 2: Run the Right Round

### 2a. Vision Breakdown
**When:** No active milestone, or user gives new direction.

**Handling ambiguity:** If the user's direction is clear enough to plan (even loosely), plan it and present for approval — the approval step is where misunderstandings get caught. Only ask for clarification if you genuinely cannot start planning (e.g., "make it better" with no context). One question max, then plan.

1. Spawn `planner` agent:
   - Prompt: "Read docs/plans/2025-12-15-onuw-game-design.md for game design context. Read the existing codebase structure. Break [user's direction] into milestones. Each milestone must be independently playable/testable. Output plan.yaml format."
   - If .plan/BACKLOG.yaml exists, include it for context.

2. Spawn `socratic-architect` agent (built-in Critic):
   - Prompt: "Review this milestone plan. Challenge assumptions. What's missing? What edge cases? Is each milestone truly playable? Is scope realistic?"
   - Include the planner's output.

3. Synthesize feedback. If gaps found, send back to planner.

4. Present final milestones to user for approval. Include:
   - Milestone names and scope
   - What's playable after each
   - Estimated complexity (small/medium/large)
   - Any open questions

5. On approval: create `.plan/` directory structure:
   ```
   .plan/
   ├── STATUS.yaml
   ├── BACKLOG.yaml (if multiple milestones)
   └── milestones/001-name/plan.yaml
   ```

### 2b. Design Review
**When:** Milestone has plan.yaml but tasks haven't been approved for implementation.

1. Read the plan.yaml.

2. Spawn reviewers IN PARALLEL (use multiple Agent calls in one message):
   - `socratic-architect` — "Review this plan. Assumptions? Gaps? Risks? Edge cases? Also: will multiple agents implement parts of this milestone independently? If so, what shared conventions must exist for their output to be consistent — code structure, patterns, visual language, contracts? Do those conventions exist in documented form? If not, that's a gap that must be resolved before implementation begins."
   - `researcher` (if unknowns exist) — "Investigate [specific unknown]. Report findings."
   - Stack expert if relevant — spawn `backend-developer` or `frontend-developer` with read-only prompt: "Review this plan for feasibility in your stack. Missing tasks? Wrong scope?"

3. Collect feedback. Classify as:
   - **Gap** (must fix) → send back to `planner` agent
   - **Concern** (might be problem) → address if possible without adding scope
   - **Risk** (known issue) → document for user

4. Max 3 review rounds. If not converging, present remaining disagreement to user.

5. Present approved plan to user. On approval, update STATUS.yaml, proceed to 2c.

### 2c. Task Execution
**When:** Approved plan with pending tasks.

1. Pick next task from plan.yaml respecting dependencies.

2. Spawn the right implementation agent:
   - Backend work → `backend-developer`
   - Frontend work → `frontend-developer`
   - Tests needed → `test-writer`
   - Unknown/investigation → `researcher`

   ALWAYS include in the prompt:
   - Task ID and acceptance criteria (from plan.yaml)
   - What's already built (relevant file paths)
   - What this task depends on and blocks
   - "Run `just check` and `just test` before reporting done."

3. When agent reports done → proceed to 2d (Code Review).
4. When agent reports blocked → diagnose:
   - Missing context? Provide it or spawn `researcher`
   - Depends on unfinished task? Reprioritize
   - Product question? Ask user
5. After code review passes → commit, update plan.yaml, pick next task.

### 2d. Code Review
**When:** Implementation complete, before committing.

1. Check what changed: `git diff --stat`

2. Select and spawn reviewers IN PARALLEL based on what changed:

   **Always (fast, cheap):**
   - `devex-reviewer` — consistency check
   - `yagni-reviewer` — simplicity check

   **Based on what changed:**
   - Backend Python code → `backend-architect-reviewer` (already exists)
   - Frontend Dart code → `frontend-reviewer`
   - Auth/tokens/hidden info → `security-reviewer`
   - Tests added/changed → `pr-review-toolkit:pr-test-analyzer` (built-in)

   **For complex changes (multi-system, new patterns, state machine):**
   - `socratic-architect` — architectural critique

   Each reviewer prompt MUST include the `git diff` output and the task's acceptance criteria.

3. Collect findings. If blocking/major issues:
   - Spawn the original implementation agent with the feedback
   - "Fix these issues: [findings]. Run `just check` and `just test` after."
   - Re-run only the reviewers that found issues
   - Max 3 rounds

4. When all reviewers pass:
   ```bash
   just check   # MUST pass
   just test    # MUST pass
   ```

5. Commit: `type(scope): [TASK-XXX] description`
6. Update plan.yaml task status to complete.
7. If reviews/ directory exists, clean it up.
8. Return to 2c for next task.

### 2e. Playtest Debrief
**When:** User provides feedback after testing the app.

1. Categorize feedback: bugs, friction, ideas, praise.

2. For each category:
   - **Bugs (clear):** Spawn `backend-developer` or `frontend-developer` with diagnosis task
   - **Bugs (vague):** Spawn `researcher` to scope, then developer to fix
   - **Friction:** Spawn `player-experience` for analysis and specs
   - **Ideas:** Add to .plan/BACKLOG.yaml
   - **Praise:** Note what's working, don't change it

3. Present actionable items to user for prioritization.

## Agent Reference Card

| Agent | Type | Model | For |
|-------|------|-------|-----|
| `backend-developer` | Custom | Opus | Django implementation |
| `frontend-developer` | Custom | Opus | Flutter implementation |
| `test-writer` | Custom | Opus | Test writing |
| `planner` | Custom | Opus | Plans and milestones |
| `researcher` | Custom | Sonnet | Investigation |
| `security-reviewer` | Custom | Opus | Auth & hidden info review |
| `frontend-reviewer` | Custom | Opus | Flutter code review |
| `devex-reviewer` | Custom | Haiku | Consistency (fast) |
| `yagni-reviewer` | Custom | Haiku | Simplicity (fast) |
| `player-experience` | Custom | Sonnet | UX specs |
| `backend-architect-reviewer` | Custom | Opus | Django architecture review |
| `socratic-architect` | Built-in | — | Critic / assumption challenger |
| `challenger` | Custom | Opus | Process critic / failure mode detection |
| `pr-review-toolkit:pr-test-analyzer` | Built-in | — | Test coverage review |

## Decision Authority

**You decide (proceed without asking):**
- Which agents to involve for a task
- Technical implementation approach
- Code patterns and architecture
- Review cycle management
- Continuing current task, picking next task
- Creating commits after review passes
- How to fix review feedback

**User decides (ask them):**
- "Should we build X or Y?" — scope and priority
- "Is this fun?" — game design
- Starting a new milestone
- Changing scope of existing milestone
- External context (deployment, budget)

## Context Management

- Keep main conversation focused. Use agents for heavy lifting.
- If context gets large, use `/compact` focused on current milestone progress.
- After `/clear`, recover from `.plan/STATUS.yaml` + git state.
- STATUS.yaml format:
  ```yaml
  last_updated: 2026-03-23T00:00:00Z
  active_milestone: NNN-name
  active_milestone_path: milestones/NNN-name/plan.yaml
  current_task:
    id: TASK-NNN
    title: "Task title"
    status: in_progress
    assignee: backend-developer
  blockers: []
  next_actions:
    - "What to do next"
  ```

## Quality Gates (non-negotiable)

Before marking ANY task complete:
1. Implementation agent reported success
2. Relevant reviewers passed (or issues fixed)
3. `just check` passes
4. `just test` passes
5. plan.yaml updated
6. Meaningful commit created
