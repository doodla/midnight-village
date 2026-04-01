// frontend/test/helpers/game_test_setup_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/night_state.dart';

import 'game_events.dart';
import 'game_state_factory.dart';
import 'game_test_setup.dart';

void main() {
  group('GameTestSetup', () {
    test('creates a setup with default game state', () {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);

      expect(setup.http, isNotNull);
      expect(setup.ws, isNotNull);
      expect(setup.container, isNotNull);
    });

    test('readGameState returns initial state from HTTP mock', () async {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);

      final state = await setup.readGameState();
      expect(state.gameId, 'test-game-id');
      expect(state.phase, 'night');
      expect(state.players.length, 3);
    });

    test('accepts custom gameMeJson', () async {
      final setup = GameTestSetup.create(
        gameMeJson: GameMeJsonBuilder()
            .inPhase('voting')
            .hasVoted(true)
            .build(),
      );
      addTearDown(setup.dispose);

      final state = await setup.readGameState();
      expect(state.phase, 'voting');
      expect(state.hasVoted, true);
    });

    test('ws events reach the notifier', () async {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);

      await setup.readGameState();

      setup.ws.addServerEvent(GameEvents.waveStart(wave: 3));
      await Future<void>.delayed(Duration.zero);

      expect(setup.currentState.currentWave, 3);
    });

    test('currentState returns the latest state synchronously', () async {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);

      await setup.readGameState();
      final state = setup.currentState;
      expect(state.gameId, 'test-game-id');
    });

    test('registerResults adds the results endpoint', () async {
      final setup = GameTestSetup.create(
        gameMeJson: GameMeJsonBuilder().inPhase('results').build(),
      );
      addTearDown(setup.dispose);

      setup.registerResults(
        resultsJson: {
          'winning_teams': ['village'],
          'players': [],
          'center_cards': [],
        },
      );

      final state = await setup.readGameState();
      expect(state.phase, 'results');
      expect(state.results, isNotNull);
    });

    test('registerActionSubmit adds the action endpoint', () async {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);

      setup.registerActionSubmit();

      await setup.readGameState();
      final response = await setup.http.dio.post<dynamic>(
        '/onuw/games/test-game-id/action/',
        data: {'action_type': 'peek_player', 'targets': {}},
      );
      expect(response.statusCode, 200);
    });

    test('registerVoteSubmit adds the vote endpoint', () async {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);

      setup.registerVoteSubmit();

      final response = await setup.http.dio.post<dynamic>(
        '/onuw/games/test-game-id/vote/',
        data: {'target_player_id': 2},
      );
      expect(response.statusCode, 200);
    });

    test('registerEndDiscussion adds the end-discussion endpoint', () async {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);

      setup.registerEndDiscussion();

      final response = await setup.http.dio.post<dynamic>(
        '/onuw/games/test-game-id/end-discussion/',
      );
      expect(response.statusCode, 200);
    });
  });
}
