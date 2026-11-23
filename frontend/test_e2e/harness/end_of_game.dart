import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/features/game/presentation/end/end_board_view.dart';

import 'live_table.dart';
import 'time_budget.dart';
import 'ui_harness.dart';

/// The end of a game on [name]'s phone, already open on the game's shell:
/// the end board, checked against the oracle, not against anything typed by
/// the caller. Every card the server eliminated (by the vote and by the
/// Hunter) says "Hanged."; this phone's own card says "Won." when the server
/// says it won (and it was not hanged), and not otherwise; with nobody dead
/// the banner says so. A phone that was in the game sees the reveal: it is
/// caught as it plays, and one touch settles it. Shared by the UI runners
/// (`ui_end_test.dart` opens a phone at the results; `ui_game_test.dart`
/// plays its phone there).
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
  final dead = [
    for (final MapEntry(key: id, value: why) in reasons.entries)
      if (why == 'vote' || why == 'hunter_chain') byId[id]!.displayName,
  ];
  final outcome =
      (results['player_outcomes'] as Map)['${table.player(name).userId}'];
  bool shows<T extends Widget>() => find.byType(T).evaluate().isNotEmpty;

  final semantics = tester.ensureSemantics();
  try {
    await ui.pumpUntil(shows<EndBoardView>, reason: 'the end board');
    // As it opens: a phone that was in the game is in its reveal.
    ui.captureMidMotion = true;
    await shoot('end-opening');
    // One touch anywhere settles the reveal (if it plays).
    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    await ui.settle();
    // A card's words for a screen reader begin "{name}." or "{name}, ".
    Finder card(String who, String saying) => find.bySemanticsLabel(
      RegExp('^${RegExp.escape(who)}[.,].*${RegExp.escape(saying)}'),
    );
    for (final who in dead) {
      expect(
        card(who, EndCopy.hangedWord).evaluate(),
        isNotEmpty,
        reason: '$who was eliminated',
      );
    }
    if (!dead.contains(name)) {
      expect(
        card(name, EndCopy.wonWord).evaluate().isNotEmpty,
        outcome == 'win',
        reason: '$name: $outcome',
      );
    }
    if (dead.isEmpty) {
      expect(
        find
            .bySemanticsLabel(RegExp(RegExp.escape(EndCopy.nobodyHanged)))
            .evaluate(),
        isNotEmpty,
        reason: 'nobody was eliminated',
      );
    }
    await shoot('end');
  } finally {
    semantics.dispose();
  }
}
