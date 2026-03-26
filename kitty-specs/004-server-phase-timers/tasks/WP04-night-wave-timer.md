---
work_package_id: WP04
title: Night Wave Timer Integration
lane: "doing"
dependencies: [WP01]
requirement_refs: [FR-002, FR-003, FR-004, FR-005, FR-007, FR-008, FR-009]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 004-server-phase-timers-WP01
base_commit: 035f6f12bca69265e4f4c4d7b4a1708811f076a4
created_at: '2026-03-26T09:23:39.321495+00:00'
subtasks:
- T019
- T020
- T021
- T022
- T023
- T024
- T025
phase: Phase 2 - Timer Integration
assignee: ''
agent: "headless-impl"
shell_pid: "91896"
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-26T08:20:45Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP04 – Night Wave Timer Integration

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

- Each night wave gets a deadline when it starts. When the timer fires, non-actors are marked as skipped and the wave advances.
- Early transitions (all-acted or host force-advance) cancel the timer.
- Wave transitions schedule a new timer for the next wave and clear the old one.
- If `night_wave_seconds == 0`, no timer is scheduled.

**Key acceptance criteria:**
1. `send_wave_prompts()` sets `game.phase_deadline` and schedules a wave timer.
2. The `wave_start` event includes `"deadline": "<ISO 8601>"` or `"deadline": null`.
3. `advance_wave()` cancels the wave timer at the start.
4. `check_and_maybe_advance()` cancels the wave timer when auto-advancing after all players acted.
5. When transitioning between waves, old timer is cancelled and new one is scheduled.
6. When transitioning from night to discussion, `phase_deadline` is cleared (discussion timer from WP02 takes over).
7. Integration tests verify all paths.

## Context & Constraints

- **Spec**: `kitty-specs/004-server-phase-timers/spec.md` — User Story 4, FR-002, FR-003, FR-004
- **Plan**: `kitty-specs/004-server-phase-timers/plan.md` — D1, D2
- **Depends on WP01**: Timer registry and `Game.phase_deadline` field.
- **Parallel with WP02/WP03**: Touches different phase transition functions.
- **Key files to modify**: `backend/apps/onuw/services.py`, `backend/apps/onuw/consumers.py`
- **Timer key**: `"{game_id}:wave:{wave_number}"`
- **Default duration**: 30 seconds (FR-008)

**Implementation command:**

```bash
spec-kitty implement WP04 --base WP01
```

## Subtasks & Detailed Guidance

### Subtask T019 – Integrate deadline in `send_wave_prompts()`

- **Purpose**: When a night wave starts, set the deadline and schedule a timer that auto-advances the wave.
- **Steps**:
  1. In `backend/apps/onuw/services.py`, locate `send_wave_prompts()`.
  2. After setting up the wave, add timer scheduling:
     ```python
     wave_seconds = get_timer_seconds(game, "night_wave_seconds", 30)
     if wave_seconds > 0:
         game.phase_deadline = timezone.now() + timedelta(seconds=wave_seconds)
         callback = timers.make_idempotent_callback(
             game.id, Phase.NIGHT,
             lambda g: _auto_advance_wave(g, wave_number)
         )
         timers.schedule(f"{game.id}:wave:{wave_number}", wave_seconds, callback)
     else:
         game.phase_deadline = None
     game.save()
     ```
  3. Create `_auto_advance_wave(game: Game, wave_number: int)` helper:
     - Check `game.current_wave == wave_number` (in addition to the phase check in the idempotent wrapper)
     - Mark non-actors for the current wave as skipped (`action_type: "skip"`)
     - Call `advance_wave(game)`
  4. Include `"deadline"` in the `wave_start` event broadcast:
     ```python
     {
         "type": "wave.start",
         "wave": wave_number,
         "deadline": game.phase_deadline.isoformat() if game.phase_deadline else None,
         # ... other existing fields
     }
     ```
- **Files**: `backend/apps/onuw/services.py` (~25 lines added)
- **Parallel?**: No — core change for this WP.
- **Notes**:
  - The wave number check inside `_auto_advance_wave` is critical: if the wave already advanced (e.g., all players acted), the callback must be a no-op.
  - Be careful with the lambda closure — the `wave_number` must be captured correctly. Consider using `functools.partial` instead.
  - Non-actors are players who have a role action in this wave but haven't submitted it.

### Subtask T020 – Update consumer `wave_start` handler for `deadline`

- **Purpose**: Forward the `deadline` field from the channel layer event to the WebSocket client.
- **Steps**:
  1. Open `backend/apps/onuw/consumers.py`
  2. Locate the `wave_start` handler method.
  3. Add `"deadline"` to the data sent to the client:
     ```python
     await self.send_json({
         "type": "wave_start",
         "wave": event["wave"],
         "deadline": event.get("deadline"),
         # ... other existing fields
     })
     ```
- **Files**: `backend/apps/onuw/consumers.py` (~2 lines modified)
- **Parallel?**: Yes — can proceed alongside T019/T021/T022 (different file).

### Subtask T021 – Cancel wave timer in `advance_wave()`

- **Purpose**: When the host force-advances a wave, cancel the pending timer.
- **Steps**:
  1. In `backend/apps/onuw/services.py`, locate `advance_wave()`.
  2. At the beginning, cancel the current wave timer:
     ```python
     timers.cancel(f"{game.id}:wave:{game.current_wave}")
     ```
