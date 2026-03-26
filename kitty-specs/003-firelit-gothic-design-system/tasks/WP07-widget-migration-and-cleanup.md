---
work_package_id: WP07
title: Widget Migration, Font Cleanup & Verification
lane: "doing"
dependencies:
- WP03
requirement_refs: [FR-014, FR-015, FR-016]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 003-firelit-gothic-design-system-WP03
base_commit: 883dee899fa7b3599f85bd716c8912f1f811663c
created_at: '2026-03-26T09:51:49.985157+00:00'
subtasks:
- T033
- T034
- T035
- T036
- T037
- T038
phase: Phase 3 - Migration & Cleanup
assignee: ''
agent: "headless-impl"
shell_pid: "29027"
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-26T08:24:14Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP07 – Widget Migration, Font Cleanup & Verification

## IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.
- **Mark as acknowledged**: When you understand the feedback and begin addressing it, update `review_status: acknowledged` in the frontmatter.

---

## Review Feedback

> **Populated by `/spec-kitty.review`** – Reviewers add detailed feedback here when work needs changes.

*[This section is empty initially.]*

---

## Markdown Formatting
Wrap HTML/XML tags in backticks: `` `<div>` ``, `` `<script>` ``
Use language identifiers in code blocks: ````python`, ````bash`

---

## Objectives & Success Criteria

- Migrate all 14+ existing widgets to use renamed spacing tokens
- Update all existing test files for new spacing names
- Update the auth screen for Firelit Gothic styling
- Remove old bundled fonts (PlayfairDisplay, Inter)
- Regenerate golden test images
- Full quality gate pass
- **Success**: All tests pass. `just check` and `just flutter-test` produce zero failures. No PlayfairDisplay or Inter font files remain. Auth flow works with new theme (SC-007, SC-009, SC-010).

## Context & Constraints

- **Spec**: `kitty-specs/003-firelit-gothic-design-system/spec.md` — User Story 7 (FR-014, FR-015, FR-016)
- **Data model**: `kitty-specs/003-firelit-gothic-design-system/data-model.md` — section 6 (Widget Update Summary)
- **Directive**: This is the final cleanup and verification WP
- **Dependencies**: WP03 (themes compile with new spacing names), WP05 (MvButton removed, PrimaryButton in place)
- **Should run after**: WP04 and WP06 for comprehensive verification, but only strictly depends on WP03 + WP05
- **Spacing rename mapping**:
  - `.s` → `.sm`
  - `.m` → `.lg`
  - `.l` → `.xl`
  - `.xl` → `.xxl`
  - `.xxl` → `.xxxl`

**Implementation command**: `spec-kitty implement WP07 --base WP05`

## Subtasks & Detailed Guidance

### Subtask T033 – Update spacing references in 14+ existing widgets

- **Purpose**: Migrate all widgets to the renamed 7-step spacing scale (FR-015).
- **Steps**:
  1. Find all spacing references:
     ```bash
     cd frontend && grep -rn "spacing\.s\b\|spacing\.m\b\|spacing\.l\b\|spacing\.xl\b\|spacing\.xxl\b" lib/
     ```
  2. Apply the rename mapping in each file:
     - `tokens.spacing.s` → `tokens.spacing.sm`
     - `tokens.spacing.m` → `tokens.spacing.lg`
     - `tokens.spacing.l` → `tokens.spacing.xl`
     - `tokens.spacing.xl` → `tokens.spacing.xxl`
     - `tokens.spacing.xxl` → `tokens.spacing.xxxl`
  3. Known widget files to update:
     - `frontend/lib/design_system/components/core/mv_scaffold.dart`
     - `frontend/lib/design_system/components/core/mv_card.dart`
     - `frontend/lib/design_system/components/core/mv_text_input.dart`
     - `frontend/lib/design_system/components/core/mv_loading.dart`
     - `frontend/lib/design_system/components/core/mv_error.dart`
     - `frontend/lib/design_system/components/core/mv_dialog.dart`
     - `frontend/lib/design_system/components/game/center_cards.dart`
     - `frontend/lib/design_system/components/game/game_results.dart`
     - `frontend/lib/design_system/components/game/game_timer.dart`
     - `frontend/lib/design_system/components/game/night_action_prompt.dart`
     - `frontend/lib/design_system/components/game/phase_indicator.dart`
     - `frontend/lib/design_system/components/game/player_circle.dart`
     - `frontend/lib/design_system/components/game/role_card.dart`
     - `frontend/lib/design_system/components/game/role_token_list.dart`
     - `frontend/lib/design_system/components/game/vote_reveal.dart`
     - `frontend/lib/design_system/components/game/vote_submission.dart`
  4. Run `flutter analyze` to catch any missed references
- **Files**: 16 widget files (update)
- **Parallel?**: Yes — can proceed with T034
- **Notes**: This is mechanical find-and-replace. The compiler enforces completeness since the old names no longer exist in the abstract interface. Be careful with regex: `.s` could match `.sm` if not bounded, `.l` could match `.lg` — use word boundary matching.

### Subtask T034 – Update spacing references in existing test files

- **Purpose**: Migrate test code to new spacing names (FR-016).
- **Steps**:
  1. Find all spacing references in tests:
     ```bash
     cd frontend && grep -rn "spacing\.s\b\|spacing\.m\b\|spacing\.l\b\|spacing\.xl\b\|spacing\.xxl\b" test/
     ```
  2. Apply the same rename mapping as T033
  3. Known test files to check:
     - 6 game component tests in `frontend/test/design_system/components/game/`
     - 3 golden tests in `frontend/test/design_system/components/core/`
     - 3 example tests in `frontend/test/design_system/`
  4. Note: `TestThemeTokens` was already updated in WP03 — this step updates spacing _references_ in test setup code
