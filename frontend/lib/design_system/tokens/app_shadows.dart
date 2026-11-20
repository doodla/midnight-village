// OLD LOOK: delete when the last old-look screen is rebuilt
@Deprecated(
  'OLD LOOK: delete when the last old-look screen is rebuilt. Build screens from lib/design_system/primitives/ instead.',
)
library;

import 'package:flutter/material.dart';

abstract final class AppShadows {
  static const fireGlow = [
    BoxShadow(
      color: Color(0x26B8432F), // emberRed at 15%
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  static const selectionGlow = [
    BoxShadow(
      color: Color(0x40C8A24D), // tallowGold at 25%
      blurRadius: 12,
      spreadRadius: 1,
    ),
  ];

  static const dangerGlow = [
    BoxShadow(
      color: Color(0x40C94038), // teamWerewolf at 25%
      blurRadius: 12,
      spreadRadius: 1,
    ),
  ];
}
