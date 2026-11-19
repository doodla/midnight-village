import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/game_result.dart';
import 'package:midnight_village/design_system/models/role.dart';

import '../../../helpers/contract/server_json.dart';
import '../../../helpers/game_events.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

/// The app's [GameResult] for the server's results body [resultsJson],
/// reached the way a phone gets it: the vote is on, `game_results` arrives,
/// the app fetches `GET .../results/`.
Future<GameResult> _resultsFor(Map<String, dynamic> resultsJson) async {
  final setup = GameTestSetup.create(
    gameMeJson: GameMeJsonBuilder().inPhase('voting').build(),
  );
  addTearDown(setup.dispose);
  setup.registerResults(resultsJson: resultsJson);
  await setup.readGameState();

  setup.ws.addServerEvent(GameEvents.gameResults());
  await Future<void>.delayed(const Duration(milliseconds: 50));

  expect(setup.currentState.phase, 'results');
  return setup.currentState.results!;
}

ResultSeat _seat(
  int index, {
  String role = 'Villager',
  String? finalRole,
  String team = 'village',
  bool won = true,
  String? eliminatedBy,
  int? votedFor,
}) => ResultSeat(
  defaultSeats[index],
  originalRole: role,
  finalRole: finalRole,
  team: team,
  won: won,
  eliminatedBy: eliminatedBy,
  votedFor: votedFor,
);

void main() {
  group('elimination_reason mapping', () {
    test('"vote" maps to EliminationReason.vote', () async {
      final results = await _resultsFor(
        serverResults(
          players: [
            _seat(
              0,
              role: 'Werewolf',
              team: 'werewolf',
              won: false,
              eliminatedBy: 'vote',
            ),
          ],
        ),
      );
      expect(results.players.first.eliminationReason, EliminationReason.vote);
    });

    test('"hunter_chain" maps to EliminationReason.hunterChain', () async {
      final results = await _resultsFor(
        serverResults(
          players: [_seat(1, won: false, eliminatedBy: 'hunter_chain')],
        ),
      );
      expect(
        results.players.first.eliminationReason,
        EliminationReason.hunterChain,
      );
    });

    test('null elimination_reason maps to null', () async {
      final results = await _resultsFor(serverResults(players: [_seat(2)]));
      expect(results.players.first.eliminationReason, isNull);
    });
  });

  group('center_cards mapping', () {
    test('the server role names map to RoleId values', () async {
      final results = await _resultsFor(
        serverResults(centerCards: ['Werewolf', 'Seer', 'Villager']),
      );
      expect(results.centerCards, [
        RoleId.werewolf,
        RoleId.seer,
        RoleId.villager,
      ]);
    });
  });

  group('vote_target_id display name lookup', () {
    test('vote_target_id maps to display name from players list', () async {
      final results = await _resultsFor(
        serverResults(players: [_seat(0, votedFor: 2)]),
      );
      final player = results.players.first;
      expect(player.voteTargetId, '2');
      expect(player.voteTargetName, 'Bob');
    });

    test('null vote_target_id means abstainer (no name lookup)', () async {
      final results = await _resultsFor(serverResults(players: [_seat(0)]));
      final player = results.players.first;
      expect(player.voteTargetId, isNull);
      expect(player.voteTargetName, isNull);
    });
  });

  group('outcome → isWinner mapping', () {
    test('"win" outcome sets isWinner=true', () async {
      final results = await _resultsFor(serverResults(players: [_seat(0)]));
      expect(results.players.first.isWinner, true);
    });

    test('"lose" outcome sets isWinner=false', () async {
      final results = await _resultsFor(
        serverResults(
          players: [_seat(0, role: 'Werewolf', team: 'werewolf', won: false)],
        ),
      );
      expect(results.players.first.isWinner, false);
    });
  });

  group('winning_teams mapping', () {
    test('maps team tokens to TeamId values', () async {
      final results = await _resultsFor(
        serverResults(winningTeams: ['werewolf']),
      );
      expect(results.winningTeams, [TeamId.werewolf]);
    });

    test('"tanner" in winning_teams maps to TeamId.independent', () async {
      final results = await _resultsFor(
        serverResults(winningTeams: ['tanner', 'village']),
      );
      expect(results.winningTeams, [TeamId.independent, TeamId.village]);
    });

    test('empty winning_teams maps to empty list (nobody wins)', () async {
      final results = await _resultsFor(serverResults(winningTeams: []));
      expect(results.winningTeams, isEmpty);
    });
  });

  group('player roles and teams', () {
    test('the server role names parse in player results', () async {
      final results = await _resultsFor(
        serverResults(
          players: [
            _seat(0, role: 'Werewolf', finalRole: 'Robber', team: 'village'),
            _seat(1, role: 'Troublemaker'),
          ],
        ),
      );
      expect(results.players[0].originalRole, RoleId.werewolf);
      expect(results.players[0].finalRole, RoleId.robber);
      expect(results.players[1].originalRole, RoleId.troublemaker);
    });

    test('"neutral" team maps to TeamId.independent', () async {
      final results = await _resultsFor(
        serverResults(
          players: [_seat(0, role: 'Tanner', team: 'neutral', won: false)],
        ),
      );
      expect(results.players.first.team, TeamId.independent);
    });
  });

  group('reason field mapping', () {
    test('reason string from backend is stored in GameResult', () async {
      final results = await _resultsFor(
        serverResults(reason: 'A Werewolf was eliminated.'),
      );
      expect(results.reason, 'A Werewolf was eliminated.');
    });
  });
}
