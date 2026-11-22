// Proves the gallery's detector: what goes wrong on a screen is reported, and
// a screen that cannot be built is a failure, not a picture. Runs with
// `just screens`, through the same capture path as the catalogue.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reading_floor.dart';
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

  group('on a player screen, the reading floor', () {
    testWidgets('is checked by the capture: text under 12 is a finding', (
      tester,
    ) async {
      final capture = await captureScreen(
        tester,
        (tester) => tester.pumpWidget(
          const MaterialApp(home: Text('tiny', style: TextStyle(fontSize: 11))),
        ),
        width: 390,
        playerScreen: true,
      );
      expect(capture.findings, [contains('"tiny" is drawn at 11.0 px')]);
    });

    testWidgets('a screen that is not a player screen is not checked', (
      tester,
    ) async {
      final capture = await _capture(
        tester,
        const Text('tiny', style: TextStyle(fontSize: 11)),
      );
      expect(capture.findings, isEmpty);
    });

    Future<List<String>> breaches(WidgetTester tester, Widget screen) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: screen)),
        ),
      );
      return readingFloorBreaches(tester);
    }

    testWidgets('a 14 role set smaller to fit is a breach; a 12 label is '
        'not', (tester) async {
      expect(
        await breaches(
          tester,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Set at 0.85: 15 drawn at 12.75, between the two floors.
              Transform.scale(
                scale: 0.85,
                child: const Text(
                  'Troublemaker',
                  style: TextStyle(fontSize: 15),
                ),
              ),
              const Text('Left', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        [allOf(contains('"Troublemaker"'), contains('14.0 px reading floor'))],
      );
    });

    testWidgets('uppercase tracked micro-labels are a breach', (tester) async {
      expect(
        await breaches(
          tester,
          const Text(
            'LEFT TO TALK',
            style: TextStyle(fontSize: 16, letterSpacing: 2),
          ),
        ),
        [contains('micro-label')],
      );
    });
  });

  testWidgets('text drawn cut short is reported, on any screen', (
    tester,
  ) async {
    final capture = await _capture(
      tester,
      const SizedBox(
        width: 60,
        child: Text(
          'Maximiliano',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
    expect(capture.findings, [
      allOf(contains('cut short'), contains('"Maximiliano"')),
    ]);
  });

  testWidgets('a clean screen has no findings', (tester) async {
    final capture = await _capture(tester, const Text('fine'));

    expect(capture.failure, isNull);
    expect(capture.png, isNotNull);
    expect(capture.findings, isEmpty);
  });
}
