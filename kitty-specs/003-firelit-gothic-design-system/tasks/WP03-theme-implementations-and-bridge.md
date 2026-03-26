---
work_package_id: WP03
title: Theme Implementations & Bridge
lane: "for_review"
dependencies:
- WP01
requirement_refs: [FR-007, FR-013]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 003-firelit-gothic-design-system-WP01
base_commit: 5d8b007a13c00f7303b2c81b852502a8631726c2
created_at: '2026-03-26T09:04:52.593653+00:00'
subtasks:
- T013
- T014
- T015
- T016
- T017
- T018
phase: Phase 1 - Foundation
assignee: ''
agent: headless-impl
shell_pid: '64952'
review_status: ''
reviewed_by: ''
history:
- timestamp: '2026-03-26T08:24:14Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP03 – Theme Implementations & Bridge

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

- Create `FirelitGothicTheme` as the new default theme implementing expanded `AppTokens`
- Update `MidnightVillageTheme` to implement all expanded interface getters
- Update `TestThemeTokens` with visually distinct values for all tokens
- Expand `ThemeBridge.generateThemeData` to map new ColorScheme, TextTheme, and component themes
- Switch the provider default to `FirelitGothicTheme`
- **Success**: `FirelitGothicTheme` passes completeness tests. `TestThemeTokens` has visually distinct values. `ThemeBridge.generateThemeData` produces valid `ThemeData`. App launches with Firelit Gothic as default (SC-008).

## Context & Constraints

- **Spec**: `kitty-specs/003-firelit-gothic-design-system/spec.md` (FR-007, FR-013)
- **Data model**: `kitty-specs/003-firelit-gothic-design-system/data-model.md` — sections 2 (Concrete Implementations) and 5 (ThemeBridge Updates)
- **Token map**: `docs/stitch/token-map.md` — `buildAppTheme()` code and `ColorScheme` mapping
- **Directive**: TEST_FIRST enforced
- **Critical architectural constraint**: Components consume tokens via `activeThemeProvider`, not static classes. The `FirelitGothicTheme` wraps `AppColors`/`AppTypography` etc. in the abstract interface.
- **Dependencies**: WP01 (expanded interfaces), WP02 (static constants)

**Implementation command**: `spec-kitty implement WP03 --base WP02`

## Subtasks & Detailed Guidance

### Subtask T013 – Write theme implementation tests

- **Purpose**: TEST_FIRST — establish test expectations for `FirelitGothicTheme`, expanded `TestThemeTokens`, and `ThemeBridge`.
- **Steps**:
  1. Create `frontend/test/design_system/tokens/firelit_gothic_theme_test.dart`:
     ```dart
     group('FirelitGothicTheme', () {
       test('returns correct name', () {
         final theme = FirelitGothicTheme();
         expect(theme.name, 'Firelit Gothic');
       });

       test('colors.primary is ember red', () {
         final theme = FirelitGothicTheme();
         expect(theme.colors.primary, AppColors.emberRed);
       });

       test('all color getters return non-null', () {
         final theme = FirelitGothicTheme();
         // verify all 29 color getters
         expect(theme.colors.primary, isNotNull);
         expect(theme.colors.nightBg, isNotNull);
         // ... all getters
       });

       test('all typography getters return non-null', () {
         // ... verify all 10 typography getters
       });

       test('spacing values match Firelit Gothic spec', () {
         final theme = FirelitGothicTheme();
         expect(theme.spacing.xs, 4.0);
         expect(theme.spacing.sm, 8.0);
         expect(theme.spacing.md, 12.0);
         // ...
       });

       test('radius and decorations are present', () {
         final theme = FirelitGothicTheme();
         expect(theme.radius.medium, isNotNull);
         expect(theme.decorations.fireGlow, isNotEmpty);
       });
     });
     ```
  2. Add ThemeBridge tests:
     ```dart
     group('ThemeBridge', () {
       test('generates valid ThemeData from FirelitGothicTheme', () {
         final themeData = ThemeBridge.generateThemeData(FirelitGothicTheme());
         expect(themeData.colorScheme.primary, AppColors.emberRed);
         expect(themeData.colorScheme.tertiary, AppColors.moonSage);
         expect(themeData.textTheme.displayLarge, isNotNull);
       });

       test('cardTheme uses medium radius', () {
         final themeData = ThemeBridge.generateThemeData(FirelitGothicTheme());
         expect(themeData.cardTheme.shape, isA<RoundedRectangleBorder>());
       });
     });
     ```
  3. Add TestThemeTokens distinctness tests:
     ```dart
     group('TestThemeTokens', () {
       test('has visually distinct primary color', () {
         final test = TestThemeTokens();
         final prod = FirelitGothicTheme();
         expect(test.colors.primary, isNot(prod.colors.primary));
       });
     });
     ```
