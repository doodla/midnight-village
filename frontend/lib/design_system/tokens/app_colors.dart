// OLD LOOK: delete when the last old-look screen is rebuilt
@Deprecated(
  'OLD LOOK: delete when the last old-look screen is rebuilt. Build screens from lib/design_system/primitives/ instead.',
)
library;

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
  static const lobbyBg = Color(0xFF1A1410);
  static const discussionBg = Color(0xFF151210);
  static const votingBg = Color(0xFF12100E);
  static const resultsBg = Color(0xFF0F0D0B);

  // Semantic
  static const danger = Color(0xFFE05A3A); // timer danger pulse
  static const warning = Color(0xFFD47A3A); // timer warning
  static const noDeathBlue = Color(
    0xFF6B7B8B,
  ); // "No One Dies" — only cold color
}
