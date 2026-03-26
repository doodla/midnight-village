---
work_package_id: WP02
title: Discussion Timer Integration
lane: "doing"
dependencies: [WP01]
requirement_refs: [FR-001, FR-003, FR-004, FR-005, FR-007, FR-008, FR-009, FR-012]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 004-server-phase-timers-WP01
base_commit: 035f6f12bca69265e4f4c4d7b4a1708811f076a4
created_at: '2026-03-26T08:59:20.740481+00:00'
subtasks:
- T006
- T007
- T008
- T009
- T010
- T011
- T012
phase: Phase 2 - Timer Integration
assignee: ''
agent: "headless-reviewer"
shell_pid: "71390"
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-26T08:20:45Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP02 – Discussion Timer Integration

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

- When the game transitions to the discussion phase, compute and store the deadline, schedule an auto-transition timer, and broadcast the deadline in the `phase_change` event.
- Host can still end discussion early, which cancels the timer.
- If `discussion_seconds == 0`, no timer is scheduled and `deadline` is `null` (backward-compatible).
- All existing tests that assert on `phase_change` event shapes are updated for the new `deadline` field.

**Key acceptance criteria:**
1. `transition_to_discussion()` sets `game.phase_deadline` and schedules a timer that calls `transition_to_voting()`.
2. The `phase_change` event includes `"deadline": "<ISO 8601>"` or `"deadline": null`.
3. `end_discussion()` cancels the discussion timer before transitioning.
4. When `discussion_seconds == 0`, no timer is scheduled and `deadline` is `null`.
5. Integration tests verify auto-transition, early end, and zero-duration behavior.

## Context & Constraints

- **Spec**: `kitty-specs/004-server-phase-timers/spec.md` — User Story 1, FR-001, FR-003, FR-004, FR-009
- **Plan**: `kitty-specs/004-server-phase-timers/plan.md` — D1 (threading.Timer), D4 (backward compat), D5 (settings source)
- **Depends on WP01**: Timer registry (`timers.schedule`, `timers.cancel`) and `Game.phase_deadline` field must exist.
- **Key files to modify**: `backend/apps/onuw/services.py`, `backend/apps/onuw/consumers.py`
- **Timer key**: `"{game_id}:discussion"`
- **Default duration**: 300 seconds (FR-008)

**Implementation command:**

```bash
spec-kitty implement WP02 --base WP01
```

## Subtasks & Detailed Guidance

### Subtask T006 – Add `get_timer_seconds()` helper to services.py

- **Purpose**: Centralize reading timer durations from game settings with defaults.
- **Steps**:
  1. Open `backend/apps/onuw/services.py`
  2. Add a helper function:
     ```python
     def get_timer_seconds(game: Game, key: str, default: int) -> int:
         """Read a timer duration from game settings, returning default if not set."""
         return game.settings.get(key, default)
     ```
  3. This will be called as `get_timer_seconds(game, "discussion_seconds", 300)`.
- **Files**: `backend/apps/onuw/services.py` (~5 lines added)
- **Parallel?**: No — other subtasks depend on this helper.
- **Notes**: `game.settings` is a `JSONField` dict that's copied from lobby settings at game start. Timer durations live alongside the `roles` key.

### Subtask T007 – Integrate deadline in `transition_to_discussion()`

- **Purpose**: Compute the deadline, store it on the game, and schedule the auto-transition timer.
- **Steps**:
  1. In `backend/apps/onuw/services.py`, locate `transition_to_discussion()`.
  2. After setting `game.phase = Phase.DISCUSSION`, add:
     ```python
     from django.utils import timezone
     from apps.onuw import timers

     discussion_seconds = get_timer_seconds(game, "discussion_seconds", 300)
     if discussion_seconds > 0:
         game.phase_deadline = timezone.now() + timedelta(seconds=discussion_seconds)
         callback = timers.make_idempotent_callback(
             game.id, Phase.DISCUSSION, _auto_transition_to_voting
         )
         timers.schedule(f"{game.id}:discussion", discussion_seconds, callback)
     else:
         game.phase_deadline = None
     game.save()
     ```
  3. Create the `_auto_transition_to_voting(game: Game)` helper that calls the existing voting transition logic.
