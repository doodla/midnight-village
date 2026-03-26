---
work_package_id: WP03
title: Voting Timer Integration
lane: "doing"
dependencies: [WP01]
requirement_refs: [FR-001, FR-003, FR-004, FR-005, FR-007, FR-008, FR-009, FR-012]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 004-server-phase-timers-WP01
base_commit: 035f6f12bca69265e4f4c4d7b4a1708811f076a4
created_at: '2026-03-26T09:13:04.032816+00:00'
subtasks:
- T013
- T014
- T015
- T016
- T017
- T018
phase: Phase 2 - Timer Integration
assignee: ''
agent: "headless-impl"
shell_pid: "76154"
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-26T08:20:45Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP03 – Voting Timer Integration

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately (right below this notice).
- **You must address all feedback** before your work is complete. Feedback items are your implementation TODO list.
- **Mark as acknowledged**: When you understand the feedback and begin addressing it, update `review_status: acknowledged` in the frontmatter.
- **Report progress**: As you address each feedback item, update the Activity Log explaining what you changed.

---

## Review Feedback

> **Populated by `/spec-kitty.review`** – Reviewers add detailed feedback here when work needs changes. Implementation must address every item listed below before returning for re-review.

*[This section is empty initially. Reviewers will populate it if the work is returned from review. If you see feedback here, treat each item as a must-do before completion.]*

---

## Markdown Formatting
Wrap HTML/XML tags in backticks: `` `<div>` ``, `` `<script>` ``
Use language identifiers in code blocks: ````python`, ````bash`

---

## Objectives & Success Criteria

- When the game transitions to the voting phase, compute and store the deadline, schedule an auto-reveal timer, and broadcast the deadline in the `phase_change` event.
- Early transitions (all-voted or host force-reveal) cancel the timer.
- Non-voters are marked as abstaining when the timer fires.
- If `voting_seconds == 0`, no timer is scheduled and `deadline` is `null`.

**Key acceptance criteria:**
1. `transition_to_voting()` sets `game.phase_deadline` and schedules a timer that calls `reveal_votes()`.
2. The `phase_change` event for voting includes `"deadline": "<ISO 8601>"` or `"deadline": null`.
3. `submit_vote()` cancels the voting timer when all players have voted.
4. `reveal_votes()` cancels the voting timer and clears `game.phase_deadline` when transitioning to results.
5. When the timer fires with non-voters, they are marked as abstaining.
6. Integration tests verify all paths.

## Context & Constraints

- **Spec**: `kitty-specs/004-server-phase-timers/spec.md` — User Story 2, FR-001, FR-003, FR-004, FR-009
- **Plan**: `kitty-specs/004-server-phase-timers/plan.md` — D1 (threading.Timer), D2 (select_for_update)
- **Depends on WP01**: Timer registry and `Game.phase_deadline` field must exist.
- **Parallel with WP02**: Touches different phase transition functions in `services.py`.
- **Key files to modify**: `backend/apps/onuw/services.py`, `backend/apps/onuw/consumers.py`
- **Timer key**: `"{game_id}:voting"`
- **Default duration**: 120 seconds (FR-008)

**Implementation command:**

```bash
spec-kitty implement WP03 --base WP01
```

## Subtasks & Detailed Guidance

### Subtask T013 – Integrate deadline in `transition_to_voting()`

- **Purpose**: Compute the voting deadline, store it, and schedule the auto-reveal timer.
- **Steps**:
  1. In `backend/apps/onuw/services.py`, locate `transition_to_voting()`.
  2. After setting `game.phase = Phase.VOTING`, add:
     ```python
     voting_seconds = get_timer_seconds(game, "voting_seconds", 120)
     if voting_seconds > 0:
         game.phase_deadline = timezone.now() + timedelta(seconds=voting_seconds)
         callback = timers.make_idempotent_callback(
             game.id, Phase.VOTING, _auto_reveal_votes
         )
         timers.schedule(f"{game.id}:voting", voting_seconds, callback)
     else:
         game.phase_deadline = None
     game.save()
     ```
  3. Create `_auto_reveal_votes(game: Game)` that calls the existing `reveal_votes()` logic. This function must handle marking non-voters as abstaining before revealing.
- **Files**: `backend/apps/onuw/services.py` (~15 lines added)
- **Parallel?**: No — core change for this WP.
- **Notes**:
  - The `_auto_reveal_votes` helper must mark players who haven't voted as abstaining before calling the reveal logic.
  - Check how `reveal_votes()` currently handles missing votes — it may already treat them as abstentions, in which case `_auto_reveal_votes` just calls `reveal_votes(game)` directly.

### Subtask T014 – Add `deadline` to voting `phase_change` event broadcast

- **Purpose**: Include the deadline in the WebSocket event for the voting phase.
- **Steps**:
  1. In `transition_to_voting()`, locate the broadcast call.
  2. Add `"deadline"` to the event payload:
     ```python
     {
         "type": "phase.change",
         "phase": "voting",
         "deadline": game.phase_deadline.isoformat() if game.phase_deadline else None,
     }
     ```
- **Files**: `backend/apps/onuw/services.py` (~3 lines modified)
- **Parallel?**: Yes — can proceed alongside T015/T016 (cancel logic).
- **Notes**: The consumer handler from WP02/T009 already forwards `deadline`, so no consumer changes needed here.

### Subtask T015 – Cancel voting timer on all-voted

- **Purpose**: When all players have submitted votes, cancel the voting timer and reveal immediately.
- **Steps**:
  1. In `backend/apps/onuw/services.py`, locate `submit_vote()` (or the function that checks if all players have voted).
  2. In the branch where all players have voted, add before calling `reveal_votes()`:
     ```python
     timers.cancel(f"{game.id}:voting")
     ```
