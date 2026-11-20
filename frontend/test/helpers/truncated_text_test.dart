import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/fit_line.dart';

import 'truncated_text.dart';

// Proves the detector the fit sweep and the screen gallery use: text drawn
// cut short is found, however it is cut; text that fits, wraps or is set
// smaller is not.

Future<List<String>> _cut(WidgetTester tester, Widget text) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 60, child: text)),
      ),
    ),
  );
  return truncatedText(tester);
}

const _long = 'Christopher Maximiliano';

void main() {
  testWidgets('an ellipsis is found', (tester) async {
    expect(
      await _cut(
        tester,
        const Text(_long, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      [contains('is cut at 1')],
    );
  });

  testWidgets('a line limit with no ellipsis is found', (tester) async {
    expect(await _cut(tester, const Text(_long, maxLines: 2)), [
      contains('is cut at 2'),
    ]);
  });

  testWidgets('one unwrapped line clipped or faded is found', (tester) async {
    for (final overflow in [TextOverflow.clip, TextOverflow.fade]) {
      expect(
        await _cut(tester, Text(_long, softWrap: false, overflow: overflow)),
        [contains('wider than its box')],
        reason: overflow.name,
      );
    }
  });

  testWidgets('glyphs lost to a clip round the text are found', (tester) async {
    expect(
      await _cut(
        tester,
        const ClipRect(
          child: SizedBox(
            height: 20,
            child: OverflowBox(
              maxWidth: 400,
              alignment: Alignment.centerLeft,
              child: Text(_long, softWrap: false),
            ),
          ),
        ),
      ),
      [contains('to the clip')],
    );
  });

  testWidgets('text that wraps, or is set smaller to fit, is not', (
    tester,
  ) async {
    expect(await _cut(tester, const Text(_long)), isEmpty);
    expect(
      await _cut(
        tester,
        const FitWords(_long, maxLines: 1, style: TextStyle(fontSize: 18)),
      ),
      isEmpty,
    );
    expect(
      await _cut(tester, const FittedBox(child: Text(_long, softWrap: false))),
      isEmpty,
    );
  });

  testWidgets('a scrolled list cuts nothing: the rest is further down', (
    tester,
  ) async {
    expect(
      await _cut(
        tester,
        SizedBox(
          height: 30,
          child: ListView(children: const [Text(_long), Text(_long)]),
        ),
      ),
      isEmpty,
    );
  });
}
