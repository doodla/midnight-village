---
work_package_id: WP05
title: Timer Settings Validation & Reconnection
lane: planned
dependencies: [WP01]
requirement_refs: [FR-006, FR-007, FR-008, FR-009, FR-010, FR-012, FR-013]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
subtasks:
- T026
- T027
- T028
- T029
- T030
- T031
phase: Phase 3 - Settings & Recovery
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

# Work Package Prompt: WP05 – Timer Settings Validation & Reconnection

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

- Validate timer duration settings (`discussion_seconds`, `voting_seconds`, `night_wave_seconds`) in lobby configuration.
- Expose the `phase_deadline` in the `/me/` endpoint for player reconnection.
- Add a startup recovery sweep that detects games with past-due deadlines and transitions them immediately, and reschedules timers for games with future deadlines.

**Key acceptance criteria:**
1. `validate_onuw_settings()` rejects negative values and values over 600; accepts 0 (no timer) and valid positive integers.
2. The `/me/` endpoint includes `"deadline"` (ISO 8601 or `null`).
3. On startup, past-due games are transitioned and future-deadline games get rescheduled.
4. Startup recovery does not run during migrations or tests (guarded).

## Context & Constraints

- **Spec**: `kitty-specs/004-server-phase-timers/spec.md` — User Stories 3 & 5, FR-006 through FR-013
- **Plan**: `kitty-specs/004-server-phase-timers/plan.md` — D3 (startup recovery), D5 (settings source)
- **Depends on WP01**: Timer registry and `Game.phase_deadline`.
- **Should follow WP02-WP04**: Startup recovery calls transition functions that should already have timer integration.
- **Validation is pure Python**: `engine/validation.py` has no Django imports — keep it that way.

**Implementation command:**

```bash
spec-kitty implement WP05 --base WP01
```

## Subtasks & Detailed Guidance

### Subtask T026 – Add timer duration validation to `validate_onuw_settings()`

- **Purpose**: Prevent invalid timer durations from being saved in lobby settings.
- **Steps**:
  1. Open `backend/apps/onuw/engine/validation.py`
  2. Locate `validate_onuw_settings()`.
  3. Add validation for optional timer fields:
     ```python
     TIMER_FIELDS = ["discussion_seconds", "voting_seconds", "night_wave_seconds"]
     for field in TIMER_FIELDS:
         if field in settings:
             value = settings[field]
             if not isinstance(value, int):
                 errors.append(f"{field} must be an integer")
             elif value < 0:
                 errors.append(f"{field} must be non-negative")
             elif value > 600:
                 errors.append(f"{field} must be at most 600 seconds")
     ```
  4. These fields are optional — if not present, defaults apply at runtime (300/120/30).
- **Files**: `backend/apps/onuw/engine/validation.py` (~15 lines added)
- **Parallel?**: Yes — independent from T027 and T028.
- **Notes**: Keep this pure Python — no Django imports. The validation function should return errors in the same format as existing validations.

### Subtask T027 – Add `deadline` field to `GameMeSerializer`

- **Purpose**: Allow reconnecting players to see the current phase deadline.
- **Steps**:
  1. Open `backend/apps/onuw/serializers.py`
  2. Locate `GameMeSerializer`.
  3. Add the deadline field:
     ```python
     deadline = serializers.DateTimeField(source='phase_deadline', allow_null=True, read_only=True)
     ```
  4. Add `"deadline"` to the `Meta.fields` list.
- **Files**: `backend/apps/onuw/serializers.py` (~2 lines added)
- **Parallel?**: Yes — independent from T026 and T028.
- **Notes**: The `source='phase_deadline'` maps the model field to a cleaner API name. The field is read-only and nullable.

### Subtask T028 – Add startup recovery in `AppConfig.ready()`

- **Purpose**: When the server restarts, any in-memory timers are lost. This sweep detects games that should have timed transitions and either transitions them (if past-due) or reschedules timers (if future).
- **Steps**:
  1. Open `backend/apps/onuw/apps.py`
  2. In `OnuwConfig.ready()`, add a recovery function call:
     ```python
     import sys

     def ready(self):
         # Guard: don't run during migrations, tests, or management commands
         if 'migrate' in sys.argv or 'makemigrations' in sys.argv or 'test' in sys.argv:
             return
         from apps.onuw.timers import recover_on_startup
         recover_on_startup()
     ```
  3. In `backend/apps/onuw/timers.py`, implement `recover_on_startup()`:
     ```python
     def recover_on_startup():
         """Recover timers for games in timed phases after server restart."""
         from django.utils import timezone
         from apps.onuw.models import Game, Phase

         timed_phases = [Phase.DISCUSSION, Phase.VOTING, Phase.NIGHT]
         games = Game.objects.filter(
             phase__in=timed_phases,
             phase_deadline__isnull=False,
         )
         now = timezone.now()
         for game in games:
             if game.phase_deadline <= now:
                 # Past due — transition immediately
                 _recover_past_due_game(game)
             else:
                 # Future deadline — reschedule timer
                 remaining = (game.phase_deadline - now).total_seconds()
                 _reschedule_game_timer(game, remaining)
     ```
  4. Implement `_recover_past_due_game(game)` and `_reschedule_game_timer(game, remaining)` helpers that call the appropriate transition or schedule functions.
