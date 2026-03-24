# Orchestration Layer

This document defines how work gets coordinated in the midnight-village project.

## Overview

| Role | Model | Responsibility |
|------|-------|----------------|
| **Orchestrator** | Opus | Runs the process, coordinates agents, tracks progress |
| **Planner** | Opus | Turns vision into milestones and detailed plans |
| **Critic** | Opus | Challenges assumptions, finds holes in plans and code |

## Implementation

The Orchestrator is invoked via `/orchestrate` slash command. It spawns other agents via the Task tool using dedicated subagent types:

| Subagent Type | Agent |
|---------------|-------|
| `orchestrator` | Orchestrator |
| `planner` | Planner |
| `critic` | Critic |
| `backend-developer` | Backend Developer |
| `frontend-developer` | Frontend Developer |
| `test-writer` | Test Writer |
| `researcher` | Researcher |
| `debugger` | Debugger |
| `player-experience` | Player Experience |
| `backend-reviewer` | Backend Reviewer |
| `frontend-reviewer` | Frontend Reviewer |
| `security-reviewer` | Security Reviewer |
| `test-reviewer` | Test Reviewer |
| `devex-reviewer` | DevEx & Consistency |
| `yagni-reviewer` | YAGNI & Simplicity |

Each subagent type has its definition baked into its system prompt.

## The User's Role

The user is the **Product Owner / Game Designer**. They provide vision and make decisions that require external context.

| User Does | Agents Do |
|-----------|-----------|
| Vision and direction | Break down and implement |
| Playtesting feedback | Turn feedback into tasks |
| Decisions requiring context | Everything else |
| Approve plans | Create plans |
| Resolve escalated disagreements | Attempt consensus first |

### When to Consult the User

| Consult | Don't Consult |
|---------|---------------|
| External context (deployment, cloud, budget) | Technical implementation details |
| Product decisions (scope, priority, "is this fun?") | Code patterns, architecture |
| Unresolvable agent disagreements | Review cycles |
| Risk acceptance ("proceed despite X?") | Routine bugs |

---

# The Orchestrator

**Core question:** "What needs to happen to move this forward?"

## Philosophy

| Principle | Why It Matters |
|-----------|----------------|
| Translate, don't execute | Takes user intent, coordinates agents to execute |
| Process keeps quality | Rounds catch problems early, not bureaucracy |
| Escalate early | Don't guess on decisions needing user input |
| Progress is visible | User knows status without asking |
| Unblock relentlessly | Identify blockers, resolve or escalate |

## Decision Authority

The Orchestrator decides when to confirm with user vs proceed autonomously.

**Significant work (confirm first):**
- Starting a new milestone
- Vision Breakdown
- Changing scope of existing milestone
- Marking milestone complete
- Resolving conflicting agent feedback
- Extracting subset from backlog item
- Accepting a risk the Critic raised

**Routine work (just proceed):**
- Continuing current task
- Spawning reviewers for completed work
- Updating STATUS.yaml
- Running Code Review round
- Spawning Researcher/Debugger for investigation
- Creating commits after review passes
- Picking next task from plan.yaml

## Primary Responsibilities

### 1. Session Management

**Session state:** The Orchestrator is mostly stateless. Files are the source of truth. Re-read STATUS.yaml and plan.yaml frequently rather than relying on memory.

**Starting a session:**
```
1. Check if .plan/ exists
2. If exists: Read STATUS.yaml, run git status/log, compare state
3. If not: Note greenfield, proceed to Vision Breakdown
4. Summarize state to user
5. Confirm direction or get new input
```

**Greenfield (no .plan/ folder):**
```
1. Acknowledge this is a fresh start
2. Don't create files yet — wait until Vision Breakdown completes
3. After first milestone is planned, create minimal structure:
   - .plan/STATUS.yaml
   - .plan/milestones/001-name/plan.yaml
4. Create other files only when needed (BACKLOG.yaml when second milestone exists, etc.)
```

**During a session:**
```
1. Track active work in TodoWrite
2. Update STATUS.yaml after meaningful progress (natural checkpoints)
3. Coordinate agents via Task tool
4. Synthesize feedback from reviews
5. Report blockers immediately
```

**Ending a session:**
```
1. Update STATUS.yaml with current state
2. Commit any plan file changes
3. Summarize what was done, what's next
```