- **Files**: `backend/apps/onuw/services.py` (~2 lines added)
- **Parallel?**: No — modifies the same service file.
- **Notes**: The timer cancel must happen before `reveal_votes()` to avoid a race where the timer fires during the reveal.

### Subtask T016 – Cancel voting timer in `reveal_votes()`

- **Purpose**: Cover the host force-reveal path and clear the deadline when transitioning to results.
- **Steps**:
  1. In `backend/apps/onuw/services.py`, locate `reveal_votes()`.
  2. At the beginning, cancel the timer:
     ```python
     timers.cancel(f"{game.id}:voting")
     ```
  3. When transitioning to results, clear the deadline:
     ```python
     game.phase_deadline = None
     ```
- **Files**: `backend/apps/onuw/services.py` (~3 lines added)
- **Parallel?**: No — modifies the same function.
- **Notes**:
  - Cancelling a non-existent timer is safe, so this works even if the timer already fired or was cancelled by all-voted.
  - The results phase is untimed, so `phase_deadline` must be `None`.

### Subtask T017 – Write integration tests for voting timer

- **Purpose**: Verify the full voting timer lifecycle.
- **Steps**:
  1. In `backend/tests/onuw/test_timer_integration.py`, add voting timer tests:

     **test_voting_auto_reveals_with_abstentions**:
     - Create a game with `voting_seconds: 1`
     - Transition to voting with some players not having voted
     - Invoke the timer callback (mock `timers.schedule` to capture it)
     - Assert non-voters are marked as abstaining
     - Assert game transitioned to results

     **test_all_voted_cancels_voting_timer**:
     - Create a game with `voting_seconds: 300`
     - Transition to voting
     - Submit votes for all players
     - Assert timer was cancelled
     - Assert game transitioned to results

     **test_host_force_reveal_cancels_voting_timer**:
     - Create a game with `voting_seconds: 300`
     - Transition to voting
     - Call host force-reveal
     - Assert timer was cancelled

     **test_voting_no_timer_when_seconds_zero**:
     - Create a game with `voting_seconds: 0`
     - Transition to voting
     - Assert `game.phase_deadline` is `None`
     - Assert no timer scheduled

- **Files**: `backend/tests/onuw/test_timer_integration.py` (~100 lines added)
- **Parallel?**: No — depends on T013-T016.
- **Notes**: Mock `timers.schedule` to capture the callback; invoke it directly for testing the auto-reveal path.

### Subtask T018 – Update existing voting tests for `deadline` field

- **Purpose**: Ensure existing voting-related tests account for the new `deadline` field in events.
- **Steps**:
  1. Search for existing voting tests:
     ```bash
     cd backend && grep -rn "Phase.VOTING\|voting" tests/ --include="*.py"
     ```
  2. Update fixtures to include `"voting_seconds": 0` where timers aren't being tested.
  3. Update event shape assertions to include `"deadline": None`.
- **Files**: Various existing test files (~5-10 lines per file)
- **Parallel?**: Yes — can proceed alongside T017 (different test files).
- **Notes**: Same approach as T012 in WP02.

## Test Strategy

**Test file**: `backend/tests/onuw/test_timer_integration.py`

**Run commands**:
```bash
cd backend && pytest tests/onuw/test_timer_integration.py -v -k voting
cd backend && pytest tests/onuw/ -v  # full suite
```

**Fixtures needed**:
- Game factory with configurable `voting_seconds`
- Mock for `timers.schedule` to capture callbacks
- Multiple player instances for all-voted scenarios

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Race between last voter and timer expiry | Both paths call `reveal_votes()` which uses `select_for_update` — second caller finds game already in results and is a no-op |
| Non-voters not marked as abstaining | `_auto_reveal_votes` must explicitly handle missing votes before calling reveal logic |
| Existing voting tests break | Set `voting_seconds: 0` in test fixtures (T018) |
| Double cancellation of timer (all-voted + reveal_votes) | `timers.cancel()` is safe to call on non-existent keys |

## Review Guidance

- Verify `transition_to_voting()` sets `game.phase_deadline` and calls `timers.schedule()`.
- Verify both `submit_vote()` (all-voted path) and `reveal_votes()` cancel the timer.
- Verify `reveal_votes()` clears `game.phase_deadline` when transitioning to results.
- Verify the race condition between timer and all-voted is handled by `select_for_update`.
- Verify non-voters are marked as abstaining in the auto-reveal callback.
- Run `just test` to confirm no regressions.

## Activity Log

> **CRITICAL**: Activity log entries MUST be in chronological order (oldest first, newest last).

### How to Add Activity Log Entries

**When adding an entry**:
1. Scroll to the bottom of this file (Activity Log section below "Valid lanes")
2. **APPEND the new entry at the END** (do NOT prepend or insert in middle)
3. Use exact format: `- YYYY-MM-DDTHH:MM:SSZ – agent_id – lane=<lane> – <action>`
4. Timestamp MUST be current time in UTC (ISO-8601 `YYYY-MM-DDTHH:MM:SSZ`) and should be generated without shell commands (prefer `NOW_UTC_ISO` from `check-prerequisites --json --paths-only`)
5. Lane MUST match the frontmatter `lane:` field exactly
6. Agent ID should identify who made the change (claude-sonnet-4-5, codex, etc.)

**Format**:
```
- YYYY-MM-DDTHH:MM:SSZ – <agent_id> – lane=<lane> – <brief action description>
```

**Valid lanes**: `planned`, `doing`, `for_review`, `done`

- 2026-03-26T08:20:45Z – system – lane=planned – Prompt created.
- 2026-03-26T09:13:04Z – headless-impl – shell_pid=76154 – lane=doing – Assigned agent via workflow command
