---
work_package_id: WP03
title: Golden Test Examples & Validation
lane: "doing"
dependencies: [WP01]
requirement_refs: [FR-001, FR-002, FR-012]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 002-flutter-ui-test-infrastructure-WP01
base_commit: 33c593410764b008553bffaeefecfd8def41d785
created_at: '2026-03-26T01:21:51.805372+00:00'
subtasks:
- T011
- T012
- T013
- T014
- T015
phase: Phase 1 - Core Layers
assignee: ''
agent: "headless-impl"
shell_pid: "76910"
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-25T23:55:37Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP03 – Golden Test Examples & Validation

## IMPORTANT: Review Feedback Status

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

Prove the golden test framework works end-to-end by writing golden tests for existing design system components. Validate the full generate/compare/update cycle and confirm deterministic output across runs.

**Success criteria**:
- Run `just flutter-test-golden` and see 3 component golden tests pass
- Modify a component color, run again, see test fail
- Run `just flutter-golden-update`, see new baselines generated
- Run golden tests twice consecutively, confirm baseline files are byte-identical

**Implementation command**: `spec-kitty implement WP03 --base WP01`

## Context & Constraints

- **Spec**: `kitty-specs/002-flutter-ui-test-infrastructure/spec.md` — User Story 1; FR-001, FR-002, FR-012
- **Plan**: `kitty-specs/002-flutter-ui-test-infrastructure/plan.md` — Decisions #1-3
- **Depends on WP01**: Golden test helper (`pumpWithGolden`), `flutter_test_config.dart`, justfile commands, platform-specific comparator
- **Theme**: Use `MidnightVillageTheme()` (production theme) for golden baselines, NOT `TestThemeTokens` — goldens should match real appearance
- **Existing components**: Check `frontend/lib/` for `MvButton`, `RoleCard`, `PlayerCircle` — these are the components to write golden tests for
- **Tag**: All golden test files must include `@Tags(['golden'])` annotation

## Subtasks & Detailed Guidance

### Subtask T011 – Golden test for `MvButton` (3 variants)

- **Purpose**: Write the first golden test to prove the framework works, covering primary, secondary, and disabled button variants.
- **Steps**:
  1. Locate `MvButton` widget in `frontend/lib/` (likely under `design_system/components/core/`)
  2. Create `frontend/test/design_system/components/core/mv_button_golden_test.dart`
  3. Add `@Tags(['golden'])` annotation at the top of the file
  4. Write golden tests for each variant:
     ```dart
     @Tags(['golden'])
     library;

     import 'package:flutter_test/flutter_test.dart';
     // ... imports

     void main() {
       testWidgets('MvButton primary variant golden', (tester) async {
         await tester.pumpWithGolden(
           MvButton(label: 'Primary', onPressed: () {}, variant: MvButtonVariant.primary),
           'mv_button_primary',
         );
       });

       testWidgets('MvButton secondary variant golden', (tester) async {
         // ... secondary variant
       });

       testWidgets('MvButton disabled variant golden', (tester) async {
         // ... disabled (onPressed: null)
       });
     }
     ```
  5. Generate initial baselines: `just flutter-golden-update`
  6. Verify tests pass on re-run: `just flutter-test-golden`
- **Files**: `frontend/test/design_system/components/core/mv_button_golden_test.dart` (new, ~60 lines)
- **Parallel?**: Yes — independent of T012 and T013 (different components)
- **Notes**: Check the actual `MvButton` API — variant enum names and constructor parameters may differ. If `MvButton` doesn't exist, use whatever primary button component is available. The `@Tags(['golden'])` must be a library-level annotation.

### Subtask T012 – Golden test for `RoleCard` (3 states)

- **Purpose**: Test a game-specific component with multiple visual states — werewolf role, villager role, and face-down (hidden) state.
- **Steps**:
  1. Locate `RoleCard` widget in `frontend/lib/` (likely under `design_system/components/game/`)
  2. Create `frontend/test/design_system/components/game/role_card_golden_test.dart`
  3. Add `@Tags(['golden'])` annotation
  4. Write golden tests for:
     - Werewolf role (face up, showing werewolf art/icon)
     - Villager role (face up, showing villager art/icon)
     - Face-down state (card back, no role revealed)
  5. Use `pumpWithGolden` for each test
  6. Generate baselines: `just flutter-golden-update`
- **Files**: `frontend/test/design_system/components/game/role_card_golden_test.dart` (new, ~60 lines)
- **Parallel?**: Yes — independent of T011 and T013
- **Notes**: `RoleCard` may need provider overrides if it reads game state. If so, compose `pumpWithGolden` with `pumpWithTokens` or pass provider overrides. Check the component's constructor requirements.

### Subtask T013 – Golden test for `PlayerCircle` (3 states)

