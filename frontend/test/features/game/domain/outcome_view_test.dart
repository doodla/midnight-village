import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/features/game/domain/outcome_view.dart';

import '../../../helpers/outcome_samples.dart';

// What the end board shows of each player, read from the recorded results
// bodies (test/helpers/outcome_samples.dart): every fact is the server's,
// never a rule applied on the phone.

List<EndSeat> _dead(String game) => [
  for (final s in endSeatsOf(outcomeOf(recordedResults(game))))
    if (s.died) s,
];

void main() {
  group('each player at the end', () {
    test("the card in front of a player at the end, with the server's team; "
        'the dealt one where it moved', () {
      final ben = _dead('results_moved_dead_card').single;
      expect(ben.seat.name, 'Ben');
      expect(ben.dealt, RoleId.robber);
      expect(ben.now, RoleId.werewolf);
      expect(ben.moved, isTrue);
      expect(ben.team, TeamId.werewolf);
      final cleo = _dead('results_doppelganger').single;
      expect(cleo.moved, isFalse);
      expect(cleo.team, TeamId.werewolf);
    });

    test('the Tanner dies alone, on no team', () {
      expect(_dead('results_tanner').single.team, TeamId.independent);
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

  test('a death the server gives no reason for fails loudly', () {
    final body = recordedResults('results');
    final fin = (body['players'] as List).cast<Map<String, dynamic>>().last;
    fin['elimination_reason'] = null;
    expect(() => endSeatsOf(outcomeOf(body)), throwsA(isA<FormatException>()));
  });
}
