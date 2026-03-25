---
work_package_id: WP01
title: Token Foundation & Theme Infrastructure
lane: done
dependencies: []
requirement_refs:
- FR-001
- FR-002
- FR-003
- FR-004
- FR-020
base_branch: main
base_commit: 33943580b08a0e2c5db5032ca50639a911a2bfce
created_at: '2026-03-25T02:34:24.932401+00:00'
subtasks:
- T001
- T002
- T003
- T004
- T005
- T006
- T007
phase: Phase A - Foundation
assignee: ''
agent: claude-opus
shell_pid: '83984'
review_status: approved
reviewed_by: Sridhar Vadlamani
history:
- timestamp: '2026-03-25T01:34:57Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP01 – Token Foundation & Theme Infrastructure

## ⚠️ IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately.
- **You must address all feedback** before your work is complete.
- **Mark as acknowledged**: When you understand the feedback and begin addressing it, update `review_status: acknowledged` in the frontmatter.

---

## Review Feedback

> **Populated by `/spec-kitty.review`** – Reviewers add detailed feedback here when work needs changes.

*[This section is empty initially.]*

---

## Objectives & Success Criteria

Build the complete theming foundation for Midnight Village:

1. **Token abstract contract** — Dart abstract classes enforcing theme completeness at compile time.
2. **Default theme** — "Midnight Village" theme with warm ambers/oranges, deep blues/indigos, muted earth tones, atmospheric serif headings.
3. **Riverpod provider** — `activeThemeProvider` notifier holding the active `AppTokens`, switchable at runtime.
4. **Material bridge** — `generateThemeData()` function producing `ThemeData` from tokens, so Material widgets inherit theme colors.
5. **Test infrastructure** — `TestThemeTokens` with visually distinct values + `pumpWithTokens` helper for widget tests.
6. **App wiring** — `app.dart` uses the provider for `MaterialApp.router(theme:)`.

**Success criteria**:
- All abstract token getters are enforced at compile time (missing token = compile error)
- `ref.watch(activeThemeProvider)` returns resolved tokens in any `ConsumerWidget`
- Switching themes via `switchTheme()` updates all consumers in a single frame rebuild
- `pumpWithTokens(widget)` wraps a widget in a test-ready `ProviderScope` with theme override support
- `just flutter-analyze` passes with zero issues

## Context & Constraints

**Key documents**:
- Token contract: `kitty-specs/001-frontend-design-system-and-architecture/contracts/token-contract.md`
- Data model: `kitty-specs/001-frontend-design-system-and-architecture/data-model.md`
- Research decisions: `kitty-specs/001-frontend-design-system-and-architecture/research.md`
- Quickstart usage: `kitty-specs/001-frontend-design-system-and-architecture/quickstart.md`

**Architectural constraints**:
- Riverpod codegen pattern (`@riverpod`) — consistent with existing `auth_notifier.dart`
- No barrel files — direct imports (consistent with existing codebase)
- All implementations must be `const`-constructible and immutable
- Tokens use reference equality (`identical()`) for change detection
- Brightness is always `Brightness.dark` for Midnight Village (the default theme is dark)

**Existing code to reference**:
- `frontend/lib/app.dart` — where to wire the provider
- `frontend/lib/features/auth/presentation/auth_notifier.dart` — example of existing Riverpod codegen pattern
- `frontend/pubspec.yaml` — where to add dependencies and font declarations

## Subtasks & Detailed Guidance

### Subtask T001 – Create token abstract contract classes

- **Purpose**: Define the type-safe theme contract that all themes must implement. Compile-time enforcement means a theme that misses any token won't compile.
- **File**: `frontend/lib/design_system/tokens/app_tokens.dart`
- **Steps**:
  1. Create `abstract class AppTokens` with getters:
     - `String get name`
     - `AppColorTokens get colors`
     - `AppTypographyTokens get typography`
     - `AppSpacingTokens get spacing`
     - `AppElevationTokens get elevation`
  2. Create `abstract class AppColorTokens` with all color getters:
     - Standard: `primary`, `onPrimary`, `secondary`, `onSecondary`, `surface`, `onSurface`, `background`, `onBackground`, `error`, `onError`, `outline`, `disabled`, `onDisabled`
     - Game-specific: `werewolfTeam`, `villageTeam`, `independentTeam`, `timerNormal`, `timerUrgent`, `cardBack`
     - All return `Color` (from `dart:ui` or `package:flutter/material.dart`)
  3. Create `abstract class AppTypographyTokens` with getters:
     - `displayHeading`, `heading`, `subheading`, `body`, `caption`, `label`
     - All return `TextStyle`
  4. Create `abstract class AppSpacingTokens` with `double` getters:
     - `xs`, `s`, `m`, `l`, `xl`, `xxl`
  5. Create `abstract class AppElevationTokens` with `double` getters:
     - `flat`, `raised`, `floating`, `overlay`
