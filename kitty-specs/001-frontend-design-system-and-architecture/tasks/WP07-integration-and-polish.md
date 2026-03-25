---
work_package_id: WP07
title: Integration & Polish
lane: done
dependencies: [WP05, WP06]
requirement_refs:
- FR-003
- FR-004
base_branch: 001-frontend-design-system-and-architecture-WP07-merge-base
base_commit: 935942f5cd141c469c185ab7eaaf02e89a12078f
created_at: '2026-03-25T03:53:28.475739+00:00'
subtasks:
- T036
- T037
- T038
- T039
phase: Phase E - Integration
assignee: ''
agent: headless-reviewer
shell_pid: '15497'
review_status: has_feedback
reviewed_by: Sridhar Vadlamani
history:
- timestamp: '2026-03-25T01:34:57Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
review_feedback_file: /private/var/folders/h1/g68scqh939n8kgw31xxqvq6r0000gn/T/tmp.Ow1Mk9LkUC
---

# Work Package Prompt: WP07 – Integration & Polish

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.

---

## Review Feedback

**Reviewed by**: Sridhar Vadlamani
**Status**: ❌ Changes Requested
**Date**: 2026-03-25
**Feedback file**: `/private/var/folders/h1/g68scqh939n8kgw31xxqvq6r0000gn/T/tmp.Ow1Mk9LkUC`

Reset from stuck doing state for orchestration re-run.


## Objectives & Success Criteria

Wire the design system into the existing app, migrate the auth screen, create placeholder assets, and verify everything works together:

1. **Auth screen migration** — Replace raw Material widgets with design system components.
2. **Placeholder SVG assets** — Create minimal card-back SVGs for theme asset resolution.
3. **Cross-theme verification** — All components render without errors with both default and test themes.
4. **Quality gates** — `just flutter-analyze` and `just flutter-test` pass with zero issues.

**Success criteria**:
- Auth/home screen renders with Midnight Village styling (amber buttons, dark background, serif headings)
- Existing auth functionality (login, create user) works identically after migration
- Placeholder SVGs exist at expected asset paths
- Zero analyzer warnings/errors
- All tests pass
- No hardcoded colors remain in migrated screen

**Implementation command**: `spec-kitty implement WP07 --base WP06`

## Context & Constraints

**Prerequisite code (from all prior WPs)**:
- Full design system: `frontend/lib/design_system/`
- Token provider wired into app.dart (WP01 T007)
- All core + game components built
- Architecture + testing docs written

**Files to modify**:
- `frontend/lib/features/auth/presentation/home_screen.dart` — migrate to design system
- `frontend/assets/themes/midnight-village/card-back.svg` — create placeholder
- `frontend/assets/themes/_placeholder/card-back.svg` — create placeholder

**Constraints**:
- Migration is a visual change only — functionality must be preserved exactly
- SVG placeholders are minimal geometric designs, not production illustrations
- Quality gates must pass: `just flutter-analyze` (alias for `dart analyze`) and `just flutter-test`

## Subtasks & Detailed Guidance

### Subtask T036 – Migrate auth/home screen to design system components

- **Purpose**: Demonstrate the design system in action by migrating the existing screen. Proves that core components work in a real feature.
- **File**: `frontend/lib/features/auth/presentation/home_screen.dart` (modify)
- **Steps**:
  1. Read the current `home_screen.dart` to understand its structure and functionality.
  2. Replace Material widgets with design system equivalents:
     - `Scaffold` → `MvScaffold` (with title, no back button for home)
     - `ElevatedButton` → `MvButton` (primary variant)
     - `TextButton` → `MvButton` (secondary variant)
     - `TextField` → `MvTextInput` (with appropriate label, hint, error handling)
     - Raw `Container`/`Padding` → Use tokens for spacing: `tokens.spacing.m`, `tokens.spacing.l`
     - Raw `Text` styling → Use `tokens.typography.heading`, `tokens.typography.body`, etc.
  3. Make the screen a `ConsumerWidget` (if not already) to access `activeThemeProvider`.
  4. Remove any hardcoded `Color(...)`, `TextStyle(fontSize: ...)`, or `EdgeInsets.all(literal)` values.
  5. Preserve all existing functionality:
     - User creation flow
     - Login flow
     - Navigation after auth
     - Error handling
  6. Verify the screen looks good with Midnight Village theme (dark background, amber buttons, legible text).
- **Validation**:
  - [ ] Screen renders with Midnight Village styling
  - [ ] Login functionality works (create user, login)
  - [ ] No hardcoded colors/sizes in the modified file
  - [ ] MvScaffold, MvButton, MvTextInput are used
  - [ ] Error states display correctly (MvTextInput error, MvError for API errors)

### Subtask T037 – Create placeholder SVG assets

- **Purpose**: Create minimal SVG files so ThemeAssets path resolution doesn't point to missing files. These are placeholder designs, not production art.
- **Files**:
  - `frontend/assets/themes/midnight-village/card-back.svg`
  - `frontend/assets/themes/_placeholder/card-back.svg`
