import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_decorations.dart';
import 'app_radius.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';
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

  @override
  AppRadiusTokens get radius => const MidnightVillageRadius();

  @override
  AppDecorationTokens get decorations => MidnightVillageDecorations();
}

class MidnightVillageColors implements AppColorTokens {
  const MidnightVillageColors();

  // Standard semantic colors
  @override
  Color get primary => AppColors.emberRed;

  @override
  Color get onPrimary => AppColors.parchment;

  @override
  Color get secondary => AppColors.tallowGold;

  @override
  Color get onSecondary => AppColors.voidBlack;

  @override
  Color get surface => AppColors.surface;

  @override
  Color get onSurface => AppColors.parchment;

  @override
  Color get background => AppColors.voidBlack;

  @override
  Color get onBackground => AppColors.parchment;

  @override
  Color get error => AppColors.danger;

  @override
  Color get onError => AppColors.parchment;

  @override
  Color get outline => AppColors.outline;

  @override
  Color get disabled => const Color(0xFF4A5568);

  @override
  Color get onDisabled => AppColors.parchmentMuted;

  // Game-specific semantic colors
  @override
  Color get werewolfTeam => AppColors.teamWerewolf;

  @override
  Color get villageTeam => AppColors.teamVillage;

  @override
  Color get independentTeam => AppColors.teamIndependent;

  @override
  Color get timerNormal => AppColors.parchment;

  @override
  Color get timerUrgent => AppColors.danger;

  @override
  Color get cardBack => AppColors.voidBlack;

  // Extended Firelit Gothic colors
  @override
  Color get tertiary => AppColors.moonSage;

  @override
  Color get nightBg => AppColors.nightBg;

  @override
  Color get lobbyBg => AppColors.lobbyBg;

  @override
  Color get discussionBg => AppColors.discussionBg;

  @override
  Color get votingBg => AppColors.votingBg;

  @override
  Color get resultsBg => AppColors.resultsBg;

  @override
  Color get surfaceDark => AppColors.surfaceDark;

  @override
  Color get danger => AppColors.danger;

  @override
  Color get warning => AppColors.warning;

  @override
  Color get noDeathBlue => AppColors.noDeathBlue;
}

class MidnightVillageTypography implements AppTypographyTokens {
  const MidnightVillageTypography();

  // Uses system default fonts — no bundled or network fonts required.
  // This theme is retained for use in tests where Google Fonts cannot load.
  @override
  TextStyle get displayHeading => const TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    height: 1.2,
  );

  @override
  TextStyle get heading => const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.25,
    height: 1.3,
  );

  @override
  TextStyle get subheading => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  @override
  TextStyle get body => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  @override
  TextStyle get caption => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.4,
  );

  @override
  TextStyle get label => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
  );

  // Extended Firelit Gothic typography
  @override
  TextStyle get timerDigits => const TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w600,
  );

  @override
  TextStyle get lobbyCode => const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    letterSpacing: 8.0,
  );

  @override
  TextStyle get phaseLabel => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.0,
  );

  @override
  TextStyle get serifAccent => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
  );
}

class MidnightVillageSpacing implements AppSpacingTokens {
  const MidnightVillageSpacing();

  @override
  double get xs => AppSpacing.xs;

  @override
  double get sm => AppSpacing.sm;

  @override
  double get md => AppSpacing.md;

  @override
  double get lg => AppSpacing.lg;

  @override
  double get xl => AppSpacing.xl;

  @override
  double get xxl => AppSpacing.xxl;

  @override
  double get xxxl => AppSpacing.xxxl;
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

class MidnightVillageRadius implements AppRadiusTokens {
  const MidnightVillageRadius();

  @override
  BorderRadius get small => AppRadius.small;

  @override
  BorderRadius get medium => AppRadius.medium;

  @override
  BorderRadius get large => AppRadius.large;

  @override
  BorderRadius get xl => AppRadius.xl;

  @override
  BorderRadius get full => AppRadius.full;
}

class MidnightVillageDecorations implements AppDecorationTokens {
  @override
  List<BoxShadow> get fireGlow => AppShadows.fireGlow;

  @override
  List<BoxShadow> get selectionGlow => AppShadows.selectionGlow;

  @override
  List<BoxShadow> get dangerGlow => AppShadows.dangerGlow;

  @override
  Gradient get visionGlow => AppDecorations.visionGlow;

  @override
  Gradient get bloodVignette => AppDecorations.bloodVignette;

  @override
  Gradient get candleGlow => AppDecorations.candleGlow;

  @override
  String get noiseOverlayAsset => AppDecorations.noiseOverlayAsset;
}
