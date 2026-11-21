import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ground.dart';

/// The phone's status and navigation bars over [ground]: no colour of their
/// own and no scrim (the screen runs edge to edge under them, its picture or
/// its ground showing through), their icons light over a dark ground and
/// dark over a light one. `ScreenFrame` and `SheetScaffold` declare it for
/// the ground they paint, so the bars follow the screen as it changes.
SystemUiOverlayStyle systemBarsOver(Ground ground) {
  final dark =
      ThemeData.estimateBrightnessForColor(ground.ground) == Brightness.dark;
  final icons = dark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
    statusBarIconBrightness: icons,
    systemNavigationBarIconBrightness: icons,
    // iOS names the bar by its background, not its icons.
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
  );
}
