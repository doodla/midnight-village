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

  @override
  AppRadiusTokens get radius => const TestRadiusTokens();

  @override
  AppDecorationTokens get decorations => TestDecorationTokens();
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

  // Extended Firelit Gothic colors
  @override
  Color get tertiary => const Color(0xFF00FFFF);

  @override
  Color get nightBg => const Color(0xFF000011);

  @override
  Color get lobbyBg => const Color(0xFF000022);

  @override
  Color get discussionBg => const Color(0xFF000033);

  @override
  Color get votingBg => const Color(0xFF000044);

  @override
  Color get resultsBg => const Color(0xFF000055);

  @override
  Color get surfaceDark => const Color(0xFF111111);

  @override
  Color get danger => const Color(0xFFFF0000);

  @override
  Color get warning => const Color(0xFFFF8800);

  @override
  Color get noDeathBlue => const Color(0xFF0000FF);
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

  // Extended Firelit Gothic typography
  @override
  TextStyle get timerDigits =>
      const TextStyle(fontSize: 60, fontWeight: FontWeight.w700);

  @override
  TextStyle get lobbyCode =>
      const TextStyle(fontSize: 36, fontWeight: FontWeight.w500);

  @override
  TextStyle get phaseLabel =>
      const TextStyle(fontSize: 10, fontWeight: FontWeight.w500);

  @override
  TextStyle get serifAccent =>
      const TextStyle(fontSize: 14, fontStyle: FontStyle.italic);
}

class TestSpacingTokens implements AppSpacingTokens {
  const TestSpacingTokens();

  @override
  double get xs => 8.0;

  @override
  double get sm => 16.0;

  @override
  double get md => 32.0;

  @override
  double get lg => 48.0;

  @override
  double get xl => 64.0;

  @override
  double get xxl => 96.0;

  @override
  double get xxxl => 128.0;
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

class TestRadiusTokens implements AppRadiusTokens {
  const TestRadiusTokens();

  @override
  BorderRadius get small => const BorderRadius.all(Radius.circular(2));

  @override
  BorderRadius get medium => const BorderRadius.all(Radius.circular(4));

  @override
  BorderRadius get large => const BorderRadius.all(Radius.circular(6));

  @override
  BorderRadius get xl => const BorderRadius.all(Radius.circular(8));

  @override
  BorderRadius get full => const BorderRadius.all(Radius.circular(500));
}

class TestDecorationTokens implements AppDecorationTokens {
  @override
  List<BoxShadow> get fireGlow => const [
    BoxShadow(color: Color(0x1100FF00), blurRadius: 10),
  ];

  @override
  List<BoxShadow> get selectionGlow => const [
    BoxShadow(color: Color(0x11FF00FF), blurRadius: 8),
  ];

  @override
  List<BoxShadow> get dangerGlow => const [
    BoxShadow(color: Color(0x11FF0000), blurRadius: 8),
  ];

  @override
  Gradient get visionGlow => const LinearGradient(
    colors: [Color(0x1100FF00), Colors.transparent],
  );

  @override
  Gradient get bloodVignette => const LinearGradient(
    colors: [Colors.transparent, Color(0x11FF0000)],
  );

  @override
  Gradient get candleGlow => const LinearGradient(
    colors: [Colors.transparent, Color(0xFF111111)],
  );

  @override
  String get noiseOverlayAsset => 'assets/textures/noise_grain.png';
}
