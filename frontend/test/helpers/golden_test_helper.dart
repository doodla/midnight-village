import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:midnight_village/design_system/tokens/app_tokens.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import 'package:midnight_village/design_system/tokens/midnight_village_theme.dart';
import 'package:midnight_village/design_system/tokens/theme_bridge.dart';

/// Routes golden baseline files to a platform-specific subdirectory so macOS
/// developer baselines don't overwrite Linux CI baselines (and vice versa).
///
/// Baselines live at `test/design_system/goldens/<platform>/<name>.png`.
/// Tests pass a path relative to `test/design_system/`, e.g.:
///   `'goldens/button_default.png'`
/// which is transparently rewritten to:
///   `'goldens/macos/button_default.png'`  (on macOS)
///   `'goldens/linux/button_default.png'`  (on Linux)
class PlatformGoldenFileComparator extends LocalFileComparator {
  PlatformGoldenFileComparator(super.testFile);

  @override
  Uri getTestUri(Uri key, int? version) {
    final Uri versioned = super.getTestUri(key, version);
    final String platform = Platform.operatingSystem; // 'macos', 'linux', …

    // Insert the platform directory before the filename.
    // e.g., 'goldens/button.png' → 'goldens/macos/button.png'
    final String path = versioned.path;
    final int lastSlash = path.lastIndexOf('/');
    final String dir =
        lastSlash >= 0 ? path.substring(0, lastSlash + 1) : '';
    final String filename =
        lastSlash >= 0 ? path.substring(lastSlash + 1) : path;

    return versioned.replace(path: '$dir$platform/$filename');
  }
}

/// Renders [widget] at a fixed iPhone 14 screen size (390×844 logical pixels,
/// 3× device pixel ratio) with the app's deterministic theme, then compares
/// the result against a golden baseline.
///
/// [goldenName] is a path relative to `test/design_system/`,
/// e.g. `'goldens/button_default.png'`.
///
/// The platform-specific comparator (registered in `flutter_test_config.dart`)
/// routes [goldenName] to the correct `macos/` or `linux/` subdirectory.
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

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(goldenName),
    );
  }
}
