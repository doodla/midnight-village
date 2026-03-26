---
work_package_id: WP02
title: Static Token Constants
lane: "doing"
dependencies: [WP01]
requirement_refs: [FR-001, FR-002, FR-003, FR-004, FR-005, FR-006, FR-017]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 003-firelit-gothic-design-system-WP01
base_commit: 5d8b007a13c00f7303b2c81b852502a8631726c2
created_at: '2026-03-26T08:44:17.843046+00:00'
subtasks:
- T006
- T007
- T008
- T009
- T010
- T011
- T012
phase: Phase 1 - Foundation
assignee: ''
agent: "headless-reviewer"
shell_pid: "61782"
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-26T08:24:14Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP02 – Static Token Constants

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

- Create all 6 static token value classes (`AppColors`, `AppTypography`, `AppRadius`, `AppSpacing`, `AppShadows`, `AppDecorations`) with concrete Firelit Gothic values
- **TEST_FIRST**: Write unit tests first that verify every value matches the Stitch specification
- **Success**: Unit tests confirm all 11 core color hex values, 8 typography styles, 5 radius values, 7 spacing values, 3 shadow presets, and 6 decoration presets match `docs/stitch/token-map.md`

## Context & Constraints

- **Spec**: `kitty-specs/003-firelit-gothic-design-system/spec.md` (FR-001 through FR-006, FR-017)
- **Token map**: `docs/stitch/token-map.md` — authoritative values with copy-paste-ready Dart code
- **Data model**: `kitty-specs/003-firelit-gothic-design-system/data-model.md` — section 4 (Static Token Classes)
- **Directive**: TEST_FIRST enforced — T006 writes tests before T007-T012 create implementations
- **All classes**: `abstract final class` (no instantiation, static members only)
- **Dependencies**: WP01 must be complete (interfaces exist, `google_fonts` dependency added)

**Implementation command**: `spec-kitty implement WP02 --base WP01`

## Subtasks & Detailed Guidance

### Subtask T006 – Write token value unit tests

- **Purpose**: TEST_FIRST — establish the expected values before creating the implementations. These tests verify every token constant matches the Stitch specification exactly.
- **Steps**:
  1. Create `frontend/test/design_system/tokens/app_colors_test.dart`:
     ```dart
     // Test all core color hex values
     test('AppColors.voidBlack is #0D0B0F', () {
       expect(AppColors.voidBlack, const Color(0xFF0D0B0F));
     });
     test('AppColors.emberRed is #B8432F', () {
       expect(AppColors.emberRed, const Color(0xFFB8432F));
     });
     // ... all 11+ core colors, phase backgrounds, semantic colors
     ```
  2. Create `frontend/test/design_system/tokens/app_typography_test.dart`:
     ```dart
     // Test font families and weights (not exact rendering)
     test('AppTypography headline uses Epilogue', () {
       final style = AppTypography.textTheme.displayLarge!;
       expect(style.fontFamily, contains('Epilogue'));
       expect(style.fontWeight, FontWeight.w700);
       expect(style.fontSize, 32);
     });
     // ... all 8 typography styles
     ```
  3. Add tests for `AppRadius` (5 values), `AppSpacing` (7 values), `AppShadows` (3 presets), `AppDecorations` (6 presets + 1 asset path)
- **Files**:
  - `frontend/test/design_system/tokens/app_colors_test.dart` (new, ~80 lines)
  - `frontend/test/design_system/tokens/app_typography_test.dart` (new, ~60 lines)
  - Add spacing/radius/shadow/decoration tests as separate test groups (either in the same files or new files)
- **Parallel?**: No — must complete before T007-T012
- **Notes**: Font family checking in tests should match `GoogleFonts.epilogue().fontFamily` pattern — the actual family name includes a hash. Use `contains('Epilogue')` or capture the expected family from `GoogleFonts.epilogue()` directly. Remember `flutter_test_config.dart` from WP01 T005 disables runtime fetching.