- **Validation**:
  - [ ] All abstract classes defined with correct return types
  - [ ] No default implementations (force implementors to provide all values)
  - [ ] `import 'package:flutter/material.dart'` for Color and TextStyle types

### Subtask T002 – Bundle fonts and configure assets

- **Purpose**: Download open-source fonts, bundle them in the project, add `flutter_svg` dependency, and declare all asset paths in pubspec.yaml.
- **Files**:
  - `frontend/pubspec.yaml` (modify)
  - `frontend/assets/fonts/` (new directory with font files)
- **Steps**:
  1. Choose fonts:
     - **Heading font**: A serif or semi-serif font for atmospheric headings. Good candidates: Playfair Display, Cormorant Garamond, Libre Baskerville, or similar.
     - **Body font**: A clean sans-serif for readability on phones. Good candidates: Inter, Source Sans 3, Nunito Sans, or similar.
     - Must be OFL or Apache 2.0 licensed.
  2. Download font files (.ttf) — Regular, Bold, and Italic weights minimum for each family.
  3. Place in `frontend/assets/fonts/<font-name>/` directories.
  4. Add to `pubspec.yaml` under `flutter.fonts:` section:
     ```yaml
     fonts:
       - family: <HeadingFont>
         fonts:
           - asset: assets/fonts/<heading-font>/Regular.ttf
           - asset: assets/fonts/<heading-font>/Bold.ttf
             weight: 700
           - asset: assets/fonts/<heading-font>/Italic.ttf
             style: italic
       - family: <BodyFont>
         fonts:
           - asset: assets/fonts/<body-font>/Regular.ttf
           - asset: assets/fonts/<body-font>/Bold.ttf
             weight: 700
           - asset: assets/fonts/<body-font>/Italic.ttf
             style: italic
     ```
  5. Add `flutter_svg` to dependencies in `pubspec.yaml`:
     ```yaml
     flutter_svg: ^2.0.0
     ```
  6. Declare asset directories in `pubspec.yaml`:
     ```yaml
     flutter:
       assets:
         - assets/themes/midnight-village/
         - assets/themes/midnight-village/roles/
         - assets/themes/_placeholder/
         - assets/themes/_placeholder/roles/
     ```
- **Parallel?**: Yes — can proceed alongside T001.
- **Validation**:
  - [ ] Font files are present in `assets/fonts/`
  - [ ] pubspec.yaml declares fonts correctly
  - [ ] `flutter_svg` dependency added
  - [ ] `flutter pub get` succeeds

### Subtask T003 – Create Midnight Village theme implementation

- **Purpose**: Implement the default theme with the visual identity: warm firelight ambers/oranges for interactives, deep blues/indigos for backgrounds, muted earth tones for secondary elements, serif headings + sans-serif body.
- **File**: `frontend/lib/design_system/tokens/midnight_village_theme.dart`
- **Steps**:
  1. Create `class MidnightVillageTheme implements AppTokens` with `const` constructor.
  2. Create `class MidnightVillageColors implements AppColorTokens` with `const` constructor:
     - `primary`: Warm amber/orange (e.g., `Color(0xFFE8A849)` — firelight gold)
     - `onPrimary`: Dark brown/black for text on amber
     - `secondary`: Muted sage/earth (e.g., `Color(0xFF8B9D83)`)
     - `onSecondary`: Light text on sage
     - `surface`: Dark blue-grey card surface (e.g., `Color(0xFF1E2A3A)`)
     - `onSurface`: Light cream/white text
     - `background`: Deep indigo/navy (e.g., `Color(0xFF0F1923)` — night sky)
     - `onBackground`: Light cream text
     - `error`: Muted red (e.g., `Color(0xFFCF6679)`)
     - `onError`: Dark text on error
     - `outline`: Subtle blue-grey border
     - `disabled`: Grey (e.g., `Color(0xFF4A5568)`)
     - `onDisabled`: Muted text on disabled
     - `werewolfTeam`: Deep red (e.g., `Color(0xFFB33A3A)`)
     - `villageTeam`: Soft blue (e.g., `Color(0xFF4A90D9)`)
     - `independentTeam`: Muted gold/amber (e.g., `Color(0xFFC4A35A)`)
     - `timerNormal`: Calm blue-white
     - `timerUrgent`: Warning red-orange
     - `cardBack`: Dark navy with slight shimmer (darker than surface)
  3. Create `class MidnightVillageTypography implements AppTypographyTokens`:
     - `displayHeading`: Heading font, size 32, bold
     - `heading`: Heading font, size 24, semi-bold
     - `subheading`: Heading font, size 18, medium
     - `body`: Body font, size 16, regular
     - `caption`: Body font, size 12, regular
     - `label`: Body font, size 14, medium
     - All `TextStyle` instances with explicit font family name
  4. Create `class MidnightVillageSpacing implements AppSpacingTokens`:
     - `xs: 4.0`, `s: 8.0`, `m: 16.0`, `l: 24.0`, `xl: 32.0`, `xxl: 48.0`
  5. Create `class MidnightVillageElevation implements AppElevationTokens`:
     - `flat: 0.0`, `raised: 2.0`, `floating: 6.0`, `overlay: 12.0`
  6. All classes must have `const` constructors.
