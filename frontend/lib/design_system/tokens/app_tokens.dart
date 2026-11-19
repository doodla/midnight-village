// OLD LOOK: delete when the last old-look screen is rebuilt
import 'package:flutter/material.dart';

/// Root token contract. All themes implement this.
/// Missing tokens cause compile errors — theme completeness is enforced.
abstract class AppTokens {
  String get name;
  AppColorTokens get colors;
  AppTypographyTokens get typography;
  AppSpacingTokens get spacing;
  AppElevationTokens get elevation;
  AppRadiusTokens get radius;
  AppDecorationTokens get decorations;
}

/// Semantic color contract: standard UI colors + game-specific team colors.
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

  // Extended Firelit Gothic colors
  Color get tertiary; // Moonlit Sage
  Color get nightBg; // Phase backgrounds
  Color get lobbyBg;
  Color get discussionBg;
  Color get votingBg;
  Color get resultsBg;
  Color get surfaceDark; // Additional surface variant
  Color get danger; // Timer danger pulse
  Color get warning; // Timer warning state
  Color get noDeathBlue; // "No One Dies" accent
}

/// Typography scale: serif headings for atmosphere, sans-serif body for readability.
abstract class AppTypographyTokens {
  TextStyle get displayHeading;
  TextStyle get heading;
  TextStyle get subheading;
  TextStyle get body;
  TextStyle get caption;
  TextStyle get label;

  // Extended Firelit Gothic typography
  TextStyle get timerDigits; // 48sp, Space Grotesk w600
  TextStyle get lobbyCode; // 28sp, Space Grotesk w500, letter-spaced
  TextStyle get phaseLabel; // 12sp, Space Grotesk w500
  TextStyle get serifAccent; // 16sp, Libre Baskerville italic
}

/// Spacing scale in density-independent pixels (7-step).
abstract class AppSpacingTokens {
  double get xs; // 4.0
  double get sm; // 8.0
  double get md; // 12.0
  double get lg; // 16.0
  double get xl; // 24.0
  double get xxl; // 32.0
  double get xxxl; // 48.0
}

/// Elevation levels for shadows/depth.
abstract class AppElevationTokens {
  double get flat;
  double get raised;
  double get floating;
  double get overlay;
}

/// Border radius scale.
abstract class AppRadiusTokens {
  BorderRadius get small; // 4dp
  BorderRadius get medium; // 8dp
  BorderRadius get large; // 12dp
  BorderRadius get xl; // 16dp
  BorderRadius get full; // 999dp (pill)
}

/// Decorative effects: glows, gradients, and texture overlays.
abstract class AppDecorationTokens {
  List<BoxShadow> get fireGlow;
  List<BoxShadow> get selectionGlow;
  List<BoxShadow> get dangerGlow;
  Gradient get visionGlow;
  Gradient get bloodVignette;
  Gradient get candleGlow;
  String get noiseOverlayAsset;
}