### Subtask T007 – Create AppColors static class

- **Purpose**: Define all Firelit Gothic color constants matching the Stitch specification (FR-001).
- **Steps**:
  1. Create `frontend/lib/design_system/tokens/app_colors.dart`:
     ```dart
     import 'package:flutter/material.dart';

     abstract final class AppColors {
       // Core palette
       static const voidBlack = Color(0xFF0D0B0F);
       static const surface = Color(0xFF1A1714);
       static const surfaceDark = Color(0xFF0F0D0C);
       static const emberRed = Color(0xFFB8432F);
       static const tallowGold = Color(0xFFC8A24D);
       static const moonSage = Color(0xFF5B8A72);
       static const parchment = Color(0xFFE8DFD3);
       static const parchmentMuted = Color(0xFF9C9084);
       static const outline = Color(0xFF3D362C);

       // Team colors
       static const teamWerewolf = Color(0xFFC94038);
       static const teamVillage = Color(0xFFC8A24D);
       static const teamIndependent = Color(0xFF8B7D6B);

       // Phase backgrounds
       static const nightBg = Color(0xFF0D0B0F);
       static const lobbyBg = Color(0xFF1A1410);
       static const discussionBg = Color(0xFF151210);
       static const votingBg = Color(0xFF12100E);
       static const resultsBg = Color(0xFF0F0D0B);

       // Semantic
       static const danger = Color(0xFFE05A3A);
       static const warning = Color(0xFFD47A3A);
       static const noDeathBlue = Color(0xFF6B7B8B);
     }
     ```
  2. Verify tests from T006 pass
- **Files**: `frontend/lib/design_system/tokens/app_colors.dart` (new, ~30 lines)
- **Parallel?**: Yes — independent of T008-T012
- **Notes**: All hex values come from `docs/stitch/token-map.md`. Use `const Color(0xFFHHHHHH)` format.

### Subtask T008 – Create AppTypography static class

- **Purpose**: Define all typography styles using Google Fonts (FR-002, FR-017).
- **Steps**:
  1. Create `frontend/lib/design_system/tokens/app_typography.dart`:
     ```dart
     import 'package:flutter/material.dart';
     import 'package:google_fonts/google_fonts.dart';
     import 'app_colors.dart';

     abstract final class AppTypography {
       static TextTheme get textTheme => TextTheme(
         // Epilogue headlines
         displayLarge: GoogleFonts.epilogue(
           fontSize: 32, fontWeight: FontWeight.w700,
           color: AppColors.parchment, letterSpacing: 1.5,
         ),
         headlineLarge: GoogleFonts.epilogue(
           fontSize: 24, fontWeight: FontWeight.w600,
           color: AppColors.parchment,
         ),
         headlineMedium: GoogleFonts.epilogue(
           fontSize: 20, fontWeight: FontWeight.w500,
           color: AppColors.parchment,
         ),
         headlineSmall: GoogleFonts.epilogue(
           fontSize: 16, fontWeight: FontWeight.w500,
           color: AppColors.parchment,
         ),
         // DM Sans body
         bodyLarge: GoogleFonts.dmSans(
           fontSize: 16, fontWeight: FontWeight.w400,
           color: AppColors.parchment,
         ),
         bodyMedium: GoogleFonts.dmSans(
           fontSize: 14, fontWeight: FontWeight.w400,
           color: AppColors.parchment,
         ),
         bodySmall: GoogleFonts.dmSans(
           fontSize: 12, fontWeight: FontWeight.w400,
           color: AppColors.parchmentMuted,
         ),
         // Space Grotesk labels
         labelLarge: GoogleFonts.spaceGrotesk(
           fontSize: 48, fontWeight: FontWeight.w600,
           color: AppColors.tallowGold,
         ), // Timer digits
         labelMedium: GoogleFonts.spaceGrotesk(
           fontSize: 28, fontWeight: FontWeight.w500,
           color: AppColors.tallowGold, letterSpacing: 8.0,
         ), // Lobby codes
         labelSmall: GoogleFonts.spaceGrotesk(
           fontSize: 12, fontWeight: FontWeight.w500,
           color: AppColors.parchmentMuted, letterSpacing: 2.0,
         ), // Phase labels
       );

       // Serif accent (FR-017)
       static TextStyle get displaySerif => GoogleFonts.libreBaskerville(
         fontSize: 16, fontWeight: FontWeight.w400,
         fontStyle: FontStyle.italic, color: AppColors.parchmentMuted,
       );
     }
     ```
  2. Verify tests from T006 pass
