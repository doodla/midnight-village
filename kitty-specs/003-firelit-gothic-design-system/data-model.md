# Data Model: Firelit Gothic Design System

**Feature**: 003-firelit-gothic-design-system
**Date**: 2026-03-26

This document defines the expanded token interfaces, new enums, and widget API surfaces for the Firelit Gothic design system migration.

---

## 1. Expanded Abstract Interfaces

### 1.1 `AppTokens` (root contract)

```dart
/// Root token contract. All themes implement this.
/// Missing tokens cause compile errors — theme completeness is enforced.
abstract class AppTokens {
  String get name;
  AppColorTokens get colors;
  AppTypographyTokens get typography;
  AppSpacingTokens get spacing;
  AppElevationTokens get elevation;
  AppRadiusTokens get radius;           // NEW
  AppDecorationTokens get decorations;  // NEW
}
```

### 1.2 `AppColorTokens` (expanded)

```dart
abstract class AppColorTokens {
  // === Existing (19 getters) ===
  Color get primary;
  Color get onPrimary;
  Color get secondary;
  Color get onSecondary;
  Color get surface;
  Color get onSurface;
  Color get background;
  Color get onBackground;
  Color get error;
  Color get onError;
  Color get outline;
  Color get disabled;
  Color get onDisabled;
  Color get werewolfTeam;
  Color get villageTeam;
  Color get independentTeam;
  Color get timerNormal;
  Color get timerUrgent;
  Color get cardBack;

  // === New (10 getters) ===

  // Tertiary accent (Moonlit Sage in Firelit Gothic)
  Color get tertiary;

  // Phase-specific background colors
  Color get nightBg;
  Color get lobbyBg;
  Color get discussionBg;
  Color get votingBg;
  Color get resultsBg;

  // Additional surface variant
  Color get surfaceDark;

  // Semantic accents
  Color get danger;        // Timer danger pulse (distinct from error)
  Color get warning;       // Timer warning state
  Color get noDeathBlue;   // "No One Dies" — only cold color in palette
}
```

**Total**: 29 color getters (19 existing + 10 new)

### 1.3 `AppTypographyTokens` (expanded)

```dart
abstract class AppTypographyTokens {
  // === Existing (6 getters) ===
  TextStyle get displayHeading;  // 32sp, bold headline
  TextStyle get heading;         // 24sp, semi-bold headline
  TextStyle get subheading;      // 18sp, medium headline
  TextStyle get body;            // 16sp, regular body
  TextStyle get caption;         // 12sp, regular small text
  TextStyle get label;           // 14sp, medium labels

  // === New (4 getters) ===
  TextStyle get timerDigits;     // 48sp, Space Grotesk w600, for countdown timers
  TextStyle get lobbyCode;       // 28sp, Space Grotesk w500, letter-spaced lobby codes
  TextStyle get phaseLabel;      // 12sp, Space Grotesk w500, phase badges/labels
  TextStyle get serifAccent;     // 16sp, Libre Baskerville italic, atmospheric flavor text
}
```

**Total**: 10 typography getters (6 existing + 4 new)

### 1.4 `AppSpacingTokens` (renamed 7-step scale)

```dart
abstract class AppSpacingTokens {
  double get xs;    // 4.0  (unchanged)
  double get sm;    // 8.0  (was: s)
  double get md;    // 12.0 (NEW)
  double get lg;    // 16.0 (was: m)
  double get xl;    // 24.0 (was: l)
  double get xxl;   // 32.0 (was: xl)
  double get xxxl;  // 48.0 (was: xxl)
}
```

**Migration**: See research.md R3 for rename mapping.

### 1.5 `AppRadiusTokens` (new)

```dart
abstract class AppRadiusTokens {
  BorderRadius get small;   // 4dp
  BorderRadius get medium;  // 8dp (default component radius)
  BorderRadius get large;   // 12dp
  BorderRadius get xl;      // 16dp
  BorderRadius get full;    // 999dp (pill shape)
}
```

### 1.6 `AppDecorationTokens` (new)

```dart
abstract class AppDecorationTokens {
  // Box shadow presets
  List<BoxShadow> get fireGlow;       // Ember-red glow (CTAs, cards)
  List<BoxShadow> get selectionGlow;  // Tallow-gold glow (selected states)
  List<BoxShadow> get dangerGlow;     // Werewolf-red glow (danger states)

  // Gradient presets
  Gradient get visionGlow;     // Radial tallow-gold from center (night result, role reveal)
  Gradient get bloodVignette;  // Radial ember-red from edges (elimination)
  Gradient get candleGlow;     // Radial transparent→void from center (night screens)

  // Asset paths
  String get noiseOverlayAsset;  // Path to pre-rendered noise grain PNG
}
```

### 1.7 `AppElevationTokens` (unchanged)

```dart
abstract class AppElevationTokens {
  double get flat;
  double get raised;
  double get floating;
  double get overlay;
}
```

---

## 2. Concrete Implementations

### 2.1 `FirelitGothicTheme` (new default)

Implements all expanded `AppTokens` with the Stitch-specified values from `docs/stitch/token-map.md`. Key values:

| Token Group | Key Values |
|---|---|
| Colors | primary: `#B8432F`, secondary: `#C8A24D`, tertiary: `#5B8A72`, surface: `#1A1714`, background/nightBg: `#0D0B0F`, onSurface: `#E8DFD3` |
| Typography | Epilogue for headlines, DM Sans for body, Space Grotesk for labels/timers, Libre Baskerville for serif accent |
| Spacing | xs=4, sm=8, md=12, lg=16, xl=24, xxl=32, xxxl=48 |
| Radius | small=4, medium=8, large=12, xl=16, full=999 |
| Decorations | fireGlow: emberRed@15% blur20, selectionGlow: tallowGold@25% blur12, etc. |

