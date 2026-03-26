---
work_package_id: WP05
title: PrimaryButton & MvButton Migration
lane: planned
dependencies: [WP03]
requirement_refs: [FR-010, FR-015]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
subtasks:
- T023
- T024
- T025
- T026
- T027
phase: Phase 2 - Foundation Widgets
assignee: ''
agent: ''
shell_pid: ''
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-26T08:24:14Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP05 – PrimaryButton & MvButton Migration

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

- Build `PrimaryButton` with filled, disabled, loading, outlined, and destructive states
- Replace all `MvButton` usages across the codebase with `PrimaryButton`
- Remove `mv_button.dart` and its golden test
- **Success**: Widget tests verify all 5 button states. All 6 files that import `MvButton` compile and render with `PrimaryButton`. `mv_button.dart` is removed (SC-005).

## Context & Constraints

- **Spec**: `kitty-specs/003-firelit-gothic-design-system/spec.md` — User Story 4
- **Contract**: `kitty-specs/003-firelit-gothic-design-system/contracts/primary_button.dart`
- **Data model**: `kitty-specs/003-firelit-gothic-design-system/data-model.md` — section 6.2 (MvButton → PrimaryButton migration)
- **Directive**: TEST_FIRST enforced
- **Dependencies**: WP03 (theme implementations must compile)
- **Migration mapping**:
  - `MvButton(variant: primary)` → `PrimaryButton()`
  - `MvButton(variant: secondary)` → `PrimaryButton.outlined()`
  - `MvButton(variant: destructive)` → `PrimaryButton(isDestructive: true)`

**Implementation command**: `spec-kitty implement WP05 --base WP03`

## Subtasks & Detailed Guidance

### Subtask T023 – Write PrimaryButton widget tests

- **Purpose**: TEST_FIRST — define all expected button behaviors before implementation.
- **Steps**:
  1. Create `frontend/test/design_system/components/core/primary_button_test.dart`:
     ```dart
     group('PrimaryButton', () {
       testWidgets('default renders filled with primary color', (tester) async {
         await pumpWithTokens(tester, PrimaryButton(
           label: 'Enter the Village',
           onPressed: () {},
         ));
         // Verify FilledButton is present
         // Verify text 'Enter the Village' is visible
         // Verify button fills available width
       });

       testWidgets('disabled renders with disabled color', (tester) async {
         await pumpWithTokens(tester, PrimaryButton(
           label: 'Start',
           onPressed: null,
         ));
         // Verify button is non-interactive
       });

       testWidgets('loading shows spinner and hides label', (tester) async {
         await pumpWithTokens(tester, PrimaryButton(
           label: 'Joining...',
           onPressed: () {},
           isLoading: true,
         ));
         // Verify CircularProgressIndicator is present
         // Verify label text is NOT visible
         // Verify button is non-interactive (onPressed disabled)
       });

       testWidgets('outlined renders with transparent background', (tester) async {
         await pumpWithTokens(tester, PrimaryButton.outlined(
           label: 'Leave',
           onPressed: () {},
         ));
         // Verify OutlinedButton is present
         // Verify text 'Leave' is visible
       });

       testWidgets('destructive renders with error color', (tester) async {
         await pumpWithTokens(tester, PrimaryButton(
           label: 'Delete',
           onPressed: () {},
           isDestructive: true,
         ));
         // Verify button uses error/danger color
       });

       testWidgets('onPressed callback fires on tap', (tester) async {
         var tapped = false;
         await pumpWithTokens(tester, PrimaryButton(
           label: 'Tap Me',
           onPressed: () => tapped = true,
         ));
         await tester.tap(find.text('Tap Me'));
         expect(tapped, isTrue);
       });

       testWidgets('consumes tokens from activeThemeProvider', (tester) async {
         // Pump with TestThemeTokens, verify colors from test theme
       });
     });
     ```
- **Files**: `frontend/test/design_system/components/core/primary_button_test.dart` (new, ~100 lines)
- **Parallel?**: No — must complete before T024 (TEST_FIRST)

### Subtask T024 – Implement PrimaryButton ConsumerWidget

- **Purpose**: Build the primary interactive button (FR-010).
- **Steps**:
  1. Create `frontend/lib/design_system/components/core/primary_button.dart`:
     ```dart
     class PrimaryButton extends ConsumerWidget {
       final String label;
       final VoidCallback? onPressed;
       final bool isLoading;
       final bool isDestructive;
       final IconData? icon;
       final bool _isOutlined;

       const PrimaryButton({
         super.key,
         required this.label,
         this.onPressed,
         this.isLoading = false,
         this.isDestructive = false,
         this.icon,
       }) : _isOutlined = false;

       const PrimaryButton.outlined({
         super.key,
         required this.label,
         this.onPressed,
         this.isLoading = false,
         this.icon,
       }) : _isOutlined = true, isDestructive = false;

       @override
       Widget build(BuildContext context, WidgetRef ref) {
         final tokens = ref.watch(activeThemeProvider);
         final effectiveOnPressed = isLoading ? null : onPressed;

         if (_isOutlined) {
           return SizedBox(
             width: double.infinity,
             child: OutlinedButton(
               onPressed: effectiveOnPressed,
               style: OutlinedButton.styleFrom(
                 foregroundColor: tokens.colors.onSurface,
                 side: BorderSide(color: tokens.colors.outline),
                 minimumSize: const Size.fromHeight(48),
                 shape: RoundedRectangleBorder(borderRadius: tokens.radius.medium),
               ),
               child: _buildChild(tokens),
             ),
           );
         }

         final bgColor = isDestructive ? tokens.colors.error : tokens.colors.primary;
         return SizedBox(
           width: double.infinity,
           child: FilledButton(
             onPressed: effectiveOnPressed,
             style: FilledButton.styleFrom(
               backgroundColor: bgColor,
               foregroundColor: tokens.colors.onPrimary,
               disabledBackgroundColor: tokens.colors.disabled,
               disabledForegroundColor: tokens.colors.onDisabled,
               minimumSize: const Size.fromHeight(56),
               shape: RoundedRectangleBorder(borderRadius: tokens.radius.medium),
             ),
             child: _buildChild(tokens),
           ),
         );
       }

       Widget _buildChild(AppTokens tokens) {
         if (isLoading) {
           return SizedBox(
             height: 20, width: 20,
             child: CircularProgressIndicator(
               strokeWidth: 2,
               color: tokens.colors.onPrimary,
             ),
           );
         }
         if (icon != null) {
           return Row(
             mainAxisSize: MainAxisSize.min,
             children: [
               Icon(icon, size: 18),
               SizedBox(width: tokens.spacing.sm),
               Text(label),
             ],
           );
         }
         return Text(label);
       }
     }
     ```
  2. Verify T023 tests pass
