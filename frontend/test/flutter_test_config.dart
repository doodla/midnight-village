import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'helpers/test_fonts.dart';

/// Global test configuration — loaded automatically by the Flutter test runner.
///
/// Responsibilities:
/// 1. Disable Google Fonts HTTP fetching so tests work offline and in CI.
/// 2. Load the app's fonts so text and icons render as real glyphs.
/// 3. Resolve golden paths against `test/design_system/`, so every golden
///    test shares one baseline set in `test/design_system/goldens/`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Prevent Google Fonts from attempting HTTP requests to Google's font CDN.
  // Without this, tests fail in CI and become flaky in offline environments.
  GoogleFonts.config.allowRuntimeFetching = false;

  TestWidgetsFlutterBinding.ensureInitialized();
  await loadAppFonts();

  goldenFileComparator = LocalFileComparator(
    Uri.file('${Directory.current.path}/test/design_system/placeholder.dart'),
  );

  await testMain();
}
