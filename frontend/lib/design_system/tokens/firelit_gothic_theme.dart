// OLD LOOK: delete when the last old-look screen is rebuilt
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_decorations.dart';
import 'app_radius.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';
import 'app_tokens.dart';

/// Firelit Gothic theme — ember reds, tallow golds, moonlit sage,
/// gothic serif display with Space Grotesk labels for game UI.
class FirelitGothicTheme implements AppTokens {
  const FirelitGothicTheme();

  @override
  String get name => 'Firelit Gothic';

  @override
  AppColorTokens get colors => const FirelitGothicColors();

  @override
  AppTypographyTokens get typography => const FirelitGothicTypography();

  @override
  AppSpacingTokens get spacing => const FirelitGothicSpacing();

  @override
  AppElevationTokens get elevation => const FirelitGothicElevation();

  @override
  AppRadiusTokens get radius => const FirelitGothicRadius();

  @override
  AppDecorationTokens get decorations => const FirelitGothicDecorations();
}

class FirelitGothicColors implements AppColorTokens {
  const FirelitGothicColors();

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
  Color get disabled => const Color(0xFF4A4642);

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

class FirelitGothicTypography implements AppTypographyTokens {
  const FirelitGothicTypography();

  @override
  TextStyle get displayHeading => GoogleFonts.epilogue(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.parchment,
    letterSpacing: 1.5,
  );

  @override
  TextStyle get heading => GoogleFonts.epilogue(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.parchment,
  );

  @override
  TextStyle get subheading => GoogleFonts.epilogue(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: AppColors.parchment,
  );

  @override
  TextStyle get body => GoogleFonts.dmSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.parchment,
  );

  @override
  TextStyle get caption => GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.parchmentMuted,
  );

  @override
  TextStyle get label => GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.parchment,
  );

  @override
  TextStyle get timerDigits => GoogleFonts.spaceGrotesk(
    fontSize: 48,
    fontWeight: FontWeight.w600,
    color: AppColors.tallowGold,
  );

  @override
  TextStyle get lobbyCode => GoogleFonts.spaceGrotesk(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    color: AppColors.tallowGold,
    letterSpacing: 8.0,
  );

  @override
  TextStyle get phaseLabel => GoogleFonts.spaceGrotesk(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.parchmentMuted,
    letterSpacing: 2.0,
  );

  @override
  TextStyle get serifAccent => GoogleFonts.libreBaskerville(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
    color: AppColors.parchmentMuted,
  );
}

class FirelitGothicSpacing implements AppSpacingTokens {
  const FirelitGothicSpacing();

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

class FirelitGothicElevation implements AppElevationTokens {
  const FirelitGothicElevation();

  @override
  double get flat => 0.0;

  @override
  double get raised => 2.0;

  @override
  double get floating => 6.0;

  @override
  double get overlay => 12.0;
}

class FirelitGothicRadius implements AppRadiusTokens {
  const FirelitGothicRadius();

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

class FirelitGothicDecorations implements AppDecorationTokens {
  const FirelitGothicDecorations();

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