- **Steps**:
  1. Create `card-back.svg` for Midnight Village theme:
     ```svg
     <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 168" width="120" height="168">
       <rect width="120" height="168" rx="8" fill="#0F1923"/>
       <rect x="4" y="4" width="112" height="160" rx="6" fill="none" stroke="#E8A849" stroke-width="1" opacity="0.3"/>
       <circle cx="60" cy="70" r="20" fill="none" stroke="#E8A849" stroke-width="1.5" opacity="0.5"/>
       <text x="60" y="110" text-anchor="middle" font-family="serif" font-size="10" fill="#E8A849" opacity="0.4">MV</text>
     </svg>
     ```
  2. Create `card-back.svg` for placeholder theme:
     ```svg
     <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 168" width="120" height="168">
       <rect width="120" height="168" rx="8" fill="#333333"/>
       <text x="60" y="88" text-anchor="middle" font-family="sans-serif" font-size="32" fill="#666666">?</text>
     </svg>
     ```
  3. Create directory structure if needed:
     - `frontend/assets/themes/midnight-village/` (should exist from pubspec.yaml declaration)
     - `frontend/assets/themes/_placeholder/`
  4. Verify paths match what `MidnightVillageAssets.cardBackPath` returns.
- **Parallel?**: Yes — independent of T036.
- **Validation**:
  - [ ] SVG files are valid XML
  - [ ] Midnight Village card-back uses theme colors (dark background, amber accents)
  - [ ] Placeholder card-back is minimal and distinct
  - [ ] File paths match ThemeAssets path resolution

### Subtask T038 – Verify cross-theme rendering

- **Purpose**: Ensure all design system components render correctly with both the default Midnight Village theme and the test theme. Catches hardcoded values that bypassed the token system.
- **Steps**:
  1. Write or run a verification pass:
     - Instantiate each core component (MvButton, MvCard, MvTextInput, MvDialog, MvScaffold, MvLoading, MvError)
     - Instantiate each game component (RoleCard, RoleTokenList, CenterCards, PhaseIndicator, GameTimer, PlayerCircle, NightActionPrompt, VoteSubmission, VoteReveal, GameResults)
     - Render with MidnightVillageTheme — verify no exceptions
     - Render with TestThemeTokens — verify no exceptions
  2. Check for hardcoded values:
     - Grep all component files for `Color(0x` — should only appear in theme implementations
     - Grep for `TextStyle(fontSize:` in component files — should not appear
     - Grep for `EdgeInsets.all(` with literal numbers in component files — should use tokens
  3. Fix any issues found.
- **Validation**:
  - [ ] All components render with default theme without exceptions
  - [ ] All components render with test theme without exceptions
  - [ ] Zero hardcoded `Color(0x` in component files
  - [ ] Zero hardcoded `fontSize:` in component files

### Subtask T039 – Run quality gates and fix issues

- **Purpose**: Ensure the complete design system passes all project quality gates. Final validation before the feature is considered complete.
- **Steps**:
  1. Run `just flutter-analyze` (or `cd frontend && dart analyze`):
     - Fix any analyzer warnings or errors
     - Common issues: unused imports, missing return types, deprecated API usage
  2. Run `just flutter-test` (or `cd frontend && flutter test`):
     - Fix any test failures
     - Ensure example tests from WP06 pass
     - Ensure any component tests pass
  3. Check code coverage if tooling supports it:
     - Target: 80% for design system code
     - If below target, identify critical untested paths
  4. Verify all generated files are up to date:
     - Run `dart run build_runner build --delete-conflicting-outputs`
     - Verify no stale `.g.dart` or `.freezed.dart` files
  5. Final checklist:
     - [ ] `just flutter-analyze` → 0 issues
     - [ ] `just flutter-test` → all pass
     - [ ] `build_runner` → no conflicts
     - [ ] All design system files follow ConsumerWidget + token pattern
     - [ ] Auth screen migrated and functional
- **Validation**:
  - [ ] Zero analyzer issues
  - [ ] All tests pass
  - [ ] Build runner clean
  - [ ] Feature is production-ready

## Risks & Mitigations

- **Auth screen regression**: The auth screen is the only working screen. Test login/create user flows manually after migration.
- **SVG rendering issues**: `flutter_svg` may not render complex SVGs correctly. Keep placeholder SVGs simple — basic shapes and text only.
- **Analyzer false positives**: Some Riverpod codegen patterns may trigger analyzer warnings. Use `// ignore:` comments only as last resort — prefer fixing the underlying issue.
- **Missing imports**: When migrating auth screen, ensure all new design system imports are added. The analyzer will catch missing imports.

## Review Guidance

- **Auth screen side-by-side**: Compare auth screen before and after migration. Functionality identical? Styling improved?
- **SVG validity**: Open SVGs in a browser to verify they render.
- **Quality gate proof**: Reviewer should see evidence that `just flutter-analyze` and `just flutter-test` passed (output or screenshot).
- **Hardcoded value sweep**: Final grep for hardcoded visual values across all design system files.

## Activity Log

- 2026-03-25T01:34:57Z – system – lane=planned – Prompt created.
- 2026-03-25T03:53:28Z – headless-impl – shell_pid=36665 – lane=doing – Assigned agent via workflow command
- 2026-03-25T04:01:33Z – headless-impl – shell_pid=36665 – lane=planned – Reset for re-run
- 2026-03-25T04:57:10Z – headless-impl – shell_pid=91612 – lane=doing – Started implementation via workflow command
- 2026-03-25T05:05:18Z – headless-impl – shell_pid=91612 – lane=for_review – Committed by orchestrator fallback - ready for review
- 2026-03-25T05:16:03Z – headless-reviewer – shell_pid=15497 – lane=doing – Started review via workflow command
- 2026-03-25T05:18:27Z – headless-reviewer – shell_pid=15497 – lane=done – Review passed