- **Purpose**: Test a component with interactive visual states — default, selected, and eliminated.
- **Steps**:
  1. Locate `PlayerCircle` widget in `frontend/lib/` (likely under `design_system/components/game/`)
  2. Create `frontend/test/design_system/components/game/player_circle_golden_test.dart`
  3. Add `@Tags(['golden'])` annotation
  4. Write golden tests for:
     - Default state (normal player circle)
     - Selected state (highlighted, e.g., during voting)
     - Eliminated state (visual indicator of elimination)
  5. Use `pumpWithGolden` for each test
  6. Generate baselines
- **Files**: `frontend/test/design_system/components/game/player_circle_golden_test.dart` (new, ~60 lines)
- **Parallel?**: Yes — independent of T011 and T012
- **Notes**: Check the component's state API — it may use an enum, boolean flags, or provider-based state. Adapt the test setup accordingly.

### Subtask T014 – Validate generate/compare/update cycle

- **Purpose**: Confirm the full golden test workflow works as expected — generate baseline, detect changes, update baseline.
- **Steps**:
  1. After T011-T013 golden tests are written and baselines generated:
  2. **Generate**: Run `just flutter-test-golden` — all tests should pass
  3. **Compare (detect failure)**: Temporarily modify one component's appearance (e.g., change a color in `MvButton`), run `just flutter-test-golden` — expect failure
  4. **Update**: Run `just flutter-golden-update` — new baselines generated
  5. **Verify recovery**: Run `just flutter-test-golden` — tests pass again
  6. **Revert**: Undo the temporary component modification and regenerate baselines
  7. Document the procedure in a comment block at the top of `mv_button_golden_test.dart`:
     ```dart
     // Golden Test Cycle Validation:
     // 1. Generate: just flutter-golden-update
     // 2. Verify: just flutter-test-golden (should pass)
     // 3. Break: modify widget appearance
     // 4. Detect: just flutter-test-golden (should fail)
     // 5. Update: just flutter-golden-update (new baselines)
     // 6. Recover: just flutter-test-golden (should pass)
     ```
- **Files**: No new files — validation of existing golden tests
- **Parallel?**: No — depends on T011, T012, T013
- **Notes**: This is a validation step, not a permanent test. The comment block serves as documentation for future developers.

### Subtask T015 – Validate deterministic output (byte-identical)

- **Purpose**: Confirm golden test baselines are deterministic — running the same test twice produces identical output.
- **Steps**:
  1. Run `just flutter-golden-update` to generate fresh baselines
  2. Copy all baseline files to a temporary directory
  3. Run `just flutter-golden-update` again
  4. Compare the new baselines with the copied originals using `diff` or `cmp`
  5. Verify all files are byte-identical
  6. If any differ, investigate: non-deterministic timestamps, random IDs, or platform-dependent rendering
- **Files**: No new files — validation step
- **Parallel?**: No — depends on T011-T013
- **Notes**: Non-deterministic golden output makes the entire framework unreliable. If any baselines differ between runs, this is a blocker that must be fixed in WP01 (font loading, screen size, or theme injection).

## Test Strategy

This WP IS the test validation. The golden tests themselves are the deliverables:
1. 3 golden test files (T011, T012, T013) with baseline images
2. Generate/compare/update cycle validated (T014)
3. Deterministic output confirmed (T015)
4. All golden tests pass: `just flutter-test-golden`

## Risks & Mitigations

- **Platform rendering differences**: Even with deterministic fonts, macOS and Linux may produce slightly different renders. This is why WP01 created platform-specific baseline directories. Generate macOS baselines locally and Linux baselines in CI.
- **Components may need provider overrides**: Some widgets may require Riverpod providers. Compose `pumpWithGolden` with `pumpWithTokens` or pass overrides.
- **Components may not exist yet**: If any of the 3 target components don't exist in `frontend/lib/`, substitute with other existing design system components. The goal is to prove the framework works, not test specific components.

## Review Guidance

- Verify all golden test files have `@Tags(['golden'])` annotation
- Verify baselines use production theme, not test theme
- Verify generate/compare/update cycle was actually tested (not just written)
- Verify determinism check was performed (byte-identical baselines across runs)
- Verify golden baselines are committed to the correct platform directory

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

**Initial entry**:
- 2026-03-25T23:55:37Z – system – lane=planned – Prompt created.

---

### Updating Lane Status

To change a work package's lane, either:

1. **Edit directly**: Change the `lane:` field in frontmatter AND append activity log entry (at the end)
2. **Use CLI**: `spec-kitty agent tasks move-task WP03 --to <lane> --note "message"` (recommended)

The CLI command updates both frontmatter and activity log automatically.

**Valid lanes**: `planned`, `doing`, `for_review`, `done`
- 2026-03-26T01:21:52Z – headless-impl – shell_pid=76910 – lane=doing – Assigned agent via workflow command
