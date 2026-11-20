import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../test/helpers/outcome_samples.dart';
import '../test/helpers/shell_setup.dart';

// 10 The count and 11 Results through the real shell (TableShell), as a
// phone at the end of a recorded game has them: `/me/` at the results
// (`me_results_v2` at that game's table) and the results body
// (test/helpers/outcome_samples.dart: recorded, or derived where no game
// was recorded). 11 is reached the way a player reaches it: "See who won".

/// The shell at the end of the game of [results] on [viewer]'s phone,
/// [host] the host; the count's motion run to its end.
Future<ShellSetup> _end(
  WidgetTester tester,
  Map<String, dynamic> results, {
  required String viewer,
  String host = 'Ana',
  double textScale = 1,
}) async {
  final setup = await ShellSetup.pump(
    tester,
    resultsMeFor(results, viewer: viewer, host: host),
    learned: Cue.values.toSet(),
    textScale: textScale,
    before: (s) => s.answerResults(results),
  );
  await setup.settle(tester);
  await tester.pump(const Duration(seconds: 4));
  return setup;
}

/// From the count to 11, the way a player goes: "See who won".
Future<void> _seeWhoWon(WidgetTester tester, ShellSetup setup) async {
  await tester.tap(find.text(CountCopy.seeWhoWon));
  await setup.settle(tester);
}

/// 10: Cleo, the lone Werewolf, dies (results_doppelganger), on Ben's phone.
Future<void> pumpCountOne(WidgetTester tester, {double textScale = 1}) => _end(
  tester,
  recordedResults('results_doppelganger'),
  viewer: 'Ben',
  textScale: textScale,
);

/// 10: Fin, the Hunter, is voted out and takes Esme with him (results).
Future<void> pumpCountHunter(WidgetTester tester) =>
    _end(tester, recordedResults('results'), viewer: 'Ben');

/// 10: Ana dies; her card moved in the night (derived: no recording).
Future<void> pumpCountMoved(WidgetTester tester) =>
    _end(tester, derivedWerewolvesWin(), viewer: 'Ben');

/// 10: nobody dies (derived: no recording).
Future<void> pumpCountNobody(WidgetTester tester) =>
    _end(tester, derivedNobodyDies(), viewer: 'Ben');

/// 10: Dev, the Tanner, dies (results_tanner).
Future<void> pumpCountTanner(WidgetTester tester) =>
    _end(tester, recordedResults('results_tanner'), viewer: 'Ben');

/// 10 at ten, with long names (results_doppelganger and two more seats).
Future<void> pumpCountTen(WidgetTester tester) => _end(
  tester,
  widened(
    recordedResults('results_doppelganger'),
    add: 2,
    rename: longEndNames,
  ),
  viewer: 'Maximiliano',
  host: 'Christopher',
);

/// 10 as it opens, the rows landing, the dead card still face down.
Future<void> pumpCountOpening(WidgetTester tester) async {
  final results = recordedResults('results_doppelganger');
  final setup = await ShellSetup.pump(
    tester,
    resultsMeFor(results, viewer: 'Ben', host: 'Ana'),
    learned: Cue.values.toSet(),
    before: (s) => s.answerResults(results),
  );
  await setup.settle(tester);
}

/// 10 while the results will not load: the day's ground and "One moment".
Future<void> pumpCountWaiting(WidgetTester tester) async {
  final results = recordedResults('results_doppelganger');
  final setup = await ShellSetup.pump(
    tester,
    resultsMeFor(results, viewer: 'Ben', host: 'Ana'),
    before: (s) => s.failResults(),
  );
  await setup.settle(tester);
}

/// 11: the village wins (results: the Hunter took a Werewolf), on the
/// host's phone.
Future<void> pumpResultsVillage(
  WidgetTester tester, {
  double textScale = 1,
}) async {
  final setup = await _end(
    tester,
    recordedResults('results'),
    viewer: 'Ana',
    textScale: textScale,
  );
  await _seeWhoWon(tester, setup);
}

/// 11: the Werewolves win (derived: no recording), on Cleo's phone (a
/// Werewolf, a guest).
Future<void> pumpResultsWerewolves(WidgetTester tester) async {
  final setup = await _end(tester, derivedWerewolvesWin(), viewer: 'Cleo');
  await _seeWhoWon(tester, setup);
}

/// 11: nobody died and the Werewolves win (derived), on Ben's phone.
Future<void> pumpResultsNobody(WidgetTester tester) async {
  final setup = await _end(tester, derivedNobodyDies(), viewer: 'Ben');
  await _seeWhoWon(tester, setup);
}

/// 11: the Tanner wins alone (results_tanner), on Dev's phone (the Tanner).
Future<void> pumpResultsTanner(WidgetTester tester) async {
  final setup = await _end(
    tester,
    recordedResults('results_tanner'),
    viewer: 'Dev',
  );
  await _seeWhoWon(tester, setup);
}

/// 11 at the Doppelganger's game (her copy and follow-up, the Masons, the
/// Drunk taking a Werewolf from the center), on Ben's phone: the night open,
/// its red line from Left to Gus.
Future<void> pumpResultsNight(WidgetTester tester) async {
  final setup = await _end(
    tester,
    recordedResults('results_doppelganger'),
    viewer: 'Ben',
  );
  await _seeWhoWon(tester, setup);
  // Eight at the table: the night starts under the fade; scroll to it.
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
  await setup.settle(tester);
}

/// 11 with the night folded by a tap on its red line (the Hunter's game).
Future<void> pumpResultsFolded(WidgetTester tester) async {
  final setup = await _end(tester, recordedResults('results'), viewer: 'Ana');
  await _seeWhoWon(tester, setup);
  final night = find.bySemanticsLabel(ResultsCopy.nightSpoken);
  await tester.ensureVisible(night);
  await tester.pump();
  await tester.tap(night);
  await setup.settle(tester);
}

/// 11 scrolled to its end: the last of the night (the Hunter's game, on
/// the host's phone).
Future<void> pumpResultsEnd(WidgetTester tester) async {
  final setup = await _end(tester, recordedResults('results'), viewer: 'Ana');
  await _seeWhoWon(tester, setup);
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
  await setup.settle(tester);
}

/// 11 at ten with long names, on a guest's phone.
Future<void> pumpResultsTen(WidgetTester tester) async {
  final setup = await _end(
    tester,
    widened(
      recordedResults('results_doppelganger'),
      add: 2,
      rename: longEndNames,
    ),
    viewer: 'Maximiliano',
    host: 'Christopher',
  );
  await _seeWhoWon(tester, setup);
}
