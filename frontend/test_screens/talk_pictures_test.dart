// The talk (08, the square) in pictures, for a look beside its mocks: six
// players with none, some and this phone ready, My night held, three and ten
// players, a short phone, text 1.6 and the host's phone, each a recorded
// `/me/` at 360 x 780 (the mocks' size) at 2x. Run it with `just
// talk-pictures`; it is not part of `just test`. `just contact-sheet
// <folder>` makes one sheet.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/sealed_note.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/domain/stage_progress.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';

import '../test/helpers/component_sheet.dart' show holdDown, learnedOverrides;
import '../test/helpers/contract/contract_samples.dart';
import '../test/helpers/pump_skinned.dart';
import '../test/helpers/sheet/sheet_data.dart' as sheet;

/// Where the pictures go: `--dart-define=TALK_PICTURES_DIR=/some/folder`.
const _dir = String.fromEnvironment(
  'TALK_PICTURES_DIR',
  defaultValue: 'build/talk_pictures',
);
const _ratio = 2.0;
const _phone = Size(360, 780);

Future<void> _save(WidgetTester tester, String name) async {
  await tester.runAsync(
    () => Future.wait([
      for (final e in find.byType(Image).evaluate())
        precacheImage((e.widget as Image).image, e),
    ]),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
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

/// [me] with [done] of its players ready: the recorded count event, its
/// numbers set for the picture (pictures only; the tests use recordings).
GameMe _ready(GameMe me, int done, {bool mine = false}) {
  final event = ContractSamples.map('ws/game/progress_talk')
    ..['done'] = done
    ..['needed'] = me.seats.length;
  return me.withProgress(StageProgress.fromJson(event)).withReady(mine);
}

void main() {
  WidgetsApp.debugAllowBannerOverride = false;
  final six = GameMe.fromJson(sheet.recordedMe('me_talk_results_seen'));
  final pages = <(String, GameMe, Size, double, bool)>[
    ('6-none', six, _phone, 1, false),
    ('6-some', _ready(six, 2), _phone, 1, false),
    ('6-pressed', _ready(six, 3, mine: true), _phone, 1, false),
    ('6-held', six, _phone, 1, true),
    (
      '3',
      GameMe.fromJson(sheet.recordedMe('me_talk_untimed')),
      _phone,
      1,
      false,
    ),
    ('10', GameMe.fromJson(sheet.recordedMe('me_talk_ten')), _phone, 1, false),
    ('360x640', six, const Size(360, 640), 1, false),
    ('text-1.6', six, _phone, 1.6, false),
    (
      'host',
      GameMe.fromJson(sheet.recordedMe('me_discussion_acting_host')),
      _phone,
      1,
      false,
    ),
  ];
  for (final (name, me, size, scale, held) in pages) {
    testWidgets(name, (tester) async {
      tester.view.physicalSize = size * _ratio;
      tester.view.devicePixelRatio = _ratio;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpSkinned(
        tester,
        ProviderScope(
          overrides: learnedOverrides({...Cue.values}),
          child: TalkView(me: me, secondsLeft: 192, onReady: () {}),
        ),
      );
      await tester.pump();
      if (held) await holdDown(tester, find.byType(SealedNote));
      await _save(tester, name);
    });
  }
}
