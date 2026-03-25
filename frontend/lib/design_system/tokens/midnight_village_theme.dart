import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Default "Midnight Village" theme — warm firelight ambers/oranges,
/// deep blues/indigos, muted earth tones, atmospheric serif headings.
class MidnightVillageTheme implements AppTokens {
  const MidnightVillageTheme();

  @override
  String get name => 'Midnight Village';

  @override
  AppColorTokens get colors => const MidnightVillageColors();

  @override
  AppTypographyTokens get typography => const MidnightVillageTypography();

  @override
  AppSpacingTokens get spacing => const MidnightVillageSpacing();

  @override
  AppElevationTokens get elevation => const MidnightVillageElevation();
}

class MidnightVillageColors implements AppColorTokens {
  const MidnightVillageColors();

  // Standard semantic colors
  @override
  Color get primary => const Color(0xFFE8A849); // firelight gold

  @override
  Color get onPrimary => const Color(0xFF1A1207); // dark brown on amber

  @override
  Color get secondary => const Color(0xFF8B9D83); // muted sage

  @override
  Color get onSecondary => const Color(0xFFF0EDE6); // light cream on sage

  @override
  Color get surface => const Color(0xFF1E2A3A); // dark blue-grey card

  @override
  Color get onSurface => const Color(0xFFE8E4DD); // light cream text

  @override
  Color get background => const Color(0xFF0F1923); // deep night sky

  @override
  Color get onBackground => const Color(0xFFE8E4DD); // light cream text

  @override
  Color get error => const Color(0xFFCF6679); // muted rose red

  @override
  Color get onError => const Color(0xFF1A0A0E); // dark on error

  @override
  Color get outline => const Color(0xFF374A5E); // subtle blue-grey border

  @override
  Color get disabled => const Color(0xFF4A5568); // grey

  @override
  Color get onDisabled => const Color(0xFF8A95A5); // muted text on disabled

  // Game-specific semantic colors
  @override
  Color get werewolfTeam => const Color(0xFFB33A3A); // deep crimson

  @override
  Color get villageTeam => const Color(0xFF4A90D9); // soft blue

  @override
  Color get independentTeam => const Color(0xFFC4A35A); // muted gold

  @override
  Color get timerNormal => const Color(0xFFB8C8DB); // calm blue-white

  @override
  Color get timerUrgent => const Color(0xFFE85A3A); // warning red-orange

  @override
  Color get cardBack => const Color(0xFF0A1320); // darker navy
}

class MidnightVillageTypography implements AppTypographyTokens {
  const MidnightVillageTypography();

  @override
  TextStyle get displayHeading => const TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    height: 1.2,
  );

  @override
  TextStyle get heading => const TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.25,
    height: 1.3,
  );

  @override
  TextStyle get subheading => const TextStyle(
    fontFamily: 'PlayfairDisplay',
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  @override
  TextStyle get body => const TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  @override
  TextStyle get caption => const TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.4,
  );

  @override
  TextStyle get label => const TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
  );
}

class MidnightVillageSpacing implements AppSpacingTokens {
  const MidnightVillageSpacing();

  @override
  double get xs => 4.0;

  @override
  double get s => 8.0;

  @override
  double get m => 16.0;

  @override
  double get l => 24.0;

  @override
  double get xl => 32.0;

  @override
  double get xxl => 48.0;
}

class MidnightVillageElevation implements AppElevationTokens {
  const MidnightVillageElevation();

  @override
  double get flat => 0.0;

  @override
  double get raised => 2.0;

  @override
  double get floating => 6.0;

  @override
  double get overlay => 12.0;
}
