import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/end_board_metrics.dart';

import '../../../helpers/end_board_plans.dart';
import '../../../helpers/outcome_samples.dart';

// The end board's layout rules added for its fixing pass
// (docs/specs/frontend/end-board.md, section 3): the hanged in view when the
// board opens, the tags' columns and heights, a small group grown and centred,
// a pick for every Hunter.

void main() {
  group('the board opens on the hanged, and on you when both fit', () {
    for (final (name, plan) in everyEndPlan()) {
      test(name, () {
        final top = plan.initialScroll;
        expect(top, greaterThanOrEqualTo(0));
        expect(top, lessThanOrEqualTo(plan.boardHeight - plan.viewHeight));
        if (!plan.scrolls) expect(top, 0);
        // What the window shows at that scroll, above the foot's lip.
        final seen = Rect.fromLTRB(
          0,
          top,
          plan.boardWidth,
          top + plan.viewHeight - EndMetrics.lip,
        );
        bool inView(Rect r) =>
            seen.inflate(0.5).contains(r.topLeft) &&
            seen.inflate(0.5).contains(r.bottomRight);
        final hanged = plan.cards.where((c) => c.hanged).toList();
        for (final c in hanged) {
          expect(
            inView(c.leaned),
            isTrue,
            reason: '${c.name} (hanged) is not in view: ${c.leaned} in $seen',
          );
        }
        if (!plan.scrolls || hanged.isEmpty) return;
        final you = plan.cards.firstWhere((c) => c.you);
        final yours = you.sealRect == null
            ? you.leaned
            : you.leaned.expandToInclude(you.sealRect!);
        final together = [
          yours,
          ...hanged.map((c) => c.reach),
        ].reduce((a, b) => a.expandToInclude(b));
        if (together.height + 2 * EndMetrics.clear <= seen.height) {
          expect(inView(yours), isTrue, reason: 'your card is not in view');
        } else if (top > 0) {
          // More above: the eave cuts a card, as the lip cuts one below.
          expect(
            plan.cards.any(
              (c) => c.leaned.top < top - 1 && c.leaned.bottom > top + 1,
            ),
            isTrue,
            reason: 'opened down the board with no card cut by the eave',
          );
        }
      });
    }
  });

  group('six players or fewer fit a 360 x 780 phone at text size 1', () {
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
      for (final viewer in [ids.first, ids.last]) {
        test('$name for $viewer', () {
          final plan = endPlan(results, viewer: viewer);
          expect(plan.scrolls, isFalse, reason: 'it scrolls');
          expect(plan.boardHeight, plan.viewHeight);
          // Cards never shrink for it.
          for (final c in plan.cards) {
            expect(
              c.portraitWidth,
              greaterThanOrEqualTo(
                c.won ? EndMetrics.winnerPortrait : EndMetrics.loserPortrait,
              ),
            );
          }
          // Nothing hung on a card lies on another card or tag.
          final tags = plan.cards.expand((c) => c.tags).map((t) => t.rect);
          for (final c in plan.cards) {
            for (final t in tags) {
              expect(t.overlaps(c.leaned.deflate(1)), isFalse);
            }
            for (final d in plan.cards.where((d) => d != c)) {
              expect(c.leaned.overlaps(d.leaned.deflate(1)), isFalse);
            }
          }
        });
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