- **Files**: `backend/apps/onuw/services.py` (~15 lines added)
- **Parallel?**: No — core change that T008 depends on.
- **Notes**:
  - The `timedelta` import is from `datetime`.
  - The idempotent wrapper from WP01 ensures that if the host ended discussion before the timer fires, the callback is a no-op.
  - `game.save()` must happen inside the same `@atomic` block that sets the phase.

### Subtask T008 – Add `deadline` to discussion `phase_change` event broadcast

- **Purpose**: Include the deadline timestamp in the WebSocket event so clients can display a countdown.
- **Steps**:
  1. In `transition_to_discussion()`, locate the broadcast call (e.g., `channel_layer.group_send(...)` or the event construction).
  2. Add `"deadline"` to the event payload:
     ```python
     {
         "type": "phase.change",
         "phase": "discussion",
         "deadline": game.phase_deadline.isoformat() if game.phase_deadline else None,
     }
     ```
  3. Ensure `deadline` is always present (as `null` when untimed).
- **Files**: `backend/apps/onuw/services.py` (~3 lines modified)
- **Parallel?**: No — part of the same `transition_to_discussion()` changes as T007.
- **Notes**: Use `.isoformat()` for ISO 8601 format. The field should always be present (not omitted) for consistent event shapes.

### Subtask T009 – Update consumer `phase_change` handler for `deadline`

- **Purpose**: Forward the `deadline` field from the channel layer event to the WebSocket client.
- **Steps**:
  1. Open `backend/apps/onuw/consumers.py`
  2. Locate the `phase_change` handler method (likely `phase_change` or `handle_phase_change`).
  3. Add `"deadline"` to the data sent to the client:
     ```python
     await self.send_json({
         "type": "phase_change",
         "phase": event["phase"],
         "deadline": event.get("deadline"),
         # ... other existing fields
     })
     ```
- **Files**: `backend/apps/onuw/consumers.py` (~2 lines modified)
- **Parallel?**: Yes — can proceed alongside T007/T008 (different file).
- **Notes**: Use `event.get("deadline")` to safely handle events that don't include the field (backward compat during rollout).

### Subtask T010 – Cancel discussion timer in `end_discussion()`

- **Purpose**: When the host manually ends discussion, cancel the scheduled auto-transition to prevent a double-transition.
- **Steps**:
  1. In `backend/apps/onuw/services.py`, locate `end_discussion()` (or the equivalent host-initiated transition function).
  2. At the beginning of the function (before changing phase), add:
     ```python
     timers.cancel(f"{game.id}:discussion")
     ```
  3. Also clear the deadline:
     ```python
     game.phase_deadline = None
     ```
- **Files**: `backend/apps/onuw/services.py` (~3 lines added)
- **Parallel?**: No — modifies the same service file.
- **Notes**: Cancelling a non-existent timer is safe (no-op), so this works even if `discussion_seconds` was 0.

### Subtask T011 – Write integration tests for discussion timer

