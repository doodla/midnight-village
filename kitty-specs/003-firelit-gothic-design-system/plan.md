# Implementation Plan: Firelit Gothic Design System

**Branch**: `main` | **Date**: 2026-03-26 | **Spec**: `kitty-specs/003-firelit-gothic-design-system/spec.md`
**Input**: Replace the current design token system with the Stitch-specified "Firelit Gothic" design system and build P0 foundation components.

## Summary

Expand the existing `AppTokens` abstraction layer to cover the full Firelit Gothic design system — new color tokens (phase backgrounds, decorations, semantic accents), new typography families (Epilogue, DM Sans, Space Grotesk, Libre Baskerville via Google Fonts), border radius and decoration token groups, and a 7-step spacing scale. Create a `FirelitGothicTheme` as the new default implementation. Build four P0 foundation widgets (`AtmosphericBackground`, `VillageAppBar`, `PrimaryButton`, `PlayerAvatar`). Migrate all 16 existing widgets to compile with the expanded token API. Remove bundled PlayfairDisplay/Inter fonts. Regenerate golden test images.

## Technical Context

**Language/Version**: Dart SDK ^3.10.4, Flutter stable
**Primary Dependencies**: Riverpod 3.0 (code-gen), GoRouter 17.0, Freezed 3.2, google_fonts (to add), material_symbols_icons (to add)
**Storage**: N/A (frontend-only feature)
**Testing**: flutter_test + mocktail 1.0, golden tests, 80% coverage target
**Target Platform**: Web (Chrome dev), iOS, Android
**Project Type**: Mobile + Web (Flutter)
**Performance Goals**: 60fps on all screens, noise overlay must not cause frame drops on low-end devices
**Constraints**: All existing tests must continue passing. No game logic changes. Token-driven styling only (no hardcoded colors/fonts).
**Scale/Scope**: 16 existing widgets to migrate, 4 new widgets to build, 5 abstract interfaces to expand/create, 2 theme implementations to write/update

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| No hardcoded values — use design tokens | PASS | All colors, typography, spacing, radii, and decorations flow through the expanded `AppTokens` contract via `activeThemeProvider`. Static `AppColors`/`AppTypography` classes exist as value definitions but are consumed only by theme implementations, never directly by widgets. |
| Riverpod patterns with code generation | PASS | `ActiveTheme` provider already uses `@Riverpod(keepAlive: true)`. New widgets will be `ConsumerWidget` consuming `activeThemeProvider`. |
| Platform-aware — works on web, iOS, Android | PASS | Google Fonts works cross-platform. Pre-rendered PNG noise texture avoids shader compatibility issues. No platform-specific code. |
| Handle loading/error states with AsyncValue | N/A | No async data in this feature — purely visual/token changes. |
| TEST_FIRST directive | ENFORCED | Tests must be written before implementation for each work package. Token value tests, widget render tests, migration regression tests. |
| 80% coverage target | ENFORCED | New widgets and token classes must have full test coverage. Existing test coverage must not decrease. |
| No game logic in widgets | PASS | All new widgets are presentational. `AtmosphericBackground` maps `GamePhase` to colors via tokens — this is display logic, not game logic. |
| Dispose resources | PASS | No new streams, controllers, or subscriptions in this feature. |
| Existing tests still pass | ENFORCED | All existing widget/golden/unit tests must pass after migration. Golden images regenerated. |

**Post-Phase 1 re-check**: Constitution gates remain satisfied. The expanded `AppTokens` interface adds compile-time enforcement — any theme missing a token fails to compile. The `TestThemeTokens` test helper must also be expanded, ensuring test theme completeness is mechanically enforced.

## Project Structure

### Documentation (this feature)

```
kitty-specs/003-firelit-gothic-design-system/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 research findings
├── data-model.md        # Expanded token interfaces and widget APIs
├── quickstart.md        # Development setup guide
├── contracts/           # Widget API contracts
│   ├── atmospheric_background.dart
│   ├── village_app_bar.dart
│   ├── primary_button.dart
│   └── player_avatar.dart
└── tasks.md             # Phase 2 output (NOT created by /spec-kitty.plan)
```

