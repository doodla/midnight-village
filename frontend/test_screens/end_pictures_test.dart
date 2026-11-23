// The end board in pictures, for a look beside its mocks: every outcome on a
// 360 x 780 phone (the mocks' size) at 2x, then a short phone and the larger
// text sizes. Run it with `just end-pictures`; it is not part of `just test`.
// `just contact-sheet <folder>` makes one sheet.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers/outcome_samples.dart';
import 'end_board_pages.dart';

/// Where the pictures go: `--dart-define=END_PICTURES_DIR=/some/folder`.
const _dir = String.fromEnvironment(
  'END_PICTURES_DIR',
  defaultValue: 'build/end_pictures',
);
const _ratio = 2.0;
const _phone = Size(360, 780);
const _short = Size(360, 640);

Future<void> _save(WidgetTester tester, String name) async {
  await tester.runAsync(
    () => Future.wait([
      for (final e in find.byType(Image).evaluate())
        precacheImage((e.widget as Image).image, e),
    ]),
  );
  await tester.pump();
  // The test binding turns blurred shadows into solid blocks as it paints;
  // the pictures show the real ones.
  debugDisableShadows = false;
  final png = await tester.runAsync(() async {
    final image = await captureImage(tester.binding.rootElement!);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  });
  debugDisableShadows = true;
  Directory(_dir).createSync(recursive: true);
  File('$_dir/$name.png').writeAsBytesSync(Uint8List.fromList(png!));
}

void main() {
  final pages = <(String, Map<String, dynamic> Function(), int, bool)>[
    ('1a', () => recordedResults('results_moved_dead_card'), 0, true),
    ('1b', () => recordedResults('results_nobody_dies'), 0, true),
    ('1c', () => recordedResults('results_three_players'), 1, true),
    ('1f', () => recordedResults('results'), 0, true),
    ('1g', () => recordedResults('results_tanner_alone'), 0, true),
    ('1h', () => recordedResults('results_five'), endGuestSeat, false),
    ('tie', () => recordedResults('results_tie'), 0, true),
    ('doppel', () => recordedResults('results_doppelganger'), 1, true),
  ];
  for (final (name, results, viewer, host) in pages) {
    testWidgets(name, (tester) async {
      tester.view.devicePixelRatio = _ratio;
      addTearDown(tester.view.reset);
      await pumpEndBoard(
        tester,
        results(),
        viewer: viewer,
        host: host,
        screen: _phone,
      );
      await _save(tester, name);
    });
  }
  for (final (name, top) in [('1d', true), ('1e', false)]) {
    testWidgets(name, (tester) async {
      tester.view.devicePixelRatio = _ratio;
      addTearDown(tester.view.reset);
      await pumpEndBoard(tester, endTen(), screen: _phone, top: top);
      await _save(tester, name);
    });
  }
  for (final (name, sample, size, scale) in [
    ('short-1a', 'results_moved_dead_card', _short, 1.0),
    ('short-1f', 'results', _short, 1.0),
    ('text13-1a', 'results_moved_dead_card', _phone, 1.3),
    ('text13-1f', 'results', _phone, 1.3),
    ('text16-1a', 'results_moved_dead_card', _phone, 1.6),
    ('text16-1f', 'results', _phone, 1.6),
  ]) {
    testWidgets(name, (tester) async {
      tester.view.devicePixelRatio = _ratio;
      addTearDown(tester.view.reset);
      await pumpEndBoard(
        tester,
        recordedResults(sample),
        screen: size,
        textScale: scale,
      );
      await _save(tester, name);
    });
  }
}
