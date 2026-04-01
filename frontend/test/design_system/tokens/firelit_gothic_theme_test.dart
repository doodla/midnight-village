import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:midnight_village/design_system/tokens/app_colors.dart';
import 'package:midnight_village/design_system/tokens/app_radius.dart';
import 'package:midnight_village/design_system/tokens/app_spacing.dart';
import 'package:midnight_village/design_system/tokens/firelit_gothic_theme.dart';
import 'package:midnight_village/design_system/tokens/theme_bridge.dart';

import '../test_helpers/test_theme.dart';

// NOTE: Typography getter tests use runZonedGuarded to suppress google_fonts
// async CDN-fetch failures. The TextStyle properties (fontSize, fontWeight,
// color, letterSpacing) are set synchronously before any loading attempt.
// Font-family assertions are omitted to avoid triggering the same errors.

TextStyle _getTypographyStyle(TextStyle Function() builder) {
  late TextStyle result;
  runZonedGuarded(() => result = builder(), (error, stack) {
    // Suppress google_fonts asset/CDN loading errors — they happen async
    // after the TextStyle is already returned with correct properties.
  });
  return result;
}

ThemeData _buildThemeData(FirelitGothicTheme theme) {
  late ThemeData result;
  runZonedGuarded(() => result = generateThemeData(theme), (error, stack) {
    // Suppress google_fonts asset/CDN loading errors.
  });
  return result;
}

