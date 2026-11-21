import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/game_result.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/features/game/domain/outcome_view.dart';

import '../../../helpers/outcome_samples.dart';

// What 10 and 11 show, read from the recorded results bodies
// (test/helpers/outcome_samples.dart): every fact is the
// server's, grouped for drawing, never a rule applied on the phone.

List<String> _names(Iterable<EndSeat> seats) => [
  for (final s in seats) s.seat.name,
];

String _line(NightLine l) => '${l.prefix} ${l.text}';

List<String> _cards(NightLine l) => [
  for (final c in l.cards) '${c.role.displayName}${c.werewolf ? '*' : ''}',
];

void main() {
  group('the count', () {
    test('the Hunter: Fin is voted out (4 votes) and takes Esme; the rows '
        'go most votes first, then by seat', () {
      final count = TheCount.of(outcomeOf(recordedResults('results')));
      expect(
        [
          for (final a in count.accused)
            '${a.player.seat.name} ${a.votes}: '
                '${a.voters.map((v) => v.name).join(', ')}',
        ],
        ['Fin 4: Ana, Ben, Cleo, Esme', 'Cleo 1: Dev', 'Esme 1: Fin'],
      );
      expect(count.noVote, isEmpty);
      expect(_names(count.deadByVote), ['Fin']);
      expect(_names(count.deadByHunter), ['Esme']);
      expect(_names(count.dead), ['Fin', 'Esme']);
      expect(count.headline, 'Fin dies.');
      expect(count.huntersPicks, ["Esme, Fin's pick, dies too."]);
      expect(count.dead.first.diedBy, EliminationReason.vote);
      expect(count.dead.last.diedBy, EliminationReason.hunterChain);
    });

    test('one dies; who did not vote is listed by name, in seat order', () {
      final count = TheCount.of(
        outcomeOf(recordedResults('results_doppelganger')),
      );
      expect(count.headline, 'Cleo dies.');
      expect(count.huntersPicks, isEmpty);
      expect(count.accused.single.voters.map((v) => v.name), ['Ana', 'Ben']);
      expect(count.accused.single.player.died, isTrue);
      expect(count.noVote.map((s) => s.name), [
        'Cleo',
        'Dev',
        'Esme',
        'Fin',
        'Gus',
        'Hana',
      ]);
    });

    test('nobody dies: no dead, every row one vote', () {
      final count = TheCount.of(
        outcomeOf(recordedResults('results_nobody_dies')),
      );
      expect(count.headline, 'Nobody dies.');
      expect(count.dead, isEmpty);
      expect(count.huntersPicks, isEmpty);
      expect(count.accused.map((a) => a.votes), everyElement(1));
      expect(count.accused, hasLength(6));
    });

    test("the dead card is the one in front of the player at the end, with "
        "the server's team; the dealt one only where it moved (finding 1)", () {
      final ben = TheCount.of(
        outcomeOf(recordedResults('results_moved_dead_card')),
      ).dead.single;
      expect(ben.seat.name, 'Ben');
      expect(ben.dealt, RoleId.robber);
      expect(ben.now, RoleId.werewolf);
      expect(ben.moved, isTrue);
      expect(ben.team, TeamId.werewolf);
      final cleo = TheCount.of(
        outcomeOf(recordedResults('results_doppelganger')),
      ).dead.single;
      expect(cleo.moved, isFalse);
      expect(cleo.team, TeamId.werewolf);
    });

    test('the Tanner dies alone, on no team', () {
      // The Tanner's game: only the Tanner dies.
      final tanner = TheCount.of(outcomeOf(recordedResults('results_tanner')));
      expect(tanner.headline, 'Dev dies.');
      expect(tanner.dead.single.team, TeamId.independent);
    });
  });

  group('who won', () {
    test('as the server says, for every recorded game', () {
      expect(
        Winners.of(outcomeOf(recordedResults('results')).result.winningTeams),
        Winners.village,
      );
      expect(
        Winners.of(
          outcomeOf(recordedResults('results_tanner')).result.winningTeams,
        ),
        Winners.tanner,
      );
      expect(
        Winners.of(
          outcomeOf(
            recordedResults('results_werewolves_win'),
          ).result.winningTeams,
        ),
        Winners.werewolves,
      );
    });

    test('every combination the rules allow has its headline and '
        'portrait; any other is a broken payload', () {
      expect(Winners.of(const []), Winners.nobody);
      expect(
        Winners.of(const [TeamId.village, TeamId.independent]),
        Winners.villageAndTanner,
      );
      expect(
        Winners.of(const [TeamId.independent, TeamId.werewolf]),
        Winners.werewolvesAndTanner,
      );
      expect(Winners.nobody.portrait, isNull);
      expect(Winners.werewolvesAndTanner.werewolvesWon, isTrue);
      expect(Winners.villageAndTanner.werewolvesWon, isFalse);
      expect(
        () => Winners.of(const [TeamId.village, TeamId.werewolf]),
        throwsFormatException,
      );
    });

    test("each player's card at the end, and a Doppelganger's as the role "
        'she copied', () {
      final seats = endSeatsOf(
        outcomeOf(recordedResults('results_doppelganger')),
      );
      final ana = seats.firstWhere((s) => s.seat.name == 'Ana');
      expect(ana.now, RoleId.doppelganger);
      expect(ana.copied, RoleId.seer);
      expect(ana.plays, RoleId.seer);
      final gus = seats.firstWhere((s) => s.seat.name == 'Gus');
      expect(
        (gus.dealt, gus.now, gus.team),
        (RoleId.drunk, RoleId.werewolf, TeamId.werewolf),
      );
      expect(seats.where((s) => s.won).map((s) => s.seat.name), [
        'Ana',
        'Ben',
        'Esme',
        'Fin',
        'Hana',
      ]);
      final tanner = endSeatsOf(outcomeOf(recordedResults('results_tanner')));
      expect(tanner.first.copied, RoleId.werewolf);
      expect(tanner.first.team, TeamId.werewolf);
    });
  });

  group('the night, a line per step', () {
    test('the Hunter game: teams, a look, a theft and a swap', () {
      final lines = nightLinesOf(outcomeOf(recordedResults('results')));
      expect(lines.map(_line), [
        'Werewolf: Cleo, Esme see each other.',
        "Seer: Ana sees Cleo's card.",
        "Robber: Ben takes Dev's card.",
        'Troublemaker: Dev swaps Ana and Ben.',
      ]);
      expect(lines.map((l) => l.number), [1, 2, 3, 4]);
      expect(lines.map(_cards), [
        <String>[],
        ['Werewolf*'],
        ['Troublemaker'],
        ['Seer', 'Troublemaker'],
      ]);
      expect(lines.map((l) => l.swap), [false, false, false, true]);
    });

    test("the Doppelganger's game: her copy and follow-up, a lone wolf's "
        'look, the Minion, the Masons, a Seer who did nothing, the Drunk, '
        'the Insomniac', () {
      final lines = nightLinesOf(
        outcomeOf(recordedResults('results_doppelganger')),
      );
      expect(lines.map(_line), [
        'Doppelganger: Ana copies Ben.',
        'Doppelganger · Seer: Ana sees Left, Right.',
        'Werewolf: Cleo sees Middle.',
        'Minion: Dev sees Cleo.',
        'Mason: Esme, Fin see each other.',
        'Seer: Ben does nothing.',
        'Drunk: Gus takes Left.',
        'Insomniac: Hana sees own card.',
      ]);
      expect(lines.map(_cards), [
        ['Seer'],
        ['Werewolf*', 'Tanner'],
        ['Villager'],
        <String>[],
        <String>[],
        <String>[],
        ['Werewolf*'],
        ['Insomniac'],
      ]);
      expect(lines.map((l) => l.role).toSet(), contains(RoleId.doppelganger));
    });

    test("the Tanner's game: the Doppelganger who copied a Werewolf wakes "
        'with the Werewolves; every line names its players', () {
      final lines = nightLinesOf(outcomeOf(recordedResults('results_tanner')));
      expect(lines.first.prefix, 'Doppelganger:');
      for (final line in lines) {
        expect(line.text, isNot(contains('  ')), reason: _line(line));
        expect(line.text, isNot(startsWith(' ')), reason: _line(line));
      }
    });
  });

  group('the red line: the server\'s werewolf flag, everywhere', () {
    test('where each Werewolf card went: one from Left to the Drunk, one '
        'that never moved', () {
      final paths = werewolfPathsOf(
        outcomeOf(recordedResults('results_doppelganger')),
      );
      expect(
        [for (final p in paths) p.places],
        [
          ['Cleo'],
          ['Left', 'Gus'],
        ],
      );
      expect(
        [for (final p in paths) p.steps],
        [
          <int>[],
          [7],
        ],
      );
    });

    test('a step is on the red line when it showed or moved a werewolf '
        'card', () {
      final lines = nightLinesOf(
        outcomeOf(recordedResults('results_doppelganger')),
      );
      expect(lines.map((l) => l.werewolf), [
        false, // copies Ben (the Seer)
        true, // sees Left (a Werewolf) and Right
        false, // the lone wolf sees Middle (a Villager)
        false,
        false,
        false,
        true, // the Drunk takes Left (a Werewolf)
        false,
      ]);
    });

    test("each player's card red by the flag: the Drunk who took a Werewolf, "
        'not the Minion', () {
      final seats = {
        for (final s in endSeatsOf(
          outcomeOf(recordedResults('results_doppelganger')),
        ))
          s.seat.name: s,
      };
      expect(seats['Gus']!.werewolfNow, isTrue);
      expect(seats['Gus']!.werewolfDealt, isFalse);
      expect(seats['Cleo']!.werewolfNow, isTrue);
      expect(seats['Dev']!.werewolfNow, isFalse, reason: 'the Minion');
    });
  });

  test('a death the server gives no reason for fails loudly', () {
    final body = recordedResults('results');
    final fin = (body['players'] as List).cast<Map<String, dynamic>>().last;
    fin['elimination_reason'] = null;
    expect(() => endSeatsOf(outcomeOf(body)), throwsA(isA<FormatException>()));
  });
}
