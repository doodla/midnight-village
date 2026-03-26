import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/golden_test_helper.dart';

/// Global test configuration — loaded automatically by the Flutter test runner.
///
/// Responsibilities:
/// 1. Load bundled font families so golden tests render text deterministically.
/// 2. Register the [PlatformGoldenFileComparator] so golden baselines are
///    routed to platform-specific directories (macos/, linux/).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Load PlayfairDisplay (headings) — regular and italic variants.
  final playfairLoader = FontLoader('PlayfairDisplay')
    ..addFont(
      rootBundle.load('assets/fonts/playfair-display/PlayfairDisplay.ttf'),
    )
    ..addFont(
      rootBundle.load(
        'assets/fonts/playfair-display/PlayfairDisplay-Italic.ttf',
      ),
    );
  await playfairLoader.load();

  // Load Inter (body) — regular and italic variants.
  final interLoader = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/inter/Inter.ttf'))
    ..addFont(rootBundle.load('assets/fonts/inter/Inter-Italic.ttf'));
  await interLoader.load();

  // Register platform-aware golden comparator.
  // Basedir: test/design_system/ — golden paths are relative to this.
  goldenFileComparator = PlatformGoldenFileComparator(
    Uri.file('${Directory.current.path}/test/design_system/placeholder.dart'),
  );

  await testMain();
}