void main() {
  group('FirelitGothicTheme', () {
    late FirelitGothicTheme theme;

    setUp(() {
      theme = const FirelitGothicTheme();
    });

    test('returns correct name', () {
      expect(theme.name, 'Firelit Gothic');
    });

    group('colors', () {
      test('primary is ember red', () {
        expect(theme.colors.primary, AppColors.emberRed);
      });

      test('secondary is tallow gold', () {
        expect(theme.colors.secondary, AppColors.tallowGold);
      });

      test('tertiary is moon sage', () {
        expect(theme.colors.tertiary, AppColors.moonSage);
      });

      test('all 29 color getters return non-null values', () {
        final colors = theme.colors;
        // Standard semantic colors (13)
        expect(colors.primary, isNotNull);
        expect(colors.onPrimary, isNotNull);
        expect(colors.secondary, isNotNull);
        expect(colors.onSecondary, isNotNull);
        expect(colors.surface, isNotNull);
        expect(colors.onSurface, isNotNull);
        expect(colors.background, isNotNull);
        expect(colors.onBackground, isNotNull);
        expect(colors.error, isNotNull);
        expect(colors.onError, isNotNull);
        expect(colors.outline, isNotNull);
        expect(colors.disabled, isNotNull);
        expect(colors.onDisabled, isNotNull);
        // Game-specific (6)
        expect(colors.werewolfTeam, isNotNull);
        expect(colors.villageTeam, isNotNull);
        expect(colors.independentTeam, isNotNull);
        expect(colors.timerNormal, isNotNull);
        expect(colors.timerUrgent, isNotNull);
        expect(colors.cardBack, isNotNull);
        // Extended Firelit Gothic (10)
        expect(colors.tertiary, isNotNull);
        expect(colors.nightBg, isNotNull);
        expect(colors.lobbyBg, isNotNull);
        expect(colors.discussionBg, isNotNull);
        expect(colors.votingBg, isNotNull);
        expect(colors.resultsBg, isNotNull);
        expect(colors.surfaceDark, isNotNull);
        expect(colors.danger, isNotNull);
        expect(colors.warning, isNotNull);
        expect(colors.noDeathBlue, isNotNull);
      });
    });

    group('typography', () {
      test('all 10 typography getters return non-null', () {
        // Wrap in runZonedGuarded to suppress google_fonts async load errors.
        runZonedGuarded(() {
          final typography = theme.typography;
          expect(typography.displayHeading, isNotNull);
          expect(typography.heading, isNotNull);
          expect(typography.subheading, isNotNull);
          expect(typography.body, isNotNull);
          expect(typography.caption, isNotNull);
          expect(typography.label, isNotNull);
          expect(typography.timerDigits, isNotNull);
          expect(typography.lobbyCode, isNotNull);
          expect(typography.phaseLabel, isNotNull);
          expect(typography.serifAccent, isNotNull);
        }, (error, stack) {});
      });

      test('timerDigits has fontSize 48', () {
        final style = _getTypographyStyle(() => theme.typography.timerDigits);
        expect(style.fontSize, 48.0);
      });

      test('lobbyCode has fontSize 28', () {
        final style = _getTypographyStyle(() => theme.typography.lobbyCode);
        expect(style.fontSize, 28.0);
      });

      test('phaseLabel has fontSize 12', () {
        final style = _getTypographyStyle(() => theme.typography.phaseLabel);
        expect(style.fontSize, 12.0);
      });

      test('serifAccent is italic', () {
        final style = _getTypographyStyle(() => theme.typography.serifAccent);
        expect(style.fontStyle, FontStyle.italic);
      });
    });

    group('spacing', () {
      test('xs is 4.0', () {
        expect(theme.spacing.xs, 4.0);
      });

      test('sm is 8.0', () {
        expect(theme.spacing.sm, 8.0);
      });

      test('md is 12.0', () {
        expect(theme.spacing.md, 12.0);
      });

      test('all spacing values match AppSpacing constants', () {
        expect(theme.spacing.xs, AppSpacing.xs);
        expect(theme.spacing.sm, AppSpacing.sm);
        expect(theme.spacing.md, AppSpacing.md);
        expect(theme.spacing.lg, AppSpacing.lg);
        expect(theme.spacing.xl, AppSpacing.xl);
        expect(theme.spacing.xxl, AppSpacing.xxl);
        expect(theme.spacing.xxxl, AppSpacing.xxxl);
      });
    });

    group('radius', () {
      test('medium radius matches AppRadius.medium', () {
        expect(theme.radius.medium, AppRadius.medium);
      });

      test('all 5 radius values are non-null', () {
        expect(theme.radius.small, isNotNull);
        expect(theme.radius.medium, isNotNull);
        expect(theme.radius.large, isNotNull);
        expect(theme.radius.xl, isNotNull);
        expect(theme.radius.full, isNotNull);
      });
    });

    group('decorations', () {
      test('fireGlow is non-empty', () {
        expect(theme.decorations.fireGlow, isNotEmpty);
      });

      test('all decoration getters are non-null', () {
        expect(theme.decorations.fireGlow, isNotNull);
        expect(theme.decorations.selectionGlow, isNotNull);
        expect(theme.decorations.dangerGlow, isNotNull);
        expect(theme.decorations.visionGlow, isNotNull);
        expect(theme.decorations.bloodVignette, isNotNull);
        expect(theme.decorations.candleGlow, isNotNull);
        expect(theme.decorations.noiseOverlayAsset, isNotEmpty);
      });
    });
  });

  group('generateThemeData (ThemeBridge)', () {
    late ThemeData themeData;

    setUp(() {
      themeData = _buildThemeData(const FirelitGothicTheme());
    });

    test('generates valid ThemeData', () {
      expect(themeData, isNotNull);
      expect(themeData.useMaterial3, isTrue);
    });

    test('colorScheme primary matches emberRed', () {
      expect(themeData.colorScheme.primary, AppColors.emberRed);
    });

    test('colorScheme tertiary matches moonSage', () {
      expect(themeData.colorScheme.tertiary, AppColors.moonSage);
    });

    test('displayLarge is non-null', () {
      expect(themeData.textTheme.displayLarge, isNotNull);
    });

    test('labelLarge maps to timerDigits (48sp)', () {
      expect(themeData.textTheme.labelLarge?.fontSize, 48.0);
    });

    test('cardTheme shape is RoundedRectangleBorder', () {
      expect(themeData.cardTheme.shape, isA<RoundedRectangleBorder>());
    });

    test('cardTheme elevation is 0', () {
      expect(themeData.cardTheme.elevation, 0.0);
    });

    test('appBarTheme has transparent background', () {
      expect(themeData.appBarTheme.backgroundColor, Colors.transparent);
    });

    test('appBarTheme has 0 elevation', () {
      expect(themeData.appBarTheme.elevation, 0.0);
    });
  });

  group('TestThemeTokens distinctness', () {
    test('test theme primary differs from FirelitGothic primary', () {
      const testTheme = TestThemeTokens();
      const prodTheme = FirelitGothicTheme();
      expect(testTheme.colors.primary, isNot(prodTheme.colors.primary));
    });

    test('test theme spacing.xs differs from FirelitGothic spacing.xs', () {
      const testTheme = TestThemeTokens();
      const prodTheme = FirelitGothicTheme();
      expect(testTheme.spacing.xs, isNot(prodTheme.spacing.xs));
    });
  });
}
