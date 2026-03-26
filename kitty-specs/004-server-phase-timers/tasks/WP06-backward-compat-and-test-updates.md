---
work_package_id: WP06
title: Backward Compatibility & Existing Test Updates
lane: planned
dependencies: [WP02, WP03, WP04]
requirement_refs: [FR-009, FR-012]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
subtasks:
- T032
- T033
- T034
- T035
- T036
- T037
phase: Phase 4 - Stabilization
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

# Work Package Prompt: WP06 – Backward Compatibility & Existing Test Updates

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

- Create a shared test fixture that disables timers for tests that don't test timer behavior.
- Update all existing test files that assert on `phase_change`, `wave_start`, or `/me/` event shapes to account for the new `deadline` field.
- Verify `just check` and `just test` pass with zero failures and passing coverage threshold.

**Key acceptance criteria:**
1. A `conftest.py` fixture auto-patches `timers.schedule` to be a no-op for all tests, with an opt-out mechanism for timer-specific tests.
2. All existing test files updated to handle the `deadline` field.
3. `just check` passes (lint + format + typecheck).
4. `just test` passes (all tests green, 80% coverage).

## Context & Constraints

- **Spec**: `kitty-specs/004-server-phase-timers/spec.md` — FR-009, FR-012
- **Depends on WP02, WP03, WP04**: All timer integration must be complete before this final verification pass.
- **This is the last WP**: All other integration is done; this ensures stability.
- **Preferred approach**: Auto-mock `timers.schedule` globally rather than updating every test's settings — this is safer and more maintainable.

**Implementation command:**

```bash
spec-kitty implement WP06 --base WP04
```

## Subtasks & Detailed Guidance

### Subtask T032 – Create shared test fixture for timer-disabled tests

- **Purpose**: Prevent timer threads from spawning in tests that don't explicitly test timer behavior.
- **Steps**:
  1. Open `backend/tests/onuw/conftest.py` (create if it doesn't exist)
  2. Add an autouse fixture that mocks the timer schedule function:
     ```python
     import pytest
     from unittest.mock import patch

     @pytest.fixture(autouse=True)
     def disable_timers():
         """Disable timer scheduling for all tests by default.
         Tests that need real timers should use @pytest.mark.enable_timers."""
         with patch("apps.onuw.timers.schedule") as mock_schedule:
             yield mock_schedule

     @pytest.fixture
     def enable_timers(disable_timers):
         """Opt out of timer mocking for tests that need real timer behavior."""
         disable_timers.side_effect = None  # Re-enable
         # Actually, better: stop the patch and re-import
         # This needs careful design — see implementation notes
     ```
  3. Also add teardown that clears the timer registry:
     ```python
     @pytest.fixture(autouse=True)
     def clean_timer_registry():
         """Clear timer registry after each test to prevent leaked threads."""
         yield
         from apps.onuw import timers
         with timers._lock:
             for timer in timers._registry.values():
                 timer.cancel()
             timers._registry.clear()
     ```
- **Files**: `backend/tests/onuw/conftest.py` (~30 lines)
- **Parallel?**: No — must be done first; other test updates depend on this.
- **Notes**:
  - The autouse fixture means NO test will accidentally schedule real timers.
  - Timer-specific tests (from WP01-WP05) should either use `@pytest.mark.enable_timers` or explicitly mock `timers.schedule` themselves.
  - The `clean_timer_registry` fixture is a safety net for timer tests that do create real timers.

### Subtask T033 – Update `test_game_consumer.py` for deadline field

- **Purpose**: Consumer tests that assert on `phase_change` and `wave_start` event shapes need updating.
- **Steps**:
  1. Open `backend/tests/onuw/test_game_consumer.py`
  2. Find all assertions on `phase_change` events and add `"deadline": None` (or match any value).
  3. Find all assertions on `wave_start` events and add `"deadline": None`.
  4. If tests create games with settings, add `"discussion_seconds": 0, "voting_seconds": 0, "night_wave_seconds": 0`.
- **Files**: `backend/tests/onuw/test_game_consumer.py`
- **Parallel?**: Yes — independent from T034/T035/T036.

### Subtask T034 – Update `test_discussion_to_voting_e2e.py` for timer changes

- **Purpose**: End-to-end test for discussion-to-voting flow needs to account for timer integration.
- **Steps**:
  1. Open `backend/tests/onuw/test_discussion_to_voting_e2e.py`
  2. Update game settings to include `"discussion_seconds": 0, "voting_seconds": 0`.
  3. Update any event shape assertions to include `"deadline": None`.
  4. If the test verifies the discussion-to-voting transition, it should still work via manual end-discussion (not timer).
- **Files**: `backend/tests/onuw/test_discussion_to_voting_e2e.py`
- **Parallel?**: Yes — independent.

### Subtask T035 – Update `test_full_game_e2e.py` for timer changes

- **Purpose**: Full game lifecycle test needs to work with the timer system.
- **Steps**:
  1. Open `backend/tests/onuw/test_full_game_e2e.py`
  2. Update game settings to disable all timers: `"discussion_seconds": 0, "voting_seconds": 0, "night_wave_seconds": 0`.
  3. Update event shape assertions to include `"deadline": None` where applicable.
- **Files**: `backend/tests/onuw/test_full_game_e2e.py`
- **Parallel?**: Yes — independent.

### Subtask T036 – Update `test_reconnection.py` for deadline field

- **Purpose**: Reconnection tests should verify the `/me/` endpoint includes the `deadline` field.
- **Steps**:
  1. Open `backend/tests/onuw/test_reconnection.py`
  2. Update assertions on the `/me/` response to include `"deadline"` (either a value or `None`).
  3. Optionally add a test that verifies `deadline` is populated during a timed phase.
- **Files**: `backend/tests/onuw/test_reconnection.py`
- **Parallel?**: Yes — independent.

### Subtask T037 – Run `just check` and `just test` — all green

- **Purpose**: Final verification that all quality gates pass.
- **Steps**:
  1. Run lint + format + typecheck:
     ```bash
     just check
     ```
  2. Fix any issues.
  3. Run full test suite:
     ```bash
     just test
     ```
  4. Verify all tests pass and coverage meets the 80% threshold.
  5. If any failures, investigate and fix — do not proceed until green.
- **Files**: None (verification only)
- **Parallel?**: No — must run after all other subtasks.
- **Notes**: This is the definitive quality gate. If this fails, the feature is not complete.

## Test Strategy

**Run commands**:
```bash
just check   # lint + format + typecheck
just test    # all tests + coverage
```

**Expected outcome**: Zero failures, 80%+ coverage, clean lint.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Autouse fixture breaks timer-specific tests | Timer tests mock `timers.schedule` explicitly or use opt-out marker |
| Leaked timer threads cause flaky tests | `clean_timer_registry` autouse fixture cancels all timers after each test |
| Coverage drops below 80% | All new code in WP01-WP05 has dedicated tests |
| Typecheck fails on new code | Ensure all timer functions have type hints; run `pyrefly` early |

## Review Guidance

- Verify the autouse fixture correctly mocks `timers.schedule` for all tests.
- Verify timer-specific tests (from WP01-WP05) still work correctly with the fixture.
- Verify `just check` and `just test` output is clean (paste output in activity log).
- Verify no test files were accidentally deleted or broken.

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
