// Proves the gallery's detector: what goes wrong on a screen is reported, and
// a screen that cannot be built is a failure, not a picture. Runs with
// `just screens`, through the same capture path as the catalogue.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_gallery.dart';

Future<ScreenCapture> _capture(WidgetTester tester, Widget screen) =>
    captureScreen(
      tester,
      (tester) => tester.pumpWidget(MaterialApp(home: screen)),
      width: 390,
    );

void main() {
  testWidgets('a layout overflow is reported', (tester) async {
    final capture = await _capture(
      tester,
      const Row(children: [SizedBox(width: 500, height: 10)]),
    );

    expect(capture.failure, isNull);
    expect(capture.png, isNotNull);
    expect(capture.findings, [
      contains('A RenderFlex overflowed by 110 pixels on the right.'),
    ]);
  });

  testWidgets('an exception thrown while building a widget is reported', (
    tester,
  ) async {
    final capture = await _capture(
      tester,
      Builder(builder: (_) => throw StateError('the screen broke')),
    );

    expect(capture.failure, isNull);
    expect(capture.png, isNotNull);
    expect(capture.findings, [contains('Bad state: the screen broke')]);
  });

  testWidgets('a builder that throws gives a failure and no picture', (
    tester,
  ) async {
    final capture = await captureScreen(
      tester,
      (_) async => throw StateError('no such state'),
      width: 390,
    );

    expect(capture.png, isNull);
    expect(
      capture.failure,
      startsWith('BUILD FAILED: Bad state: no such state'),
    );
  });

  testWidgets('a clean screen has no findings', (tester) async {
    final capture = await _capture(tester, const Text('fine'));

    expect(capture.failure, isNull);
    expect(capture.png, isNotNull);
    expect(capture.findings, isEmpty);
  });
}
