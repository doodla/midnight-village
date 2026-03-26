---
work_package_id: WP01
title: Token Interfaces & Project Setup
lane: "doing"
dependencies: []
requirement_refs: [FR-012, FR-013]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: main
base_commit: 68f428339608aab7cbdb738aeebfdce18afdde05
created_at: '2026-03-26T08:36:53.810656+00:00'
subtasks:
- T001
- T002
- T003
- T004
- T005
phase: Phase 1 - Foundation
assignee: ''
agent: "headless-impl"
shell_pid: "34459"
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-26T08:24:14Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP01 – Token Interfaces & Project Setup

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

- Expand the abstract token interfaces (`AppTokens`, `AppColorTokens`, `AppTypographyTokens`, `AppSpacingTokens`) and create two new interfaces (`AppRadiusTokens`, `AppDecorationTokens`) to define the full Firelit Gothic contract
- Add `google_fonts` and `material_symbols_icons` dependencies
- Create the `AvatarSize` enum
- Add the noise grain texture asset
- Configure test infrastructure for Google Fonts
- **Success**: `flutter analyze` passes with the expanded interfaces (even though no concrete implementations exist yet — those are in WP02/WP03). `AvatarSize` enum is importable. Google Fonts test config is active.

## Context & Constraints

- **Spec**: `kitty-specs/003-firelit-gothic-design-system/spec.md` (FR-012, FR-013)
- **Data model**: `kitty-specs/003-firelit-gothic-design-system/data-model.md` — full interface definitions
- **Plan**: `kitty-specs/003-firelit-gothic-design-system/plan.md`
- **Quickstart**: `kitty-specs/003-firelit-gothic-design-system/quickstart.md`
- **Constitution**: `.kittify/memory/constitution.md`
- **Directive**: TEST_FIRST enforced. Write tests before implementations where applicable.
- **Critical**: The spacing rename (s→sm, m→lg, etc.) will cause compile errors in every existing widget and theme. This is intentional — compile-error-driven migration ensures no consumer is missed. These errors are fixed in WP03 (themes) and WP07 (widgets).
- **No dependencies**: This is the starting package.

**Implementation command**: `spec-kitty implement WP01`

## Subtasks & Detailed Guidance

### Subtask T001 – Add google_fonts and material_symbols_icons dependencies

- **Purpose**: These packages are required by the Firelit Gothic design system. `google_fonts` provides Epilogue, DM Sans, Space Grotesk, and Libre Baskerville. `material_symbols_icons` provides the icon set for role icons.
- **Steps**:
  1. Add to `frontend/pubspec.yaml` under `dependencies`:
     ```yaml
     google_fonts: ^6.2.1  # or latest stable
     material_symbols_icons: ^4.2800.0  # or latest stable
     ```
  2. Run `cd frontend && flutter pub get` to resolve dependencies
  3. Verify no version conflicts with existing dependencies
- **Files**: `frontend/pubspec.yaml`
- **Parallel?**: No — must complete first since T005 needs `google_fonts` import
- **Notes**: Pin to a specific version range to avoid breaking changes

### Subtask T002 – Expand abstract token interfaces in `app_tokens.dart`

- **Purpose**: Define the expanded contract that every downstream WP targets. This is the critical subtask — all other work depends on these interfaces.
- **Steps**:
  1. Read the current file at `frontend/lib/design_system/tokens/app_tokens.dart`
  2. Add 10 new color getters to `AppColorTokens`:
     ```dart
     Color get tertiary;       // Moonlit Sage
     Color get nightBg;        // Phase backgrounds
     Color get lobbyBg;
     Color get discussionBg;
     Color get votingBg;
     Color get resultsBg;
     Color get surfaceDark;    // Additional surface variant
     Color get danger;         // Timer danger pulse
     Color get warning;        // Timer warning state
     Color get noDeathBlue;    // "No One Dies" accent
     ```
  3. Add 4 new typography getters to `AppTypographyTokens`:
     ```dart
     TextStyle get timerDigits;   // 48sp, Space Grotesk w600
     TextStyle get lobbyCode;     // 28sp, Space Grotesk w500, letter-spaced
     TextStyle get phaseLabel;    // 12sp, Space Grotesk w500
     TextStyle get serifAccent;   // 16sp, Libre Baskerville italic
     ```
  4. Rename `AppSpacingTokens` to 7-step scale:
     - Remove: `s`, `m`, `l` (old names)
     - Add: `sm` (was s, 8.0), `md` (new, 12.0), `lg` (was m, 16.0)
     - Rename: `xl` (was l, 24.0), `xxl` (was xl, 32.0), `xxxl` (was xxl, 48.0)
     - Keep: `xs` (4.0, unchanged)
  5. Create `AppRadiusTokens` abstract class:
     ```dart
     abstract class AppRadiusTokens {
       BorderRadius get small;   // 4dp
       BorderRadius get medium;  // 8dp
       BorderRadius get large;   // 12dp
       BorderRadius get xl;      // 16dp
       BorderRadius get full;    // 999dp (pill)
     }
     ```
  6. Create `AppDecorationTokens` abstract class:
     ```dart
     abstract class AppDecorationTokens {
       List<BoxShadow> get fireGlow;
       List<BoxShadow> get selectionGlow;
       List<BoxShadow> get dangerGlow;
       Gradient get visionGlow;
       Gradient get bloodVignette;
       Gradient get candleGlow;
       String get noiseOverlayAsset;
     }
     ```
  7. Add `radius` and `decorations` to the `AppTokens` root:
     ```dart
     AppRadiusTokens get radius;
     AppDecorationTokens get decorations;
     ```
