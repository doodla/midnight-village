import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:midnight_village/design_system/tokens/app_tokens.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import 'package:midnight_village/design_system/tokens/midnight_village_theme.dart';
import 'package:midnight_village/design_system/tokens/theme_bridge.dart';

/// Renders [widget] at a fixed iPhone 14 screen size (390×844 logical pixels,
/// 3× device pixel ratio) with the app's deterministic theme, then compares
/// the result against a golden baseline.
///
/// [goldenName] is a path relative to `test/design_system/` (the comparator's
/// base, set in `flutter_test_config.dart`), e.g. `'goldens/button_default.png'`.
/// There is one set of baselines, made on Linux; see `dart_test.yaml`.
///
/// Usage:
/// ```dart
/// testWidgets('button renders correctly', (tester) async {
///   await tester.pumpWithGolden(MyButton(), 'goldens/my_button.png');
/// }, tags: ['golden']);
/// ```
extension GoldenTestExtension on WidgetTester {
  Future<void> pumpWithGolden(
    Widget widget,
    String goldenName, {
    AppTokens? theme,
  }) async {
    // iPhone 14 logical size at 3× DPR.
    const double logicalWidth = 390.0;
    const double logicalHeight = 844.0;
    const double dpr = 3.0;

    view.physicalSize = const Size(logicalWidth * dpr, logicalHeight * dpr);
    view.devicePixelRatio = dpr;

    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    final effectiveTheme = theme ?? const MidnightVillageTheme();
    await pumpWidget(
      ProviderScope(
        overrides: [activeThemeProvider.overrideWithValue(effectiveTheme)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: generateThemeData(effectiveTheme),
          home: widget,
        ),
      ),
    );
    await pumpAndSettle();

    await expectLater(find.byType(MaterialApp), matchesGoldenFile(goldenName));
  }
}