Internal classes: `FirelitGothicColors`, `FirelitGothicTypography`, `FirelitGothicSpacing`, `FirelitGothicElevation`, `FirelitGothicRadius`, `FirelitGothicDecorations`.

The `FirelitGothicColors`/`FirelitGothicTypography` classes reference the static `AppColors`/`AppTypography` constants internally.

### 2.2 `MidnightVillageTheme` (updated)

Must implement the 10 new color getters, 4 new typography getters, renamed spacing getters, and new radius/decoration groups. Values should be sensible defaults in the existing warm-amber/deep-blue palette. This theme may be removed in a future feature but must compile now.

### 2.3 `TestThemeTokens` (updated)

Must implement all expanded interfaces with visually distinct values (bright/obvious colors, doubled spacing) to verify widgets consume tokens rather than hardcoding.

---

## 3. New Enums

### 3.1 `AvatarSize`

```dart
enum AvatarSize {
  small(32),
  medium(48),
  large(64);

  const AvatarSize(this.pixels);
  final double pixels;
}
```

**Location**: `frontend/lib/design_system/models/avatar_size.dart`

### 3.2 `GamePhase` (existing, no changes)

```dart
enum GamePhase {
  lobby('Lobby'),
  night('Night'),
  discussion('Discussion'),
  voting('Voting'),
  results('Results');
}
```

Already exists at `frontend/lib/design_system/models/game_phase.dart`. The `AtmosphericBackground` widget uses this enum to select phase-specific background colors from tokens.

---

## 4. Static Token Classes

These classes hold the concrete Firelit Gothic values. They are NOT part of the `AppTokens` interface — they are implementation details referenced by `FirelitGothicTheme`.

### 4.1 `AppColors`

Static `abstract final class` with all color constants. Copy-paste from `docs/stitch/token-map.md`.

**Location**: `frontend/lib/design_system/tokens/app_colors.dart`

### 4.2 `AppTypography`

Static `abstract final class` producing `TextStyle` instances using `google_fonts` package.

**Location**: `frontend/lib/design_system/tokens/app_typography.dart`

### 4.3 `AppRadius`

Static `abstract final class` with `BorderRadius` constants.

**Location**: `frontend/lib/design_system/tokens/app_radius.dart`

### 4.4 `AppSpacing`

Static `abstract final class` with `double` spacing constants.

**Location**: `frontend/lib/design_system/tokens/app_spacing.dart`

### 4.5 `AppShadows`

Static `abstract final class` with `List<BoxShadow>` presets.

**Location**: `frontend/lib/design_system/tokens/app_shadows.dart`

### 4.6 `AppDecorations`

Static `abstract final class` with `Gradient` presets and asset path constants.

**Location**: `frontend/lib/design_system/tokens/app_decorations.dart`

---

## 5. ThemeBridge Updates

`generateThemeData(AppTokens tokens)` in `theme_bridge.dart` must be expanded to:

1. Map expanded `ColorScheme` fields (tertiary, surfaceContainerHighest, surfaceContainerLow, etc.)
2. Map expanded `TextTheme` fields (timerDigits → labelLarge, lobbyCode → labelMedium, phaseLabel → labelSmall, serifAccent as extension)
3. Set component themes:
   - `cardTheme` using `tokens.radius.medium`
   - `filledButtonTheme` using `tokens.colors.primary`, `tokens.radius.medium`
   - `outlinedButtonTheme` using `tokens.colors.outline`, `tokens.radius.medium`
   - `inputDecorationTheme` using `tokens.colors.surface`, `tokens.colors.outline`, `tokens.radius.medium`
   - `dividerTheme` using `tokens.colors.outline`
   - `appBarTheme` using transparent background, `tokens.typography.subheading`

---

## 6. Widget Update Summary

### 6.1 Spacing Token Rename — All 16 Existing Widgets

Every widget that references `tokens.spacing.s`, `.m`, `.l`, `.xl`, `.xxl` must be updated:

| Old | New | Affected Files |
|-----|-----|----------------|
| `tokens.spacing.s` | `tokens.spacing.sm` | All components |
| `tokens.spacing.m` | `tokens.spacing.lg` | All components |
| `tokens.spacing.l` | `tokens.spacing.xl` | All components |
| `tokens.spacing.xl` | `tokens.spacing.xxl` | All components |
| `tokens.spacing.xxl` | `tokens.spacing.xxxl` | All components |

### 6.2 MvButton → PrimaryButton Migration

All usages of `MvButton` in the codebase must be replaced:
- `MvButton(variant: primary)` → `PrimaryButton()`
- `MvButton(variant: secondary)` → `PrimaryButton.outlined()`
- `MvButton(variant: destructive)` → `PrimaryButton(isDestructive: true)`

Known consumers: `home_screen.dart`, `vote_submission.dart`, `game_results.dart`, `night_action_prompt.dart`, `mv_error.dart`, `mv_dialog.dart`.

### 6.3 Existing Core Widgets — Token API Updates Only

`MvScaffold`, `MvCard`, `MvTextInput`, `MvLoading`, `MvError`, `MvDialog`: Only spacing rename changes. Visual behavior unchanged.

### 6.4 Existing Game Widgets — Token API Updates Only

All 9 game widgets: Only spacing rename changes. Visual behavior determined by theme, which now provides Firelit Gothic values.
