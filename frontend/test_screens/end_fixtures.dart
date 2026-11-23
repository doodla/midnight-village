import '../test/helpers/finger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/presentation/shell/table_shell.dart';
import 'package:midnight_village/features/game/presentation/table_screen.dart';

import '../test/helpers/contract/contract_samples.dart';
import '../test/helpers/mock_http_client.dart';
import '../test/helpers/outcome_samples.dart';
import '../test/helpers/shell_setup.dart';

// 10 The count and 11 Results through the real shell (TableShell), as a
// phone at the end of a recorded game has them: `/me/` at the results
// (`me_results` at that game's table) and the results body
// (test/helpers/outcome_samples.dart, every one recorded). 11 is reached the way a player reaches it: "See who won".

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
  await pressLikeAFinger(tester, find.text(CountCopy.seeWhoWon));
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

/// 10: Ben dies; his card moved in the night (results_moved_dead_card: the
/// Robber took a Werewolf's card).
Future<void> pumpCountMoved(WidgetTester tester) =>
    _end(tester, recordedResults('results_moved_dead_card'), viewer: 'Ana');

/// 10: nobody dies (results_nobody_dies).
Future<void> pumpCountNobody(WidgetTester tester) =>
    _end(tester, recordedResults('results_nobody_dies'), viewer: 'Ben');

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

/// 11: the Werewolves win (results_werewolves_win), on Cleo's phone (a
/// Werewolf, a guest).
Future<void> pumpResultsWerewolves(WidgetTester tester) async {
  final setup = await _end(
    tester,
    recordedResults('results_werewolves_win'),
    viewer: 'Cleo',
  );
  await _seeWhoWon(tester, setup);
}

/// 11: nobody died and the Werewolves win (results_nobody_dies), on Ben's
/// phone.
Future<void> pumpResultsNobody(WidgetTester tester) async {
  final setup = await _end(
    tester,
    recordedResults('results_nobody_dies'),
    viewer: 'Ben',
  );
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
  await pressLikeAFinger(tester, night);
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

/// 11 of the pack's game (game 7), on Ben's phone (a guest), scrolled to
/// its end: the whole night, the Robber's take and the Troublemaker's swap
/// back above "Ana deals next."
Future<void> pumpResultsFiveEnd(WidgetTester tester) async {
  final setup = await _end(
    tester,
    recordedResults('results_five'),
    viewer: 'Ben',
  );
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
// ---------------------------------------------------------------------------
// Waiting and failing (issue 10)
// ---------------------------------------------------------------------------

/// The shell at the results with the results body held: the wait where the
/// count will be. [seeWhoWon] goes on to 11's wait.
Future<ShellSetup> _endHeld(
  WidgetTester tester, {
  required String viewer,
  String host = 'Ana',
  bool seeWhoWon = false,
}) async {
  final results = recordedResults('results');
  late HeldReplies held;
  final setup = await ShellSetup.pump(
    tester,
    resultsMeFor(results, viewer: viewer, host: host),
    learned: Cue.values.toSet(),
    before: (s) {
      s.answerResults(results);
      held = s.http.hold(
        method: 'GET',
        path: '/onuw/games/${s.gameId}/results/',
      );
    },
  );
  addTearDown(held.releaseAll);
  await setup.settle(tester);
  if (seeWhoWon) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TableShell)),
    );
    await container.read(localStepsProvider.notifier).seeWhoWon(setup.gameId);
    await setup.settle(tester);
  }
  return setup;
}

/// 10 while the results load: the day's ground and the wait.
Future<void> pumpCountLoading(WidgetTester tester) async {
  await _endHeld(tester, viewer: 'Ben');
}

/// 11 while the results load: the night's ground and the wait.
Future<void> pumpResultsLoading(WidgetTester tester) async {
  await _endHeld(tester, viewer: 'Ben', seeWhoWon: true);
}

/// The path of the table's play-again and leave.
String _tablePath(ShellSetup s, String endpoint) =>
    '/lobbies/${s.me['lobby_code']}/$endpoint/';

/// 11 with "Play again" tapped, the server not answered yet: that button
/// busy, "Edit deck" and "Leave" dim.
Future<void> pumpResultsPlayingAgain(WidgetTester tester) async {
  final setup = await _end(tester, recordedResults('results'), viewer: 'Ana');
  await _seeWhoWon(tester, setup);
  final path = _tablePath(setup, 'play-again');
  setup.http
    ..hold(method: 'POST', path: path)
    ..answer('POST', path, ContractSamples.load('http/lobby/play_again'));
  await pressLikeAFinger(tester, find.text(ResultsCopy.playAgain));
  await setup.settle(tester);
}

/// 11 on a guest's phone with "Leave" tapped, the server not answered yet.
Future<void> pumpResultsLeaving(WidgetTester tester) async {
  final setup = await _end(tester, recordedResults('results'), viewer: 'Ben');
  await _seeWhoWon(tester, setup);
  final path = _tablePath(setup, 'leave');
  setup.http
    ..hold(method: 'POST', path: path)
    ..answer('POST', path, ContractSamples.load('http/lobby/left'));
  await pressLikeAFinger(tester, find.text(CommonCopy.leave));
  await setup.settle(tester);
}

/// 11 when "Play again" got no answer: "Not sent." with "Try again".
Future<void> pumpResultsNotSent(WidgetTester tester) async {
  final setup = await _end(tester, recordedResults('results'), viewer: 'Ana');
  await _seeWhoWon(tester, setup);
  setup.http.answer(
    'POST',
    _tablePath(setup, 'play-again'),
    'Server Error',
    status: 503,
  );
  await pressLikeAFinger(tester, find.text(ResultsCopy.playAgain));
  await setup.settle(tester);
}

/// 11 when the server refuses "Play again" with a reason: no "Try again".
Future<void> pumpResultsRefused(WidgetTester tester) async {
  final setup = await _end(tester, recordedResults('results'), viewer: 'Ana');
  await _seeWhoWon(tester, setup);
  setup.http.answer(
    'POST',
    _tablePath(setup, 'play-again'),
    ContractSamples.load('http/lobby/play_again_not_finished'),
    status: 409,
  );
  await pressLikeAFinger(tester, find.text(ResultsCopy.playAgain));
  await setup.settle(tester);
}
