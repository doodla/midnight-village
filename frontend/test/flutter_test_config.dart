import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'helpers/contract/contract_shape.dart';
import 'helpers/mock_http_client.dart';
import 'helpers/test_fonts.dart';

/// Global test configuration — loaded automatically by the Flutter test runner.
///
/// Responsibilities:
/// 1. Load the app's fonts so text and icons render as real glyphs.
/// 2. Check every body a test registers on [MockHttpClient] against what the
///    server sends (`contract_samples/`, see `helpers/contract/`).
/// 3. Resolve golden paths against `test/design_system/`, so every golden
///    test shares one baseline set in `test/design_system/goldens/`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadAppFonts();

  MockHttpClient.responseCheck = checkHttpBody;

  goldenFileComparator = LocalFileComparator(
    Uri.file('${Directory.current.path}/test/design_system/placeholder.dart'),
  );

  await testMain();
}