- **Files**: `frontend/lib/design_system/tokens/app_typography.dart` (new, ~50 lines)
- **Parallel?**: Yes — independent of T007, T009-T012
- **Notes**: Uses `GoogleFonts.epilogue()`, `GoogleFonts.dmSans()`, `GoogleFonts.spaceGrotesk()`, `GoogleFonts.libreBaskerville()` with explicit fallback font families. Tests should verify `TextStyle` properties, not actual rendering.

### Subtask T009 – Create AppRadius static class

- **Purpose**: Define border radius constants (FR-003).
- **Steps**:
  1. Create `frontend/lib/design_system/tokens/app_radius.dart`:
     ```dart
     import 'package:flutter/material.dart';

     abstract final class AppRadius {
       static const small = BorderRadius.all(Radius.circular(4));
       static const medium = BorderRadius.all(Radius.circular(8));
       static const large = BorderRadius.all(Radius.circular(12));
       static const xl = BorderRadius.all(Radius.circular(16));
       static const full = BorderRadius.all(Radius.circular(999));
     }
     ```
  2. Verify tests pass
- **Files**: `frontend/lib/design_system/tokens/app_radius.dart` (new, ~10 lines)
- **Parallel?**: Yes

### Subtask T010 – Create AppSpacing static class

- **Purpose**: Define the 7-step spacing scale (FR-004).
- **Steps**:
  1. Create `frontend/lib/design_system/tokens/app_spacing.dart`:
     ```dart
     abstract final class AppSpacing {
       static const xs = 4.0;
       static const sm = 8.0;
       static const md = 12.0;
       static const lg = 16.0;
       static const xl = 24.0;
       static const xxl = 32.0;
       static const xxxl = 48.0;
     }
     ```
  2. Verify tests pass
- **Files**: `frontend/lib/design_system/tokens/app_spacing.dart` (new, ~12 lines)
- **Parallel?**: Yes

### Subtask T011 – Create AppShadows static class

- **Purpose**: Define glow effect box shadow presets (FR-005).
- **Steps**:
  1. Create `frontend/lib/design_system/tokens/app_shadows.dart`:
     ```dart
     import 'package:flutter/material.dart';

     abstract final class AppShadows {
       static const fireGlow = [
         BoxShadow(
           color: Color(0x26B8432F), // emberRed at 15%
           blurRadius: 20,
           spreadRadius: 2,
         ),
       ];

       static const selectionGlow = [
         BoxShadow(
           color: Color(0x40C8A24D), // tallowGold at 25%
           blurRadius: 12,
           spreadRadius: 1,
         ),
       ];

       static const dangerGlow = [
         BoxShadow(
           color: Color(0x40C94038), // teamWerewolf at 25%
           blurRadius: 12,
           spreadRadius: 1,
         ),
       ];
     }
     ```
  2. Verify tests pass
- **Files**: `frontend/lib/design_system/tokens/app_shadows.dart` (new, ~25 lines)
- **Parallel?**: Yes

### Subtask T012 – Create AppDecorations static class

