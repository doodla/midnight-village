// The night board's small moments in motion: picking a card, and the candle
// across a window, one PNG per 17 ms step (real speed for a 60 Hz phone) into
// a folder, for a recording. Run it with `just night-frames` (see
// frontend/test/README.md); it is not part of `just test`.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/design_system/night/choose_prompt.dart';
import 'package:midnight_village/design_system/faces/night_report.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/presentation/shell/night_screen.dart';

import '../test/helpers/component_sheet.dart' show learnedOverrides;
import '../test/helpers/pump_skinned.dart' show skinsUnderTest;
import '../test/helpers/shell_setup.dart';
import '../test/helpers/sheet/sheet_data.dart' show selfIn;

/// Where the frames go: `--dart-define=NIGHT_FRAMES_DIR=/some/folder`.
const _dir = String.fromEnvironment(
  'NIGHT_FRAMES_DIR',
  defaultValue: 'build/night_frames',
);

/// What to call the run (a folder name inside it), for before and after.
const _label = String.fromEnvironment(
  'NIGHT_FRAMES_LABEL',
  defaultValue: 'run',
);

/// One frame every this many milliseconds: a 60 Hz phone's frame.
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

/// The frames of one film, numbered, with the time of each in the name.
class _Film {
  _Film(this.name) {
    Directory('$_dir/$_label/$name').createSync(recursive: true);
  }

  final String name;
  var _n = 0;
  var _at = Duration.zero;

  /// The frame as it is now, called [note].
  Future<void> frame(WidgetTester tester, [String note = '']) async {
    // The test binding turns blurred shadows into solid blocks as it paints;
    // the film shows the real glow.
    final png = await tester.runAsync(() async {
      final image = await captureImage(tester.binding.rootElement!);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes!.buffer.asUint8List();
    });
    File(
      '$_dir/$_label/$name/${(_n++).toString().padLeft(3, '0')}'
      '-${_at.inMilliseconds}ms${note.isEmpty ? '' : '-$note'}.png',
    ).writeAsBytesSync(Uint8List.fromList(png!));
  }

  /// Runs the clock [span] in 17 ms steps, a frame after each.
  Future<void> run(
    WidgetTester tester,
    Duration span, [
    String note = '',
  ]) async {
    for (var t = Duration.zero; t < span; t += _step) {
      await tester.pump(_step);
      _at += _step;
      await frame(tester, note);
    }
  }
}

void main() {
  testWidgets('pick: a finger on a card, the pick, the pick taken back', (
    tester,
  ) async {
    await _phone(tester);
    debugDisableShadows = false;
    final s = await ShellSetup.pump(
      tester,
      recordedMe('me_choose_prompt_seer'),
      learned: const {Cue.hold, Cue.nightChoose},
    );
    await s.settle(tester);
    expect(find.byType(NightScreen), findsOneWidget);
    await _loadPictures(tester);
    await tester.pump(const Duration(seconds: 1));
    final film = _Film('pick');
    final cleo = find.ancestor(
      of: find.text('Cleo'),
      matching: find.byType(FaceDownCard),
    );
    await film.frame(tester, 'rest');
    await film.run(tester, const Duration(milliseconds: 85), 'rest');
    // The finger lands and stays 170 ms.
    final finger = await tester.startGesture(tester.getCenter(cleo));
    await film.run(tester, const Duration(milliseconds: 170), 'down');
    await finger.up();
    // The pick: the lift, the light, the dim, the button rising.
    await film.run(tester, const Duration(milliseconds: 510), 'picked');
    await film.run(tester, const Duration(milliseconds: 340), 'hold');
    // Taken back with a tap.
    final again = await tester.startGesture(tester.getCenter(cleo));
    await film.run(tester, const Duration(milliseconds: 68), 'down');
    await again.up();
    await film.run(tester, const Duration(milliseconds: 510), 'back');
    await film.run(tester, const Duration(milliseconds: 170), 'rest');
    debugDisableShadows = true;
    await s.close(tester);
  });

  testWidgets('candle: a window of 30 seconds, one step each', (tester) async {
    await _phone(tester);
    debugDisableShadows = false;
    final recorded = recordedMe('me_choose_prompt_seer');
    final prompt = ChoosePrompt.fromMe(recorded);
    await tester.pumpWidget(
      ProviderScope(
        overrides: learnedOverrides({Cue.hold, Cue.nightChoose}),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: skinTheme(skinsUnderTest.values.first),
          builder: (context, child) =>
              GroundScope(ground: GroundKind.night, child: child!),
          home: StatefulBuilder(
            builder: (context, set) =>
                _CandleHost(me: recorded, prompt: prompt, step: _seconds),
          ),
        ),
      ),
    );
    await tester.pump();
    await _loadPictures(tester);
    final film = _Film('candle');
    const window = 30;
    for (var left = window; left >= 0; left--) {
      _seconds.value = left;
      await tester.pump();
      await tester.pump();
      await film.frame(tester, '${left}s');
    }
    debugDisableShadows = true;
  });
}

final _seconds = ValueNotifier<int>(30);

/// The board with the seconds of [step] left in a window of 30.
class _CandleHost extends StatelessWidget {
  const _CandleHost({
    required this.me,
    required this.prompt,
    required this.step,
  });

  final Map<String, dynamic> me;
  final ChoosePrompt prompt;
  final ValueListenable<int> step;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: step,
    builder: (context, left, _) => NightBoard(
      seats: NightSeat.seatsOf(me),
      selfId: selfIn(me),
      prompt: prompt,
      face: NightReport.fromMe(me).you(prompt),
      dealt: NightReport.fromMe(me).dealt,
      secondsLeft: left,
      share: left / 30,
      onChoose: (_, _) async => ChooseAnswer.taken,
    ),
  );
}
