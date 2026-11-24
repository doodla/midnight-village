import '../test/helpers/finger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../test/helpers/contract/contract_samples.dart';
import '../test/helpers/mock_http_client.dart';
import '../test/helpers/outcome_samples.dart';
import '../test/helpers/shell_setup.dart';

// The results phase through the real shell (TableShell), as a phone at the
// end of a recorded game has it: `/me/` at the results (`me_results` at that
// game's table) and the results body (test/helpers/outcome_samples.dart,
// every one recorded). The end board's live states (loading, a request on its
// way, failed, refused) are in the gallery.

/// The shell at the end of the game of [results] on [viewer]'s phone,
/// [host] the host; the reveal's motion run to its end.
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

// ---------------------------------------------------------------------------
// Waiting and failing (issue 10)
// ---------------------------------------------------------------------------

/// The shell at the results with the results body held: the wait where the
/// board will be.
Future<ShellSetup> _endHeld(
  WidgetTester tester, {
  required String viewer,
  String host = 'Ana',
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
  return setup;
}

/// The end board while the results load: the night's ground and the wait.
Future<void> pumpResultsLoading(WidgetTester tester) async {
  await _endHeld(tester, viewer: 'Ben');
}

/// The path of the table's play-again and leave.
String _tablePath(ShellSetup s, String endpoint) =>
    '/lobbies/${s.me['lobby_code']}/$endpoint/';

/// The end board with "Play again" tapped, the server not answered yet: that
/// button busy.
Future<void> pumpResultsPlayingAgain(WidgetTester tester) async {
  final setup = await _end(tester, recordedResults('results'), viewer: 'Ana');
  final path = _tablePath(setup, 'play-again');
  setup.http
    ..hold(method: 'POST', path: path)
    ..answer('POST', path, ContractSamples.load('http/lobby/play_again'));
  await plainTap(
    tester,
    find.text(EndCopy.playAgain),
    why: 'the gallery\'s picture of a busy button is timed from the tap',
  );
  await setup.settle(tester);
}

/// The end board on a guest's phone with "Leave" tapped, the server not answered yet.
Future<void> pumpResultsLeaving(WidgetTester tester) async {
  final setup = await _end(tester, recordedResults('results'), viewer: 'Ben');
  final path = _tablePath(setup, 'leave');
  setup.http
    ..hold(method: 'POST', path: path)
    ..answer('POST', path, ContractSamples.load('http/lobby/left'));
  await plainTap(
    tester,
    find.text(EndCopy.leave),
    why: 'the gallery\'s picture of a busy button is timed from the tap',
  );
  await setup.settle(tester);
}

/// The end board when "Play again" got no answer: "Not sent." with "Try again".
Future<void> pumpResultsNotSent(WidgetTester tester) async {
  final setup = await _end(tester, recordedResults('results'), viewer: 'Ana');
  setup.http.answer(
    'POST',
    _tablePath(setup, 'play-again'),
    'Server Error',
    status: 503,
  );
  await pressLikeAFinger(tester, find.text(EndCopy.playAgain));
  await setup.settle(tester);
}

/// The end board when the server refuses "Play again" with a reason: no "Try again".
Future<void> pumpResultsRefused(WidgetTester tester) async {
  final setup = await _end(tester, recordedResults('results'), viewer: 'Ana');
  setup.http.answer(
    'POST',
    _tablePath(setup, 'play-again'),
    ContractSamples.load('http/lobby/play_again_not_finished'),
    status: 409,
  );
  await pressLikeAFinger(tester, find.text(EndCopy.playAgain));
  await setup.settle(tester);
}
