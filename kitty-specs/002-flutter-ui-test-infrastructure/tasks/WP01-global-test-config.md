---
work_package_id: WP01
title: Global Test Configuration & Deterministic Rendering
lane: "doing"
dependencies: []
requirement_refs: [FR-001, FR-002, FR-003, FR-011, FR-013, FR-016]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: main
base_commit: 3eda14dd89585fc4ecb5b4f9aab2b044d2f5d8a6
created_at: '2026-03-26T00:46:26.208182+00:00'
subtasks:
- T001
- T002
- T003
- T004
- T005
phase: Phase 0 - Foundation
assignee: ''
agent: "headless-reviewer"
shell_pid: "67639"
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-25T23:55:37Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP01 – Global Test Configuration & Deterministic Rendering

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

Establish the foundational test configuration that ensures deterministic rendering across platforms — font loading, screen sizing, golden file comparison, and platform-specific baseline management.

**Success criteria**:
- Any widget test loads bundled fonts deterministically via `flutter_test_config.dart`
- `pumpWithGolden` extension renders widgets at a fixed 390x844 screen size with deterministic theme
- Golden baselines are routed to platform-specific directories (`macos/`, `linux/`)
- `just flutter-test-golden` and `just flutter-golden-update` commands work (even with no golden tests yet)
- Existing tests are not broken by the new global config

**Implementation command**: `spec-kitty implement WP01`

## Context & Constraints

- **Spec**: `kitty-specs/002-flutter-ui-test-infrastructure/spec.md` — User Stories 1, 6; FR-001 through FR-003, FR-011, FR-013, FR-016
- **Plan**: `kitty-specs/002-flutter-ui-test-infrastructure/plan.md` — Decisions #1-3, #6, #9-10
- **Existing helpers**: `frontend/test/design_system/test_helpers/pump_with_tokens.dart` and `frontend/test/design_system/test_helpers/test_theme.dart` — extend, don't replace
- **Constraint**: `flutter_test_config.dart` is project-global; font loading must be additive and must not break any existing tests
- **Constraint**: Use Flutter built-in `matchesGoldenFile` — no third-party golden test packages
- **Font families**: PlayfairDisplay (headings), Inter (body) — these are the app's bundled fonts
- **Screen size**: 390x844 logical pixels (iPhone 14 dimensions)

## Subtasks & Detailed Guidance

### Subtask T001 – Create `flutter_test_config.dart` with font loading

- **Purpose**: Provide a global test configuration that loads bundled fonts before any test runs, ensuring deterministic text rendering in golden tests.
- **Steps**:
  1. Create `frontend/test/flutter_test_config.dart`
  2. Define a top-level `Future<void> testExecutable(FutureOr<void> Function() testMain)` function — Flutter's test runner automatically discovers and calls this
  3. Inside `testExecutable`:
     - Load PlayfairDisplay font data from `rootBundle` using `FontLoader('PlayfairDisplay')`
     - Load Inter font data from `rootBundle` using `FontLoader('Inter')`
     - Call `await fontLoader.load()` for each
     - Then call `await testMain()`
  4. Verify font asset paths match what's declared in `frontend/pubspec.yaml` under `flutter.fonts`
- **Files**: `frontend/test/flutter_test_config.dart` (new, ~40 lines)
- **Parallel?**: Yes — can proceed in parallel with T005
- **Notes**: The `FontLoader` API loads font bytes from the asset bundle. Each font family/weight needs a separate `add()` call. Check `pubspec.yaml` for exact font file paths. If fonts are loaded via Google Fonts package instead of bundled assets, adapt the approach accordingly.

### Subtask T002 – Create `golden_test_helper.dart` with `pumpWithGolden`

