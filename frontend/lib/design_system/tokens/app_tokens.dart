import 'package:flutter/material.dart';

/// Root token contract. All themes implement this.
/// Missing tokens cause compile errors — theme completeness is enforced.
abstract class AppTokens {
  String get name;
  AppColorTokens get colors;
  AppTypographyTokens get typography;
  AppSpacingTokens get spacing;
  AppElevationTokens get elevation;
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
}

/// Typography scale: serif headings for atmosphere, sans-serif body for readability.
abstract class AppTypographyTokens {
  TextStyle get displayHeading;
  TextStyle get heading;
  TextStyle get subheading;
  TextStyle get body;
  TextStyle get caption;
  TextStyle get label;
}

/// Spacing scale in density-independent pixels.
abstract class AppSpacingTokens {
  double get xs;
  double get s;
  double get m;
  double get l;
  double get xl;
  double get xxl;
}

/// Elevation levels for shadows/depth.
abstract class AppElevationTokens {
  double get flat;
  double get raised;
  double get floating;
  double get overlay;
}