- **Files**: ~12 test files (update)
- **Parallel?**: Yes — can proceed with T033

### Subtask T035 – Update home_screen.dart for Firelit Gothic styling

- **Purpose**: Ensure the auth flow renders correctly with the new design system (US7).
- **Steps**:
  1. Read `frontend/lib/features/auth/presentation/home_screen.dart`
  2. Update any typography references to use the new token getters
  3. PrimaryButton migration should already be done (WP05) — verify
  4. Ensure the screen uses tokens via provider, not hardcoded values
  5. Verify the screen compiles and renders with Firelit Gothic theme
- **Files**: `frontend/lib/features/auth/presentation/home_screen.dart` (update)
- **Parallel?**: Yes — can proceed with T036
- **Notes**: This screen may reference typography styles like `displayHeading` — these still work but now use Epilogue instead of PlayfairDisplay (coming from the theme).

### Subtask T036 – Remove old font assets and pubspec font declarations

- **Purpose**: Clean up deprecated font assets (FR-014).
- **Steps**:
  1. Delete `frontend/assets/fonts/PlayfairDisplay/` directory and all contents
  2. Delete `frontend/assets/fonts/Inter/` directory and all contents
  3. Remove font declarations from `frontend/pubspec.yaml`:
     ```yaml
     # Remove these font family entries
     fonts:
       - family: PlayfairDisplay
         fonts: ...
       - family: Inter
         fonts: ...
     ```
  4. Verify no remaining references:
     ```bash
     cd frontend && grep -rn "PlayfairDisplay\|Inter" lib/ test/ pubspec.yaml assets/
     ```
  5. Note: The `Inter` grep may match unrelated strings — check context carefully
- **Files**: Delete 2 asset directories, update `frontend/pubspec.yaml`
- **Parallel?**: Yes — can proceed with T035
- **Notes**: Old fonts are replaced by Google Fonts (Epilogue, DM Sans, Space Grotesk, Libre Baskerville) loaded via the `google_fonts` package.

### Subtask T037 – Regenerate golden test images

- **Purpose**: Golden images must be regenerated because visual output changes (FR-016).
- **Steps**:
  1. Run golden test update:
     ```bash
     cd frontend && flutter test --update-goldens
     ```
  2. Review the updated golden images for visual correctness
  3. Golden tests affected:
     - `player_circle` golden test
     - `role_card` golden test
     - Any new golden tests added by WP04-WP06
  4. Commit the updated golden image files
- **Files**: Updated golden image files in `frontend/test/` (binary files)
- **Parallel?**: No — must run after T033-T036 (all source changes must be complete)
- **Notes**: Golden images are binary PNG files generated by the Flutter test framework. They will change because fonts, colors, and spacing have all been updated.

### Subtask T038 – Run full quality gate

- **Purpose**: Final verification that the entire design system migration is complete (SC-009).
- **Steps**:
  1. Run lint + format + typecheck:
     ```bash
     just check
     ```
  2. Run all Flutter tests:
     ```bash
     just flutter-test
     ```
     Or from root:
     ```bash
     just test
     ```
  3. Verify zero failures
  4. If any failures, fix and re-run
  5. Document final results in activity log
- **Files**: No new files (fix any failing files)
- **Parallel?**: No — must be the final step after all other subtasks
- **Notes**: This is the ultimate quality gate for the feature. Both `just check` and `just test` must pass with zero failures.

## Test Strategy

This WP is primarily a migration and verification package. Tests are run at the end to verify completeness.

Run sequentially:
```bash
cd frontend && flutter analyze                    # Verify no compile errors
cd frontend && flutter test --update-goldens      # Regenerate goldens
just check                                         # Lint + format + typecheck
just test                                          # All tests
```

## Risks & Mitigations

- **Missed spacing reference** → Compiler catches it (old names don't exist); also grep for `.s `, `.m `, `.l ` patterns with word boundaries
- **Golden image diff in CI** → Regenerate locally (T037) and commit updated images
- **Font assets referenced elsewhere** → Grep for `PlayfairDisplay` and `Inter` across entire frontend after removal
- **`Inter` grep false positives** → The word "Inter" appears in many contexts; check each match is actually the font reference

## Review Guidance

- Verify **every** spacing reference is updated (grep for old names should return zero results)
- Verify PlayfairDisplay and Inter directories are deleted
- Verify pubspec.yaml font declarations are removed
- Verify `home_screen.dart` uses tokens via provider, not hardcoded values
- Verify `just check` and `just test` both pass (SC-009)
- Verify no PlayfairDisplay or Inter font files remain (SC-010)

## Activity Log

> **CRITICAL**: Activity log entries MUST be in chronological order (oldest first, newest last).

- 2026-03-26T08:24:14Z – system – lane=planned – Prompt created.

---

### Updating Lane Status

To change a work package's lane, either:
1. **Edit directly**: Change the `lane:` field in frontmatter AND append activity log entry (at the end)
2. **Use CLI**: `spec-kitty agent tasks move-task WP07 --to <lane> --note "message"` (recommended)

**Valid lanes**: `planned`, `doing`, `for_review`, `done`
- 2026-03-26T09:51:50Z – headless-impl – shell_pid=29027 – lane=doing – Assigned agent via workflow command
