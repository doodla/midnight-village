import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_exception.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/features/game/data/game_service.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/mock_http_client.dart';

/// Creates a [GameService] backed by a [MockHttpClient].
({GameService service, MockHttpClient http}) _createService() {
  final http = MockHttpClient();
  final client = AuthenticatedClient.forTesting(dio: http.dio);
  final service = GameService(client: client);
  return (service: service, http: http);
}

void main() {
  group('GameService.getGameState', () {
    test('returns GameSessionState from successful response', () async {
      final (:service, :http) = _createService();
      http.answer(
        'GET',
        '/onuw/games/abc123/me/',
        GameMeJsonBuilder().withGameId('abc123').build(),
      );

      final state = await service.getGameState('abc123');
      expect(state.gameId, 'abc123');
      expect(state.phase, 'night');
      expect(state.players.length, 3);
      expect(state.yourRole.originalRole, 'Seer');
    });
  });

  group('GameService.submitAction', () {
    test('sends correct payload', () async {
      final (:service, :http) = _createService();
      http.answer(
        'POST',
        '/onuw/games/abc123/action/',
        ContractSamples.load('http/game/action_submitted'),
      );

      await service.submitAction('abc123', 'peek_player', {'player_id': 3});

      expect(http.requests.single.data, {
        'action_type': 'peek_player',
        'targets': {'player_id': 3},
      });
    });

    test('treats 409 as success (already acted)', () async {
      final (:service, :http) = _createService();
      http.answer(
        'POST',
        '/onuw/games/abc123/action/',
        ContractSamples.load('http/game/action_already_acted'),
        status: 409,
      );

      // Should not throw.
      await service.submitAction('abc123', 'peek_player', {'player_id': 3});
    });

    test('throws on 400 (invalid action), with the server message', () async {
      final (:service, :http) = _createService();
      http.answer(
        'POST',
        '/onuw/games/abc123/action/',
        ContractSamples.load('http/game/action_invalid'),
        status: 400,
      );

      expect(
        () => service.submitAction('abc123', 'peek_player', {'player_id': 1}),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.firstErrorFor('detail'),
            'message',
            'Cannot target yourself.',
          ),
        ),
      );
    });
  });

  group('GameService.submitVote', () {
    test('sends correct payload', () async {
      final (:service, :http) = _createService();
      http.answer(
        'POST',
        '/onuw/games/abc123/vote/',
        ContractSamples.load('http/game/vote_submitted'),
      );

      await service.submitVote('abc123', 3);

      expect(http.requests.single.data, {'target_player_id': 3});
    });

    test('treats 409 as success (already voted)', () async {
      final (:service, :http) = _createService();
      http.answer(
        'POST',
        '/onuw/games/abc123/vote/',
        ContractSamples.load('http/game/vote_already_voted'),
        status: 409,
      );

      await service.submitVote('abc123', 3);
    });
  });

  group('GameService.endDiscussion', () {
    test('sends POST to correct endpoint', () async {
      final (:service, :http) = _createService();
      http.answer(
        'POST',
        '/onuw/games/abc123/end-discussion/',
        ContractSamples.load('http/game/end_discussion'),
      );

      await service.endDiscussion('abc123');

      expect(http.requests.single.path, '/onuw/games/abc123/end-discussion/');
    });
  });

  group('GameService.fetchResults', () {
    test('returns raw results map', () async {
      final (:service, :http) = _createService();
      http.answer('GET', '/onuw/games/abc123/results/', serverResults());

      final results = await service.fetchResults('abc123');
      expect(results['winning_teams'], ['village']);
    });
  });

  group('GameService night_results, presence and host calls', () {
    test(
      'getGameState parses night_results in the action_result shape',
      () async {
        final (:service, :http) = _createService();
        http.answer(
          'GET',
          '/onuw/games/g1/me/',
          GameMeJsonBuilder()
              .withGameId('g1')
              .inPhase('discussion')
              .withNightResults([serverNightResult('peek_center')])
              .build(),
        );

        final state = await service.getGameState('g1');

        expect(state.nightResults, hasLength(1));
        expect(state.nightResults.single.wave, 2);
        expect(
          state.nightResults.single.revealedInfo['action_type'],
          'peek_center',
        );
      },
    );

    test('fetchPresence maps player ids to connected', () async {
      final (:service, :http) = _createService();
      http.answer(
        'GET',
        '/onuw/games/g1/players/',
        serverPlayerList(away: {1}),
      );

      expect(await service.fetchPresence('g1'), {1: false, 2: true, 3: true});
    });

    test('advanceNight posts to advance-wave', () async {
      final (:service, :http) = _createService();
      http.answer(
        'POST',
        '/onuw/games/g1/advance-wave/',
        ContractSamples.load('http/game/advance_wave'),
      );

      await service.advanceNight('g1');

      expect(http.requests.single.path, '/onuw/games/g1/advance-wave/');
    });

    test('revealVotes posts to reveal-votes', () async {
      final (:service, :http) = _createService();
      http.answer(
        'POST',
        '/onuw/games/g1/reveal-votes/',
        ContractSamples.load('http/game/reveal_votes'),
      );

      await service.revealVotes('g1');

      expect(http.requests.single.path, '/onuw/games/g1/reveal-votes/');
    });
  });
}
