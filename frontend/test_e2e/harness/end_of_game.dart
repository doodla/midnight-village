import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/face_content.dart'
    show nameList;
import 'package:midnight_village/features/game/presentation/shell/count_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/results_screen.dart';

import 'live_table.dart';
import 'time_budget.dart';
import 'ui_harness.dart';

/// The end of a game on [name]'s phone, already open on the
/// game's shell, checked against the oracle, not against anything typed by
/// the caller: 10's headline names whom the server eliminated by the vote
/// (in seat order) and each the Hunter took; "See who won"; 11 says the
/// server's winning teams and this phone's own outcome. Shared by the
/// UI runners (`ui_end_test.dart` opens a phone at the
/// results; `ui_game_test.dart` plays its phone there).
Future<void> endAsTheOracleSays({
  required WidgetTester tester,
  required UiHarness ui,
  required LiveTable table,
  required String name,
  required Future<void> Function(String state) shoot,
}) async {
  final oracle = (await tester.runAsync(
    () => table.oracleJson().timeout(eventTimeout),
  ))!;
  final results = oracle['results'] as Map<String, dynamic>;
  final reasons = (results['elimination_reasons'] as Map)
      .cast<String, String>();
  final byId = {for (final p in table.table.players) '${p.userId}': p};
  final seats = [for (final p in table.table.players) '${p.userId}'];
  List<String> dead(String why) => [
    for (final id in seats)
      if (reasons[id] == why) byId[id]!.displayName,
  ];
  final byVote = dead('vote');
  final byHunter = dead('hunter_chain');
  final headline = switch (byVote) {
    [] => CountCopy.nobodyDies,
    [final one] => CountCopy.dies.fill({'name': one}),
    final several => CountCopy.die.fill({'names': nameList(several)}),
  };
  final teams = (results['winning_teams'] as List).cast<String>().toSet();
  final winners = {
    'village': ResultsCopy.villageWins,
    'werewolf': ResultsCopy.werewolvesWin,
    'tanner': ResultsCopy.tannerWins,
  };
  final outcome =
      (results['player_outcomes'] as Map)['${table.player(name).userId}'];
  bool shows<T extends Widget>() => find.byType(T).evaluate().isNotEmpty;
  bool text(String t) => find.text(t).evaluate().isNotEmpty;

  await ui.pumpUntil(shows<CountView>, reason: '10 The count');
  await shoot('count-opening');
  await tester.tap(find.byType(CountView), warnIfMissed: false);
  await tester.pump();
  expect(text(headline), isTrue, reason: headline);
  for (final picked in byHunter) {
    expect(
      find.textContaining('$picked, ').evaluate(),
      isNotEmpty,
      reason: "the Hunter's pick, $picked",
    );
  }
  await shoot('count');

  await tester.tap(find.text(CountCopy.seeWhoWon));
  await tester.pump();
  await ui.settle();
  await ui.pumpUntil(shows<ResultsView>, reason: '11 Results');
  expect(teams, hasLength(1), reason: 'one winning team in these games');
  expect(text(winners[teams.single]!), isTrue, reason: 'winners: $teams');
  expect(
    text(outcome == 'win' ? ResultsCopy.youWon : ResultsCopy.youLost),
    isTrue,
    reason: '$name: $outcome',
  );
  await shoot('results');
}
