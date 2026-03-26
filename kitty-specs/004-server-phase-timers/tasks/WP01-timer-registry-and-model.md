---
work_package_id: WP01
title: Timer Registry & Model Foundation
lane: planned
dependencies: []
requirement_refs: [FR-003, FR-004, FR-005, FR-006, FR-011]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
subtasks:
- T001
- T002
- T003
- T004
- T005
phase: Phase 1 - Foundation
assignee: ''
agent: ''
shell_pid: ''
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-26T08:20:45Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP01 – Timer Registry & Model Foundation

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

- Create the `backend/apps/onuw/timers.py` module with an in-process timer registry that supports `schedule`, `cancel`, and `cancel_all_for_game` operations.
- Add a `phase_deadline` nullable `DateTimeField` to the `Game` model with a clean migration.
- Timer callbacks are wrapped with an idempotent `select_for_update` pattern so stale callbacks are no-ops.
- All new code is covered by unit tests in `backend/tests/onuw/test_timers.py`.

**Key acceptance criteria:**
1. `schedule(key, delay, callback, *args)` stores a `threading.Timer` in the registry and starts it.
2. `cancel(key)` stops and removes a timer; calling cancel on a non-existent key is safe.
3. `cancel_all_for_game(game_id)` cancels all timers whose key starts with `"{game_id}:"`.
4. Scheduling with an existing key cancels the old timer first (idempotent re-schedule).
5. `Game.phase_deadline` is a nullable `DateTimeField` that migrates cleanly.
6. All tests pass; no leaked timer threads after test teardown.

## Context & Constraints

- **Spec**: `kitty-specs/004-server-phase-timers/spec.md` — FR-003, FR-005, FR-006, FR-011
- **Plan**: `kitty-specs/004-server-phase-timers/plan.md` — Design decisions D1 (threading.Timer), D2 (select_for_update)
- **Constitution**: Server-authoritative, atomicity (`@atomic`), determinism (seeded randomness)
- **No new dependencies**: Use `threading.Timer` from the standard library (plan.md D1). No Celery, no APScheduler.
- **Thread safety**: The `_registry` dict must be guarded by a `threading.Lock`.

**Implementation command:**

```bash
spec-kitty implement WP01
```

## Subtasks & Detailed Guidance

### Subtask T001 – Add `phase_deadline` field to Game model

- **Purpose**: Store the current phase's expiry timestamp so it can be returned on reconnection and checked by timer callbacks.
- **Steps**:
  1. Open `backend/apps/onuw/models.py`
  2. Add to the `Game` model:
     ```python
     phase_deadline = models.DateTimeField(null=True, blank=True)
     ```
  3. Place it near the `phase` field for logical grouping.
- **Files**: `backend/apps/onuw/models.py` (~1 line added)
- **Parallel?**: Yes — can proceed alongside T003/T004 (timer module).
- **Notes**: The field is nullable because not all phases are timed (lobby, results). When transitioning to an untimed phase, this should be set to `None`.

### Subtask T002 – Generate and verify the Django migration

- **Purpose**: Create a database migration for the new `phase_deadline` field.
- **Steps**:
  1. Run:
     ```bash
     cd backend && python manage.py makemigrations onuw
     ```
  2. Verify the generated migration adds a nullable `DateTimeField`.
  3. Run:
     ```bash
     cd backend && python manage.py migrate
     ```
  4. Verify the migration applies cleanly.
- **Files**: `backend/apps/onuw/migrations/XXXX_add_phase_deadline.py` (auto-generated)
- **Parallel?**: No — depends on T001.
- **Notes**: This is a safe additive migration (nullable column). No data migration needed.

### Subtask T003 – Create `timers.py` with the timer registry

