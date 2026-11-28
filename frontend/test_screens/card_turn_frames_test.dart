// Your card turning over, in motion: a finger lands, the card turns to its
// face after the hold, and turns back when let go; one PNG per 17 ms step
// (a 60 Hz phone's frame) into a folder. Run it with `just card-frames` (see
// frontend/test/README.md); it is not part of `just flutter-test`.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../test/helpers/shell_setup.dart';

/// Where the frames go: `--dart-define=CARD_FRAMES_DIR=/some/folder`.
const _dir = String.fromEnvironment(
  'CARD_FRAMES_DIR',
  defaultValue: 'build/card_frames',
);

/// What to call the run (a folder name inside it).
const _label = String.fromEnvironment('CARD_FRAMES_LABEL', defaultValue: 'run');

/// Under reduce motion, for the film of the cut.
const _still = bool.fromEnvironment('CARD_FRAMES_STILL');

const _step = Duration(milliseconds: 17);
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

void main() {
  testWidgets('your card: the finger, the turn, the turn back', (tester) async {
    await _phone(tester);
    final s = await ShellSetup.pump(
      tester,
      recordedMe('me_look_stage'),
      learned: const {Cue.hold},
      disableAnimations: _still,
    );
    await s.settle(tester);
    await _loadPictures(tester);
    await tester.pump(const Duration(seconds: 1));
    final out = Directory('$_dir/$_label')..createSync(recursive: true);
    var n = 0;
    var at = Duration.zero;
    Future<void> frame(String note) async {
      final png = await tester.runAsync(() async {
        final image = await captureImage(tester.binding.rootElement!);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        return bytes!.buffer.asUint8List();
      });
      File(
        '${out.path}/${(n++).toString().padLeft(3, '0')}-${at.inMilliseconds}ms'
        '-$note.png',
      ).writeAsBytesSync(Uint8List.fromList(png!));
    }

    Future<void> run(Duration span, String note) async {
      for (var t = Duration.zero; t < span; t += _step) {
        await tester.pump(_step);
        at += _step;
        await frame(note);
      }
    }

    await frame('rest');
    final finger = await tester.startGesture(
      tester.getCenter(find.byType(FaceDownCard)),
    );
    // The hold's delay, then the turn, then a beat of the face.
    await run(
      HoldToReveal.holdDelay + const Duration(milliseconds: 220),
      'turn',
    );
    await run(const Duration(milliseconds: 170), 'face');
    await finger.up();
    await run(const Duration(milliseconds: 170), 'back');
    await run(const Duration(milliseconds: 68), 'rest');
    await s.close(tester);
  });
}
