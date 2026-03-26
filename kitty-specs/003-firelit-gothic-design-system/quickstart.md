# Quickstart: Firelit Gothic Design System

**Feature**: 003-firelit-gothic-design-system

## Prerequisites

- Flutter SDK (stable channel)
- Dart SDK ^3.10.4
- Working `just` command runner
- Backend running for integration tests (optional)

## Setup

```bash
# From project root
cd frontend

# Add new dependencies
flutter pub add google_fonts
flutter pub add material_symbols_icons

# Verify setup
just flutter-analyze
```

## Key Files to Understand

Before implementing, read these files in order:

1. **Token interfaces** — `lib/design_system/tokens/app_tokens.dart`
   - The abstract contracts all themes must implement
   - Expand these first; everything else follows

2. **Existing theme** — `lib/design_system/tokens/midnight_village_theme.dart`
   - Current default implementation
   - Must be updated to implement expanded interfaces

3. **Theme bridge** — `lib/design_system/tokens/theme_bridge.dart`
   - Maps AppTokens → Flutter ThemeData
   - Must be expanded for new token categories

4. **Stitch token map** — `docs/stitch/token-map.md`
   - Copy-paste-ready Dart code for all Firelit Gothic values
   - The authoritative source for color hex values, font sizes, etc.

5. **Test helper** — `test/design_system/test_helpers/test_theme.dart`
   - Must implement expanded interfaces with distinct values
   - Used by all widget tests

## Development Workflow

```bash
# Run frontend tests
just flutter-test

# Run analysis (lint + type check)
just flutter-analyze

# Run code generation (after modifying freezed/riverpod annotated files)
just flutter-build-runner

# Full quality gate
just check
```

## Testing Strategy

### Token Value Tests
```dart
// Verify hex values match spec
test('AppColors.emberRed matches Stitch spec', () {
  expect(AppColors.emberRed, equals(const Color(0xFFB8432F)));
});
```

### Widget Tests
```dart
// Use pumpWithTokens helper for all widget tests
await tester.pumpWithTokens(
  AtmosphericBackground(
    phase: GamePhase.night,
    child: Text('test'),
  ),
);
```

### Google Fonts in Tests
```dart
// In flutter_test_config.dart — disable runtime font fetching
GoogleFonts.config.allowRuntimeFetching = false;
```

## Architecture Diagram

```
Static Constants                    Abstract Contracts
─────────────────                   ──────────────────
AppColors                           AppTokens
AppTypography          ──────►        ├── AppColorTokens
AppRadius                             ├── AppTypographyTokens
AppSpacing                            ├── AppSpacingTokens
AppShadows                            ├── AppElevationTokens
AppDecorations                        ├── AppRadiusTokens
                                      └── AppDecorationTokens
                                              │
                                    ┌─────────┼─────────┐
                                    ▼         ▼         ▼
                              FirelitGothic  MV Theme  TestTheme
                              Theme (NEW)   (UPDATED) (UPDATED)
                                    │
                                    ▼
                              activeThemeProvider (Riverpod)
                                    │
                                    ▼
                              All Widgets (ConsumerWidget)
```

## Dependency Order for Implementation

1. Expand `app_tokens.dart` interfaces
2. Create static constant classes (`app_colors.dart`, `app_typography.dart`, etc.)
3. Create `FirelitGothicTheme`
4. Update `MidnightVillageTheme` (implement new getters)
5. Update `TestThemeTokens`
6. Update `ThemeBridge`
7. Build new foundation widgets
8. Migrate existing widgets (spacing rename)
9. Replace MvButton with PrimaryButton
10. Remove old fonts, update pubspec.yaml
11. Regenerate golden images
12. Final verification: `just check` + `just flutter-test`