- **Purpose**: Verify the full discussion timer lifecycle: auto-transition, early cancellation, and zero-duration behavior.
- **Steps**:
  1. Create or extend `backend/tests/onuw/test_timer_integration.py`
  2. Write tests with `@pytest.mark.integration` and `@pytest.mark.django_db`:

     **test_discussion_auto_transitions_to_voting**:
     - Create a game, set `discussion_seconds: 1` (short for testing)
     - Transition to discussion
     - Assert `game.phase_deadline` is set
     - Wait for timer (or mock `timers.schedule` to capture callback and invoke it directly)
     - Assert game is now in voting phase

     **test_end_discussion_cancels_timer**:
     - Create a game, set `discussion_seconds: 300`
     - Transition to discussion
     - Call `end_discussion()`
     - Assert the timer for `"{game_id}:discussion"` is no longer in the registry
     - Assert game is in voting phase (from the manual transition)

     **test_discussion_no_timer_when_seconds_zero**:
     - Create a game, set `discussion_seconds: 0`
     - Transition to discussion
     - Assert `game.phase_deadline` is `None`
     - Assert no timer was scheduled for `"{game_id}:discussion"`

     **test_discussion_phase_change_includes_deadline**:
     - Create a game with `discussion_seconds: 180`
     - Transition to discussion
     - Capture the broadcast event
     - Assert event contains `"deadline"` with an ISO 8601 timestamp ~180s in the future

- **Files**: `backend/tests/onuw/test_timer_integration.py` (new or extended, ~100 lines)
- **Parallel?**: No — depends on T006-T010 being complete.
- **Notes**: Prefer mocking `timers.schedule` to capture the callback rather than using real timers with `time.sleep`. This makes tests fast and deterministic.

### Subtask T012 – Update existing tests for `phase_change` deadline field

- **Purpose**: Existing tests that assert on the shape of `phase_change` events will fail because they don't expect the `deadline` field.
- **Steps**:
  1. Search for tests asserting on `phase_change` events:
     ```bash
     cd backend && grep -r "phase.change\|phase_change" tests/ --include="*.py"
     ```
  2. For each test that doesn't test timers:
     - Add `"discussion_seconds": 0, "voting_seconds": 0` to the game/lobby settings fixture
     - OR update the assertion to include `"deadline": None`
  3. Verify these tests still pass.
- **Files**: Various existing test files in `backend/tests/onuw/` (~5-10 lines modified per file)
- **Parallel?**: Yes — can proceed alongside T011 (different test files).
- **Notes**: The preferred approach is to set `*_seconds: 0` in test fixtures that don't test timers. This keeps assertions clean and avoids dealing with timer thread cleanup.

## Test Strategy

**Test files**:
- `backend/tests/onuw/test_timer_integration.py` (new tests)
- Various existing test files (updates)

**Run commands**:
```bash
cd backend && pytest tests/onuw/test_timer_integration.py -v
cd backend && pytest tests/onuw/ -v  # full suite to verify no regressions
```

**Fixtures needed**:
- Game factory with configurable `discussion_seconds` in settings
- Mock or patch for `timers.schedule` to capture callbacks without real threads

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Existing tests break from unexpected `deadline` field | Set `discussion_seconds: 0` in existing test fixtures (T012) |
| Timer callback fires during test teardown | Mock `timers.schedule` in integration tests; use daemon threads |
| Race between host end-discussion and timer callback | Idempotent callback wrapper from WP01 handles this |
| `phase_change` event shape change breaks frontend | `deadline` is always present (null when untimed) — additive change |

## Review Guidance

- Verify `transition_to_discussion()` sets `game.phase_deadline` and calls `timers.schedule()`.
- Verify `end_discussion()` calls `timers.cancel()` and clears `game.phase_deadline`.
- Verify the `phase_change` event always includes `"deadline"` (not conditionally omitted).
- Verify existing test updates use `discussion_seconds: 0` or equivalent.
- Verify integration tests cover: auto-transition, early cancellation, zero-duration.
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
- 2026-03-26T08:59:20Z – headless-impl – shell_pid=58693 – lane=doing – Assigned agent via workflow command
- 2026-03-26T09:09:23Z – headless-impl – shell_pid=58693 – lane=for_review – Ready for review: discussion timer integrated — phase_deadline set on transition, auto-transition via idempotent callback, end_discussion cancels timer, phase_change event always includes deadline field, 5 integration tests covering all cases, 459/459 tests passing
- 2026-03-26T09:09:41Z – headless-reviewer – shell_pid=71390 – lane=doing – Started review via workflow command
