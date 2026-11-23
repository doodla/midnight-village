import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/paper_scrap.dart';

import '../test/helpers/end_board_pump.dart';
import '../test/helpers/outcome_samples.dart';
import 'end_night_pages.dart' show nightOf;

// What happened, filmed: the six-player game (`results`) stepped through at a
// player's pace, a frame every 66 ms: the scrap tapped, each step played and
// read for a moment, the next tap, and back to the result. Run it with
// `just end-night-frames` (frontend/test/README.md); not part of `just test`.

const _dir = String.fromEnvironment(
  'END_NIGHT_DIR',
  defaultValue: 'build/end_night',
);

final _width = int.fromEnvironment('END_NIGHT_WIDTH', defaultValue: 360) * 1.0;
const _ratio = 1.0;
const _film = Duration(milliseconds: 66);

/// How long a player reads a step before the next tap.
const _read = Duration(milliseconds: 1500);

Future<void> _phone(WidgetTester tester) async {
  final height = _width < 390 ? 780.0 : 844.0;
  tester.view.physicalSize = Size(_width * _ratio, height * _ratio);
  tester.view.devicePixelRatio = _ratio;
  addTearDown(tester.view.reset);
  WidgetsApp.debugAllowBannerOverride = false;
  addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);
}

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
  // The real shadows in the picture (the test binding draws solid blocks),
  // put back before the binding checks it.
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
  testWidgets('What happened, filmed', (tester) async {
    await _phone(tester);
    await pumpEndBoardOn(tester, recordedResults('results'));
    await _loadPictures(tester);
    var n = 0;
    Future<void> film(Duration length) async {
      for (var t = Duration.zero; t < length; t += _film) {
        await _save(
          tester,
          '$_dir/film/${(n++).toString().padLeft(3, '0')}.png',
        );
        await tester.pump(_film);
        await _loadPictures(tester);
      }
    }

    Finder scrap(String label) => find.byWidgetPredicate(
      (w) => w is PaperScrap && w.label.replaceAll('\n', ' ') == label,
    );
    await film(const Duration(milliseconds: 600));
    await tester.tap(scrap(EndCopy.whatHappened).first);
    await tester.pump();
    final night = nightOf(tester);
    for (var i = 0; i < night.story!.steps.length; i++) {
      if (i > 0) {
        await tester.tapAt(Offset(_width / 2, 330));
        await tester.pump();
      }
      await film(night.clock.duration! + _read);
    }
    await tester.tap(scrap(EndCopy.backToResult).first);
    await tester.pump();
    await film(Motion.scene + const Duration(milliseconds: 900));
  });
}
