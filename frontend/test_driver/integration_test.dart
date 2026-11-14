import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver for `flutter drive` integration tests.
///
/// The tests call `binding.takeScreenshot` after each test. On the web that
/// call waits for the driver to collect the image, so the driver must handle
/// it: the plain `integrationDriver` does not, and the run then waits forever.
Future<void> main() => integrationDriver(
  onScreenshot:
      (String name, List<int> bytes, [Map<String, Object?>? args]) async {
        final file = File('integration_test/screenshots/$name.png');
        await file.create(recursive: true);
        await file.writeAsBytes(bytes);
        return true;
      },
);