- **Files**: `backend/apps/onuw/apps.py` (~10 lines), `backend/apps/onuw/timers.py` (~40 lines)
- **Parallel?**: Yes — independent from T026 and T027.
- **Notes**:
  - The `ready()` guard is critical — without it, timer recovery runs during `makemigrations` and `test` commands.
  - `_recover_past_due_game` should call the same transition functions used by timer callbacks (which are idempotent).
  - `_reschedule_game_timer` needs to determine which timer to schedule based on `game.phase` (discussion, voting, or wave).

### Subtask T029 – Write unit tests for timer settings validation

- **Purpose**: Verify the validation rules for timer duration fields.
- **Steps**:
  1. In `backend/tests/onuw/test_validation.py` (or create if needed), add tests:

     **test_valid_timer_durations**: Settings with `discussion_seconds: 300, voting_seconds: 120, night_wave_seconds: 30` pass validation.

     **test_zero_timer_means_no_timer**: Settings with `discussion_seconds: 0` pass validation.

     **test_negative_timer_rejected**: Settings with `discussion_seconds: -5` produce a validation error.

     **test_over_max_timer_rejected**: Settings with `discussion_seconds: 601` produce a validation error.

     **test_missing_timer_keys_valid**: Settings without any timer keys pass validation (defaults used at runtime).

     **test_non_integer_timer_rejected**: Settings with `discussion_seconds: "fast"` produce a validation error.

- **Files**: `backend/tests/onuw/test_validation.py` (~50 lines added)
- **Parallel?**: Yes — can proceed alongside T030 and T031.

### Subtask T030 – Write integration tests for reconnection deadline

- **Purpose**: Verify the `/me/` endpoint returns the deadline during timed phases.
- **Steps**:
  1. In `backend/tests/onuw/test_timer_integration.py`, add:

     **test_me_endpoint_returns_deadline_during_discussion**:
     - Create a game in discussion phase with a deadline set
     - Call `GET /api/onuw/games/<id>/me/`
     - Assert response includes `"deadline"` with an ISO 8601 value

     **test_me_endpoint_returns_null_deadline_during_results**:
     - Create a game in results phase
     - Call `GET /api/onuw/games/<id>/me/`
     - Assert response includes `"deadline": null`

- **Files**: `backend/tests/onuw/test_timer_integration.py` (~40 lines added)
- **Parallel?**: Yes — independent tests.

### Subtask T031 – Write integration tests for startup recovery

- **Purpose**: Verify the startup recovery sweep correctly handles past-due and future-deadline games.
- **Steps**:
  1. In `backend/tests/onuw/test_timer_integration.py`, add:

     **test_startup_recovery_transitions_past_due_game**:
     - Create a game in discussion phase with `phase_deadline` 1 minute in the past
     - Call `recover_on_startup()`
     - Assert game is now in voting phase

     **test_startup_recovery_reschedules_future_deadline**:
     - Create a game in discussion phase with `phase_deadline` 5 minutes in the future
     - Call `recover_on_startup()`
     - Assert a timer is scheduled in the registry for `"{game_id}:discussion"`

     **test_startup_recovery_ignores_untimed_games**:
     - Create a game in results phase (no deadline)
     - Call `recover_on_startup()`
     - Assert no timers scheduled, game unchanged

- **Files**: `backend/tests/onuw/test_timer_integration.py` (~60 lines added)
- **Parallel?**: Yes — independent tests.

## Test Strategy

**Test files**:
- `backend/tests/onuw/test_validation.py` (timer settings validation)
- `backend/tests/onuw/test_timer_integration.py` (reconnection + startup recovery)

**Run commands**:
```bash
cd backend && pytest tests/onuw/test_validation.py -v -k timer
cd backend && pytest tests/onuw/test_timer_integration.py -v -k "reconnect or startup"
cd backend && pytest tests/onuw/ -v  # full suite
```

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `ready()` runs during migrations | Guard with `sys.argv` check |
| `ready()` runs during tests | Guard with `sys.argv` check; tests call `recover_on_startup()` directly |
| Startup recovery calls transition functions that schedule new timers | Transition functions use idempotent timer scheduling (cancel-before-schedule from WP01) |
| Validation rejects previously-valid settings | Timer fields are optional — omitting them is valid |

## Review Guidance

- Verify validation is pure Python (no Django imports in `engine/validation.py`).
- Verify `ready()` has guards for migrations, tests, and management commands.
- Verify `recover_on_startup()` handles both past-due and future-deadline cases.
- Verify `/me/` serializer includes `deadline` mapped to `phase_deadline`.
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
