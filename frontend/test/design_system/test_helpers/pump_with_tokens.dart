import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:midnight_village/design_system/tokens/app_tokens.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import 'package:midnight_village/design_system/tokens/midnight_village_theme.dart';
import 'package:midnight_village/design_system/tokens/theme_bridge.dart';

extension PumpWithTokens on WidgetTester {
  /// Pump [widget] inside a themed [ProviderScope] + [MaterialApp].
  ///
  /// Set [goldenMode] to `true` to apply a fixed 390×844 logical screen size
  /// (iPhone 14 dimensions, 3× DPR) for deterministic golden test rendering.
  /// Use [screenSize] to override the default dimensions in golden mode.
  ///
  /// Existing callers that omit [goldenMode] are unaffected.
  Future<void> pumpWithTokens(
    Widget widget, {
    AppTokens? theme,
    bool goldenMode = false,
    Size? screenSize,
  }) async {
    if (goldenMode) {
      const double dpr = 3.0;
      final Size logical = screenSize ?? const Size(390.0, 844.0);
      view.physicalSize = Size(logical.width * dpr, logical.height * dpr);
      view.devicePixelRatio = dpr;
      addTearDown(() {
        view.resetPhysicalSize();
        view.resetDevicePixelRatio();
      });
    }

    final effectiveTheme = theme ?? const MidnightVillageTheme();
    await pumpWidget(
      ProviderScope(
        overrides: [
          activeThemeProvider.overrideWithValue(effectiveTheme),
        ],
        child: MaterialApp(
          theme: generateThemeData(effectiveTheme),
          home: widget,
        ),
      ),
    );
  }
}