- **Purpose**: Provide a single-call extension on `WidgetTester` that handles all golden test boilerplate: fixed screen size, deterministic theme, and golden file comparison.
- **Steps**:
  1. Create `frontend/test/helpers/golden_test_helper.dart`
  2. Define `extension GoldenTestExtension on WidgetTester`:
     - `Future<void> pumpWithGolden(Widget widget, String goldenName)` method
  3. Inside `pumpWithGolden`:
     - Set `tester.view.physicalSize = Size(390 * 3, 844 * 3)` (3x device pixel ratio)
     - Set `tester.view.devicePixelRatio = 3.0`
     - Wrap widget in `MidnightVillageTheme` (or `MaterialApp` with the app's theme data)
     - Call `await tester.pumpWidget(wrappedWidget)`
     - Call `await tester.pumpAndSettle()`
     - Call `await expectLater(find.byType(...), matchesGoldenFile(goldenName))`
  4. Add a `addTearDown` to reset view size after each test
- **Files**: `frontend/test/helpers/golden_test_helper.dart` (new, ~60 lines)
- **Parallel?**: No — tightly coupled with T003 (same file)
- **Notes**: Use `tester.view` (not deprecated `tester.binding.window`). The golden name should include the platform path prefix — T003's comparator handles this. Consider accepting an optional `theme` parameter for tests that need non-default themes.

### Subtask T003 – Implement platform-specific `GoldenFileComparator`

- **Purpose**: Route golden baseline files to platform-specific directories so macOS dev baselines don't conflict with Linux CI baselines.
- **Steps**:
  1. In `frontend/test/helpers/golden_test_helper.dart` (same file as T002), create a class:
     ```dart
     class PlatformGoldenFileComparator extends LocalFileComparator {
       PlatformGoldenFileComparator(super.testFile);

       @override
       Uri getTestUri(Uri key, int? version) {
         final platform = Platform.operatingSystem; // 'macos', 'linux', 'windows'
         // Insert platform directory into the golden path
         // e.g., goldens/button_test.png → goldens/macos/button_test.png
         ...
       }
     }
     ```
  2. Register the comparator in `flutter_test_config.dart` (T001) or in `pumpWithGolden` setup:
     ```dart
     goldenFileComparator = PlatformGoldenFileComparator(Uri.parse('test/'));
     ```
  3. Ensure baselines are stored in:
     - `test/design_system/goldens/macos/` for macOS
     - `test/design_system/goldens/linux/` for Linux
  4. Create both directories with `.gitkeep` files
- **Files**: `frontend/test/helpers/golden_test_helper.dart` (extends T002), `frontend/test/design_system/goldens/macos/.gitkeep` (new), `frontend/test/design_system/goldens/linux/.gitkeep` (new)
- **Parallel?**: No — same file as T002
- **Notes**: `LocalFileComparator` is from `package:flutter_test`. Import `dart:io` for `Platform`. The comparator must correctly resolve relative paths from the test file location. Test by verifying the URI rewriting produces correct paths.

### Subtask T004 – Extend `pumpWithTokens` for golden configuration

- **Purpose**: Allow the existing `pumpWithTokens` helper to optionally apply golden test settings (fixed screen size, deterministic fonts) so golden tests can reuse the existing widget test infrastructure.
- **Steps**:
  1. Read `frontend/test/design_system/test_helpers/pump_with_tokens.dart` to understand the current API
  2. Add optional named parameters:
     - `bool goldenMode = false` — when true, applies fixed screen size (390x844) and device pixel ratio (3.0)
     - `Size? screenSize` — override screen size (defaults to 390x844 in golden mode)
  3. When `goldenMode` is true:
     - Set `tester.view.physicalSize` and `tester.view.devicePixelRatio`
     - Add teardown to reset view dimensions
  4. Ensure the default behavior (no golden config) is unchanged — existing tests must not break
- **Files**: `frontend/test/design_system/test_helpers/pump_with_tokens.dart` (modify, ~15 lines added)
- **Parallel?**: No — depends on understanding the existing helper
- **Notes**: This creates a bridge between the existing test helper and the new golden infrastructure. Tests that use `pumpWithTokens` can opt into golden mode without switching to `pumpWithGolden`. Keep the API backward-compatible.

### Subtask T005 – Add golden test justfile commands

- **Purpose**: Provide developer-friendly commands for running golden tests and updating baselines.
- **Steps**:
  1. Read `frontend/justfile` to understand existing command patterns
  2. Add these commands:
     ```just
     # Run golden tests only
     flutter-test-golden:
         flutter test --tags golden

     # Update all golden baselines
     flutter-golden-update:
         flutter test --update-goldens --tags golden
     ```
  3. Verify the commands work (they should succeed even with no golden tests yet — just "no tests found")
  4. Ensure consistency with existing justfile naming conventions (kebab-case, `flutter-` prefix)
- **Files**: `frontend/justfile` (modify, ~10 lines added)
- **Parallel?**: Yes — independent of T001-T004 (different file)
- **Notes**: The `--tags golden` flag filters tests annotated with `@Tags(['golden'])`. This tag annotation will be used in WP03 when actual golden tests are written.

## Test Strategy

This WP IS test infrastructure. Validation tests:

1. **Font loading smoke test**: Write a minimal widget test that renders text and confirm it doesn't fail with "unable to load font" errors (validates T001)
2. **pumpWithGolden smoke test**: Write a minimal golden test that renders a `Container` with a fixed color, generate the baseline, and confirm it passes on re-run (validates T002, T003)
3. **Existing test regression**: Run `just flutter-test` and confirm all existing tests still pass after adding `flutter_test_config.dart` (validates T001 backward compatibility)
4. **justfile command test**: Run `just flutter-test-golden` and confirm it completes without error (validates T005)

## Risks & Mitigations

- **Font loading may behave differently in test vs runtime**: Verify with a simple rendering test before proceeding. If `FontLoader` doesn't work in tests, fall back to loading font bytes directly via `rootBundle.load()`.
- **`flutter_test_config.dart` is project-global**: Make font loading additive (don't clear existing fonts). Run the full test suite to verify no regressions.
- **`LocalFileComparator` API may differ across Flutter versions**: Check the Flutter SDK version in `pubspec.yaml` and verify the API surface. If `getTestUri` isn't available, use `compare` override instead.

## Review Guidance

- Verify `flutter_test_config.dart` follows Flutter's expected function signature (`testExecutable`)
- Verify `pumpWithGolden` resets view dimensions in teardown (prevents test pollution)
- Verify platform comparator correctly routes to `macos/` or `linux/` directories
- Verify `pumpWithTokens` changes are backward-compatible (existing tests pass)
- Verify justfile commands follow existing naming conventions

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
2. **Use CLI**: `spec-kitty agent tasks move-task WP01 --to <lane> --note "message"` (recommended)

The CLI command updates both frontmatter and activity log automatically.

**Valid lanes**: `planned`, `doing`, `for_review`, `done`
- 2026-03-26T00:46:26Z – headless-impl – shell_pid=41550 – lane=doing – Assigned agent via workflow command
- 2026-03-26T00:53:22Z – headless-impl – shell_pid=41550 – lane=for_review – Ready for review: global test config with font loading, PlatformGoldenFileComparator routing baselines to macos/linux dirs, pumpWithGolden extension, goldenMode flag on pumpWithTokens, justfile commands, smoke tests — 155 tests pass
- 2026-03-26T01:13:44Z – headless-reviewer – shell_pid=67639 – lane=doing – Started review via workflow command
