import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/layout/space.dart';

import '../test/helpers/end_board_pump.dart';
import '../test/helpers/outcome_samples.dart';
import 'end_board_pages.dart' show endTen;
import 'end_night_pages.dart' show nightOf;

// What happened's links, every step of a few recorded nights, done, on three
// phones (360, 390 and the owner's 412): one PNG a step, to look at every
// thread at full size. Run it with `just end-link-pictures`
// (frontend/test/README.md); not part of `just test`.

const _dir = String.fromEnvironment(
  'END_LINKS_DIR',
  defaultValue: 'build/end_links',
);

/// Text size (`END_LINKS_SCALE`), and one game alone (`END_LINKS_GAME`).
final _scale = double.parse(
  const String.fromEnvironment('END_LINKS_SCALE', defaultValue: '1'),
);
const _only = String.fromEnvironment('END_LINKS_GAME');

/// The short phone (360 x 640) for 360 (`END_LINKS_SHORT`).
const _short = bool.fromEnvironment('END_LINKS_SHORT');

final _games = <(String, Map<String, dynamic> Function())>[
  ('three', () => recordedResults('results_three_players')),
  ('game', () => recordedResults('results')),
  ('dop', () => recordedResults('results_doppelganger')),
  ('drunk', () => recordedResults('results_doppelganger_drunk')),
  ('ten', endTen),
  ('practice', () => recordedResults('results_practice')),
  ('five', () => recordedResults('results_five')),
];

Future<void> _loadPictures(WidgetTester tester) async {
  final images = [
    for (final element in find.byType(Image).evaluate())
      ((element.widget as Image).image, element),
  ];
  if (images.isEmpty) return;
  await tester.runAsync(
    () => Future.wait([
      for (final (provider, context) in images)
        precacheImage(provider, context),
    ]),
  );
  await tester.pump();
}

Future<void> _save(WidgetTester tester, String path) async {
  debugDisableShadows = false;
  tester.binding.rootElement!.renderObject!.markNeedsPaint();
  await tester.pump();
  final png = await tester.runAsync(() async {
    final image = await captureImage(tester.binding.rootElement!);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  });
  debugDisableShadows = true;
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(Uint8List.fromList(png!));
}

void main() {
  for (final (name, results) in _games) {
    if (_only.isNotEmpty && name != _only) continue;
    for (final size in const [
      Size(360, _short ? 640 : 780),
      Size(390, 844),
      Size(412, 915),
    ]) {
      testWidgets('$name at ${size.width.toInt()}: every step', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        WidgetsApp.debugAllowBannerOverride = false;
        addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);
        await pumpEndBoardOn(tester, results(), scale: _scale);
        await tester.pump(const Duration(seconds: 1));
        await _loadPictures(tester);
        await tester.tap(find.textContaining('happened').first);
        await tester.pump();
        final night = nightOf(tester);
        for (var i = 0; i <= night.story!.steps.length; i++) {
          if (i > 0) night.next();
          await tester.pump();
          await tester.pump(night.clock.duration);
          await tester.pump(Motion.scene);
          await _loadPictures(tester);
          final kind = i == 0 ? 'deal' : night.current!.kind.name;
          await _save(
            tester,
            '$_dir/$name/w${size.width.toInt()}/'
            '${i.toString().padLeft(2, '0')}-$kind.png',
          );
        }
      });
    }
  }
}