- **Files**: `frontend/test/design_system/tokens/firelit_gothic_theme_test.dart` (new, ~120 lines)
- **Parallel?**: No — must complete before T014-T018

### Subtask T014 – Create FirelitGothicTheme

- **Purpose**: New default theme implementation with all Stitch-specified values (FR-013).
- **Steps**:
  1. Create `frontend/lib/design_system/tokens/firelit_gothic_theme.dart`:
     - Class `FirelitGothicTheme implements AppTokens`
     - Internal classes: `FirelitGothicColors implements AppColorTokens`, `FirelitGothicTypography implements AppTypographyTokens`, `FirelitGothicSpacing implements AppSpacingTokens`, `FirelitGothicElevation implements AppElevationTokens`, `FirelitGothicRadius implements AppRadiusTokens`, `FirelitGothicDecorations implements AppDecorationTokens`
     - Each internal class references static constants from WP02's classes
     - Example:
       ```dart
       class FirelitGothicColors implements AppColorTokens {
         @override Color get primary => AppColors.emberRed;
         @override Color get nightBg => AppColors.nightBg;
         // ... all 29 color getters
       }
       ```
  2. Verify T013 tests pass
- **Files**: `frontend/lib/design_system/tokens/firelit_gothic_theme.dart` (new, ~200 lines)
- **Parallel?**: Yes — can proceed with T015/T016 once T013 is written
- **Notes**: The internal classes wrap static constants in the abstract interface, bridging the concrete values to the contract.

### Subtask T015 – Update MidnightVillageTheme for expanded interfaces

- **Purpose**: Existing theme must compile with the expanded interfaces.
- **Steps**:
  1. Read `frontend/lib/design_system/tokens/midnight_village_theme.dart`
  2. Add implementations for all new getters:
     - 10 new color getters: Use sensible defaults in the existing warm-amber/deep-blue palette
     - 4 new typography getters: Use the same font families as existing styles with appropriate sizes
     - Renamed spacing: Update getter names (s→sm, m→lg, l→xl, xl→xxl, xxl→xxxl, add md)
     - New radius group: Add `AppRadiusTokens` implementation with same values as Firelit Gothic
     - New decorations group: Add `AppDecorationTokens` implementation with similar effects in the existing palette
  3. Verify the theme compiles
- **Files**: `frontend/lib/design_system/tokens/midnight_village_theme.dart` (update)
- **Parallel?**: Yes — can proceed with T014/T016
- **Notes**: This theme may be removed in a future feature but must compile now. Values don't need to look perfect — just reasonable and compilable.

### Subtask T016 – Update TestThemeTokens for expanded interfaces

- **Purpose**: Test helper theme must have visually distinct values so tests catch hardcoded colors.
- **Steps**:
  1. Read `frontend/test/design_system/test_helpers/test_theme.dart`
  2. Add implementations for all new getters with **bright, obvious, distinct values**:
     - Colors: Use `Colors.cyan`, `Colors.lime`, `Colors.pink`, etc. — clearly wrong for production
     - Typography: Use obviously different sizes (e.g., `fontSize: 99` for display styles)
     - Spacing: Use doubled values (e.g., xs=8, sm=16, md=24, lg=32, xl=48, xxl=64, xxxl=96)
     - Radius: Use exaggerated values
     - Decorations: Use bright neon shadows/gradients
  3. Verify distinctness test from T013 passes
- **Files**: `frontend/test/design_system/test_helpers/test_theme.dart` (update)
- **Parallel?**: Yes — can proceed with T014/T015
- **Notes**: The whole point of TestThemeTokens is to catch widgets that hardcode values instead of consuming tokens. Bright, wrong values make this obvious.

### Subtask T017 – Expand ThemeBridge.generateThemeData

