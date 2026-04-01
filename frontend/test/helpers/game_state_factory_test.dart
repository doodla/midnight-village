import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/game_session_state.dart';
import 'package:midnight_village/features/game/domain/night_state.dart';

import 'game_state_factory.dart';

void main() {
  group('GameStateBuilder', () {
    test('defaults produce a valid night-phase state with 3 players', () {
      final state = GameStateBuilder().build();

      expect(state.gameId, 'test-game-id');
      expect(state.phase, 'night');
      expect(state.currentWave, 1);
      expect(state.yourRole.originalRole, 'seer');
      expect(state.yourRole.hasActed, false);
      expect(state.players.length, 3);
      expect(state.players[0].displayName, 'Alice');
      expect(state.players[1].displayName, 'Bob');
      expect(state.players[2].displayName, 'Charlie');
      expect(state.nightSubView, NightSubView.waiting);
      expect(state.isHost, false);
    });

    test('inPhase sets the phase', () {
      final state = GameStateBuilder().inPhase('voting').build();
      expect(state.phase, 'voting');
    });

    test('withRole sets yourRole', () {
      final state = GameStateBuilder()
          .withRole('werewolf', hasActed: true)
          .build();
      expect(state.yourRole.originalRole, 'werewolf');
      expect(state.yourRole.hasActed, true);
    });

    test('withPlayers overrides default player list', () {
      final state = GameStateBuilder().withPlayers([
        const GamePlayer(playerId: 10, displayName: 'Zara'),
      ]).build();
      expect(state.players.length, 1);
      expect(state.players[0].displayName, 'Zara');
    });

    test('asHost sets isHost to true', () {
      final state = GameStateBuilder().asHost().build();
      expect(state.isHost, true);
    });

    test('hasVoted sets hasVoted and voteProgress', () {
      final state = GameStateBuilder().inPhase('voting').hasVoted(true).build();
      expect(state.hasVoted, true);
      expect(state.voteProgress.currentPlayerVoted, true);
    });

    test('withSeerPrompt sets actionPrompt and seerChoice subview', () {
      final state = GameStateBuilder()
          .withSeerPrompt(wave: 2, playerTargets: [2, 3])
          .build();
      expect(state.nightSubView, NightSubView.seerChoice);
      expect(state.actionPrompt, isNotNull);
      expect(state.actionPrompt!.roleActingAs, 'Seer');
      expect(state.actionPrompt!.actionTypes, ['peek_player', 'peek_center']);
      expect(state.actionPrompt!.wave, 2);
    });

    test('withActionPrompt sets arbitrary prompt and actionPrompt subview', () {
      final prompt = const ActionPrompt(
        roleActingAs: 'Robber',
        actionTypes: ['swap_with_player'],
        validTargets: {
          'swap_with_player': {
            'players': [2, 3],
          },
        },
        wave: 1,
      );
      final state = GameStateBuilder().withActionPrompt(prompt).build();
      expect(state.nightSubView, NightSubView.actionPrompt);
      expect(state.actionPrompt, prompt);
    });

    test('withActionResult sets result and actionResult subview', () {
      final result = const ActionResult(
        wave: 1,
        revealedInfo: {'action_type': 'peek_player', 'role': 'werewolf'},
      );
      final state = GameStateBuilder().withActionResult(result).build();
      expect(state.nightSubView, NightSubView.actionResult);
      expect(state.lastActionResult, result);
    });

    test('withVoteProgress sets custom vote progress', () {
      final state = GameStateBuilder().inPhase('voting').withVoteProgress({
        1: true,
        2: false,
        3: true,
      }).build();
      expect(state.voteProgress.playerVoted[1], true);
      expect(state.voteProgress.playerVoted[2], false);
      expect(state.voteProgress.playerVoted[3], true);
    });

    test('withVoteReveal sets vote reveal data', () {
      final state = GameStateBuilder()
          .inPhase('voting')
          .withVoteReveal(
            votes: {'1': 3, '2': 3, '3': 1},
            tally: {'3': 2, '1': 1},
          )
          .build();
      expect(state.voteRevealData, isNotNull);
      expect(state.voteRevealData!.votes['1'], 3);
      expect(state.voteRevealData!.tally['3'], 2);
    });
  });
}
