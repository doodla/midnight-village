// My night held (08), every night's picture story, for a look beside the
// mock's frames: each night of story_samples.dart at 360 x 780 (the mocks'
// size), and again at 360 x 640 and at text 1.6, at 2x. Run it with `just
// story-pictures`; it is not part of `just test`. `just contact-sheet
// <folder>` makes one sheet.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';

import '../test/helpers/component_sheet.dart' show learnedOverrides;
import '../test/helpers/pump_skinned.dart';
import '../test/helpers/sheet/story_samples.dart';

/// Where the pictures go: `--dart-define=STORY_PICTURES_DIR=/some/folder`.
const _dir = String.fromEnvironment(
  'STORY_PICTURES_DIR',
  defaultValue: 'build/story_pictures',
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

void main() {
  WidgetsApp.debugAllowBannerOverride = false;
  final pages = <(String, String, Size, double)>[
    for (final night in allNights.keys) (night, night, _phone, 1),
    for (final night in allNights.keys) ...[
      ('$night-360x640', night, const Size(360, 640), 1),
      ('$night-x1.6', night, _phone, 1.6),
    ],
  ];
  for (final (name, night, size, scale) in pages) {
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
          child: TalkView(
            me: GameMe.fromJson(allNights[night]!()),
            secondsLeft: 192,
            onReady: () {},
            openNight: true,
          ),
        ),
      );
      await tester.pump();
      await _save(tester, name);
    });
  }
}