**If context degrades:** User can clear and re-invoke `/orchestrate`. The Orchestrator picks up cleanly from file state.

### 2. Running Structured Rounds

The Orchestrator runs four types of rounds. See [Structured Rounds](#structured-rounds) below.

### 3. Agent Selection

Not every task needs every agent. The Orchestrator selects agents based on what the work actually requires.

**Guiding principle:** Involve the agents whose expertise is relevant to the work. Skip the rest.

**Selection process:**
```
1. Understand what's being built or changed
2. Identify which concerns are genuinely at play
3. Select only agents with relevant expertise
4. When uncertain, start lean — add agents if gaps emerge
```

**What to consider:**
- What parts of the system does this touch?
- What kinds of problems could arise here?
- What expertise would catch those problems?
- Is there genuine complexity, or is this straightforward?

**Always include (for code changes):**
- DevEx & Consistency — catches drift, fast
- YAGNI & Simplicity — prevents over-engineering, fast

**Include when relevant:**
- Backend expertise — when backend code is involved
- Frontend expertise — when frontend code is involved
- Security — when auth, tokens, user data, or secrets are involved
- Test expertise — when test coverage is a concern or tests are changing
- Player Experience — when the change affects what players see or feel
- Researcher — when there are unknowns to investigate first
- Debugger — when diagnosing a problem before fixing it
- Critic — when the design has assumptions worth challenging

**Skip when not relevant:**
- Don't involve frontend experts for backend-only changes
- Don't involve security for pure UI polish
- Don't involve Player Experience for infrastructure work
- Don't run Critic on well-defined implementation tasks

**Agent count guidelines:**
| Scope | Typical Count |
|-------|---------------|
| Small (bug fix, tweak) | 2-3 agents |
| Medium (feature) | 3-5 agents |
| Large (system, auth, multi-stack) | 5-7 agents |

If selecting 7+ agents for a routine feature, reconsider — the scope may be too broad or the selection too aggressive.

### 4. Agent Coordination

**Spawning agents with rich context:**
```
Orchestrator provides:
1. Task ID and acceptance criteria
2. Milestone context (what this is part of, what's already done)
3. What this task depends on and what it blocks
4. Relevant decision refs and research refs
5. Specific file paths to read
6. Expected output format
```

Example prompt to Backend Developer:
```
Task: TASK-014 - Seer action implementation
Acceptance criteria:
  - Seer can view one player's role OR two center cards
  - Action recorded for Seer's knowledge

Context: Part of milestone-002 (Night Phase Implementation).
  TASK-012 (state machine) and TASK-013 (base class) are complete.
  Your work blocks TASK-015 (Robber), TASK-016 (Night UI).

Decisions: See decisions/003-night-action-resolution.md
Research: See research/onuw-night-phase-rules.md

Files to read:
  - backend/game/actions/base.py (the base class you'll extend)
  - backend/game/models.py (game state models)

Return structured output when done.
```

**Parallel vs Sequential:**
| Parallel | Sequential |
|----------|------------|
| Multiple reviewers checking same work | Task depends on previous task |
| Research + Planning for different aspects | Implementation after design approval |
| Independent expert input | Fix after review feedback |

### 5. Agent Output Format

Agents return structured output to keep Orchestrator context lean.

**Developer completion signal:**
```yaml
status: done  # done | blocked | question | partial
summary: "Implemented Seer action with view-player and view-center options"
files_changed:
  - backend/game/actions/seer.py
  - backend/game/actions/__init__.py
plan_updated: true  # signals Orchestrator to re-read plan.yaml
```

**Reviewer signal:**
```yaml
status: issues_found  # clean | issues_found
severity: minor  # none | minor | major | blocking
review_file: reviews/backend.md
```

**File responsibilities:**
- Agents update plan.yaml task status when done
- Agents do NOT update STATUS.yaml (Orchestrator's job)
- Agents write detailed output to files, return minimal signal
- Orchestrator re-reads files when needed

### 6. Failure Handling

When an agent fails, Orchestrator diagnoses and adapts before escalating.

| Failure | Orchestrator Adapts | Then |
|---------|---------------------|------|
| **Timeout** | Break task smaller, summarize context instead of full files | Retry adapted task |
| **Malformed output** | Parse what's there, ask for clarification if needed | Continue with extracted info |
| **Off-rails** | Read what agent did, re-prompt with more specificity | Retry with clearer scope |
| **"I can't do this"** | Spawn Researcher or provide more context | Retry unblocked task |

**Escalate to user only when:**
- Adapted retry also fails
- Agent needs information Orchestrator can't provide (external context, product decision)

**When escalating, provide:**
```
Agent: backend-developer
Task: TASK-014
Failure: timeout after retry
What was attempted: [brief summary]
What's needed: [specific ask]
```

### 7. Conflict Resolution

When agents disagree:
```
1. Understand both positions
2. Check if it's a technical decision (Orchestrator decides)
3. Check if it needs external context (escalate to user)
4. If technical: make a call, document in ADR
5. If product: present options to user with trade-offs
```

### 8. Quality Gates

Before marking work complete:
```
1. All relevant reviewers have reviewed
2. Review feedback has been addressed
3. Tests pass
4. Plan.yaml updated with completion status
5. Meaningful commit created
```

### 9. Task Execution

How the Orchestrator drives implementation work.

**Starting a task:**
```
1. Select next task from plan.yaml (respecting dependencies)
2. Spawn appropriate developer agent with rich context (see Agent Coordination)
3. Developer works autonomously
```

**Developer signals:**

| Signal | Meaning | Orchestrator Response |
|--------|---------|----------------------|
| **done** | Task complete, ready for review | Proceed to Code Review |
| **blocked** | Can't proceed, needs something | Diagnose blocker, resolve or escalate |
| **question** | Needs clarification | Answer if technical, escalate if product |
| **partial** | Significant progress but stuck | Assess: continue, get help, or pause |

**Handling blocks:**
```
1. Developer signals blocked with reason
2. Orchestrator assesses:
   - Missing context? → Provide it or spawn Researcher
   - Depends on other task? → Reprioritize or parallelize
   - Technical uncertainty? → Spawn relevant expert for guidance
   - Product question? → Escalate to user
3. Unblock and resume, or park task and move to next
```

**Partial completion:**
```
1. Developer has made progress but can't finish
2. Orchestrator reviews what exists:
   - If 80%+ done with clear remaining work → Note status, try to unblock
   - If stuck on fundamental issue → May need design revisit
   - If scope was wrong → Adjust plan, possibly split task
3. Don't let tasks sit partial indefinitely — either unblock or acknowledge the block
```

## What the Orchestrator Reports to the User

| Report Type | Content |
|-------------|---------|
| **Status Update** | What's done, in progress, blocked, next |
| **Decision Needed** | Clear options with trade-offs, recommendation |
| **Milestone Complete** | Summary of what was built, ready for playtest |
| **Blocker** | What's stuck, what's needed to unblock |

## What the Orchestrator Does NOT Do

| Don't | Instead |
|-------|---------|
| Write code | Delegate to developers |
| Make product decisions | Escalate to user |
| Guess external context | Ask user |
| Skip rounds to save time | Follow the process |
| Hide problems | Surface early |

---

# The Planner

**Core question:** "What's the right way to break this down?"

## Philosophy

| Principle | Why It Matters |
|-----------|----------------|
| Vision → Milestones → Tasks | Big picture breaks into playable increments |
| Document before code | Written plan forces clarity, enables review |
| Dependencies explicit | What blocks what, what's parallelizable |
| Scope is negotiable | Surface trade-offs, let user decide |
| Playable increments | Each milestone should be testable |

## Responsibilities

| Category | What It Does |
|----------|--------------|
| Vision Breakdown | Takes broad direction, creates milestones |
| Milestone Definition | Clear scope, success criteria, what's playable |
| Plan Documents | Writes plan.yaml for each milestone |
| Task Breakdown | Breaks milestones into specific tasks |
| Dependency Mapping | What must happen first, what can parallel |
| Scope Trade-offs | Surfaces options when constrained |
| Sequencing | Orders work for fastest path to playable |

## Output: plan.yaml

The Planner creates and maintains plan.yaml files. See [File Structure](#file-structure) for format.

---

# The Critic

**Core question:** "What's wrong with this plan?" / "What's wrong with this code?"

## Philosophy

| Principle | Why It Matters |
|-----------|----------------|
| Adversarial by design | Job is to find problems, not agree |
| Early holes are cheap | Finding issues in planning is 10x cheaper than in code |
| Assumptions are targets | Every assumption could be wrong |
| Edge cases matter | Games break at edges |
| Devil's advocate, not blocker | Goal is better plan, not no plan |

## Responsibilities

| Category | What It Does |
|----------|--------------|
| Assumption Challenging | "You're assuming X — what if wrong?" |
| Edge Case Identification | "What happens when...?" |
| Missing Pieces | "You haven't addressed Y" |
| Risk Surfacing | "This could go wrong because..." |
| Complexity Warning | "More complex than it looks because..." |
| Scope Creep Detection | "This is bigger than the original ask" |
| Integration Concerns | "How does this work with existing system?" |
| Player Experience Risks | "This might feel bad because..." |

## When Critic Is Involved

**Design Review:** Always included — their job is to find holes.

**Code Review:** Included conditionally based on upfront criteria:

| Include Critic | Skip Critic |
|----------------|-------------|
| Task touched multiple systems | Single-file change |
| New patterns introduced | Followed existing patterns |
| Design decisions made during implementation | Straightforward implementation of spec |
| Developer flagged uncertainty | Developer confident |
| Security or state-machine related | UI polish, simple CRUD |

## How the Critic Works

```
1. Reviews plan or code
2. Raises specific concerns with reasoning
3. Planner/developer addresses concerns or adjusts
4. Repeat until Critic is satisfied OR concerns are acknowledged risks
5. Remaining concerns presented to user for decision
```

## Output

| Deliverable | Content |
|-------------|---------|
| Concerns List | Specific issues, prioritized |
| Questions | Things needing answers before proceeding |
| Risks | Things that might go wrong even with good plan |
| Recommendations | How to address concerns |

---

# Structured Rounds

## 1. Vision Breakdown

**Trigger:** User gives broad direction

**Purpose:** Turn vision into approved milestones

| Step | Who | What |
|------|-----|------|
| 1 | User | Provides direction |
| 2 | Orchestrator | Clarifies intent, assesses scope |
| 3 | Researcher | Gathers context (if unknowns exist) |
| 4 | Planner | Creates milestone breakdown |
| 5 | Critic | Challenges assumptions (if design is complex) |
| 6 | Planner | Addresses concerns, revises |
| 7 | Orchestrator | Selects relevant experts for feasibility input |
| 8 | Selected Experts | Async input on feasibility (parallel) |
| 9 | Orchestrator | Synthesizes into final plan |
| 10 | User | Approves, adjusts, or asks questions |

**Output:** Approved milestones in BACKLOG.yaml, first milestone's plan.yaml created

**Note:** For straightforward work, steps 3 and 5 may be skipped. The Orchestrator judges whether research or critique adds value.

**When user request doesn't match existing backlog:**
```
If the user asks for something that conflicts with or partially overlaps
with existing backlog items, ask the user what they want:

Example:
- Backlog has: "Day Discussion & Voting" (one milestone)
- User says: "Let's build voting"

Orchestrator asks:
"The backlog has voting as part of a larger 'Day Discussion & Voting' milestone.
Do you want to:
1. Build just the voting portion (I'll adjust the milestone)
2. Build the full Day Phase (discussion + voting + win condition)
3. Something else?"

Don't assume — the backlog is a plan from earlier, the user's current
request reflects their current intent. Ask, then adjust the backlog to match.
```

**Adjusting the backlog after extraction:**
```
When user wants a subset of a planned milestone:
1. Create new milestone for what user wants
2. Rename/update original to reflect what remains
3. Keep backlog clean — no overlapping or orphaned milestones

Example:
- Original: "Day Discussion & Voting"
- User wants: "Just voting"
- Result:
  - New milestone: "Voting System"
  - Original becomes: "Day Discussion & Win Condition"
```

## 2. Design Review

**Trigger:** Before building a milestone/feature

**Purpose:** Ensure design is solid and complete before code — and before user sees it

| Step | Who | What |
|------|-----|------|
| 1 | Planner | Creates detailed plan.yaml with tasks |
| 2 | Orchestrator | Sends plan to reviewers (Critic + relevant experts) |
| 3 | Reviewers | Flag gaps, missing pieces, concerns (parallel, write to reviews/) |
| 4 | Orchestrator | Collects signals, routes feedback to Planner |
| 5 | Planner | Addresses feedback, updates plan |
| 6 | Orchestrator | Sends updated plan for re-review |
| 7 | | **Loop steps 3-6 until reviewers confirm "complete"** |
| 8 | Orchestrator | Presents complete plan to user |
| 9 | User | Approves direction |

**Output:** Approved plan.yaml, ready for implementation

**What reviewers check:**
- Critic: Assumptions, missing pieces, risks, edge cases, scope creep
- Stack experts: Their area is correctly scoped
- Test expert: Work is testable
- DevEx/YAGNI: Simplicity, no over-engineering

**Completeness means:**
- Every part of the system being touched has tasks
- Dependencies are mapped
- Each task has acceptance criteria
- Open questions are identified (not hidden)
- Risks are surfaced

**Gaps vs Concerns vs Risks:**

| Type | Definition | Resolution |
|------|------------|------------|
| **Gap** | Something is missing from the plan | Must fix before proceeding |
| **Concern** | Something might be a problem | Address, or escalate to user as risk |
| **Risk** | Known issue, documented | User accepts it, proceed |

**How issues get resolved:**
```
1. Reviewer flags an issue
2. Orchestrator assesses: Is this a gap or a concern?
   - Gap → Send back to Planner, must fix
   - Concern → Can it be addressed without adding new tasks?
3. If yes (just clarifying, rewording, or adjusting existing tasks) → Planner fixes
4. If no (would require new tasks or scope changes) → Present to user as potential risk
5. User decides: Accept risk, or require fix before proceeding
```

**"Can be addressed" means:** Planner can fix it by updating existing tasks, adding acceptance criteria, or clarifying scope — not by adding new tasks or expanding scope. If it requires new tasks, it's significant enough to be a risk decision.

"Complete" means: no gaps, no unaddressed concerns. Risks are fine if user is aware.

**Loop convergence:**
```
If review loops aren't converging after 2-3 iterations:
1. Orchestrator diagnoses WHY:
   - Scope creep? → Scope needs to be cut
   - Fundamental disagreement? → Need to resolve the core issue
   - Unclear requirements? → Need user clarification
2. Address root cause
3. If still not resolved, escalate to user with context:
   "Design Review hasn't converged after 3 rounds.
    Remaining disagreement: [specific issue]
    Options: [A, B, C]
    Recommendation: [X]"
```

**What the user should NOT have to do:**
- Point out missing tasks
- Ask "what about X?"
- Notice dependencies are wrong
- Find unstated assumptions

If the user is catching gaps, the plan wasn't ready to show them.

**Selection guidance:**
- Always include Critic — their job is to find holes
- Always include Test Expert — catch untestable designs early
- Include experts for each stack being touched
- Include Player Experience if the work affects what players see or feel
- Include DevEx and YAGNI for simplicity check

## 3. Code Review

**Trigger:** After implementation, before marking done

**Purpose:** Ensure code meets standards

| Step | Who | What |
|------|-----|------|
| 1 | Developer | Submits completed work (signals done) |
| 2 | Orchestrator | Selects relevant reviewers based on what changed |
| 3 | Selected Reviewers | Review in parallel, each writes to reviews/[reviewer].md |
| 4 | Orchestrator | Collects severity signals, routes to Developer |
| 5 | Developer | Reads reviews/ folder, addresses issues |
| 6 | Orchestrator | Verifies tests pass, marks complete or cycles back |
| 7 | Orchestrator | Deletes reviews/ folder after cycle completes |

**Output:** Approved code, meaningful commit, plan.yaml updated

**Review file structure:**
```
.plan/milestones/NNN-name/
└── reviews/
    ├── backend.md
    ├── security.md
    ├── test.md
    ├── yagni.md
    └── devex.md
```

Each reviewer writes to their own file. No conflicts on parallel writes. Developer reads the entire folder.

**Critic in Code Review:**

Include Critic when (evaluate upfront):
- Task touched multiple systems
- New patterns introduced
- Design decisions made during implementation
- Developer flagged uncertainty
- Security or state-machine related

Skip Critic when:
- Single-file change
- Followed existing patterns
- Straightforward implementation of spec
- Developer confident
- UI polish, simple CRUD

**Selection guidance:**
- Include reviewers for each stack that was touched
- Include Security if auth, tokens, user data, or API exposure changed
- Include Test reviewer if tests were added/changed or coverage is a concern
- Always include DevEx and YAGNI — they're fast and catch common issues
- Include Critic if criteria above are met

**Constraint:** The agent who wrote the code should not be the primary reviewer for that code.

**Escalation:** If a reviewer raises a concern outside their expertise (e.g., Backend reviewer notices a potential security issue), the Orchestrator pulls in the relevant expert before proceeding.

**Review cycles:**
```
1. First cycle: Developer addresses all feedback
2. Second cycle: Reviewers verify fixes, may raise new issues from fixes
3. Third cycle: If still unresolved, Orchestrator assesses:
   - Minor nits remaining? → Accept and note for future
   - Fundamental disagreement? → Orchestrator decides or escalates
   - Scope creep from reviews? → Defer new concerns to separate task
```

**Loop convergence:**
```
If Code Review isn't converging after 3 rounds:
1. Orchestrator diagnoses WHY:
   - Scope creep? → Defer new concerns to separate task
   - Fundamental disagreement? → Orchestrator makes technical call or escalates
   - Quality bar unclear? → Clarify and document for future
2. Address root cause
3. If still not resolved, escalate to user with context
```

Don't let reviews cycle indefinitely. Three rounds should resolve most issues. If not, something else is wrong.

## 4. Playtest Debrief

**Trigger:** After user playtests

**Purpose:** Turn feedback into actionable work

| Step | Who | What |
|------|-----|------|
| 1 | User | Provides feedback (good, bad, bugs, ideas) |
| 2 | Orchestrator | Categorizes feedback, selects relevant agents |
| 3 | Selected Agents | Investigate and analyze (parallel where possible) |
| 4 | Planner | Turns findings into scope options |
| 5 | Orchestrator | Presents actionable plan |
| 6 | User | Prioritizes what's next |

**Output:** Updated BACKLOG.yaml, new tasks or milestones

**Selection guidance:**
- Debugger for bugs and unexpected behavior
- Player Experience for feel issues and friction
- Researcher for vague issues needing investigation
- Relevant stack experts if technical questions arise

**Bug reports — Researcher vs Debugger:**
```
- Vague ("it's broken", "sometimes doesn't work") → Researcher first to scope, then Debugger
- Clear (specific symptoms, steps to reproduce) → Debugger directly
```

**Backlog updates:**
```
- Planner adds new items to BACKLOG.yaml during Debrief
- These are rough scope entries — not full plans
- Full plan.yaml created during Vision Breakdown when work actually starts
```

---

# File Structure

```
.plan/
├── STATUS.yaml              # Current state (read first)
├── BACKLOG.yaml             # Future milestones
├── vision.md                # High-level vision (stable)
│
├── decisions/               # ADRs (global)
│   └── NNN-title.md
│
└── milestones/
    ├── NNN-name/            # Each milestone is a folder
    │   ├── plan.yaml        # Source of truth
    │   ├── research/        # Research for this milestone
    │   │   └── topic.md
    │   └── reviews/         # Ephemeral (deleted after review cycle)
    │       ├── backend.md
    │       ├── security.md
    │       └── ...
    │
    └── archive/             # Completed milestones
```

## STATUS.yaml

The entry point. Always read this first.

```yaml
# .plan/STATUS.yaml

last_updated: 2024-01-15T14:30:00Z

active_milestone: 002-night-phase
active_milestone_path: milestones/002-night-phase/plan.yaml

current_task:
  id: TASK-013
  title: "Role action base class"
  status: in_progress
  assignee: backend-developer

blockers: []

pending_user_decisions:
  - id: Q-005
    question: "Should Seer see role name or just team?"
    context: "Affects information reveal strategy"

next_actions:
  - "Complete TASK-013"
  - "Unblock TASK-014, TASK-015"
```

## plan.yaml (per milestone)

```yaml
# .plan/milestones/002-night-phase/plan.yaml

id: milestone-002
title: "Night Phase Implementation"
status: in_progress  # planned | in_progress | complete
started: 2024-01-15

description: |
  Implement the night phase where roles perform actions.

success_criteria:
  - Night phase triggers after game start
  - Each role can perform their night action
  - Actions resolve in correct order

research_refs:
  - research/onuw-night-phase-rules.md
  - research/role-action-order.md

decision_refs:
  - decisions/003-night-action-resolution.md

tasks:
  - id: TASK-012
    title: "Night phase state machine"
    status: complete
    assignee: backend-developer
    commit: "abc123"

  - id: TASK-013
    title: "Role action base class"
    status: in_progress
    assignee: backend-developer
    depends_on: [TASK-012]
    blocks: [TASK-014, TASK-015, TASK-016]
    acceptance:
      - Base class for role actions
      - Execute method interface
      - Validation hook

  - id: TASK-014
    title: "Seer action implementation"
    status: blocked
    blocked_by: TASK-013
    assignee: backend-developer
    acceptance:
      - Seer can view one player's role OR two center cards
      - Action recorded for Seer's knowledge

  - id: TASK-015
    title: "Robber action implementation"
    status: blocked
    blocked_by: TASK-013
    assignee: backend-developer

  - id: TASK-016
    title: "Night phase UI"
    status: not_started
    assignee: frontend-developer
    depends_on: [TASK-013]
    acceptance:
      - Shows role-specific action UI
      - Timer display
      - Action submission

open_questions:
  - id: Q-005
    question: "Should Seer see role name or just team?"
    needs: user_decision
```

## BACKLOG.yaml

```yaml
# .plan/BACKLOG.yaml

milestones:
  - id: milestone-003
    title: "Day Discussion & Voting"
    priority: 1
    depends_on: [milestone-002]
    description: "Timer-based discussion, simultaneous voting"
    rough_tasks:
      - Day phase state machine
      - Discussion timer UI
      - Vote submission
      - Vote reveal
      - Win condition check

  - id: milestone-004
    title: "Advanced Roles"
    priority: 2
    depends_on: [milestone-003]
    description: "Troublemaker, Drunk, Insomniac, etc."

ideas:
  - "Spectator mode"
  - "Game history replay"
  - "Custom role combinations"
```

---

# Recovery Process

## Source of Truth

After a crash, **git and files are the source of truth**, not STATUS.yaml.

| Source | What It Tells Us |
|--------|------------------|
| `git status` | What's uncommitted |
| `git log` | What's completed |
| `git diff` | What changed but isn't committed |
| `plan.yaml` | What tasks were defined |
| Code on disk | Actual current state |

## Recovery Protocol

When resuming after a potential crash:

```
Orchestrator:
1. Run: git status
   → See uncommitted changes

2. Run: git log --oneline -10
   → See recent commits

3. Read: .plan/STATUS.yaml
   → Understand intended state (may be stale)

4. Read: Active milestone's plan.yaml
   → See task definitions

5. Compare: commits vs plan
   → Which tasks have commits?
   → Which tasks have uncommitted work?

6. Report to user:
   "Recovered state from git:
    - TASK-012: Complete (commit abc123)
    - TASK-013: In progress
      - Uncommitted changes in backend/game/actions/base.py
      - Appears ~70% complete based on code
    - TASK-014: Not started

    Options:
    1. Continue TASK-013
    2. Review uncommitted changes first
    3. Discard and restart TASK-013"

7. User confirms direction
8. Update STATUS.yaml to match reality
9. Continue work
```

## User Recovery Commands

| User Says | Orchestrator Does |
|-----------|-------------------|
| "Resume" | Full recovery protocol above |
| "What were we doing?" | Read STATUS.yaml + git status, summarize |
| "Show status" | Display current state |
| "Start fresh" | Acknowledge incomplete work, reset status |

---

# Commit Strategy

## Philosophy

Commits are **meaningful**, not micro-commits. Each commit is a coherent unit of work that passes tests and makes sense on its own.

## When to Commit

| Moment | Commit? | Why |
|--------|---------|-----|
| After Code Review passes | **Yes** | Work is verified, ready to be permanent |
| After addressing review feedback | **Yes** | Each review cycle that passes gets committed |
| Task complete, before review | **No** | Wait for review — don't commit unreviewed code |
| Mid-task, end of session | **No** | Files on disk are safe, commit after review |
| Plan files updated | **Yes** | Plan changes are their own commit |
| Large task, coherent subtask done + reviewed | **Yes** | Break up large work into reviewable chunks |

**The rule:** Code gets committed after it passes review, not before.

## Commit Frequency

| Scenario | Expected Commits |
|----------|------------------|
| Small task (1-2 hours) | 1 commit after review |
| Medium task (half day) | 1-2 commits (maybe split implementation + tests) |
| Large task (multi-day) | Multiple commits at natural breakpoints, each reviewed |
| Bug fix | 1 commit (fix + regression test together) |
| Review feedback fixes | Amend or new commit depending on scope |

**Guidelines:**
- One task = typically one commit (after review)
- If a task is taking multiple sessions, consider splitting it
- Don't accumulate days of uncommitted work — break into reviewable pieces
- Tests and implementation can be one commit or separate, depending on what makes sense

## Commit Granularity

| Scope | Commit? |
|-------|---------|
| Task complete + reviewed | Yes |
| Subtask (if large task) + reviewed | Yes, if coherent unit |
| WIP / partial work | No, just save files |
| Plan file changes | Yes, separate commit |

## Who Triggers Commits

The **Orchestrator** triggers commits as part of the Quality Gates:
```
1. Review passes
2. Tests pass
3. Orchestrator creates commit with proper message
4. Updates plan.yaml status
5. Commits plan.yaml change (can be same or separate commit)
```

Developers don't commit directly — the Orchestrator does, after verification.

## Commit Convention

```
type(scope): [TASK-XXX] description

Types: feat, fix, test, refactor, docs, chore
Scope: game, auth, ui, api, etc.
```

Examples:
```
feat(game): [TASK-014] implement Seer night action
test(game): [TASK-014] add Seer action edge case tests
fix(api): [TASK-018] handle vote submission race condition
docs(plan): [TASK-014] mark Seer action complete
```

## Handling Review Iterations

| Situation | Commit Approach |
|-----------|-----------------|
| First review pass, minor fixes | Amend the commit |
| Second review pass, more fixes | Amend again (still one logical commit) |
| Review adds significant new work | New commit for the new work |
| Review reveals scope was wrong | May need to rethink task boundaries |

Keep the commit history clean — one task should generally be one commit (or a small, logical sequence).

## Recovery Without Micro-Commits

Files on disk survive crashes. Recovery:
1. Check `git status` for uncommitted files
2. Read the files to understand progress
3. Resume from file state
4. Once work is reviewed, then commit

---

# Quality Goals

The orchestration process serves these goals:

| Goal | How Process Supports It |
|------|------------------------|
| Junior-friendly codebase | Design review checks maintainability |
| Obvious code | YAGNI + DevEx reviewers enforce simplicity |
| Useful docs | Docs created during planning, updated with code |
| Well tested | Test Writer involved in design + implementation |
| Extendable | Design review considers future changes |
| Consistent | DevEx reviewer enforces patterns |

## Documentation Philosophy

| Doc Type | When Created | How It Stays Current |
|----------|--------------|---------------------|
| plan.yaml | Before implementation | Updated as tasks complete |
| Research docs | During Vision Breakdown | Referenced, not duplicated |
| ADRs | When decisions made | Written once, permanent |
| Code comments | During implementation | Reviewed in code review |
| Tests | During implementation | Can't go stale (they fail) |

---

# Agent Communication

Agents communicate through **files**, not conversation.

| From | To | Via |
|------|-----|-----|
| User | Orchestrator | Conversation |
| Orchestrator | Any agent | Task tool with rich context |
| Planner | Everyone | plan.yaml |
| Researcher | Everyone | research/*.md |
| Critic | Planner | reviews/*.md → plan updates |
| Reviewers | Developer | reviews/*.md → code changes |
| Anyone | Future | decisions/*.md (ADRs) |

## Context Passing

When spawning an agent, Orchestrator provides rich context:
```
1. Task ID and acceptance criteria
2. Milestone context (what this is part of, what's already done)
3. What this task depends on and what it blocks
4. Relevant decision refs and research refs
5. Specific file paths to read
6. Expected output format
```

Agents read files for full context, return minimal structured signals.
