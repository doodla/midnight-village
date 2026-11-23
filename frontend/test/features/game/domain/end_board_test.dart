import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/features/game/domain/end_board.dart';
import 'package:midnight_village/features/game/domain/end_board_metrics.dart';

import '../../../helpers/end_board_plans.dart';
import '../../../helpers/outcome_samples.dart';

// The end board's layout (docs/specs/frontend/end-board.md, section 3), on
// every recorded results body and on the table sizes no recording has (the
// recordings widened, as `widened` does), at text sizes 1, 1.3 and 1.6. The
// measure is a plain stand-in for the serif (a name 8.4 a letter, a role 6.8 a
// letter, times the text size): the invariants hold whatever the letters
// measure, and the screen sweep (`end_board_pages.dart`) checks the drawn board on the real
// fonts.

void main() {
  group('no card overlaps another, the lantern or the board\'s edge', () {
    for (final (name, plan) in everyEndPlan()) {
      test(name, () {
        final inner = Rect.fromLTWH(0, 0, plan.boardWidth, plan.boardHeight);
        final lantern = plan.lantern.deflate(8);
        for (final card in plan.cards) {
          expect(
            inner.contains(card.leaned.topLeft) &&
                inner.contains(card.leaned.bottomRight),
            isTrue,
            reason: '${card.name} leaves the board: ${card.leaned} in $inner',
          );
          // Everything pinned to it too (the tags, the ribbon, the seal).
          final reach = card.reach;
          expect(reach.left, greaterThanOrEqualTo(0), reason: card.name);
          expect(reach.top, greaterThanOrEqualTo(0), reason: card.name);
          expect(
            reach.right,
            lessThanOrEqualTo(plan.boardWidth),
            reason: card.name,
          );
          expect(
            reach.bottom,
            lessThanOrEqualTo(plan.boardHeight),
            reason: card.name,
          );
          expect(
            card.leaned.overlaps(lantern),
            isFalse,
            reason: '${card.name} under the lantern',
          );
          for (final part in [card.dealtRect, card.ribbonRect, card.sealRect]) {
            if (part != null) {
              expect(
                part.overlaps(lantern),
                isFalse,
                reason: '${card.name}\'s mark under the lantern',
              );
            }
          }
        }
        for (final a in plan.cards) {
          for (final b in plan.cards) {
            if (a.id >= b.id) continue;
            expect(
              a.leaned.overlaps(b.leaned),
              isFalse,
              reason: '${a.name} and ${b.name} overlap',
            );
          }
        }
      });
    }
  });

  group('what hangs on a card covers no other card, name or tag', () {
    for (final (name, plan) in everyEndPlan()) {
      test(name, () {
        for (final a in plan.cards) {
          final hung = <(String, Rect)>[
            if (a.dealtRect != null) ('dealt card', a.dealtRect!),
            if (a.ribbonRect != null) ('ribbon', a.ribbonRect!),
            if (a.sealRect != null) ('seal', a.sealRect!),
            if (a.pin != null) ('pin', a.pin!),
            for (final t in a.tags) ('tag of ${t.name}', t.rect),
          ];
          for (final (what, rect) in hung) {
            for (final b in plan.cards) {
              if (a.id == b.id) {
                // A tag, a seal or a ribbon never covers its own name.
                if (what != 'dealt card' && what != 'pin') {
                  expect(
                    rect.overlaps(a.nameText),
                    isFalse,
                    reason: '${a.name}\'s $what covers its name',
                  );
                }
                continue;
              }
              expect(
                rect.overlaps(b.leaned),
                isFalse,
                reason: '${a.name}\'s $what covers ${b.name}',
              );
              for (final t in b.tags) {
                if (what.startsWith('tag')) {
                  expect(
                    rect.overlaps(t.rect),
                    isFalse,
                    reason: '${a.name}\'s $what covers a tag of ${b.name}',
                  );
                }
              }
            }
          }
          // A strand hangs in its card's column, every tag clear of the next.
          for (final t in a.tags) {
            for (final u in a.tags) {
              if (identical(t, u)) continue;
              expect(
                t.rect.overlaps(u.rect),
                isFalse,
                reason: '${t.name}\'s and ${u.name}\'s tags touch',
              );
            }
            expect(
              t.rect.left >= a.column.left - 0.01 &&
                  t.rect.right <= a.column.right + 0.01,
              isTrue,
              reason: '${t.name}\'s tag leaves ${a.name}\'s column',
            );
          }
        }
        for (final pick in plan.picks) {
          for (final c in plan.cards) {
            expect(
              pick.slip.overlaps(c.nameText),
              isFalse,
              reason: 'the Hunter\'s slip covers ${c.name}',
            );
            for (final t in c.tags) {
              expect(pick.slip.overlaps(t.rect), isFalse);
            }
            if (c.id != pick.hunterId && c.id != pick.pickId) {
              expect(
                pick.slip.overlaps(c.leaned),
                isFalse,
                reason: 'the Hunter\'s slip covers ${c.name}',
              );
            }
            for (final part in [c.sealRect, c.ribbonRect]) {
              if (part != null) expect(pick.slip.overlaps(part), isFalse);
            }
          }
          expect(
            pick.slip.left >= 0 && pick.slip.right <= plan.boardWidth,
            isTrue,
          );
        }
      });
    }
  });

  group('the order and the rows', () {
    test('living winners, living losers, then the dead: the vote\'s, then '
        'the Hunter\'s pick', () {
      // results: Ana, Ben, Dev win and live; Cleo loses and lives; Fin (the
      // Hunter) is hanged and takes Esme.
      final plan = endPlan(recordedResults('results'));
      expect(
        [for (final c in plan.cards) c.name],
        ['Ana', 'Ben', 'Dev', 'Cleo', 'Fin', 'Esme'],
      );
      expect(plan.rows, [
        [0, 1],
        [2, 3],
        [4, 5],
      ]);
      expect(plan.cards[4].hanged && plan.cards[5].hanged, isTrue);
      expect(plan.cards[5].pickedByHunter, isTrue);
      expect(plan.cards[4].pickedByHunter, isFalse);
    });

    test('a single living card joins the dead in the last row, the dead on '
        'the left', () {
      // results_werewolves_win: Fin is hanged; five live; the last living
      // card (a loser) stands beside Fin.
      final plan = endPlan(recordedResults('results_werewolves_win'));
      final last = plan.rows.last;
      expect(last.length, 2);
      expect(plan.cards[last[0]].hanged, isTrue);
      expect(plan.cards[last[1]].hanged, isFalse);
    });

    test('a tie: every hanged card is in the dead rows, each with its own '
        'strand', () {
      final plan = endPlan(recordedResults('results_tie'));
      final hanged = plan.cards.where((c) => c.hanged).toList();
      expect([for (final c in hanged) c.name], ['Cleo', 'Dev']);
      expect(hanged.every((c) => c.ribbonRect != null), isTrue);
      expect(hanged.every((c) => c.tags.isNotEmpty), isTrue);
      expect(
        plan.cards.where((c) => !c.hanged).every((c) => c.tags.isEmpty),
        isTrue,
      );
    });

    test('nobody hanged: no ribbon, and every card carries the one tag of '
        'whoever voted for it', () {
      final plan = endPlan(recordedResults('results_nobody_dies'));
      expect(plan.nobodyHanged, isTrue);
      expect(plan.cards.any((c) => c.hanged || c.ribbonRect != null), isFalse);
      expect(plan.cards.every((c) => c.tags.length == 1), isTrue);
      // Ana voted for Ben: Ben's tag is Ana's.
      expect(
        plan.cards.firstWhere((c) => c.name == 'Ben').tags.single.name,
        'Ana',
      );
    });

    test('a player who did not vote has no tag', () {
      final plan = endPlan(recordedResults('results_doppelganger'));
      // Dev, Esme, Fin, Gus and Hana did not vote: only Ana and Ben did.
      final tags = [for (final c in plan.cards) ...c.tags];
      expect(tags.map((t) => t.name).toSet(), {'Ana', 'Ben'});
      expect(plan.card(9).tags.length, 2);
    });

    test('the Hunter: the pick dies too, the slip hangs between them', () {
      final plan = endPlan(recordedResults('results'));
      final pick = plan.picks.single;
      expect(plan.card(pick.hunterId).name, 'Fin');
      expect(plan.card(pick.pickId).name, 'Esme');
      expect(pick.hunterName, 'Fin');
      expect(pick.slip.width, greaterThan(EndMetrics.slipRoom));
      // The pick's card carries no tags (it was not hanged by the vote).
      expect(plan.card(pick.pickId).tags, isEmpty);
      expect(plan.card(pick.hunterId).tags, isNotEmpty);
    });

    test('no Hunter, no slip', () {
      for (final name in [
        'results_tie',
        'results_three_players',
        'results_tanner_alone',
      ]) {
        expect(endPlan(recordedResults(name)).picks, isEmpty, reason: name);
      }
    });

    test('the dealt card shows only when the role changed', () {
      final plan = endPlan(recordedResults('results'));
      // Ana was dealt the Seer and ends the Troublemaker; Cleo never moved.
      expect(plan.cards.firstWhere((c) => c.name == 'Ana').dealt, isNotNull);
      expect(plan.cards.firstWhere((c) => c.name == 'Cleo').dealt, isNull);
    });

    test('a Doppelganger\'s face is the role she copied; the strip says '
        'Doppelganger', () {
      final plan = endPlan(recordedResults('results_doppelganger'));
      final ana = plan.cards.firstWhere((c) => c.name == 'Ana');
      expect(ana.face.displayName, 'Seer');
      expect(ana.strip.displayName, 'Doppelganger');
      expect(ana.dealt, isNull);
    });

    test('winners are larger than losers, and the Tanner who wins is a '
        'winner', () {
      final plan = endPlan(recordedResults('results_tanner_alone'));
      final dev = plan.cards.firstWhere((c) => c.name == 'Dev');
      final ana = plan.cards.firstWhere((c) => c.name == 'Ana');
      expect(dev.won, isTrue);
      expect(dev.portraitWidth, greaterThan(ana.portraitWidth));
      expect(dev.hanged, isTrue);
      expect(dev.lit, isFalse, reason: 'the pool lights the living only');
    });

    test('red paper is the Werewolf team\'s, won or lost', () {
      final plan = endPlan(recordedResults('results_werewolves_win'));
      expect(
        {for (final c in plan.cards) c.name: c.look}['Cleo'],
        EndCardLook.werewolfWon,
      );
      final lost = endPlan(recordedResults('results'));
      expect(
        lost.cards.firstWhere((c) => c.name == 'Cleo').look,
        EndCardLook.werewolfLost,
      );
    });

    test('the centre cards are the three nobody held', () {
      final plan = endPlan(recordedResults('results'));
      expect(
        [for (final r in plan.centre) r.displayName],
        ['Villager', 'Insomniac', 'Villager'],
      );
    });
  });

  group('sizes', () {
    test('winners 90, losers 64 at six and more; never smaller', () {
      for (final entry in endSamples.entries) {
        final n = (entry.value['players'] as List).length;
        if (n <= EndMetrics.growsUpTo) continue;
        final plan = endPlan(entry.value);
        expect(plan.growth, 1, reason: entry.key);
        for (final c in plan.cards) {
          expect(
            c.portraitWidth,
            c.won ? EndMetrics.winnerPortrait : EndMetrics.loserPortrait,
            reason: '${entry.key} ${c.name}',
          );
        }
      }
    });

    test('five or fewer: the cards grow, up to 1.3, while they fit', () {
      for (final name in ['results_three_players', 'results_five']) {
        final plan = endPlan(recordedResults(name), screen: endBig);
        expect(plan.growth, greaterThan(1), reason: name);
        expect(plan.growth, lessThanOrEqualTo(EndMetrics.mostGrowth));
        expect(plan.scrolls, isFalse);
        for (final c in plan.cards) {
          final base = c.won
              ? EndMetrics.winnerPortrait
              : EndMetrics.loserPortrait;
          expect(c.portraitWidth / base, inInclusiveRange(1, plan.growth));
        }
      }
      // On the short phone three players still grow as far as they fit.
      final short = endPlan(
        recordedResults('results_three_players'),
        screen: endShort,
      );
      expect(short.growth, greaterThanOrEqualTo(1));
    });

    test('7 or more scroll; 6 fit one screen at 390x844, and at 360x780 '
        'unless a hanged winner carries a strand or one has four tags', () {
      for (final n in [7, 8, 9, 10]) {
        final plan = endPlan(endTable(n < 8 ? 8 : n));
        expect(plan.scrolls, isTrue, reason: '$n');
      }
      for (final name in [
        'results',
        'results_tie',
        'results_nobody_dies',
        'results_werewolves_win',
        'results_tanner_alone',
        'results_moved_dead_card',
        'results_hunter_chain',
      ]) {
        final n = (recordedResults(name)['players'] as List).length;
        final plan = endPlan(recordedResults(name));
        final hangedWinner = plan.cards.any(
          (c) => c.hanged && c.won && c.tags.isNotEmpty,
        );
        // Spec section 3: six fit, except the rare table with a strand of four tags
        // and a dealt card in every row.
        final longest = plan.cards
            .map((c) => c.tags.length)
            .fold(0, (a, b) => a > b ? a : b);
        if (n == 6 && longest <= 3) {
          expect(
            endPlan(recordedResults(name), screen: endBig).scrolls,
            isFalse,
            reason: '$name at 390x844',
          );
        }
        if (n == 6 && longest <= 3 && !hangedWinner) {
          expect(plan.scrolls, isFalse, reason: name);
        }
      }
      final seven = widened(recordedResults('results'), add: 1);
      expect(endPlan(seven).scrolls, isTrue);
      expect(
        endPlan(widened(recordedResults('results'), add: 4)).scrolls,
        isTrue,
      );
    });

    test('when it scrolls and opens at the top, a card is cut by the bottom '
        'edge', () {
      for (final entry in endSamples.entries) {
        for (final screen in [endPhone, endBig, endShort]) {
          final plan = endPlan(entry.value, screen: screen);
          if (!plan.scrolls || plan.initialScroll > 0) continue;
          final edge = plan.seenAtTop;
          bool straddles(Rect r) => r.top < edge - 8 && r.bottom > edge + 4;
          final cut = plan.cards.any(
            (c) => straddles(c.rect) || c.tags.any((t) => straddles(t.rect)),
          );
          expect(cut, isTrue, reason: '${entry.key} on $screen: nothing cut');
        }
      }
    });

    test('the board is as tall as its window when it fits, taller when it '
        'scrolls', () {
      for (final (name, plan) in everyEndPlan()) {
        if (plan.scrolls) {
          expect(plan.boardHeight, greaterThan(plan.viewHeight), reason: name);
        } else {
          expect(plan.boardHeight, plan.viewHeight, reason: name);
        }
      }
    });

    test('a taller banner pushes the board down; the cards do not shrink', () {
      final two = endPlan(recordedResults('results'));
      final three = endPlan(recordedResults('results'), bannerHeight: 158);
      expect(three.boardTop, two.boardTop + 30);
      expect(three.viewHeight, two.viewHeight - 30);
      expect(three.cards.first.portraitWidth, two.cards.first.portraitWidth);
    });

    test('a short phone has less sky above the banner', () {
      expect(
        EndMetrics.bannerTopFor(640),
        lessThan(EndMetrics.bannerTopFor(780)),
      );
      expect(EndMetrics.bannerTopFor(780), EndMetrics.bannerTopTall);
      expect(EndMetrics.bannerTopFor(900), EndMetrics.bannerTopTall);
    });

    test('a tilted card\'s box is its corners turned, not a flat margin', () {
      const rect = Rect.fromLTWH(0, 0, 160, 100);
      final lean = EndMetrics.leanOf(rect.size, 3 * 3.14159265 / 180);
      // A wide card at 3 degrees leans out further down than across.
      expect(
        lean.height,
        closeTo((160 * 0.0523 + 100 * 0.9986 - 100) / 2, 0.05),
      );
      expect(lean.width, greaterThan(0));
      expect(EndMetrics.leaned(rect, 0), rect);
    });
  });

  group('long names', () {
    test('a 20-character name is whole, and alone in its row', () {
      final plan = endPlan(endTable(10, longNames: true));
      final long = plan.cards.firstWhere((c) => c.name.length == 20);
      expect(long.name, 'Rosalind Fairweather');
      // A name that does not fit a slot has a row of its own.
      final nameWidth =
          endMeasure(EndText.name, long.name) + EndMetrics.nameRoom;
      final slot = (plan.boardWidth - 2 * EndMetrics.insetX) / 2;
      if (nameWidth + 2 * EndMetrics.clear > slot) {
        expect(
          plan.rows.firstWhere((r) => r.contains(plan.cards.indexOf(long))),
          hasLength(1),
        );
      }
      expect(long.rect.width, greaterThanOrEqualTo(nameWidth - 0.01));
    });

    test('a one-word name of 20 letters, ten players, nobody leaves the '
        'board', () {
      final results = endTable(10);
      (results['players'] as List)
              .cast<Map<String, dynamic>>()[3]['display_name'] =
          'Wolfgangamadeusmozart';
      final plan = endPlan(results);
      final long = plan.cards.firstWhere((c) => c.name.length > 20);
      expect(
        plan.rows.firstWhere((r) => r.contains(plan.cards.indexOf(long))),
        hasLength(1),
      );
      expect(long.leaned.right, lessThanOrEqualTo(plan.boardWidth));
    });
  });

  group('the same on every phone', () {
    test('the tilt comes from the id: the same card leans the same way for '
        'every viewer and every screen', () {
      final results = recordedResults('results');
      final a = endPlan(results, viewer: 1);
      final b = endPlan(results, viewer: 6, screen: endBig);
      for (final c in a.cards) {
        expect(b.card(c.id).angle, c.angle);
      }
      expect(
        a.cards.any((c) => c.angle > 0) && a.cards.any((c) => c.angle < 0),
        isTrue,
      );
      for (final c in a.cards) {
        final limit = (c.hanged ? 3.0 : 2.0) * 3.1416 / 180 + 1e-6;
        expect(c.angle.abs(), lessThanOrEqualTo(limit));
      }
    });

    test(
      'who is looking moves no card: only the seal and the banner differ',
      () {
        for (final entry in endSamples.entries) {
          final ids = [
            for (final p in entry.value['players'] as List)
              (p as Map)['player_id'] as int,
          ];
          final first = endPlan(entry.value, viewer: ids.first);
          final last = endPlan(entry.value, viewer: ids.last);
          expect(first.rows, last.rows, reason: entry.key);
          for (final c in first.cards) {
            expect(last.card(c.id).rect, c.rect, reason: entry.key);
            expect(
              [for (final t in last.card(c.id).tags) t.rect],
              [for (final t in c.tags) t.rect],
            );
          }
          expect(first.cards.where((c) => c.you).single.id, ids.first);
          expect(last.cards.where((c) => c.you).single.id, ids.last);
          expect(first.cards.where((c) => c.sealRect != null).length, 1);
        }
      },
    );

    test('the same results, the same plan', () {
      final a = endPlan(recordedResults('results_tie'));
      final b = endPlan(recordedResults('results_tie'));
      expect(
        [for (final c in a.cards) c.rect],
        [for (final c in b.cards) c.rect],
      );
    });
  });

  group('the foot', () {
    test('the host has What happened, Edit deck, Play again; a guest has '
        'Leave and who deals next', () {
      final host = endPlan(recordedResults('results'), host: true);
      expect(host.foot.host, isTrue);
      expect(host.foot.whatHappened, isTrue);
      final guest = endPlan(recordedResults('results'), host: false);
      expect(guest.foot.host, isFalse);
      expect(guest.foot.hostName, 'Ana');
    });
  });
}
