import 'package:flutter/material.dart';

import 'package:midnight_village/design_system/tokens/app_tokens.dart';

/// Test theme with visually distinct values from Midnight Village.
/// Used to verify components actually consume tokens rather than hardcoding.
class TestThemeTokens implements AppTokens {
  const TestThemeTokens();

  @override
  String get name => 'Test Theme';

  @override
  AppColorTokens get colors => const TestColorTokens();

  @override
  AppTypographyTokens get typography => const TestTypographyTokens();

  @override
  AppSpacingTokens get spacing => const TestSpacingTokens();

  @override
  AppElevationTokens get elevation => const TestElevationTokens();
}

class TestColorTokens implements AppColorTokens {
  const TestColorTokens();

  @override
  Color get primary => const Color(0xFF00FF00); // bright green

  @override
  Color get onPrimary => const Color(0xFF000000);

  @override
  Color get secondary => const Color(0xFFFF00FF); // magenta

  @override
  Color get onSecondary => const Color(0xFF000000);

  @override
  Color get surface => const Color(0xFF333333);

  @override
  Color get onSurface => const Color(0xFFFFFFFF);

  @override
  Color get background => const Color(0xFF111111);

  @override
  Color get onBackground => const Color(0xFFFFFFFF);

  @override
  Color get error => const Color(0xFFFF0000); // pure red

  @override
  Color get onError => const Color(0xFFFFFFFF);

  @override
  Color get outline => const Color(0xFF888888);

  @override
  Color get disabled => const Color(0xFF666666);

  @override
  Color get onDisabled => const Color(0xFF999999);

  @override
  Color get werewolfTeam => const Color(0xFFFF4444);

  @override
  Color get villageTeam => const Color(0xFF4444FF);

  @override
  Color get independentTeam => const Color(0xFFFFFF00); // yellow

  @override
  Color get timerNormal => const Color(0xFFCCCCCC);

  @override
  Color get timerUrgent => const Color(0xFFFF8800);

  @override
  Color get cardBack => const Color(0xFF222222);
}

class TestTypographyTokens implements AppTypographyTokens {
  const TestTypographyTokens();

  @override
  TextStyle get displayHeading =>
      const TextStyle(fontSize: 40, fontWeight: FontWeight.w700);

  @override
  TextStyle get heading =>
      const TextStyle(fontSize: 28, fontWeight: FontWeight.w600);

  @override
  TextStyle get subheading =>
      const TextStyle(fontSize: 22, fontWeight: FontWeight.w500);

  @override
  TextStyle get body =>
      const TextStyle(fontSize: 18, fontWeight: FontWeight.w400);

  @override
  TextStyle get caption =>
      const TextStyle(fontSize: 14, fontWeight: FontWeight.w400);

  @override
  TextStyle get label =>
      const TextStyle(fontSize: 16, fontWeight: FontWeight.w500);
}

class TestSpacingTokens implements AppSpacingTokens {
  const TestSpacingTokens();

  @override
  double get xs => 8.0;

  @override
  double get s => 16.0;

  @override
  double get m => 32.0;

  @override
  double get l => 48.0;

  @override
  double get xl => 64.0;

  @override
  double get xxl => 96.0;
}

class TestElevationTokens implements AppElevationTokens {
  const TestElevationTokens();

  @override
  double get flat => 0.0;

  @override
  double get raised => 4.0;

  @override
  double get floating => 12.0;

  @override
  double get overlay => 24.0;
}
