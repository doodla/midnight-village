// The dusk and the dawn in motion: each scene change of the table's shell
// pumped to fixed times, a PNG per frame and one strip of them side by side.
// Run it with `just scene-frames` (see frontend/CLAUDE.md); it is not part of
// `just test`. The same run on a shell that crossfades gives the "before".
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/presentation/shell/night_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/your_card_screen.dart';
import 'package:midnight_village/features/lobby/presentation/at_table_screen.dart';

import '../test/helpers/contract/server_json.dart' show serverMyTable;
import '../test/helpers/shell_setup.dart';

/// Where the frames go: `--dart-define=SCENE_FRAMES_DIR=/some/folder`.
const _dir = String.fromEnvironment(
  'SCENE_FRAMES_DIR',
  defaultValue: 'build/scene_frames',
);

/// What to call the run: `after` (the scenes) or `before` (a crossfade).
const _label = String.fromEnvironment(
  'SCENE_FRAMES_LABEL',
  defaultValue: 'run',
);

/// How many frames of the change, evenly from the first to the last; or, with
/// `--dart-define=SCENE_FRAMES_STEP_MS=17`, one every that many milliseconds
/// (for an animation at real speed; no strip is made then).
const _frames = 8;
const _stepMs = int.fromEnvironment('SCENE_FRAMES_STEP_MS');

const _width = 390.0;
const _height = 844.0;
const _ratio = 2.0;

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(_width * _ratio, _height * _ratio);
  tester.view.devicePixelRatio = _ratio;
  addTearDown(tester.view.reset);
  WidgetsApp.debugAllowBannerOverride = false;
  addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);
}

/// Image providers load on real I/O, which the test clock never waits for:
/// load every picture on screen for real, then draw again.
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

Future<Uint8List> _png(WidgetTester tester) async {
  final png = await tester.runAsync(() async {
    final image = await captureImage(tester.binding.rootElement!);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  });
  return png!;
}

/// Pumps until [arrived] is on screen (the change has begun), loads what
/// the scene draws, then captures [_frames] frames evenly from the start
/// to [over] later, and writes them and a strip.
Future<void> _film(
  WidgetTester tester,
  String name, {
  required Finder arrived,
  required Duration over,
}) async {
  for (var i = 0; i < 40 && arrived.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 5));
  }
  expect(arrived, findsWidgets);
  // The scene's first frame: its art is requested now, loaded, and drawn.
  await tester.pump();
  await _loadPictures(tester);
  final out = Directory('$_dir/$name')..createSync(recursive: true);
  final frames = <img.Image>[];
  var at = Duration.zero;
  final count = _stepMs > 0 ? over.inMilliseconds ~/ _stepMs + 1 : _frames;
  for (var i = 0; i < count; i++) {
    final when = _stepMs > 0
        ? Duration(milliseconds: i * _stepMs)
        : over * i ~/ (_frames - 1);
    await tester.pump(when - at);
    at = when;
    await _loadPictures(tester);
    final png = await _png(tester);
    File(
      '${out.path}/$_label-${i.toString().padLeft(2, '0')}'
      '-${when.inMilliseconds}ms.png',
    ).writeAsBytesSync(png);
    frames.add(img.decodePng(png)!);
  }
  if (_stepMs == 0) _writeStrip(frames, '$_dir/$name/$_label-strip.png');
  // Let the rest of the change finish before the test ends.
  await tester.pump(const Duration(seconds: 1));
}

void _writeStrip(List<img.Image> frames, String to) {
  const gap = 12;
  final small = [
    for (final frame in frames) img.copyResize(frame, width: frame.width ~/ 2),
  ];
  final strip = img.Image(
    width: small.length * (small.first.width + gap) - gap,
    height: small.first.height,
  )..clear(img.ColorRgb8(128, 128, 128));
  for (var i = 0; i < small.length; i++) {
    img.compositeImage(strip, small[i], dstX: i * (small.first.width + gap));
  }
  File(to).writeAsBytesSync(img.encodePng(strip));
}

void main() {
  testWidgets('dusk: the deal to the night', (tester) async {
    await _phone(tester);
    final s = await ShellSetup.pump(
      tester,
      recordedMe('me_look_stage'),
      learned: const {},
    );
    await s.settle(tester);
    // The table waits (02), as it does before a deal.
    final code = s.me['lobby_code'] as String;
    s.answerLobby(code);
    s.answerTable(
      serverMyTable(
        code: code,
        isHost: true,
        gameId: s.gameId,
        phase: 'results',
      ),
    );
    s.resume();
    await s.settle(tester);
    await s.settle(tester);
    expect(find.byType(AtTableScreen), findsOneWidget);
    await _loadPictures(tester);
    await tester.pump(const Duration(seconds: 1));
    // The deal commits.
    s.answerMe(recordedMe('me_look_stage'));
    s.resume();
    await _film(
      tester,
      'dusk',
      arrived: find.byType(YourCardScreen),
      over: _scene,
    );
    await s.close(tester);
  });

  testWidgets('dawn: the night to the talk', (tester) async {
    await _phone(tester);
    final s = await ShellSetup.pump(
      tester,
      recordedMe('me_choose_prompt_seer'),
      learned: const {Cue.hold},
      before: (s) => s.answerNightResultsSeen(),
    );
    await s.settle(tester);
    expect(find.byType(NightScreen), findsOneWidget);
    await _loadPictures(tester);
    await tester.pump(const Duration(seconds: 1));
    s.answerMe(recordedMe('me_discussion_choose_seer'));
    s.resume();
    await _film(tester, 'dawn', arrived: find.byType(TalkScreen), over: _scene);
    await s.close(tester);
  });
}

/// The length of a scene ([Motion.scene]); a crossfade is shorter, so the
/// "before" run films the same span and ends on the finished screen.
final _scene = Motion.scene;
