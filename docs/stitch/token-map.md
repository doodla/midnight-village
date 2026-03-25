# Stitch → Flutter Design Token Mapping

This maps every Tailwind token from the Stitch-generated HTML to exact Flutter equivalents. Copy-paste ready for `app_theme.dart` and `app_colors.dart`.

---

## Color Tokens

### Stitch Tailwind → Flutter ColorScheme

| Stitch Tailwind Token | Hex | Flutter ColorScheme Field | Notes |
|-----------------------|-----|---------------------------|-------|
| `village-dark` / `village.void` | `#0D0B0F` | `surface` | Deepest background (night phase) |
| `village-surface` / `stone-900` | `#1A1714` | `surfaceContainerHighest` | Cards, elevated surfaces |
| `village-surface-dark` / `stone-950` | `#0F0D0C` | `surfaceContainerLow` | Slightly elevated from void |
| `village-ember` / `village.blood` | `#B8432F` | `primary` | Primary CTA, brand accent |
| `village-gold` / `village.tallow` | `#C8A24D` | `secondary` | Selection, highlights, village |
| `village-sage` / `village.sage` | `#5B8A72` | `tertiary` | Safe/positive accents |
| `village-cream` / `village.parchment` | `#E8DFD3` | `onSurface` | Primary text |
| `village.mist` | `#9C9084` | `onSurfaceVariant` | Muted/secondary text |
| `village.outline` | `#3D362C` | `outline` | Borders, dividers |
| — | `#C94038` | — (custom) | Werewolf team color |
| — | `#8B7D6B` | — (custom) | Independent/Tanner team |

### Dart Code: `app_colors.dart`

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
  static const teamVillage = Color(0xFFC8A24D); // same as tallowGold
  static const teamIndependent = Color(0xFF8B7D6B);

  // Phase backgrounds
  static const nightBg = Color(0xFF0D0B0F);
  static const discussionBg = Color(0xFF151210);
  static const votingBg = Color(0xFF12100E);
  static const resultsBg = Color(0xFF0F0D0B);
  static const lobbyBg = Color(0xFF1A1410);

  // Semantic
  static const danger = Color(0xFFE05A3A);  // timer danger pulse
  static const warning = Color(0xFFD47A3A); // timer warning
  static const noDeathBlue = Color(0xFF6B7B8B); // "No One Dies" — only cold color in palette
}
```

### Dart Code: `ColorScheme`

```dart
ColorScheme get colorScheme => const ColorScheme(
  brightness: Brightness.dark,
  primary: AppColors.emberRed,
  onPrimary: AppColors.parchment,
  secondary: AppColors.tallowGold,
  onSecondary: AppColors.voidBlack,
  tertiary: AppColors.moonSage,
  onTertiary: AppColors.parchment,
  error: AppColors.danger,
  onError: AppColors.parchment,
  surface: AppColors.voidBlack,
  onSurface: AppColors.parchment,
  onSurfaceVariant: AppColors.parchmentMuted,
  outline: AppColors.outline,
  surfaceContainerHighest: AppColors.surface,
  surfaceContainerLow: AppColors.surfaceDark,
);
```

---

## Typography Tokens

### Stitch Fonts → Flutter TextTheme

| Stitch CSS | Font Family | Google Fonts Import | Flutter TextTheme Field |
|------------|-------------|--------------------|-----------------------|
| `font-headline` / Epilogue | Epilogue | `GoogleFonts.epilogue()` | `displayLarge`, `headlineLarge`, `headlineMedium`, `headlineSmall` |
| `font-body` / DM Sans | DM Sans | `GoogleFonts.dmSans()` | `bodyLarge`, `bodyMedium`, `bodySmall` |
| `font-label` / Space Grotesk | Space Grotesk | `GoogleFonts.spaceGrotesk()` | `labelLarge`, `labelMedium`, `labelSmall` |
| `font-serif` / Libre Baskerville | Libre Baskerville | `GoogleFonts.libreBaskerville()` | Custom `displaySerif` extension |

**Note:** Stitch also introduced Crimson Pro on the night waiting screen as a serif variant. Libre Baskerville appeared on the welcome/home screens. Pick one — Libre Baskerville has better weight range.

### Dart Code: `app_typography.dart`

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

abstract final class AppTypography {
  static TextTheme get textTheme => TextTheme(
    // Epilogue headlines
    displayLarge: GoogleFonts.epilogue(
      fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.parchment,
      letterSpacing: 1.5,
    ),
    headlineLarge: GoogleFonts.epilogue(
      fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.parchment,
    ),
    headlineMedium: GoogleFonts.epilogue(
      fontSize: 20, fontWeight: FontWeight.w500, color: AppColors.parchment,
    ),
    headlineSmall: GoogleFonts.epilogue(
      fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.parchment,
    ),

    // DM Sans body
    bodyLarge: GoogleFonts.dmSans(
      fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.parchment,
    ),
    bodyMedium: GoogleFonts.dmSans(
      fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.parchment,
    ),
    bodySmall: GoogleFonts.dmSans(
      fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.parchmentMuted,
    ),

    // Space Grotesk labels
    labelLarge: GoogleFonts.spaceGrotesk(
      fontSize: 48, fontWeight: FontWeight.w600, color: AppColors.tallowGold,
    ), // Timer digits
    labelMedium: GoogleFonts.spaceGrotesk(
      fontSize: 28, fontWeight: FontWeight.w500, color: AppColors.tallowGold,
      letterSpacing: 8.0,
    ), // Lobby codes
    labelSmall: GoogleFonts.spaceGrotesk(
      fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.parchmentMuted,
      letterSpacing: 2.0,
    ), // Phase labels, badges
  );

  // Serif accent for atmospheric text ("The night begins...", taglines)
  static TextStyle get displaySerif => GoogleFonts.libreBaskerville(
    fontSize: 16, fontWeight: FontWeight.w400, fontStyle: FontStyle.italic,
    color: AppColors.parchmentMuted,
  );
}
```