- **Validation**:
  - [ ] All token getters implemented (compiler enforces this)
  - [ ] Color values create a cohesive dark theme evoking firelight + night sky
  - [ ] Typography uses the bundled font family names
  - [ ] All classes are `const`-constructible

### Subtask T004 – Create Riverpod activeThemeProvider notifier

- **Purpose**: Provide the active theme to all widgets via Riverpod. Supports runtime theme switching.
- **File**: `frontend/lib/design_system/tokens/app_tokens_provider.dart`
- **Steps**:
  1. Create a Riverpod `Notifier` using codegen:
     ```dart
     @Riverpod(keepAlive: true)
     class ActiveTheme extends _$ActiveTheme {
       @override
       AppTokens build() => const MidnightVillageTheme();

       void switchTheme(AppTokens theme) {
         state = theme;
       }
     }
     ```
  2. Run `dart run build_runner build` to generate `.g.dart` file.
  3. Verify the provider:
     - `ref.watch(activeThemeProvider)` returns the current `AppTokens`
     - `ref.read(activeThemeProvider.notifier).switchTheme(newTheme)` switches
     - `ref.watch(activeThemeProvider.select((t) => t.colors.primary))` enables fine-grained rebuilds
- **Validation**:
  - [ ] Provider codegen compiles
  - [ ] Default value is `MidnightVillageTheme`
  - [ ] `keepAlive: true` ensures theme survives navigation
  - [ ] `switchTheme()` triggers rebuild on all watchers

### Subtask T005 – Create Material ThemeData bridge

- **Purpose**: Generate `ThemeData` from `AppTokens` so Material widgets (TextField, ElevatedButton, Scaffold, etc.) automatically inherit theme colors.
- **File**: `frontend/lib/design_system/tokens/theme_bridge.dart`
- **Steps**:
  1. Create `ThemeData generateThemeData(AppTokens tokens)`:
     ```dart
     ThemeData generateThemeData(AppTokens tokens) {
       final colors = tokens.colors;
       return ThemeData(
         useMaterial3: true,
         brightness: Brightness.dark,
         colorScheme: ColorScheme.fromSeed(
           seedColor: colors.primary,
           brightness: Brightness.dark,
         ).copyWith(
           primary: colors.primary,
           onPrimary: colors.onPrimary,
           secondary: colors.secondary,
           onSecondary: colors.onSecondary,
           surface: colors.surface,
           onSurface: colors.onSurface,
           error: colors.error,
           onError: colors.onError,
           outline: colors.outline,
         ),
         scaffoldBackgroundColor: colors.background,
         textTheme: TextTheme(
           displayLarge: tokens.typography.displayHeading,
           headlineMedium: tokens.typography.heading,
           titleMedium: tokens.typography.subheading,
           bodyMedium: tokens.typography.body,
           bodySmall: tokens.typography.caption,
           labelLarge: tokens.typography.label,
         ),
       );
     }
     ```
  2. Create computed provider using codegen:
     ```dart
     @riverpod
     ThemeData activeThemeData(Ref ref) {
       final tokens = ref.watch(activeThemeProvider);
       return generateThemeData(tokens);
     }
     ```
  3. Run `dart run build_runner build` to generate `.g.dart`.
- **Validation**:
  - [ ] `generateThemeData` produces valid `ThemeData`
  - [ ] `activeThemeDataProvider` watches `activeThemeProvider` and recomputes on theme change
  - [ ] Material widgets pick up correct colors from generated ThemeData

### Subtask T006 – Create test theme + pumpWithTokens helper

- **Purpose**: Provide test infrastructure so widget tests can render with theme tokens. Test theme uses visually distinct values to detect token leaks.
- **Files**:
  - `frontend/test/design_system/test_helpers/test_theme.dart`
  - `frontend/test/design_system/test_helpers/pump_with_tokens.dart`
