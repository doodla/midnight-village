import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/features/game/presentation/end/end_night.dart';

import '../test/helpers/outcome_samples.dart';
import 'end_board_pages.dart' show endTen, pumpEndBoard;
import 'screen_catalogue.dart';

// What happened, on the end board, stopped at its moments, for `just screens`
// (strict at 360 and 390) and the pictures beside the mock's motion sheet: a
// whole game's night (the cards turned to the deal, a look, a take, a swap in
// mid-move, the last step, back to the result), the Doppelganger's game, ten
// players in mid-step (the board scrolled to the step's cards) and large text.

/// The night of the board on screen.
EndNight nightOf(WidgetTester tester) =>
    tester.widget<EndNightScope>(find.byType(EndNightScope)).notifier!;

/// The board on [results], What happened tapped, played to step [step] (0 is
/// the first) and stopped [at] that step's motion (1: done); with [back], the
/// scrap tapped again afterwards and the dawn come back.
Future<void> pumpEndNight(
  WidgetTester tester,
  Map<String, dynamic> results, {
  int step = 0,
  double at = 1,
  double textScale = 1,
  bool back = false,
}) async {
  await pumpEndBoard(tester, results, textScale: textScale);
  await tester.tap(find.text(EndCopy.whatHappened).first);
  // A clock started counts from the next frame.
  await tester.pump();
  final night = nightOf(tester);
  for (var i = 0; i < step; i++) {
    await tester.pump(night.clock.duration);
    await tester.pump(Motion.scene);
    night.next();
    await tester.pump();
  }
  if (back) {
    await tester.pump(night.clock.duration);
    await tester.tap(find.text(EndCopy.backToResult).first);
    await tester.pump(Motion.scene);
    await tester.pump(Motion.scene);
    return;
  }
  // The scroll a step brings (a tall board) is over by its motion's end.
  final d = night.clock.duration! * at;
  if (d > Duration.zero) await tester.pump(d);
  if (at >= 1) await tester.pump(Motion.scene);
}

/// The pages: (name, results, step, at, text scale, back).
final _nights =
    <(String, Map<String, dynamic> Function(), int, double, double, bool)>[
      ('game-1-dealt', () => recordedResults('results'), 0, 0.4, 1, false),
      ('game-2-team', () => recordedResults('results'), 0, 1, 1, false),
      ('game-3-look', () => recordedResults('results'), 1, 1, 1, false),
      ('game-4-take', () => recordedResults('results'), 2, 1, 1, false),
      (
        'game-5-swap-moving',
        () => recordedResults('results'),
        3,
        0.72,
        1,
        false,
      ),
      ('game-6-last', () => recordedResults('results'), 3, 1, 1, false),
      ('game-7-back', () => recordedResults('results'), 3, 1, 1, true),
      (
        'dop-1-copy',
        () => recordedResults('results_doppelganger'),
        0,
        1,
        1,
        false,
      ),
      (
        'dop-2-copied-look',
        () => recordedResults('results_doppelganger'),
        1,
        1,
        1,
        false,
      ),
      (
        'dop-3-lone-werewolf',
        () => recordedResults('results_doppelganger'),
        2,
        1,
        1,
        false,
      ),
      (
        'dop-6-drunk',
        () => recordedResults('results_doppelganger'),
        5,
        1,
        1,
        false,
      ),
      (
        'dop-7-insomniac',
        () => recordedResults('results_doppelganger'),
        6,
        1,
        1,
        false,
      ),
      ('ten-mid-step', endTen, 3, 0.7, 1, false),
      ('ten-drunk', endTen, 5, 1, 1, false),
      ('text-1.6', () => recordedResults('results'), 3, 1, 1.6, false),
    ];

final endNightEntries = <ScreenEntry>[
  for (final (name, results, step, at, scale, back) in _nights)
    ScreenEntry(
      '12-end-night-$name',
      mock: null,
      build: (t) => pumpEndNight(
        t,
        results(),
        step: step,
        at: at,
        textScale: scale,
        back: back,
      ),
      playerScreen: true,
      // The moment is pumped to exactly; no settling frames after it.
      frames: 0,
    ),
];