### Source Code (repository root)

```
frontend/
├── pubspec.yaml                           # Add google_fonts, material_symbols_icons
├── assets/
│   ├── fonts/                             # REMOVE: PlayfairDisplay, Inter
│   └── textures/
│       └── noise_grain.png                # NEW: Pre-rendered noise texture
├── lib/
│   ├── app.dart                           # No changes (already uses activeThemeDataProvider)
│   ├── design_system/
│   │   ├── tokens/
│   │   │   ├── app_tokens.dart            # EXPAND: +AppRadiusTokens, +AppDecorationTokens, expand color/typo/spacing
│   │   │   ├── app_tokens_provider.dart   # MINOR: Default changes to FirelitGothicTheme
│   │   │   ├── firelit_gothic_theme.dart  # NEW: FirelitGothicTheme implements expanded AppTokens
│   │   │   ├── app_colors.dart            # NEW: Static color constants (referenced by FirelitGothicTheme)
│   │   │   ├── app_typography.dart        # NEW: Static typography definitions using Google Fonts
│   │   │   ├── app_radius.dart            # NEW: Static border radius constants
│   │   │   ├── app_spacing.dart           # NEW: Static spacing constants
│   │   │   ├── app_shadows.dart           # NEW: Static box shadow presets
│   │   │   ├── app_decorations.dart       # NEW: Static gradient/effect presets
│   │   │   ├── midnight_village_theme.dart # UPDATE: Implement new interface getters
│   │   │   ├── theme_bridge.dart          # UPDATE: Expanded ThemeData generation
│   │   │   └── theme_assets.dart          # No changes
│   │   ├── components/
│   │   │   ├── core/
│   │   │   │   ├── mv_scaffold.dart       # UPDATE: New spacing names
│   │   │   │   ├── mv_button.dart         # REMOVE: Replaced by PrimaryButton
│   │   │   │   ├── primary_button.dart    # NEW: Ember red filled button with variants
│   │   │   │   ├── mv_card.dart           # UPDATE: New spacing/radius names
│   │   │   │   ├── mv_text_input.dart     # UPDATE: New spacing names
│   │   │   │   ├── mv_loading.dart        # UPDATE: New spacing names
│   │   │   │   ├── mv_error.dart          # UPDATE: New spacing names
│   │   │   │   └── mv_dialog.dart         # UPDATE: New spacing names
│   │   │   ├── game/                      # UPDATE: All 9 widgets, new spacing names
│   │   │   │   └── [existing files]
│   │   │   └── foundation/                # NEW: Foundation components
│   │   │       ├── atmospheric_background.dart  # NEW
│   │   │       ├── village_app_bar.dart          # NEW
│   │   │       └── player_avatar.dart            # NEW
│   │   └── models/
│   │       ├── game_phase.dart            # No changes (enum already exists)
│   │       └── avatar_size.dart           # NEW: AvatarSize enum
│   └── features/
│       └── auth/
│           └── presentation/
│               └── home_screen.dart       # UPDATE: Use new widgets/tokens
└── test/
    ├── design_system/
    │   ├── test_helpers/
    │   │   ├── test_theme.dart            # UPDATE: Implement expanded interfaces
    │   │   └── pump_with_tokens.dart      # No changes
    │   ├── tokens/                        # NEW: Token value tests
    │   │   ├── app_colors_test.dart
    │   │   ├── app_typography_test.dart
    │   │   └── firelit_gothic_theme_test.dart
    │   ├── components/
    │   │   ├── foundation/                # NEW: Foundation widget tests
    │   │   │   ├── atmospheric_background_test.dart
    │   │   │   ├── village_app_bar_test.dart
    │   │   │   ├── primary_button_test.dart
    │   │   │   └── player_avatar_test.dart
    │   │   ├── core/
    │   │   │   └── mv_button_golden_test.dart  # REMOVE/REPLACE
    │   │   └── game/                      # UPDATE: Existing tests compile
    │   └── examples/                      # UPDATE: Compile with new tokens
    ├── helpers/
    │   └── font_loading_smoke_test.dart   # UPDATE: Google Fonts config
    └── flutter_test_config.dart           # UPDATE: GoogleFonts.config
```