- **Purpose**: Map expanded tokens to a complete `ThemeData` with proper ColorScheme, TextTheme, and component themes (FR-007).
- **Steps**:
  1. Read `frontend/lib/design_system/tokens/theme_bridge.dart`
  2. Expand `generateThemeData(AppTokens tokens)` to include:
     - **ColorScheme**: Map `tertiary`, `surfaceContainerHighest` (→surface), `surfaceContainerLow` (→surfaceDark)
     - **TextTheme**: Map `timerDigits`→`labelLarge`, `lobbyCode`→`labelMedium`, `phaseLabel`→`labelSmall` (overwrite existing label mappings)
     - **Component themes** (from `docs/stitch/token-map.md`):
       ```dart
       cardTheme: CardTheme(
         color: tokens.colors.surface,
         shape: RoundedRectangleBorder(borderRadius: tokens.radius.medium),
         elevation: 0,
       ),
       filledButtonTheme: FilledButtonThemeData(
         style: FilledButton.styleFrom(
           backgroundColor: tokens.colors.primary,
           foregroundColor: tokens.colors.onPrimary,
           minimumSize: const Size.fromHeight(56),
           shape: RoundedRectangleBorder(borderRadius: tokens.radius.medium),
         ),
       ),
       outlinedButtonTheme: OutlinedButtonThemeData(
         style: OutlinedButton.styleFrom(
           foregroundColor: tokens.colors.onSurface,
           side: BorderSide(color: tokens.colors.outline),
           minimumSize: const Size.fromHeight(48),
           shape: RoundedRectangleBorder(borderRadius: tokens.radius.medium),
         ),
       ),
       inputDecorationTheme: InputDecorationTheme(
         filled: true,
         fillColor: tokens.colors.surface,
         border: OutlineInputBorder(
           borderRadius: tokens.radius.medium,
           borderSide: BorderSide(color: tokens.colors.outline),
         ),
       ),
       dividerTheme: DividerThemeData(
         color: tokens.colors.outline,
         thickness: 1,
       ),
       appBarTheme: AppBarTheme(
         backgroundColor: Colors.transparent,
         elevation: 0,
         scrolledUnderElevation: 0,
       ),
       ```
  3. Verify ThemeBridge tests from T013 pass
- **Files**: `frontend/lib/design_system/tokens/theme_bridge.dart` (update)
- **Parallel?**: No — should follow after T014/T015/T016 (themes must compile first)

### Subtask T018 – Update provider default to FirelitGothicTheme

- **Purpose**: Make `FirelitGothicTheme` the default theme via the Riverpod provider.
- **Steps**:
  1. Read `frontend/lib/design_system/tokens/app_tokens_provider.dart`
  2. Change the default theme from `MidnightVillageTheme()` to `FirelitGothicTheme()`
  3. Add import for `firelit_gothic_theme.dart`
  4. Run `cd frontend && dart run build_runner build --delete-conflicting-outputs` to regenerate provider code
  5. Verify generated `app_tokens_provider.g.dart` is updated
- **Files**: `frontend/lib/design_system/tokens/app_tokens_provider.dart` (update), generated `.g.dart` files
- **Parallel?**: No — must follow after T014
- **Notes**: After this, the app will launch with Firelit Gothic styling by default.

## Test Strategy

**TEST_FIRST**: T013 writes tests before T014-T018 create implementations.

Run:
```bash
cd frontend && flutter test test/design_system/tokens/firelit_gothic_theme_test.dart
```

Key test areas:
- `FirelitGothicTheme` completeness — all 29 colors, 10 typography, 7 spacing, 5 radius, 7 decorations
- `ThemeBridge` output — valid `ThemeData` with correct `ColorScheme` and component themes
- `TestThemeTokens` distinctness — values differ from production theme

## Risks & Mitigations

- **Build runner fails** → Run `just flutter-build-runner` and verify generated code
- **MidnightVillageTheme defaults look wrong** → Acceptable; this theme may be removed; just needs to compile
- **Theme completeness gaps** → Compile errors catch any missing getters — this is the whole point of the interface pattern

## Review Guidance

- Verify `FirelitGothicTheme` implements ALL expanded interface getters (count: 29 colors + 10 typography + 7 spacing + 4 elevation + 5 radius + 7 decorations = 62 total)
- Verify `TestThemeTokens` values are obviously different from production (bright colors, exaggerated sizes)
- Verify `ThemeBridge` maps all 6 component themes listed in the token map
- Verify provider default changed to `FirelitGothicTheme`
- Verify build runner was executed and generated files are committed

## Activity Log

> **CRITICAL**: Activity log entries MUST be in chronological order (oldest first, newest last).

- 2026-03-26T08:24:14Z – system – lane=planned – Prompt created.

---

### Updating Lane Status

To change a work package's lane, either:
1. **Edit directly**: Change the `lane:` field in frontmatter AND append activity log entry (at the end)
2. **Use CLI**: `spec-kitty agent tasks move-task WP03 --to <lane> --note "message"` (recommended)

**Valid lanes**: `planned`, `doing`, `for_review`, `done`
- 2026-03-26T09:04:52Z – headless-impl – shell_pid=64952 – lane=doing – Assigned agent via workflow command
- 2026-03-26T09:18:15Z – headless-impl – shell_pid=64952 – lane=for_review – Ready for review: FirelitGothicTheme implements all 62 token getters (29 colors, 10 typography via GoogleFonts, 7 spacing, 4 elevation, 5 radius, 7 decorations). ThemeBridge expanded with tertiary/surfaceDark ColorScheme mapping, timerDigits/lobbyCode/phaseLabel TextTheme labels, and 6 component themes. Provider default switched to FirelitGothicTheme. 29 new tests all passing. T015/T016 completed by WP02 merge.