- **Purpose**: Define gradient/effect presets and noise overlay asset path (FR-006).
- **Steps**:
  1. Create `frontend/lib/design_system/tokens/app_decorations.dart`:
     ```dart
     import 'package:flutter/material.dart';
     import 'app_colors.dart';

     abstract final class AppDecorations {
       static final visionGlow = RadialGradient(
         colors: [
           AppColors.tallowGold.withValues(alpha: 0.1),
           Colors.transparent,
         ],
       );

       static final bloodVignette = RadialGradient(
         colors: [
           Colors.transparent,
           AppColors.emberRed.withValues(alpha: 0.15),
         ],
       );

       static final candleGlow = RadialGradient(
         center: Alignment.center,
         colors: [Colors.transparent, AppColors.voidBlack],
       );

       static const noiseOverlayAsset = 'assets/textures/noise_grain.png';
     }
     ```
  2. Verify tests pass
- **Files**: `frontend/lib/design_system/tokens/app_decorations.dart` (new, ~25 lines)
- **Parallel?**: Yes
- **Notes**: Use `withValues(alpha:)` (Flutter 3.27+) instead of deprecated `withOpacity()`. The `noiseOverlayAsset` path must match the asset registered in WP01 T004.

## Test Strategy

**TEST_FIRST**: T006 writes all tests before T007-T012 create implementations.

- **Color tests**: Verify every hex value matches Stitch spec exactly
- **Typography tests**: Verify font family, weight, size, and color properties of each `TextStyle`
- **Radius tests**: Verify `BorderRadius.circular` values (4, 8, 12, 16, 999)
- **Spacing tests**: Verify 7 double constants (4, 8, 12, 16, 24, 32, 48)
- **Shadow tests**: Verify `BoxShadow` color, blur radius, and spread radius for each preset
- **Decoration tests**: Verify gradient colors and asset path

Run:
```bash
cd frontend && flutter test test/design_system/tokens/
```

## Risks & Mitigations

- **Google Fonts API changes** → Pin package version; fallback font families specified in each `TextStyle`
- **Stitch spec value drift** → Tests verify exact hex values; any discrepancy caught immediately
- **Font family name format** → Google Fonts uses hashed family names in `TextStyle.fontFamily`; test using `contains()` or comparing against `GoogleFonts.epilogue().fontFamily`

## Review Guidance

- Compare every color hex value against `docs/stitch/token-map.md` — exact matches required
- Verify `AppTypography.textTheme` field mapping: displayLarge=Epilogue 32/w700, headlineLarge=Epilogue 24/w600, etc.
- Verify `AppTypography.displaySerif` uses Libre Baskerville italic (FR-017)
- Confirm all classes are `abstract final class`
- Confirm tests run before implementations (TEST_FIRST)

## Activity Log

> **CRITICAL**: Activity log entries MUST be in chronological order (oldest first, newest last).

- 2026-03-26T08:24:14Z – system – lane=planned – Prompt created.

---

### Updating Lane Status

To change a work package's lane, either:
1. **Edit directly**: Change the `lane:` field in frontmatter AND append activity log entry (at the end)
2. **Use CLI**: `spec-kitty agent tasks move-task WP02 --to <lane> --note "message"` (recommended)

**Valid lanes**: `planned`, `doing`, `for_review`, `done`
- 2026-03-26T08:44:18Z – headless-impl – shell_pid=46560 – lane=doing – Assigned agent via workflow command
- 2026-03-26T09:02:35Z – headless-impl – shell_pid=46560 – lane=for_review – Ready for review: 6 static token classes (AppColors, AppTypography, AppRadius, AppSpacing, AppShadows, AppDecorations) with all Firelit Gothic values from token-map.md. 93 unit tests passing. Also fixed pre-existing WP01 compile errors: full AppTokens interface now implemented in MidnightVillageTheme and TestThemeTokens; spacing field names updated (s/m/l → sm/md/lg) across all components.
- 2026-03-26T09:02:50Z – headless-reviewer – shell_pid=61782 – lane=doing – Started review via workflow command
