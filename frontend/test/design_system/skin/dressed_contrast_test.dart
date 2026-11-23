import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/mood.dart';
import 'package:midnight_village/design_system/skin/dress.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../../helpers/component_sheet.dart';
import '../../helpers/painted_text.dart';
import '../../helpers/pump_skinned.dart';
import '../../helpers/sheet/night_pages.dart';
import '../../helpers/sheet/sheet_data.dart';
import '../../helpers/sheet/table_pages.dart';

// The dressed screens on a real phone, village and lights on: the contrast of
// every run of text against the WORST pixel just round it (not the commonest
// one: a word half over a moon pool is read against the pool). The page tests
// (`contrast_test.dart`) render pages 3000 px tall, where the village never
// sits behind the content; these are the sizes a player holds. Where a word
// has to be over the picture it has a paper backing, never a dulled scene.

const _phones = [Size(360, 780), Size(390, 844)];

Future<void> _pump(WidgetTester tester, Widget page, Size phone) async {
  tester.view.physicalSize = phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Mood.forget();
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    ProviderScope(
      overrides: learnedOverrides(ComponentPage.action.learned),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: skinTheme(skinsUnderTest.values.first),
        builder: (context, child) =>
            GroundScope(ground: GroundKind.night, child: child!),
        home: page,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  for (final phone in _phones) {
    for (final (name, page) in <(String, Widget)>[
      ('the host\'s table', const TablePage(dress: Dress.paper)),
      ('a guest\'s table', const TablePage(guest: true, dress: Dress.paper)),
      (
        'the night board (the Seer)',
        BoardPage(viewer: Viewer.seer, dress: Dress.paper),
      ),
      (
        'the night board (the Villager)',
        BoardPage(viewer: Viewer.villager, dress: Dress.paper),
      ),
    ]) {
      testWidgets(
        '$name at ${phone.width.round()} x ${phone.height.round()}: every '
        'word keeps 7:1 on the worst pixel round it, village on',
        (tester) async {
          await _pump(tester, page, phone);
          // The village's layers decode on real I/O: let them in.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 800)),
          );
          await tester.pump();
          final readings = await readPaintedText(tester);
          expect(readings, isNotEmpty);
          // Words on paper (dark ink on bone) have their paper under them,
          // which the page tests read; the words that can sit over the
          // village or a light are the light ones on the dark mood.
          final bare = [
            for (final r in readings)
              if (luminance(r.foreground) > luminance(r.background)) r,
          ];
          expect(bare, isNotEmpty);
          expect([
            for (final r in bare)
              if (!r.readableEverywhere)
                '"${r.text}" ${r.worstRatio.toStringAsFixed(2)}:1 on the '
                    'worst pixel (${r.ratio.toStringAsFixed(2)}:1 on the '
                    'commonest)',
          ], isEmpty);
        },
      );
    }
  }
}
