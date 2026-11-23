import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/art_picture.dart';

import 'helpers/contract/contract_shape.dart';
import 'helpers/mock_http_client.dart';
import 'helpers/test_fonts.dart';

/// Global test configuration — loaded automatically by the Flutter test runner.
///
/// Responsibilities:
/// 1. Load the app's fonts so text and icons render as real glyphs.
/// 2. Check every body a test registers on [MockHttpClient] against what the
///    server sends (`contract_samples/`, see `helpers/contract/`).
/// 3. Fail a test that draws a picture that is missing or does not decode
///    (`ArtPicture.debugBeforeDraw`, `debugOnError`).
/// 4. Resolve golden paths against `test/design_system/`, so every golden
///    test shares one baseline set in `test/design_system/goldens/`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await loadAppFonts();

  MockHttpClient.responseCheck = checkHttpBody;

  // A role portrait (or any picture) that is not a file of the app fails every
  // test that draws it, the moment it is built; bytes that do not decode fail
  // it too. A test that feeds bad bytes on purpose clears `debugOnError`.
  ArtPicture.debugBeforeDraw = (image) {
    if (!File(image.path).existsSync()) {
      throw StateError('Picture is not a file in the app: ${image.path}');
    }
  };
  ArtPicture.debugOnError = (image, error) {
    throw StateError('Picture ${image.path} did not load: $error');
  };

  goldenFileComparator = LocalFileComparator(
    Uri.file('${Directory.current.path}/test/design_system/placeholder.dart'),
  );

  await testMain();
}
