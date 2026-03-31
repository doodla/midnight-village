import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/tokens/app_colors.dart';
import 'package:midnight_village/design_system/tokens/app_typography.dart';

// NOTE: This test uses runZonedGuarded around the AppTypography calls to
// prevent google_fonts' async CDN-fetch failures from propagating into the test
// zone. The font bytes can't load in an offline test environment but the
// TextStyle properties (fontSize, fontWeight, color, letterSpacing) are set
// synchronously before any loading attempt and are what we actually verify.
// Font-family assertions are omitted because accessing GoogleFonts.xxx() in
// the test itself would trigger the same zone errors.

TextTheme _buildTextTheme() {
  late TextTheme result;
  runZonedGuarded(() => result = AppTypography.textTheme, (error, stack) {
    // Suppress google_fonts asset/CDN loading errors — they happen async
    // after the TextStyle is already returned with correct properties.
  });
  return result;
}

TextStyle _buildDisplaySerif() {
  late TextStyle result;
  runZonedGuarded(() => result = AppTypography.displaySerif, (error, stack) {});
  return result;
}

void main() {
  group('AppTypography', () {
    late TextTheme textTheme;
    late TextStyle displaySerif;

    setUp(() {
      textTheme = _buildTextTheme();
      displaySerif = _buildDisplaySerif();
    });

    group('displayLarge (Epilogue 32/w700)', () {
      test('has fontSize 32', () {
        expect(textTheme.displayLarge!.fontSize, 32);
      });

      test('has fontWeight w700', () {
        expect(textTheme.displayLarge!.fontWeight, FontWeight.w700);
      });

      test('has color parchment', () {
        expect(textTheme.displayLarge!.color, AppColors.parchment);
      });

      test('has letterSpacing 1.5', () {
        expect(textTheme.displayLarge!.letterSpacing, 1.5);
      });
    });

    group('headlineLarge (Epilogue 24/w600)', () {
      test('has fontSize 24', () {
        expect(textTheme.headlineLarge!.fontSize, 24);
      });

      test('has fontWeight w600', () {
        expect(textTheme.headlineLarge!.fontWeight, FontWeight.w600);
      });

      test('has color parchment', () {
        expect(textTheme.headlineLarge!.color, AppColors.parchment);
      });
    });

    group('headlineMedium (Epilogue 20/w500)', () {
      test('has fontSize 20', () {
        expect(textTheme.headlineMedium!.fontSize, 20);
      });

      test('has fontWeight w500', () {
        expect(textTheme.headlineMedium!.fontWeight, FontWeight.w500);
      });

      test('has color parchment', () {
        expect(textTheme.headlineMedium!.color, AppColors.parchment);
      });
    });

    group('headlineSmall (Epilogue 16/w500)', () {
      test('has fontSize 16', () {
        expect(textTheme.headlineSmall!.fontSize, 16);
      });

      test('has fontWeight w500', () {
        expect(textTheme.headlineSmall!.fontWeight, FontWeight.w500);
      });

      test('has color parchment', () {
        expect(textTheme.headlineSmall!.color, AppColors.parchment);
      });
    });

    group('bodyLarge (DM Sans 16/w400)', () {
      test('has fontSize 16', () {
        expect(textTheme.bodyLarge!.fontSize, 16);
      });

      test('has fontWeight w400', () {
        expect(textTheme.bodyLarge!.fontWeight, FontWeight.w400);
      });

      test('has color parchment', () {
        expect(textTheme.bodyLarge!.color, AppColors.parchment);
      });
    });

    group('bodyMedium (DM Sans 14/w400)', () {
      test('has fontSize 14', () {
        expect(textTheme.bodyMedium!.fontSize, 14);
      });

      test('has fontWeight w400', () {
        expect(textTheme.bodyMedium!.fontWeight, FontWeight.w400);
      });

      test('has color parchment', () {
        expect(textTheme.bodyMedium!.color, AppColors.parchment);
      });
    });

    group('bodySmall (DM Sans 12/w400)', () {
      test('has fontSize 12', () {
        expect(textTheme.bodySmall!.fontSize, 12);
      });

      test('has fontWeight w400', () {
        expect(textTheme.bodySmall!.fontWeight, FontWeight.w400);
      });

      test('has color parchmentMuted', () {
        expect(textTheme.bodySmall!.color, AppColors.parchmentMuted);
      });
    });

    group('labelLarge (Space Grotesk 48/w600 — timer digits)', () {
      test('has fontSize 48', () {
        expect(textTheme.labelLarge!.fontSize, 48);
      });

      test('has fontWeight w600', () {
        expect(textTheme.labelLarge!.fontWeight, FontWeight.w600);
      });

      test('has color tallowGold', () {
        expect(textTheme.labelLarge!.color, AppColors.tallowGold);
      });
    });

    group('labelMedium (Space Grotesk 28/w500 — lobby codes)', () {
      test('has fontSize 28', () {
        expect(textTheme.labelMedium!.fontSize, 28);
      });

      test('has fontWeight w500', () {
        expect(textTheme.labelMedium!.fontWeight, FontWeight.w500);
      });

      test('has color tallowGold', () {
        expect(textTheme.labelMedium!.color, AppColors.tallowGold);
      });

      test('has letterSpacing 8.0', () {
        expect(textTheme.labelMedium!.letterSpacing, 8.0);
      });
    });

    group('labelSmall (Space Grotesk 12/w500 — phase labels)', () {
      test('has fontSize 12', () {
        expect(textTheme.labelSmall!.fontSize, 12);
      });

      test('has fontWeight w500', () {
        expect(textTheme.labelSmall!.fontWeight, FontWeight.w500);
      });

      test('has color parchmentMuted', () {
        expect(textTheme.labelSmall!.color, AppColors.parchmentMuted);
      });

      test('has letterSpacing 2.0', () {
        expect(textTheme.labelSmall!.letterSpacing, 2.0);
      });
    });

    group('displaySerif (Libre Baskerville 16/w400 italic)', () {
      test('has fontSize 16', () {
        expect(displaySerif.fontSize, 16);
      });

      test('has fontWeight w400', () {
        expect(displaySerif.fontWeight, FontWeight.w400);
      });

      test('has italic style', () {
        expect(displaySerif.fontStyle, FontStyle.italic);
      });

      test('has color parchmentMuted', () {
        expect(displaySerif.color, AppColors.parchmentMuted);
      });
    });
  });
}
