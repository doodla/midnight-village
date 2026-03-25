import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:midnight_village/design_system/tokens/app_tokens.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import 'package:midnight_village/design_system/tokens/midnight_village_theme.dart';
import 'package:midnight_village/design_system/tokens/theme_bridge.dart';

extension PumpWithTokens on WidgetTester {
  Future<void> pumpWithTokens(
    Widget widget, {
    AppTokens? theme,
  }) async {
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
