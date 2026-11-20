// The screen gallery: renders every entry of the screen catalogue from the
// real widgets to PNG, next to its mock. Run it with `just screens` (see
// frontend/CLAUDE.md); it is not part of `just test`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'screen_catalogue.dart';
import 'screen_gallery.dart';

/// `--dart-define=SCREENS_WIDTH=360` renders at another phone width.
const _width = int.fromEnvironment('SCREENS_WIDTH', defaultValue: 390);

/// `--dart-define=SCREENS_STRICT=true` fails each screen with findings.
const _strict = bool.fromEnvironment('SCREENS_STRICT');

void main() {
  final results = <String, ScreenResult>{};

  setUpAll(() => clearOutput(_width));
  tearDownAll(() {
    final summary = summarize(results, width: _width, strict: _strict);
    File('${outputDir(_width)}/summary.txt')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('$summary\n');
    // ignore: avoid_print
    print('\n$summary');
  });

  for (final entry in screenCatalogue.where((e) => e.build != null)) {
    testWidgets(entry.id, (tester) async {
      final capture = await captureScreen(
        tester,
        entry.build!,
        width: _width,
        playerScreen: entry.playerScreen,
      );
      results[entry.id] = saveScreen(entry, capture, width: _width);
      // A screen that cannot be built always fails the run.
      if (capture.failure case final failure?) fail(failure);
      if (_strict) expect(capture.findings, isEmpty, reason: entry.id);
    });
  }
}