**Structure Decision**: The feature uses the existing `frontend/lib/design_system/` directory structure. New foundation widgets go in `components/foundation/` (distinct from `core/` which has the existing utility widgets, and `game/` which has game-specific widgets). Static token classes go in `tokens/` alongside the abstract interfaces and theme implementations.

## Complexity Tracking

No constitution violations to justify. The design adds two new abstract classes (`AppRadiusTokens`, `AppDecorationTokens`) which is proportionate to the feature scope — these represent genuinely new token categories not covered by the existing interface.

---

## Phase 0: Research (Complete)

See `kitty-specs/003-firelit-gothic-design-system/research.md` for full findings.

| # | Unknown | Resolution |
|---|---------|------------|
| R1 | Google Fonts integration | Use `google_fonts` package; runtime fetch with caching; fallback to system fonts |
| R2 | Noise grain texture | Pre-rendered 512×512 PNG at 3-5% opacity; no real-time shaders |
| R3 | Spacing token rename | Full rename to 7-step scale (xs, sm, md, lg, xl, xxl, xxxl); update all consumers |
| R4 | Interface expansion | Expand 3 existing + add 2 new abstract classes; compile-error-driven migration |
| R5 | Component migration | Dependency order: interfaces → themes → bridge → new widgets → existing widgets → cleanup |
| R6 | PrimaryButton vs MvButton | New widget with `isDestructive` param; replace all MvButton usages; remove MvButton |
| R7 | Google Fonts in tests | Disable runtime fetching; verify TextStyle properties; regenerate goldens |

---

## Phase 1: Design & Contracts (Complete)

### Entities

See `kitty-specs/003-firelit-gothic-design-system/data-model.md` for the full expanded token interfaces.

Key entities:
- **`AppTokens`** (expanded) — root contract with 6 groups: colors, typography, spacing, elevation, radius, decorations
- **`AppColorTokens`** (expanded) — 29 color getters (19 existing + 10 new)
- **`AppTypographyTokens`** (expanded) — 10 style getters (6 existing + 4 new)
- **`AppSpacingTokens`** (renamed) — 7-step scale replacing 6-step
- **`AppRadiusTokens`** (new) — 5 border radius presets
- **`AppDecorationTokens`** (new) — 6 glow/gradient presets + noise asset path
- **`FirelitGothicTheme`** — new concrete implementation with all Stitch values
- **`AvatarSize`** (new) — enum with small (32dp), medium (48dp), large (64dp)

### Widget Contracts

See `kitty-specs/003-firelit-gothic-design-system/contracts/` for full widget API contracts:
- `atmospheric_background.dart` — phase-aware background with optional noise overlay
- `village_app_bar.dart` — 4-variant app bar (brand, back, phase, minimal)
- `primary_button.dart` — full-width ember red button with disabled/loading/outlined/destructive states
- `player_avatar.dart` — circular initials avatar with deterministic hue and 3 sizes

### Dependencies Between Artifacts

```
app_tokens.dart (interfaces)
    ↓
firelit_gothic_theme.dart + midnight_village_theme.dart + test_theme.dart (implementations)
    ↓
theme_bridge.dart (MaterialTheme mapping)
    ↓
foundation widgets (AtmosphericBackground, VillageAppBar, PrimaryButton, PlayerAvatar)
    ↓
existing widgets migration (spacing rename, MvButton→PrimaryButton)
    ↓
cleanup (remove old fonts, regenerate goldens)
```

### Quickstart

See `kitty-specs/003-firelit-gothic-design-system/quickstart.md` for development setup.