---

## Shape / Border Radius Tokens

| Stitch Tailwind | Value | Flutter |
|-----------------|-------|---------|
| `rounded` (default) | 0.25rem (4px) | `BorderRadius.circular(4)` |
| `rounded-lg` | 0.5rem (8px) | `BorderRadius.circular(8)` — **primary radius** |
| `rounded-xl` | 0.75rem (12px) | `BorderRadius.circular(12)` |
| `rounded-2xl` | 1rem (16px) | `BorderRadius.circular(16)` |
| `rounded-full` | 9999px | `BorderRadius.circular(999)` |

**Design system uses ROUND_EIGHT** → default component radius is `8.0`.

```dart
abstract final class AppRadius {
  static const small = BorderRadius.all(Radius.circular(4));
  static const medium = BorderRadius.all(Radius.circular(8));  // default
  static const large = BorderRadius.all(Radius.circular(12));
  static const xl = BorderRadius.all(Radius.circular(16));
  static const full = BorderRadius.all(Radius.circular(999));
}
```

---

## Shadow / Glow Tokens

| Stitch CSS Class | Effect | Flutter Equivalent |
|------------------|--------|--------------------|
| `.fire-glow` | `box-shadow: 0 0 20px rgba(184,67,47, 0.15)` | `BoxShadow(color: AppColors.emberRed.withOpacity(0.15), blurRadius: 20, spreadRadius: 2)` |
| `.vision-glow` | Radial gradient, tallow-gold center | `RadialGradient(colors: [AppColors.tallowGold.withOpacity(0.1), Colors.transparent])` |
| `.blood-vignette` | Radial gradient, ember-red edges | `RadialGradient(colors: [Colors.transparent, AppColors.emberRed.withOpacity(0.15)])` |
| `.skull-glow` | `filter: drop-shadow(0 0 15px tallow)` | `BoxShadow(color: AppColors.tallowGold.withOpacity(0.4), blurRadius: 15)` |
| `.candle-glow` | Radial gradient transparent→void from center | `RadialGradient(center: Alignment.center, colors: [Colors.transparent, AppColors.voidBlack])` |
| SVG noise overlay | `feTurbulence` at 0.03-0.05 opacity | `ShaderMask` with noise texture PNG, or `ImageFiltered` with custom shader |

```dart
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

---

## Spacing Tokens

Stitch uses Tailwind's default spacing scale. Map to Flutter:

| Tailwind | Pixels | Usage |
|----------|--------|-------|
| `p-2` / `m-2` | 8px | Tight inner padding |
| `p-3` / `m-3` | 12px | Card padding |
| `p-4` / `m-4` | 16px | Standard section padding |
| `p-6` / `m-6` | 24px | Screen horizontal margin |
| `p-8` / `m-8` | 32px | Section vertical spacing |
| `gap-2` | 8px | Tight grid gap |
| `gap-3` | 12px | Card grid gap |
| `gap-4` | 16px | Standard gap |

Use `const` spacing values:

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

---

## Putting It Together: `app_theme.dart`

```dart
import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: /* colorScheme from above */,
    textTheme: AppTypography.textTheme,
    scaffoldBackgroundColor: AppColors.voidBlack,
    cardTheme: CardTheme(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.emberRed,
        foregroundColor: AppColors.parchment,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.epilogue(
          fontSize: 16, fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.parchment,
        side: BorderSide(color: AppColors.outline),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.tallowGold),
      ),
      labelStyle: TextStyle(color: AppColors.parchmentMuted),
      hintStyle: TextStyle(color: AppColors.parchmentMuted.withOpacity(0.6)),
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.outline,
      thickness: 1,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.epilogue(
        fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.parchment,
      ),
      iconTheme: IconThemeData(color: AppColors.parchment),
    ),
  );
}
```
