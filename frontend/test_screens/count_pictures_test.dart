// The count (10) in pictures, for a look: one death, a tie of two, nobody, as
// it ends and as it goes (four frames), and the count at ten with long names
// at several widths and text sizes. Run it with `just count-pictures`; it is
// not part of `just test`. `just contact-sheet <folder>` makes one sheet.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/features/game/domain/outcome_view.dart';
import 'package:midnight_village/features/game/presentation/shell/count_screen.dart';

import '../test/helpers/outcome_samples.dart';
import '../test/helpers/pump_skinned.dart';

/// Where the pictures go: `--dart-define=COUNT_PICTURES_DIR=/some/folder`.
const _dir = String.fromEnvironment(
  'COUNT_PICTURES_DIR',
  defaultValue: 'build/count_pictures',
);
const _width = int.fromEnvironment('COUNT_PICTURES_WIDTH', defaultValue: 360);
const _height = 800.0;
const _ratio = 2.0;

Future<void> _show(
  WidgetTester tester,
  Map<String, dynamic> results, {
  required int viewer,
  double width = _width * 1.0,
  double textScale = 1,
  bool reduced = false,
}) async {
  final phone = Size(width, _height);
  tester.view.physicalSize = phone * _ratio;
  tester.view.devicePixelRatio = _ratio;
  addTearDown(tester.view.reset);
  await pumpSkinned(
    tester,
    MediaQuery(
      data: MediaQueryData(
        size: phone,
        textScaler: TextScaler.linear(textScale),
        disableAnimations: reduced,
      ),
      child: SizedBox.fromSize(
        size: phone,
        child: CountView(
          count: TheCount.of(outcomeOf(results)),
          viewerId: viewer,
          onSeeWhoWon: () {},
        ),
      ),
    ),
    ground: GroundKind.day,
  );
  await tester.pump();
  await tester.runAsync(
    () => Future.wait([
      for (final e in find.byType(Image).evaluate())
        precacheImage((e.widget as Image).image, e),
    ]),
  );
  await tester.pump();
}

Future<void> _save(WidgetTester tester, String name) async {
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

/// The count's motion to its end, then a moment more.
Future<void> _end(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await _load(tester);
  await tester.pump(const Duration(milliseconds: 500));
}

/// The pictures on show are loaded for real (the test clock never waits).
Future<void> _load(WidgetTester tester) async {
  await tester.runAsync(
    () => Future.wait([
      for (final e in find.byType(Image).evaluate())
        precacheImage((e.widget as Image).image, e),
    ]),
  );
  await tester.pump();
}

Future<void> _frames(WidgetTester tester, String name, List<int> atMs) async {
  var at = 0;
  for (final (i, ms) in atMs.indexed) {
    await tester.pump(Duration(milliseconds: ms - at));
    at = ms;
    await _load(tester);
    await _save(tester, '$name-${i + 1}-${ms}ms');
  }
}

Map<String, dynamic> _one() => recordedResults('results_moved_dead_card');
Map<String, dynamic> _tie() => recordedResults('results_tie');
Map<String, dynamic> _nobody() => recordedResults('results_nobody_dies');
Map<String, dynamic> _ten() => widened(
  recordedResults('results_doppelganger'),
  add: 2,
  rename: longEndNames,
);

void main() {
  testWidgets('one death, at its end', (tester) async {
    await _show(tester, _one(), viewer: 55);
    await _end(tester);
    await _save(tester, 'one-death');
  });

  testWidgets('a tie of two, at its end', (tester) async {
    await _show(tester, _tie(), viewer: 56);
    await _end(tester);
    await _save(tester, 'tie');
  });

  testWidgets('nobody dies, at its end', (tester) async {
    await _show(tester, _nobody(), viewer: 56);
    await _end(tester);
    await _save(tester, 'nobody');
  });

  testWidgets('one death as it goes: four frames', (tester) async {
    await _show(tester, _one(), viewer: 55);
    await _frames(tester, 'moment', [250, 800, 1810, 2100]);
  });

  testWidgets('a long name beside its number, text x1.6', (tester) async {
    final results = _tie();
    final players = (results['players'] as List).cast<Map<String, dynamic>>();
    players.firstWhere((p) => p['display_name'] == 'Cleo')['display_name'] =
        'Christopher';
    await _show(tester, results, viewer: 56, textScale: 1.6);
    await _end(tester);
    await _save(tester, 'christopher-large-text');
  });

  for (final (name, width, scale) in [
    ('sizes-ten-320', 320.0, 1.0),
    ('sizes-ten-360', 360.0, 1.0),
    ('sizes-ten-390', 390.0, 1.0),
    ('sizes-ten-large-text', 360.0, 1.6),
  ]) {
    testWidgets(name, (tester) async {
      await _show(tester, _ten(), viewer: 56, width: width, textScale: scale);
      await _end(tester);
      expect(tester.takeException(), isNull);
      await _save(tester, name);
    });
  }
}