- **Files**: `frontend/lib/design_system/components/core/primary_button.dart` (new, ~80 lines)
- **Parallel?**: No — follows T023 (TEST_FIRST)

### Subtask T025 – Replace all MvButton usages with PrimaryButton

- **Purpose**: Migrate all existing screens to the new button (FR-015).
- **Steps**:
  1. Grep for all `MvButton` imports and usages:
     ```bash
     cd frontend && grep -rn "MvButton\|mv_button" lib/
     ```
  2. Known consumers to update:
     - `frontend/lib/features/auth/presentation/home_screen.dart`
     - `frontend/lib/design_system/components/game/vote_submission.dart`
     - `frontend/lib/design_system/components/game/night_action_prompt.dart`
     - `frontend/lib/design_system/components/game/game_results.dart`
     - `frontend/lib/design_system/components/core/mv_error.dart`
     - `frontend/lib/design_system/components/core/mv_dialog.dart`
  3. Apply migration mapping:
     - `MvButton(... variant: MvButtonVariant.primary ...)` → `PrimaryButton(label: ..., onPressed: ...)`
     - `MvButton(... variant: MvButtonVariant.secondary ...)` → `PrimaryButton.outlined(label: ..., onPressed: ...)`
     - `MvButton(... variant: MvButtonVariant.destructive ...)` → `PrimaryButton(label: ..., onPressed: ..., isDestructive: true)`
  4. Update imports in each file
  5. Update any barrel exports referencing `mv_button.dart`
- **Files**: 6 files listed above (update)
- **Parallel?**: No — must follow T024 (PrimaryButton must exist)
- **Notes**: Check each file for the exact `MvButton` API used and map to the correct `PrimaryButton` constructor.

### Subtask T026 – Remove MvButton widget and golden test

- **Purpose**: Clean up the deprecated widget after all usages are migrated.
- **Steps**:
  1. Delete `frontend/lib/design_system/components/core/mv_button.dart`
  2. Delete `frontend/test/design_system/components/core/mv_button_golden_test.dart`
  3. Update any barrel exports or index files that reference `mv_button.dart`
  4. Grep to confirm no remaining references:
     ```bash
     cd frontend && grep -rn "mv_button\|MvButton" lib/ test/
     ```
- **Files**: Delete 2 files, update barrel exports
- **Parallel?**: No — must follow T025 (all usages must be replaced first)

### Subtask T027 – Verify existing tests pass after migration

- **Purpose**: Confirm no regressions from the MvButton → PrimaryButton migration.
- **Steps**:
  1. Run: `cd frontend && flutter test`
  2. If any tests reference `MvButton`, update them to use `PrimaryButton`
  3. Verify all tests pass
  4. Document results in activity log
- **Files**: Any failing test files (update)
- **Parallel?**: No — final verification step

## Test Strategy

**TEST_FIRST**: T023 writes tests before T024 implements the widget.

Run:
```bash
cd frontend && flutter test test/design_system/components/core/primary_button_test.dart
```

After migration:
```bash
cd frontend && flutter test
```

## Risks & Mitigations

- **Missed MvButton usage** → Grep for `MvButton` and `mv_button` after removal; compile errors catch remaining references
- **Test golden images break** → Golden tests for MvButton are removed (T026); new golden tests for PrimaryButton are optional
- **Loading state double-tap** → `isLoading` sets `onPressed` to null, preventing double-tap

## Review Guidance

- Verify PrimaryButton has all 5 states: filled, disabled, loading, outlined, destructive
- Verify `SizedBox(width: double.infinity)` for full-width behavior
- Verify loading state uses `CircularProgressIndicator` and disables `onPressed`
- Verify all 6 MvButton consumers are migrated with correct variant mapping
- Verify `mv_button.dart` and its golden test are deleted
- Grep for any remaining `MvButton`/`mv_button` references

## Activity Log

> **CRITICAL**: Activity log entries MUST be in chronological order (oldest first, newest last).

- 2026-03-26T08:24:14Z – system – lane=planned – Prompt created.

---

### Updating Lane Status

To change a work package's lane, either:
1. **Edit directly**: Change the `lane:` field in frontmatter AND append activity log entry (at the end)
2. **Use CLI**: `spec-kitty agent tasks move-task WP05 --to <lane> --note "message"` (recommended)

**Valid lanes**: `planned`, `doing`, `for_review`, `done`
