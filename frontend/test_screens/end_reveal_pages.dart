import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/end_reveal.dart';
import 'package:midnight_village/features/game/presentation/end/end_reveal.dart';

import '../test/helpers/end_board_pump.dart';
import '../test/helpers/outcome_samples.dart';
import 'end_board_pages.dart' show endTen;
import 'screen_catalogue.dart';

// The end board's reveal stopped at fixed moments, for `just screens` (strict
// at 360 and 390) and the pictures beside the mock's motion sheet: the start
// (face down in place), the hanged big, the stamp landing (the knock), the
// banner unrolling, the rows turning, and settled. Each moment is read off the
// board's own timeline, so the pages follow it when a token changes.

/// A moment of a reveal, from its timeline.
typedef RevealMoment = Duration? Function(EndReveal reveal);

/// The moments, by name, in order. A moment a reveal does not have (nobody
/// hanged has no stamp) is null and has no page.
final revealMoments = <String, RevealMoment>{
  'start': (r) => Duration.zero,
  'big': (r) {
    final lift = r.of(RevealBeat.lift), stamp = r.of(RevealBeat.stamp);
    if (lift == null || stamp == null) return null;
    return lift.end + (stamp.start - lift.end) * 0.5;
  },
  'stamp': (r) => r.of(RevealBeat.stamp)?.end,
  'banner': (r) {
    final b = r.of(RevealBeat.banner)!;
    return b.start + b.length * 0.6;
  },
  'turning': (r) {
    final turns = r.all(RevealBeat.turn).where((s) => s.row != null).toList();
    final first = turns.first.start, last = turns.last.end;
    return first + (last - first) * 0.5;
  },
  'settled': (r) => r.total,
};

/// The reveal of [results] for the first seat, stopped at [moment]; false
/// when the reveal has no such moment (and nothing is pumped past the start).
Future<bool> pumpEndReveal(
  WidgetTester tester,
  Map<String, dynamic> results,
  RevealMoment moment, {
  Size? screen,
}) async {
  if (screen != null) {
    tester.view.physicalSize = screen * tester.view.devicePixelRatio;
  }
  await pumpEndBoardOn(tester, results, reveal: true);
  final driver = tester
      .widget<EndRevealScope>(find.byType(EndRevealScope))
      .driver!;
  final at = moment(driver.reveal!);
  if (at == null) return false;
  if (at > Duration.zero) await tester.pump(at);
  // The last beat over, the board settles in the next frame.
  if (at >= driver.reveal!.total) {
    await tester.pump(const Duration(milliseconds: 17));
  }
  return true;
}

/// The four reveals of the pages: one hanged, nobody hanged, the Hunter, ten
/// players with long names.
final revealCases = <String, Map<String, dynamic> Function()>{
  'one-hanged': () => recordedResults('results_moved_dead_card'),
  'nobody-hanged': () => recordedResults('results_nobody_dies'),
  'hunter': () => recordedResults('results'),
  'ten': endTen,
};

/// Which moments each case has a page for.
List<String> momentsOf(String reveal) => reveal == 'nobody-hanged'
    ? const ['start', 'turning', 'banner', 'settled']
    : const ['start', 'big', 'stamp', 'banner', 'turning', 'settled'];

final endRevealEntries = <ScreenEntry>[
  for (final MapEntry(key: name, value: results) in revealCases.entries)
    for (final (i, moment) in momentsOf(name).indexed)
      ScreenEntry(
        '12-end-reveal-$name-${i + 1}-$moment',
        mock: null,
        build: (t) => pumpEndReveal(t, results(), revealMoments[moment]!),
        playerScreen: true,
        // The moment is pumped to exactly; no settling frames after it.
        frames: 0,
      ),
];
