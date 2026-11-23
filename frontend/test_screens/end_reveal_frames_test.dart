import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/presentation/end/end_reveal.dart';

import '../test/helpers/end_board_pump.dart';
import 'end_reveal_pages.dart';

// The end board's reveal, in frames: each reveal of the pages (one hanged,
// nobody hanged, the Hunter, ten players) at its moments, each named with its
// time, and the one-hanged reveal filmed a frame every 33 ms. Run it with
// `just end-reveal-frames` (frontend/test/README.md); it is not part of
// `just test`.

/// Where the frames go: `--dart-define=END_REVEAL_DIR=/some/folder`.
const _dir = String.fromEnvironment(
  'END_REVEAL_DIR',
  defaultValue: 'build/end_reveal',
);

/// The phone's width (the height is the mocks').
final _width = int.fromEnvironment('END_REVEAL_WIDTH', defaultValue: 390) * 1.0;
const _ratio = 2.0;
const _film = Duration(milliseconds: 33);

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

/// The reveal of [results] with every picture it shows loaded: the settled
/// board first (the faces), then the reveal at its start (the backs).
Future<EndRevealDriver> _ready(
  WidgetTester tester,
  Map<String, dynamic> results,
) async {
  await pumpEndBoardOn(tester, results);
  await _loadPictures(tester);
  await tester.pumpWidget(const SizedBox());
  await pumpEndBoardOn(tester, results, reveal: true);
  await _loadPictures(tester);
  return tester.widget<EndRevealScope>(find.byType(EndRevealScope)).driver!;
}

void main() {
  for (final MapEntry(key: name, value: results) in revealCases.entries) {
    testWidgets('the reveal at its moments: $name', (tester) async {
      await _phone(tester);
      final driver = await _ready(tester, results());
      final reveal = driver.reveal!;
      var at = Duration.zero;
      for (final (i, moment) in momentsOf(name).indexed) {
        final to = revealMoments[moment]!(reveal)!;
        if (to > at) await tester.pump(to - at);
        if (to >= reveal.total) {
          await tester.pump(const Duration(milliseconds: 17));
        }
        at = to;
        await _loadPictures(tester);
        await _save(
          tester,
          '$_dir/$name/${i + 1}-${to.inMilliseconds}ms-$moment.png',
        );
      }
    });
  }

  testWidgets('the one-hanged reveal, filmed', (tester) async {
    await _phone(tester);
    final driver = await _ready(tester, revealCases['one-hanged']!());
    final end = driver.reveal!.total + const Duration(milliseconds: 400);
    var n = 0;
    for (var t = Duration.zero; t <= end; t += _film) {
      await _save(tester, '$_dir/film/${(n++).toString().padLeft(3, '0')}.png');
      await tester.pump(_film);
      await _loadPictures(tester);
    }
  });
}
