import 'dart:math' as math;
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
        // Every death, the Hunter's picks too: each gets its own beat.
        final hanged = [
          for (final c in plan.cards)
            if (c.hanged && !c.pickedByHunter) c,
          for (final c in plan.cards)
            if (c.hanged && c.pickedByHunter) c,
        ];
        expect(r.dead, [for (final c in hanged) c.id]);
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
        // A knock as each stamp lands (a thud), or one light one as the
        // banner unrolls when nobody hangs; all inside the reveal.
        expect(r.knocks, hasLength(hanged.isEmpty ? 1 : hanged.length));
        for (final k in r.knocks) {
          expect(ms(k), inInclusiveRange(0, ms(r.total)));
        }
        expect(r.thud, hanged.isNotEmpty);
        // Short: two and a half seconds for one death at any table, and
        // under a second more for each death after it; nobody hanged is
        // shorter than one.
        expect(
          ms(r.total),
          lessThanOrEqualTo(2500 + 960 * math.max(0, hanged.length - 1)),
        );
        if (hanged.isEmpty) expect(ms(r.total), lessThan(2030));
        // The seats never move: from the first frame the board stands where
        // the settled board opens, and nothing scrolls.
        expect(r.scroll, plan.scrolls ? plan.initialScroll : 0);
        // One size at the start: every back's portrait as wide as the least,
        // each back inside its card and centred on it, and as tall as every
        // other (a back says nothing of who won or who hangs).
        final least = plan.cards.map((c) => c.portraitWidth).reduce(math.min);
        expect(r.backPortrait, least);
        final heights = {
          for (final c in plan.cards) r.backs[c.id]!.height.toStringAsFixed(3),
        };
        expect(heights, hasLength(1));
        for (final c in plan.cards) {
          final back = r.backs[c.id]!;
          expect((back.center - c.rect.center).distance, lessThan(0.01));
          expect(back.width, lessThanOrEqualTo(c.rect.width + 0.01));
          expect(back.width, greaterThanOrEqualTo(least));
        }
        // The banner unrolls once.
        expect(r.all(RevealBeat.banner), hasLength(1));
        if (hanged.isEmpty) return;

        final lift = r.of(RevealBeat.lift)!;
        final stamp = r.of(RevealBeat.stamp)!;
        final view = Rect.fromLTWH(
          0,
          r.scroll,
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
          // Its own beat: up, face up on the way, stamped, back down.
          final mine = r.of(RevealBeat.stamp, card: c.id)!;
          final up = r.of(RevealBeat.lift, card: c.id)!;
          expect(r.turnOf(c.id).end, lessThanOrEqualTo(mine.start));
          expect(r.turnOf(c.id).start, greaterThanOrEqualTo(up.start));
          expect(
            r.of(RevealBeat.drop, card: c.id)!.start,
            greaterThanOrEqualTo(mine.end),
          );
          // The art fills its twin, and the twin is never smaller.
          expect(r.up[c.id]!.width, closeTo(c.rect.width, 0.01));
          expect(r.up[c.id]!.height, greaterThan(c.rect.height - 0.01));
          expect(big.width, greaterThanOrEqualTo(r.up[c.id]!.width - 0.01));
        }
        // One beat after the other: a card is back in its slot before the
        // next one lifts, so only one is ever up.
        for (var i = 1; i < hanged.length; i++) {
          expect(
            r.of(RevealBeat.lift, card: hanged[i].id)!.start,
            greaterThanOrEqualTo(
              r.of(RevealBeat.drop, card: hanged[i - 1].id)!.end,
            ),
          );
        }
        // A stamp and a knock for each; the banner with the first.
        expect(r.all(RevealBeat.stamp), hasLength(hanged.length));
        expect(r.knocks, [for (final s in r.all(RevealBeat.stamp)) s.end]);
        expect(lift.card, hanged.first.id);
        expect(r.of(RevealBeat.banner)!.start, stamp.start);
        // The rest turn while the last of the dead goes back, never before.
        final drop = r.of(RevealBeat.drop, card: hanged.last.id)!;
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
    expect(beats(RevealBeat.stamp), matches(r'^stamp #\d+ 820\+90$'));
    expect(beats(RevealBeat.banner), 'banner 820+500');
    expect(beats(RevealBeat.drop), matches(r'^drop #\d+ 1310\+260$'));
    expect(r.knocks.map(ms), [910]);
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

  test(
    'nobody hanged: the winners rise together and turn, then the banner '
    'unrolls with the light knock as they settle; shorter than a hanging',
    () {
      final plan = endPlan(endSamples['results_nobody_dies']!);
      final r = revealOf(plan);
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
      final rise = r.of(RevealBeat.rise)!;
      final banner = r.of(RevealBeat.banner)!;
      expect(rise.start, Motion.reveal);
      // Every winner turns as the rise begins; the pool comes on with them.
      for (final c in plan.cards.where((c) => c.won)) {
        expect(r.turnOf(c.id).start, rise.start, reason: c.name);
      }
      expect(r.of(RevealBeat.pool)!.start, rise.start);
      // Then the banner, the light knock, the winners back down, the rest.
      expect(banner.start, greaterThan(rise.end));
      expect(r.of(RevealBeat.lower)!.start, banner.start);
      expect(r.knocks, [banner.start]);
      for (final c in plan.cards.where((c) => !c.won)) {
        expect(r.turnOf(c.id).start, greaterThanOrEqualTo(banner.start));
      }
      expect(ms(r.total), 1390);
    },
  );

  test('a tie: each hanged gets its own beat, one after the other, the same '
      'size, a knock each', () {
    final plan = endPlan(endSamples['results_tie']!);
    final r = revealOf(plan);
    final lifts = r.all(RevealBeat.lift).toList();
    expect(lifts.length, greaterThanOrEqualTo(2));
    expect(lifts.map((s) => s.start).toSet(), hasLength(lifts.length));
    expect(r.all(RevealBeat.stamp), hasLength(lifts.length));
    expect(r.knocks, hasLength(lifts.length));
    final bigs = [for (final s in lifts) r.big[s.card]!];
    expect(bigs.map((b) => b.center).toSet(), hasLength(1));
    // Turned one way and then the other.
    expect(r.bigTurn[lifts[0].card]! * r.bigTurn[lifts[1].card]!, lessThan(0));
    expect(ms(r.total), 2880);
  });

  test('the Hunter: his pick gets a second, smaller land and stamp once he is '
      'back in his slot, and the twine after it', () {
    final plan = endPlan(endSamples['results']!);
    expect(plan.picks, hasLength(1));
    final p = plan.picks.single;
    final r = revealOf(plan);
    expect(r.dead, [p.hunterId, p.pickId]);
    final hunterDrop = r.of(RevealBeat.drop, card: p.hunterId)!;
    final pickLift = r.of(RevealBeat.lift, card: p.pickId)!;
    expect(pickLift.start, hunterDrop.end);
    expect(r.knocks, hasLength(2));
    expect(r.big[p.pickId]!.width, lessThan(r.big[p.hunterId]!.width));
    final pick = r.of(RevealBeat.pick, card: p.pickId)!;
    expect(pick.start, r.of(RevealBeat.drop, card: p.pickId)!.end);
    expect(pick.end, lessThanOrEqualTo(r.total));
    expect(ms(r.total), 2880);
  });

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

  test('three players: the backs have one portrait size, the hanged lands '
      'big', () {
    final plan = endPlan(endSamples['results_three_players']!);
    final r = revealOf(plan);
    for (final c in plan.cards) {
      expect(
        r.backs[c.id]!.height,
        lessThanOrEqualTo(c.rect.height),
        reason: c.name,
      );
    }
    for (final s in r.all(RevealBeat.lift)) {
      final c = plan.card(s.card!);
      expect(r.big[c.id]!.width / c.rect.width, greaterThan(1.5));
    }
  });

  test('ten players on a short phone: the board stands where it opens from '
      'the first frame, and the reveal stays short', () {
    final plan = endPlan(endSamples['doppelganger_10_long']!, screen: endShort);
    expect(plan.scrolls, isTrue);
    final r = revealOf(plan);
    expect(r.scroll, plan.initialScroll);
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
    expect(r.isUp(any.id, Duration.zero), isFalse);
  });
}
