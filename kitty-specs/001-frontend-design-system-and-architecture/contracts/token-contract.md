# Token Contract API

**Feature**: 001-frontend-design-system-and-architecture
**Date**: 2026-03-24

## Token Provider API

### Provider: `activeThemeProvider`

Riverpod `Notifier` with `keepAlive: true`. Holds the currently active `AppTokens` instance.

**Read tokens in a widget**:
```dart
final tokens = ref.watch(activeThemeProvider);
// Access: tokens.colors.primary, tokens.typography.heading, etc.
```

**Switch theme**:
```dart
ref.read(activeThemeProvider.notifier).switchTheme(newTheme);
```

**Fine-grained rebuild**:
```dart
final primaryColor = ref.watch(activeThemeProvider.select((t) => t.colors.primary));
```

**Test override**:
```dart
ProviderScope(
  overrides: [activeThemeProvider.overrideWithValue(TestThemeTokens())],
  child: widgetUnderTest,
)
```

### Provider: `activeThemeDataProvider`

Computed provider that generates `ThemeData` from `activeThemeProvider` for the Material bridge.

```dart
@riverpod
ThemeData activeThemeData(Ref ref) {
  final tokens = ref.watch(activeThemeProvider);
  return generateThemeData(tokens);
}
```

Used in `app.dart`:
```dart
MaterialApp.router(
  theme: ref.watch(activeThemeDataProvider),
  ...
)
```

## Token Contract (Abstract Classes)

### AppTokens

```dart
abstract class AppTokens {
  String get name;
  AppColorTokens get colors;
  AppTypographyTokens get typography;
  AppSpacingTokens get spacing;
  AppElevationTokens get elevation;
}
```

### AppColorTokens

```dart
abstract class AppColorTokens {
  // Standard semantic colors
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

  // Game-specific semantic colors
  Color get werewolfTeam;
  Color get villageTeam;
  Color get independentTeam;
  Color get timerNormal;
  Color get timerUrgent;
  Color get cardBack;
}
```

### AppTypographyTokens

```dart
abstract class AppTypographyTokens {
  TextStyle get displayHeading;  // Large display (game title, phase names)
  TextStyle get heading;         // Section headings
  TextStyle get subheading;      // Sub-section headings
  TextStyle get body;            // Standard body text
  TextStyle get caption;         // Small supplementary text
  TextStyle get label;           // Button/input labels
}
```

### AppSpacingTokens

```dart
abstract class AppSpacingTokens {
  double get xs;   // 4.0 in default theme
  double get s;    // 8.0
  double get m;    // 16.0
  double get l;    // 24.0
  double get xl;   // 32.0
  double get xxl;  // 48.0
}
```

### AppElevationTokens

```dart
abstract class AppElevationTokens {
  double get flat;      // 0.0
  double get raised;    // 2.0
  double get floating;  // 6.0
  double get overlay;   // 12.0
}
```

## Material ThemeData Bridge

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

## Theme Assets API

```dart
abstract class ThemeAssets {
  String get themeId;
  String roleCardPath(RoleId role);
  String get cardBackPath;
}
```

Provided alongside `AppTokens` — either as a field on `AppTokens` or as a separate Riverpod provider keyed to the active theme ID.
