// The parts page: every component of the inventory (`dress_inventory.dart`) in
// paper dress, in every state it has (rest, pressed, picked, locked, focused),
// on the night ground and on the lantern ground, for an art director to judge
// the paper's consistency at a glance. Run it with `just paper-parts [folder]`;
// it is not part of `just test`.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/mood.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/skin/dress.dart';
import 'package:midnight_village/design_system/skin/dress_inventory.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../test/helpers/parts_catalogue.dart';
import 'end_parts_page.dart';
import '../test/helpers/pump_skinned.dart';
import '../test/helpers/real_wait.dart';

const _dir = String.fromEnvironment(
  'PAPER_PARTS_DIR',
  defaultValue: 'build/paper_parts',
);
const _ratio = 2.0;
const _height = 4600.0;

Future<void> _save(WidgetTester tester, String name) async {
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

Future<void> _settle(WidgetTester tester) async {
  // The mood's layers decode on real I/O: wait for the picture, not a time.
  await untilMoodsArePainted(tester);
  await tester.runAsync(
    () => Future.wait([
      for (final e in find.byType(Image).evaluate())
        precacheImage((e.widget as Image).image, e),
    ]),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

Widget _page(MoodKind mood) => ScreenFrame(
  ground: GroundKind.night,
  dress: Dress.paper,
  mood: mood,
  moodLight: MoodLight.high,
  body: Builder(
    builder: (context) {
      final caption = context.skin.typography.caption.copyWith(
        color: context.ground.text,
      );
      final heading = context.skin.typography.title.copyWith(
        color: context.ground.text,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 18,
        children: [
          for (final entry in inventory)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 6,
              children: [
                Text(entry.name, style: heading),
                Wrap(
                  spacing: 16,
                  runSpacing: 14,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    for (final sample in partsCatalogue.where(
                      (s) => s.entry == entry.name,
                    ))
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 4,
                        children: [
                          sampleOf(sample),
                          Text(sample.state.name, style: caption),
                        ],
                      ),
                  ],
                ),
              ],
            ),
        ],
      );
    },
  ),
);

void main() {
  // The end board's parts, on the dawn with the lantern as the one light.
  testWidgets('the end board parts on the dawn, the lantern their light', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * _ratio, 2150 * _ratio);
    tester.view.devicePixelRatio = _ratio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: skinTheme(skinsUnderTest.values.first),
        builder: (context, child) =>
            GroundScope(ground: GroundKind.night, child: child!),
        home: endPartsPage(),
      ),
    );
    await _settle(tester);
    await _save(tester, 'parts-end');
  });

  for (final mood in [MoodKind.night, MoodKind.lantern]) {
    testWidgets('the parts page on the ${mood.name} ground', (tester) async {
      tester.view.physicalSize = const Size(390 * _ratio, _height * _ratio);
      tester.view.devicePixelRatio = _ratio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: skinTheme(skinsUnderTest.values.first),
          builder: (context, child) =>
              GroundScope(ground: GroundKind.night, child: child!),
          home: _page(mood),
        ),
      );
      await _settle(tester);
      await _save(tester, 'parts-${mood.name}');
    });
  }
}