- **Steps**:
  1. Create `TestThemeTokens implements AppTokens` with distinct values:
     - All colors should be noticeably different from Midnight Village (e.g., bright greens, magentas)
     - Typography can use default system fonts
     - Spacing values should differ (e.g., double the normal values)
     - Purpose: When testing, switching to this theme verifies components actually use tokens
  2. Create `pumpWithTokens` extension on `WidgetTester`:
     ```dart
     extension PumpWithTokens on WidgetTester {
       Future<void> pumpWithTokens(
         Widget widget, {
         AppTokens? theme,
       }) async {
         await pumpWidget(
           ProviderScope(
             overrides: [
               if (theme != null)
                 activeThemeProvider.overrideWith(() => ActiveTheme()..switchTheme(theme)),
             ],
             child: MaterialApp(
               theme: generateThemeData(theme ?? const MidnightVillageTheme()),
               home: widget,
             ),
           ),
         );
       }
     }
     ```
     Note: The exact override mechanism may vary based on Riverpod 3.x API. Check the existing test patterns in `frontend/test/` for reference.
  3. Ensure the helper wraps the widget with both `ProviderScope` and `MaterialApp` so Material widgets render correctly.
- **Validation**:
  - [ ] `TestThemeTokens` compiles (all abstract getters implemented)
  - [ ] Test theme values are visually distinct from Midnight Village
  - [ ] `pumpWithTokens(widget)` renders widget with default Midnight Village theme
  - [ ] `pumpWithTokens(widget, theme: TestThemeTokens())` renders with test theme

### Subtask T007 – Wire token provider + ThemeData into app.dart

- **Purpose**: Connect the theme system to the app so all screens use themed styling.
- **File**: `frontend/lib/app.dart` (modify)
- **Steps**:
  1. Read the current `app.dart` to understand existing structure.
  2. Add `ref.watch(activeThemeDataProvider)` to get the `ThemeData`.
  3. Pass it to `MaterialApp.router(theme:)`:
     ```dart
     MaterialApp.router(
       theme: ref.watch(activeThemeDataProvider),
       routerConfig: appRouter,
       // ... existing config
     )
     ```
  4. Ensure `App` widget is already a `ConsumerWidget` (it should be, given existing Riverpod usage).
- **Validation**:
  - [ ] App renders with Midnight Village theme colors
  - [ ] Background color is deep indigo/navy
  - [ ] Text is legible on dark background
  - [ ] Existing auth screen still functions (no regression)

## Risks & Mitigations

- **Codegen failures**: Run `dart run build_runner build --delete-conflicting-outputs` if conflicts arise. Verify all `.g.dart` files generate cleanly.
- **Font not loading**: Ensure font family names in `TextStyle` exactly match the `family` name in `pubspec.yaml`. Flutter is case-sensitive on font names.
- **Color contrast**: Verify primary-on-dark and error-on-dark combinations meet minimum contrast ratios. Use 4.5:1 for body text, 3:1 for large text.
- **Import cycles**: `theme_bridge.dart` imports `app_tokens_provider.dart` which imports `app_tokens.dart`. Keep the dependency chain unidirectional.

## Review Guidance

- **Token completeness**: Verify all abstract getters exist with correct types. Attempt to create a new theme — does the compiler catch missing tokens?
- **Color palette cohesion**: Do the Midnight Village colors work together as a dark theme? Check primary-on-surface, error-on-surface, team colors against backgrounds.
- **Test helper usability**: Is `pumpWithTokens` easy to use? Does it properly scope the provider override?
- **No hardcoded values**: Grep for `Color(0x` or `TextStyle(fontSize:` in component code — should only appear in theme implementations.
- **Codegen output**: Are all `.g.dart` files present and up to date?

## Activity Log

- 2026-03-25T01:34:57Z – system – lane=planned – Prompt created.
- 2026-03-25T02:34:25Z – claude-opus – shell_pid=71533 – lane=doing – Assigned agent via workflow command
- 2026-03-25T02:42:40Z – claude-opus – shell_pid=71533 – lane=for_review – Ready for review: Token foundation complete — abstract contracts, Midnight Village theme, Riverpod provider, ThemeData bridge, test infrastructure, app wiring. flutter analyze clean, 104 tests passing.
- 2026-03-25T02:48:39Z – claude-opus – shell_pid=83984 – lane=doing – Started review via workflow command
- 2026-03-25T02:50:03Z – claude-opus – shell_pid=83984 – lane=done – Review passed: All 7 subtasks verified. Token contracts enforce compile-time completeness. Midnight Village palette is cohesive. Riverpod provider + ThemeData bridge wired correctly. Test infrastructure ready. flutter analyze clean, 104 tests passing. No hardcoded colors outside theme. Unidirectional dependency chain.
