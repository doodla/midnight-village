import 'dart:ui';

import 'package:midnight_village/features/game/domain/end_board.dart';
import 'package:midnight_village/features/game/domain/end_board_metrics.dart';
import 'package:midnight_village/features/game/domain/game_outcome.dart';

import 'outcome_samples.dart';

// The end board's plans for the layout tests (`end_board_test.dart`,
// `end_board_rules_test.dart`): every recorded results body and the table
// sizes no recording has (the recordings widened), on three phones, for the
// first and the last seat, at text sizes 1, 1.3 and 1.6. The measure is a plain
// stand-in for the serif (a name 8.4 a letter, a role 6.8 a letter, times the
// text size); the drawn board on the real fonts is `end_board_sweep_test.dart`.

double endMeasure(EndText kind, String text) => switch (kind) {
  EndText.role => text.length * 6.8,
  _ => text.length * 8.4,
};

const endPhone = Size(360, 780);
const endBig = Size(390, 844);
const endShort = Size(360, 640);

/// The mocks' foot: what the board's window leaves under it.
const endFoot = 148.0;

EndBoardPlan endPlan(
  Map<String, dynamic> results, {
  int? viewer,
  Size screen = endPhone,
  double bannerHeight = 128,
  double scale = 1,
  bool host = true,
  double Function(EndText, String) measure = endMeasure,
}) {
  final outcome = GameOutcome.fromJson(results);
  final boardTop = EndMetrics.boardTopFor(screen.height, bannerHeight);
  return planEndBoard(
    outcome: outcome,
    viewerId: viewer ?? outcome.seats.first.id,
    isHost: host,
    hostName: host ? null : outcome.seats.first.name,
    screen: screen,
    boardTop: boardTop,
    viewHeight: screen.height - endFoot - boardTop,
    nameLine: 17.6 * scale,
    roleLine: 14.4 * scale,
    measure: (kind, text) => measure(kind, text) * scale,
  );
}

/// A table of [n] (6 to 10) as the recordings have them, with the long names.
Map<String, dynamic> endTable(int n, {bool longNames = false}) {
  final base = n <= 8 ? 'results_doppelganger' : 'results_doppelganger';
  final results = recordedResults(base);
  final have = (results['players'] as List).length;
  if (n < have) throw ArgumentError('no recording of $n');
  return widened(
    results,
    add: n - have,
    rename: longNames ? longEndNames : const {},
  );
}

final endSamples = <String, Map<String, dynamic>>{
  for (final name in [
    'results',
    'results_tie',
    'results_nobody_dies',
    'results_werewolves_win',
    'results_tanner_alone',
    'results_three_players',
    'results_doppelganger',
    'results_five',
    'results_moved_dead_card',
    'results_hunter_chain',
  ])
    name: recordedResults(name),
  for (final n in [9, 10]) 'doppelganger_$n': endTable(n),
  'doppelganger_10_long': endTable(10, longNames: true),
  'hunter_10': widened(recordedResults('results'), add: 4),
  'werewolves_10': widened(recordedResults('results_werewolves_win'), add: 4),
};

Iterable<(String, EndBoardPlan)> everyEndPlan() sync* {
  for (final entry in endSamples.entries) {
    final ids = [
      for (final p in entry.value['players'] as List)
        (p as Map)['player_id'] as int,
    ];
    for (final screen in [endPhone, endBig, endShort]) {
      for (final viewer in [ids.first, ids.last]) {
        for (final scale in [1.0, 1.3, 1.6]) {
          yield (
            '${entry.key} on ${screen.width.toInt()}x${screen.height.toInt()} '
                'for $viewer at $scale',
            endPlan(entry.value, viewer: viewer, screen: screen, scale: scale),
          );
        }
      }
    }
  }
}
