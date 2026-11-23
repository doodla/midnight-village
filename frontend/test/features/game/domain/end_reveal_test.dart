import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/features/game/domain/end_board_cards.dart';
import 'package:midnight_village/features/game/domain/end_reveal.dart';

import '../../../helpers/end_board_plans.dart';
import '../../../helpers/outcome_samples.dart';

// The reveal's timeline (docs/specs/frontend/end-board.md, section 8): on every
// recorded results body and the widened ten-player tables, at three phone
// sizes and three text sizes (`everyEndPlan`), and beat by beat on the
// samples that each show one case: one hanged, nobody, a tie, the Hunter's
// second death, the Tanner, three players and ten.

int ms(Duration d) => d.inMilliseconds;

EndReveal revealFor(String sample, {Size screen = endPhone}) =>
    revealOf(endPlan(endSamples[sample]!, screen: screen));

void main() {
  group('on every board', () {
    for (final (name, plan) in everyEndPlan()) {
      test(name, () {
        final r = revealOf(plan);
        final hanged = [
          for (final c in plan.cards)
            if (c.hanged && !c.pickedByHunter) c,
        ];
        // Every card turns exactly once, and the reveal ends when its last
        // beat does.
        for (final c in plan.cards) {
          expect(
            r.all(RevealBeat.turn, card: c.id),
            hasLength(1),
            reason: c.name,
          );
        }
        final last = r.spans.map((s) => s.end).reduce((a, b) => a > b ? a : b);
        expect(r.total, last);
        expect(r.spans.every((s) => s.start >= Duration.zero), isTrue);
        // One vibration, inside the reveal; a thud only with a hanging.
        expect(ms(r.knockAt), inInclusiveRange(0, ms(r.total)));
        expect(r.thud, hanged.isNotEmpty);
        // Short: under two and a half seconds at any table.
        expect(ms(r.total), lessThanOrEqualTo(2500));
        // The settled board stands where piece 2's opens.
        expect(r.scrollTo, plan.scrolls ? plan.initialScroll : 0);
        // One size at the start: every card's portrait as wide as the least.
        final starts = {
          for (final c in plan.cards)
            (c.portraitWidth * r.startScale[c.id]!).toStringAsFixed(3),
        };
        expect(starts, hasLength(1));
        // The banner unrolls once.
        expect(r.all(RevealBeat.banner), hasLength(1));
        if (hanged.isEmpty) return;

        final lift = r.of(RevealBeat.lift)!;
        final stamp = r.of(RevealBeat.stamp)!;
        // The hanged are scrolled into view before they lift.
        final scroll = r.of(RevealBeat.scroll);
        if (scroll != null) expect(scroll.end, lessThanOrEqualTo(lift.start));
        final view = Rect.fromLTWH(
          0,
          r.scrollTo,
          plan.boardWidth,
          plan.seenAtTop,
        );
        final top = hanged
            .map((c) => c.leaned.top)
            .reduce((a, b) => a < b ? a : b);
        final bottom = hanged
            .map((c) => c.leaned.bottom)
            .reduce((a, b) => a > b ? a : b);
        for (final c in hanged) {
          expect(
            c.leaned.top,
            greaterThanOrEqualTo(view.top - 0.01),
            reason: c.name,
          );
          if (bottom - top <= view.height) {
            expect(
              c.leaned.bottom,
              lessThanOrEqualTo(view.bottom + 0.01),
              reason: '${c.name} below the lip',
            );
          }
          // Big, in the window, beside each other, and face up before the stamp.
          final big = r.big[c.id]!;
          expect(big.width, greaterThanOrEqualTo(c.rect.width - 0.01));
          expect(
            view.inflate(0.01).contains(big.topLeft),
            isTrue,
            reason: c.name,
          );
          expect(
            view.inflate(0.01).contains(big.bottomRight),
            isTrue,
            reason: '${c.name} big at $big leaves the window $view',
          );
          expect(r.turnOf(c.id).end, lessThanOrEqualTo(stamp.start));
          expect(r.turnOf(c.id).start, greaterThanOrEqualTo(lift.start));
        }
        for (final a in hanged) {
          for (final b in hanged) {
            if (a.id != b.id) {
              expect(r.big[a.id]!.overlaps(r.big[b.id]!), isFalse);
            }
          }
        }
        // One stamp however many are hanged; the knock as it lands; the
        // banner with it.
        expect(r.all(RevealBeat.stamp), hasLength(1));
        expect(r.knockAt, stamp.end);
        expect(r.of(RevealBeat.banner)!.start, stamp.start);
        // The rest turn while the hanged go back, never before.
        final drop = r.of(RevealBeat.drop)!;
        for (final c in plan.cards.where((c) => !hanged.contains(c))) {
          expect(r.turnOf(c.id).start, greaterThanOrEqualTo(drop.start));
        }
      });
    }
  });

  test('one hanged: hold, lift and turn, stamp and banner, drop, rows, '
      'then the board settles: 2.03 s at six', () {
    final r = revealFor('results_moved_dead_card');
    String beats(RevealBeat kind) => r.all(kind).join('; ');
    expect(beats(RevealBeat.hold), 'hold 0+400');
    expect(beats(RevealBeat.lift), matches(r'^lift #\d+ 400\+260$'));
    expect(beats(RevealBeat.stamp), 'stamp 820+90');
    expect(beats(RevealBeat.banner), 'banner 820+260');
    expect(beats(RevealBeat.drop), 'drop 1310+260');
    expect(ms(r.knockAt), 910);
    expect(r.thud, isTrue);
    // The rows turn 150 ms apart, the middle cards with the last.
    final rows = {
      for (final s in r.all(RevealBeat.turn))
        if (s.row != null) s.row!: ms(s.start),
    };
    final starts = rows.values.toList();
    for (var i = 1; i < starts.length; i++) {
      expect(starts[i] - starts[i - 1], ms(Motion.stagger));
    }
    expect(ms(r.of(RevealBeat.middle)!.start), starts.last);
    expect(ms(r.of(RevealBeat.tags)!.start), starts.last + ms(Motion.quick));
    expect(ms(r.total), 2030);
  });

  test('nobody hanged: no lift, no stamp; the banner unrolls as the tags tie '
      'on, with the light knock', () {
    final r = revealFor('results_nobody_dies');
    for (final kind in [
      RevealBeat.dim,
      RevealBeat.lift,
      RevealBeat.stamp,
      RevealBeat.drop,
      RevealBeat.ribbon,
    ]) {
      expect(r.all(kind), isEmpty, reason: kind.name);
    }
    expect(r.big, isEmpty);
    expect(r.thud, isFalse);
    final tags = r.of(RevealBeat.tags)!;
    expect(r.of(RevealBeat.banner)!.start, tags.start);
    expect(r.knockAt, tags.start);
    // The first row turns as the hold ends.
    expect(
      r
          .all(RevealBeat.turn)
          .map((s) => s.start)
          .reduce((a, b) => a < b ? a : b),
      Motion.reveal,
    );
  });

  test('a tie: the hanged lift together, side by side, under one stamp', () {
    final plan = endPlan(endSamples['results_tie']!);
    final r = revealOf(plan);
    final lifts = r.all(RevealBeat.lift).toList();
    expect(lifts.length, greaterThanOrEqualTo(2));
    expect(lifts.map((s) => s.start).toSet(), hasLength(1));
    expect(r.all(RevealBeat.stamp), hasLength(1));
    final bigs = [for (final s in lifts) r.big[s.card]!];
    expect(bigs.map((b) => b.center.dy.round()).toSet(), hasLength(1));
  });

  test(
    'the Hunter: his pick is told once both cards are up, after the drop',
    () {
      final plan = endPlan(endSamples['results']!);
      expect(plan.picks, hasLength(1));
      final r = revealOf(plan);
      final pick = r.of(RevealBeat.pick, card: plan.picks.single.pickId)!;
      expect(pick.start, greaterThanOrEqualTo(r.of(RevealBeat.drop)!.end));
      expect(
        pick.start,
        greaterThanOrEqualTo(r.turnOf(plan.picks.single.pickId).end),
      );
      expect(pick.end, lessThanOrEqualTo(r.total));
      // The Hunter is the one hanged; the pick is not lifted.
      expect(r.of(RevealBeat.lift, card: plan.picks.single.pickId), isNull);
      expect(
        r.of(RevealBeat.lift, card: plan.picks.single.hunterId),
        isNotNull,
      );
    },
  );

  test('a chain of Hunters: each pick after the one before', () {
    final r = revealFor('results_hunter_chain');
    final picks = r.all(RevealBeat.pick).toList();
    for (var i = 1; i < picks.length; i++) {
      expect(picks[i].start, greaterThanOrEqualTo(picks[i - 1].end));
    }
  });

  test('the Tanner hanged alone: one lift and the thud', () {
    final r = revealFor('results_tanner_alone');
    expect(r.all(RevealBeat.lift), hasLength(1));
    expect(r.thud, isTrue);
  });

  test('three players: the cards grow from one size, the hanged lands big', () {
    final plan = endPlan(endSamples['results_three_players']!);
    final r = revealOf(plan);
    for (final c in plan.cards) {
      expect(r.startScale[c.id], c.won ? lessThan(1) : 1, reason: c.name);
    }
    for (final s in r.all(RevealBeat.lift)) {
      final c = plan.card(s.card!);
      expect(r.big[c.id]!.width / c.rect.width, greaterThan(1.5));
    }
  });

  test('ten players on a short phone: the board scrolls to the hanged in the '
      'hold, and the reveal stays short', () {
    final plan = endPlan(endSamples['doppelganger_10_long']!, screen: endShort);
    expect(plan.scrolls, isTrue);
    final r = revealOf(plan);
    final scroll = r.of(RevealBeat.scroll);
    if (plan.initialScroll > 0) {
      expect(scroll, isNotNull);
      expect(scroll!.end, r.of(RevealBeat.hold)!.end);
    }
    expect(ms(r.total), lessThanOrEqualTo(2400));
    expect(
      r.all(RevealBeat.turn).map((s) => s.row).toSet().length,
      greaterThanOrEqualTo(4),
    );
  });

  test('RevealSpan.at runs 0 to 1 over its length', () {
    const s = RevealSpan(
      RevealBeat.hold,
      Duration(milliseconds: 100),
      Duration(milliseconds: 200),
    );
    expect(s.at(Duration.zero), 0);
    expect(s.at(const Duration(milliseconds: 200)), 0.5);
    expect(s.at(const Duration(seconds: 1)), 1);
    expect(outcomeOf(recordedResults('results')).seats, isNotEmpty);
  });

  test('EndReveal.at is 1 for a beat that is not there', () {
    final r = revealFor('results_nobody_dies');
    expect(r.at(RevealBeat.lift, Duration.zero), 1);
    expect(r.anyHanged, isFalse);
    final EndCard any = endPlan(endSamples['results_nobody_dies']!).cards.first;
    expect(r.turnOf(any.id).kind, RevealBeat.turn);
  });
}