- **Files**: `backend/apps/onuw/services.py` (~2 lines added)
- **Parallel?**: No — modifies the same service file as T019.
- **Notes**: This covers the host force-advance path. The `advance_wave()` function is also called by the timer callback's `_auto_advance_wave`, but the timer will already be expired at that point — cancelling a non-existent timer is safe.

### Subtask T022 – Cancel wave timer in `check_and_maybe_advance()`

- **Purpose**: When all players in a wave have acted, cancel the timer before auto-advancing.
- **Steps**:
  1. In `backend/apps/onuw/services.py`, locate `check_and_maybe_advance()` (or equivalent function that detects all-acted).
  2. Before calling `advance_wave()`, cancel the timer:
     ```python
     timers.cancel(f"{game.id}:wave:{game.current_wave}")
     ```
- **Files**: `backend/apps/onuw/services.py` (~2 lines added)
- **Parallel?**: No — modifies the same service file.
- **Notes**: This must happen before `advance_wave()` which calls `send_wave_prompts()` for the next wave — otherwise the new wave's timer could conflict with the old one.

### Subtask T023 – Handle deadline lifecycle across wave transitions

- **Purpose**: Ensure deadline is correctly managed when advancing between waves and when transitioning from night to discussion.
- **Steps**:
  1. When `advance_wave()` calls `send_wave_prompts()` for the next wave, the new wave's timer scheduling (from T019) naturally replaces `game.phase_deadline`.
  2. When the last wave ends and the game transitions to discussion:
     - `game.phase_deadline` is cleared (set to `None`) by `advance_wave()` before `transition_to_discussion()` sets its own deadline (from WP02).
  3. Verify that `advance_wave()` clears `game.phase_deadline` when there are no more waves:
     ```python
     game.phase_deadline = None
     game.save()
     # then call transition_to_discussion(game)
     ```
- **Files**: `backend/apps/onuw/services.py` (~5 lines)
- **Parallel?**: No — depends on T019-T022.
- **Notes**: The key concern is ensuring the old wave's deadline doesn't leak into the discussion phase. The discussion timer from WP02 should set its own deadline independently.

### Subtask T024 – Write integration tests for night wave timer

- **Purpose**: Verify the full night wave timer lifecycle.
- **Steps**:
  1. In `backend/tests/onuw/test_timer_integration.py`, add night wave tests:

     **test_wave_auto_advances_with_skips**:
     - Create a game with `night_wave_seconds: 1`
     - Start a wave where a player has an action
     - Invoke the timer callback
     - Assert the non-acting player's action is recorded as `"skip"`
     - Assert the wave advanced

     **test_all_acted_cancels_wave_timer**:
     - Create a game with `night_wave_seconds: 300`
     - Start a wave, have all active players submit actions
     - Assert wave timer was cancelled
     - Assert wave advanced

     **test_host_force_advance_cancels_wave_timer**:
     - Create a game with `night_wave_seconds: 300`
     - Start a wave
     - Call host force-advance
     - Assert timer was cancelled

     **test_wave_no_timer_when_seconds_zero**:
     - Create a game with `night_wave_seconds: 0`
     - Start a wave
     - Assert no timer scheduled, `phase_deadline` is `None`

     **test_wave_transition_reschedules_timer**:
     - Create a game, advance through two waves
     - Assert each wave had its own timer scheduled with the correct key

- **Files**: `backend/tests/onuw/test_timer_integration.py` (~120 lines added)
- **Parallel?**: No — depends on T019-T023.

### Subtask T025 – Update existing night-phase tests for `deadline`

- **Purpose**: Ensure existing night-phase tests account for the new `deadline` field in `wave_start` events.
- **Steps**:
  1. Search for existing night-phase tests:
     ```bash
     cd backend && grep -rn "wave_start\|send_wave_prompts" tests/ --include="*.py"
     ```
  2. Update fixtures to include `"night_wave_seconds": 0` where timers aren't being tested.
  3. Update event shape assertions to include `"deadline": None`.
- **Files**: Various existing test files
- **Parallel?**: Yes — can proceed alongside T024 (different test files).

## Test Strategy

**Test file**: `backend/tests/onuw/test_timer_integration.py`

**Run commands**:
```bash
cd backend && pytest tests/onuw/test_timer_integration.py -v -k wave
cd backend && pytest tests/onuw/ -v  # full suite
```

**Fixtures needed**:
- Game factory with configurable `night_wave_seconds`
- Ability to create a game in night phase with specific wave configurations
- Mock for `timers.schedule` to capture callbacks

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Old wave timer fires after wave advanced | Idempotent callback checks `game.current_wave == wave_number` |
| Lambda closure captures wrong wave_number | Use `functools.partial` instead of lambda |
| Deadline leaks from night to discussion | `advance_wave()` clears `phase_deadline` before calling `transition_to_discussion()` |
| `send_wave_prompts()` called from `advance_wave()` schedules timer before old is cancelled | T021/T022 cancel old timer before `advance_wave()` runs |

## Review Guidance

- Verify `_auto_advance_wave` checks both phase AND wave number before acting.
- Verify wave timer cancellation happens before `advance_wave()` in both all-acted and host force-advance paths.
- Verify deadline lifecycle: old wave cleared → new wave set → night-to-discussion cleared.
- Verify lambda/partial captures `wave_number` correctly.
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
- 2026-03-26T09:23:39Z – headless-impl – shell_pid=91896 – lane=doing – Assigned agent via workflow command