- **Files**: `frontend/lib/design_system/tokens/app_tokens.dart`
- **Parallel?**: No — defines contracts for all downstream work
- **Notes**: The spacing rename will cause compile errors in every widget/theme that references the old names. This is expected. See `data-model.md` section 1 for the full interface specification. Refer to `docs/stitch/token-map.md` for authoritative values.

### Subtask T003 – Create AvatarSize enum

- **Purpose**: Define the three avatar sizes used by `PlayerAvatar` (WP06).
- **Steps**:
  1. Create `frontend/lib/design_system/models/avatar_size.dart`:
     ```dart
     enum AvatarSize {
       small(32),
       medium(48),
       large(64);

       const AvatarSize(this.pixels);
       final double pixels;
     }
     ```
  2. Export from the design system barrel file if one exists
- **Files**: `frontend/lib/design_system/models/avatar_size.dart` (new, ~10 lines)
- **Parallel?**: Yes — independent of T002
- **Notes**: Simple enum with value mapping. No dependencies on other work.

### Subtask T004 – Add noise_grain.png texture asset

- **Purpose**: Pre-rendered noise grain texture for `AtmosphericBackground` overlay (FR-012).
- **Steps**:
  1. Create a 512x512 tileable noise grain PNG image
     - Use a tool or script to generate a tileable Perlin/simplex noise texture
     - Save as `frontend/assets/textures/noise_grain.png`
     - The image should be grayscale noise, designed to be overlaid at ~3% opacity
  2. Register in `frontend/pubspec.yaml`:
     ```yaml
     flutter:
       assets:
         - assets/textures/
     ```
  3. Verify the asset loads in a test context
- **Files**: `frontend/assets/textures/noise_grain.png` (new), `frontend/pubspec.yaml`
- **Parallel?**: Yes — independent of T002
- **Notes**: If generating programmatically is complex, a 512x512 semi-transparent white-noise PNG is sufficient. The visual effect comes from low opacity layering, not texture quality. The texture must be tileable (seamless edges).

### Subtask T005 – Configure flutter_test_config.dart for Google Fonts

- **Purpose**: Prevent Google Fonts from attempting HTTP fetches during test execution.
- **Steps**:
  1. Create or update `frontend/test/flutter_test_config.dart`:
     ```dart
     import 'dart:async';
     import 'package:google_fonts/google_fonts.dart';

     Future<void> testExecutable(FutureOr<void> Function() testMain) async {
       GoogleFonts.config.allowRuntimeFetching = false;
       await testMain();
     }
     ```
  2. Verify this file is picked up by the Flutter test runner (it must be at `test/flutter_test_config.dart`)
- **Files**: `frontend/test/flutter_test_config.dart` (new or update, ~10 lines)
- **Parallel?**: Yes — independent of T002 (but requires T001 for `google_fonts` import)
- **Notes**: Without this config, tests will attempt HTTP requests to Google's font CDN, which fails in CI and causes flaky tests.

## Test Strategy

This WP is primarily about interface expansion — the "tests" are compiler verification:
- `flutter analyze` must pass with the expanded interfaces
- Existing tests will **fail to compile** due to spacing rename — this is expected and correct
- T005's test config is verified by running any test that uses `google_fonts` (upcoming in WP02)
- The `AvatarSize` enum (T003) can be verified with a simple import test

Run: `cd frontend && flutter analyze` (expect warnings about unimplemented interfaces, but no errors in the new code itself)

## Risks & Mitigations

- **Spacing rename causes compile errors everywhere** → Expected behavior. Compile-error-driven migration ensures completeness. Fixed systematically in WP03 (themes) and WP07 (widgets).
- **Google Fonts not available in CI** → `flutter_test_config.dart` (T005) disables runtime fetching. Tests verify `TextStyle` properties only.
- **Noise grain asset quality** → Pre-rendered PNG at fixed resolution avoids shader complexity. Visual effect comes from low opacity.
- **Dependency version conflicts** → Pin `google_fonts` and `material_symbols_icons` to compatible ranges.

## Review Guidance

- Verify all 10 new color getters match the data model specification in `data-model.md` section 1.2
- Verify all 4 new typography getters match section 1.3
- Verify spacing rename follows the exact mapping: s→sm, m→lg, l→xl, xl→xxl, xxl→xxxl, new md
- Verify `AppRadiusTokens` and `AppDecorationTokens` match sections 1.5 and 1.6
- Verify `AvatarSize` enum values: small=32, medium=48, large=64
- Confirm `flutter_test_config.dart` disables Google Fonts runtime fetching

## Activity Log

> **CRITICAL**: Activity log entries MUST be in chronological order (oldest first, newest last).

- 2026-03-26T08:24:14Z – system – lane=planned – Prompt created.

---

### Updating Lane Status

To change a work package's lane, either:
1. **Edit directly**: Change the `lane:` field in frontmatter AND append activity log entry (at the end)
2. **Use CLI**: `spec-kitty agent tasks move-task WP01 --to <lane> --note "message"` (recommended)

**Valid lanes**: `planned`, `doing`, `for_review`, `done`
- 2026-03-26T08:36:54Z – headless-impl – shell_pid=34459 – lane=doing – Assigned agent via workflow command
