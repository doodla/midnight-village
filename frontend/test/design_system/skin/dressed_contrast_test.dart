import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/mood.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/skin/dress.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../../helpers/component_sheet.dart';
import '../../helpers/painted_text.dart';
import '../../helpers/pump_skinned.dart';
import '../../helpers/shell_setup.dart';
import '../../helpers/sheet/night_pages.dart';
import '../../helpers/sheet/sheet_data.dart';
import '../../helpers/sheet/table_pages.dart';

// The dressed screens on a real phone, village and lights on: the contrast of
// every run of text against the WORST pixel just round it (not the commonest
// one: a word half over a moon pool is read against the pool). The page tests
// (`contrast_test.dart`) render pages 3000 px tall, where the village never
// sits behind the content; these are the sizes a player holds. Where a word
// has to be over the picture it has a paper backing, never a dulled scene.
// The three screens the owner chose dressed up (the table, your card and the
// night board) are all here.

const _phones = [Size(360, 780), Size(390, 844)];

/// Waits for the mood's own picture, with the village in it: the layers decode
/// on real I/O, so the test waits on [Mood.composed] (the event itself), never
/// on a stretch of time. A mood composed with a layer missing is never kept
/// ([Mood.cachedPictures]), so a village that failed to load fails here.
Future<void> _untilComposed(WidgetTester tester, int before) async {
  for (var i = 0; i < 1000 && Mood.composed == before; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
  expect(Mood.composed, greaterThan(before), reason: 'the mood was composed');
  await tester.pump();
  expect(
    Mood.cachedPictures,
    greaterThan(0),
    reason: 'the mood was composed with every layer of its village',
  );
  expect(find.byType(RawImage), findsWidgets);
}

Future<int> _pump(WidgetTester tester, Widget page, Size phone) async {
  tester.view.physicalSize = phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Mood.forget();
  await tester.pumpWidget(const SizedBox());
  final before = Mood.composed;
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
  return before;
}

/// Every run of text that sits bare on the mood reads on the worst pixel round
/// it.
Future<void> _expectReadable(WidgetTester tester) async {
  final readings = await readPaintedText(tester);
  expect(readings, isNotEmpty);
  // Words on paper (dark ink on bone) have their paper under them, which the
  // page tests read; the words that can sit over the village or a light are
  // the light ones on the dark mood.
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
}

void main() {
  // The host steps from the table into the deck set-up page: paper too. It
  // scrolls under its button, so it is read whole, on a phone as tall as it is.
  for (final width in [360.0, 390.0]) {
    testWidgets(
      'the deck set-up page at ${width.round()} wide: every word keeps 7:1 on '
      'the worst pixel round it, village on',
      (tester) async {
        final before = await _pump(tester, const DeckPage(), Size(width, 1500));
        await _untilComposed(tester, before);
        await _expectReadable(tester);
      },
    );
  }

  for (final phone in _phones) {
    final size = '${phone.width.round()} x ${phone.height.round()}';
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
        '$name at $size: every word keeps 7:1 on the worst pixel round it, '
        'village on',
        (tester) async {
          final before = await _pump(tester, page, phone);
          await _untilComposed(tester, before);
          await _expectReadable(tester);
        },
      );
    }

    // The real screen, as the app builds it (it dresses itself up).
    testWidgets(
      'your card at $size: every word keeps 7:1 on the worst pixel round it, '
      'mood on',
      (tester) async {
        tester.view.physicalSize = phone;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        Mood.forget();
        final before = Mood.composed;
        final setup = await ShellSetup.pump(
          tester,
          recordedMe('me_look_stage'),
          learned: const {},
        );
        addTearDown(() => setup.close(tester));
        await setup.settle(tester);
        await _untilComposed(tester, before);
        expect(
          DressScope.of(tester.element(find.byType(ScreenFrame))),
          Dress.paper,
          reason: 'the screen is dressed up by itself',
        );
        await _expectReadable(tester);
      },
    );
  }
}
