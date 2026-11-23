import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/end_board_metrics.dart';

import '../../../helpers/end_board_plans.dart';
import '../../../helpers/end_board_rules.dart';
import '../../../helpers/outcome_samples.dart';

// The end board's layout rules added for its fixing pass
// (docs/specs/frontend/end-board.md, section 3): the hanged in view when the
// board opens, the tags' columns and heights, a small group grown and centred,
// a pick for every Hunter.

void main() {
  group('the board opens on the hanged, and on you when both fit; opened '
      'down the board, the eave cuts a card', () {
    for (final (name, plan) in everyEndPlan()) {
      test(name, () => expectOpensByTheRule(plan, name: name));
    }
  });

  // Six or fewer fit one screen as far as the hard rule lets them: a board
  // that scrolls stands at the tightest fit step that covers nothing, and
  // opens by the rule. The hardest six-player boards (a Hunter hanged by five,
  // a three-and-three tie, long names) are cases of that rule, not of a fit.
  group('six or fewer that scroll gave up nothing they could give', () {
    final boards = {
      for (final e in endSamples.entries)
        if ((e.value['players'] as List).length <= EndMetrics.fitsUpTo)
          e.key: e.value,
      ...endWorstSix(),
    };
    for (final MapEntry(key: name, value: results) in boards.entries) {
      final ids = [
        for (final p in results['players'] as List)
          (p as Map)['player_id'] as int,
      ];
      for (final screen in [endPhone, endBig, endShort]) {
        for (final scale in [1.0, 1.3, 1.6]) {
          final where =
              '$name on ${screen.width.toInt()}x${screen.height.toInt()} '
              'at $scale';
          test(where, () {
            for (final viewer in ids) {
              final plan = endPlan(
                results,
                viewer: viewer,
                screen: screen,
                scale: scale,
              );
              final who = '$where for $viewer';
              expectGaveUpNothing(plan, name: who);
              expectOpensByTheRule(plan, name: who);
              expect(coverFaults(plan), isEmpty, reason: who);
              // Cards never shrink for it.
              for (final c in plan.cards) {
                expect(
                  c.portraitWidth,
                  greaterThanOrEqualTo(
                    c.won
                        ? EndMetrics.winnerPortrait
                        : EndMetrics.loserPortrait,
                  ),
                );
              }
            }
          });
        }
      }
    }
  });

  group('the tags', () {
    test('past three, a strand hangs in columns where they fit', () {
      // Ben, hanged, has five tags; Esme beside him has none: his strand
      // takes the row, in columns, under the lower of the two cards.
      final plan = endPlan(recordedResults('results_moved_dead_card'));
      final ben = plan.cards.firstWhere((c) => c.name == 'Ben');
      expect(ben.tags.length, 5);
      expect(ben.tags.map((t) => t.column).toSet().length, greaterThan(1));
      final esme = plan.cards.firstWhere((c) => c.name == 'Esme');
      for (final t in ben.tags) {
        expect(t.rect.overlaps(esme.leaned), isFalse);
      }
    });

    test('a tag is as tall as its name at the text size, at least 26', () {
      final one = endPlan(recordedResults('results'));
      final big = endPlan(recordedResults('results'), scale: 1.6);
      final t1 = one.cards.expand((c) => c.tags).first.rect.height;
      final t16 = big.cards.expand((c) => c.tags).first.rect.height;
      expect(t1, closeTo(EndMetrics.tagLeast, 0.001));
      expect(t16, greaterThan(t1));
    });
  });

  group('four players or fewer', () {
    test('each row grows as far as its own room lets it; the group stands '
        'centred', () {
      final plan = endPlan(recordedResults('results_three_players'));
      // The first row stops at the lantern; the row below has the width.
      final below = plan.cards.where((c) => c.row > 0);
      for (final c in below) {
        expect(
          c.portraitWidth,
          closeTo(
            (c.won ? EndMetrics.winnerPortrait : EndMetrics.loserPortrait) *
                EndMetrics.mostGrowth,
            0.01,
          ),
          reason: c.name,
        );
      }
      final top = plan.cards.map((c) => c.reach.top).reduce(math.min);
      final bottom = plan.cards.map((c) => c.reach.bottom).reduce(math.max);
      // As much air above the group as below it, give or take what hangs.
      expect(
        (top - (plan.boardHeight - bottom)).abs(),
        lessThan(EndMetrics.gapDealt + EndMetrics.insetTop),
      );
    });
  });

  group('the Hunter', () {
    test('every Hunter the vote took who took someone has a pick', () {
      for (final entry in endSamples.entries) {
        final plan = endPlan(entry.value);
        final chosen = plan.cards.where((c) => c.pickedByHunter).length;
        expect(plan.picks.length, chosen, reason: entry.key);
      }
    });
  });
}