- **Purpose**: Provide the core timer scheduling infrastructure that all phase timers will use.
- **Steps**:
  1. Create `backend/apps/onuw/timers.py`
  2. Implement module-level state:
     ```python
     import threading
     from typing import Any, Callable

     _registry: dict[str, threading.Timer] = {}
     _lock = threading.Lock()
     ```
  3. Implement `schedule(key: str, delay_seconds: float, callback: Callable, *args: Any) -> None`:
     - Acquire `_lock`
     - If `key` already in `_registry`, cancel the existing timer
     - Create a new `threading.Timer(delay_seconds, callback, args=args)`
     - Set `timer.daemon = True` (so it doesn't block process shutdown)
     - Store in `_registry[key]` and start it
  4. Implement `cancel(key: str) -> None`:
     - Acquire `_lock`
     - If `key` in `_registry`, cancel the timer and remove it
     - If `key` not in `_registry`, no-op (safe double-cancel)
  5. Implement `cancel_all_for_game(game_id: int | str) -> None`:
     - Acquire `_lock`
     - Find all keys starting with `"{game_id}:"`
     - Cancel and remove each
- **Files**: `backend/apps/onuw/timers.py` (new, ~60 lines)
- **Parallel?**: Yes — can proceed alongside T001/T002 (model changes).
- **Notes**:
  - Key format convention: `"{game_id}:discussion"`, `"{game_id}:voting"`, `"{game_id}:wave:{wave_number}"`
  - `timer.daemon = True` ensures timer threads don't prevent process exit
  - The lock must be held for the shortest possible duration

### Subtask T004 – Implement idempotent callback wrapper

- **Purpose**: Ensure timer callbacks are safe even if the game state has already changed (e.g., host ended discussion 1ms before the timer fired).
- **Steps**:
  1. In `timers.py`, create a wrapper function or pattern:
     ```python
     from django.db import transaction
     from apps.onuw.models import Game

     def make_idempotent_callback(game_id: int, expected_phase: str, action: Callable[[Game], None]) -> Callable:
         """Wrap a timer action so it only executes if the game is still in the expected phase."""
         def _callback():
             with transaction.atomic():
                 try:
                     game = Game.objects.select_for_update().get(id=game_id)
                 except Game.DoesNotExist:
                     return  # Game was deleted
                 if game.phase != expected_phase:
                     return  # Phase already changed — no-op
                 action(game)
         return _callback
     ```
  2. This wrapper will be used by WP02-WP04 when scheduling actual timer callbacks.
- **Files**: `backend/apps/onuw/timers.py` (~20 lines added)
- **Parallel?**: Yes — can proceed alongside T001/T002.
- **Notes**:
  - The `select_for_update()` serializes concurrent callbacks — if two timer threads race, only one proceeds.
  - The `Game.DoesNotExist` guard handles edge cases where a game is deleted while a timer is pending.
  - Import Game at function scope if needed to avoid circular imports.

### Subtask T005 – Write unit tests for the timer registry

- **Purpose**: Verify all timer registry operations work correctly and edge cases are handled.
- **Steps**:
  1. Create `backend/tests/onuw/test_timers.py`
  2. Write tests using `pytest` with `@pytest.mark.unit`:
     - **test_schedule_fires_callback**: Schedule a timer with a short delay (0.1s), assert callback is called.
     - **test_cancel_prevents_firing**: Schedule a timer, cancel it, wait past the delay, assert callback was NOT called.
     - **test_cancel_all_for_game**: Schedule multiple timers for a game ID, call `cancel_all_for_game`, assert none fire.
     - **test_double_cancel_is_safe**: Cancel a key that doesn't exist — no exception raised.
     - **test_reschedule_replaces_existing**: Schedule key "X", schedule key "X" again with different callback, assert only the second callback fires.
     - **test_idempotent_callback_noop_on_phase_change**: Create a game in discussion phase, build an idempotent callback expecting discussion, change phase to voting, fire callback — assert no transition occurs.
     - **test_idempotent_callback_executes_on_matching_phase**: Create a game in discussion phase, build an idempotent callback expecting discussion, fire callback — assert action is executed.
  3. Add teardown fixture that calls `cancel_all_for_game` or clears `_registry` to prevent leaked threads.
- **Files**: `backend/tests/onuw/test_timers.py` (new, ~120 lines)
- **Parallel?**: No — depends on T003 and T004 (timer module must exist). T005 also needs T001 for the idempotent callback tests that use the Game model.
- **Notes**:
  - Use `threading.Event` for synchronization in callback-fired assertions (avoid `time.sleep` where possible).
  - The idempotent callback tests (last two) need a database, so mark them as `@pytest.mark.integration` or use `@pytest.mark.django_db`.
  - Teardown is critical: add a fixture that clears `_registry` after each test to prevent leaked timer threads.

## Test Strategy

**Test file**: `backend/tests/onuw/test_timers.py`

**Run command**:
```bash
cd backend && pytest tests/onuw/test_timers.py -v
```

**Fixtures needed**:
- A `clean_timer_registry` autouse fixture that clears `timers._registry` after each test
- For idempotent callback tests: a Game instance created via the existing test factories

**Coverage targets**: All branches in `schedule()`, `cancel()`, `cancel_all_for_game()`, and `make_idempotent_callback()`.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Leaked timer threads in tests | Autouse fixture clears registry and cancels all timers after each test |
| Thread safety of `_registry` dict | `threading.Lock` guards all mutations |
| Circular imports (Game model in timers.py) | Import Game inside the callback wrapper function, not at module level |
| Timer callbacks running during test teardown | Set `timer.daemon = True` so threads don't block process exit |

## Review Guidance

- Verify `_lock` is acquired for every `_registry` mutation (schedule, cancel, cancel_all).
- Verify `timer.daemon = True` is set on all created timers.
- Verify `make_idempotent_callback` uses `transaction.atomic()` and `select_for_update()`.
- Verify the migration is additive (nullable field, no data migration).
- Verify test teardown clears the registry.
- Verify no leaked threads by running `pytest` with `-x` and observing clean exit.

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
