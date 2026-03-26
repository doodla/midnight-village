import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'helpers/golden_test_helper.dart';

/// Global test configuration — loaded automatically by the Flutter test runner.
///
/// Responsibilities:
/// 1. Disable Google Fonts HTTP fetching so tests work offline and in CI.
/// 2. Register the [PlatformGoldenFileComparator] so golden baselines are
///    routed to platform-specific directories (macos/, linux/).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Prevent Google Fonts from attempting HTTP requests to Google's font CDN.
  // Without this, tests fail in CI and become flaky in offline environments.
  GoogleFonts.config.allowRuntimeFetching = false;

  TestWidgetsFlutterBinding.ensureInitialized();

  // Register platform-aware golden comparator.
  // Basedir: test/design_system/ — golden paths are relative to this.
  goldenFileComparator = PlatformGoldenFileComparator(
    Uri.file('${Directory.current.path}/test/design_system/placeholder.dart'),
  );

  await testMain();
}
