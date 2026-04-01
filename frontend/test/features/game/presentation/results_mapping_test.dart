import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/design_system/models/game_result.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/game/data/game_service.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import '../../../helpers/mock_http_client.dart';
import '../../../helpers/mock_websocket.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Default game state JSON — includes 3 players for display-name lookups.
Map<String, dynamic> _defaultGameMeJson() => {
  'game_id': 'test-game-id',
  'phase': 'voting',
  'current_wave': 0,
  'deadline': null,
  'your_role': {'original_role': 'seer', 'has_acted': false},
  'players': [
    {'player_id': 1, 'display_name': 'Alice'},
    {'player_id': 2, 'display_name': 'Bob'},
    {'player_id': 3, 'display_name': 'Charlie'},
  ],
  'roles_in_game': [],
};

({ProviderContainer container, MockHttpClient http, MockWebSocketChannel ws})
_createTestSetup({required Map<String, dynamic> resultsJson}) {
  final http = MockHttpClient();
  final ws = MockWebSocketChannel();

  http
      .when(method: 'GET', path: '/onuw/games/test-game-id/me/')
      .thenReturn(
        Response(
          requestOptions: RequestOptions(path: '/onuw/games/test-game-id/me/'),
          statusCode: 200,
          data: _defaultGameMeJson(),
        ),
      );

  http
      .when(method: 'GET', path: '/onuw/games/test-game-id/results/')
      .thenReturn(
        Response(
          requestOptions: RequestOptions(
            path: '/onuw/games/test-game-id/results/',
          ),
          statusCode: 200,
          data: resultsJson,
        ),
      );

  final client = AuthenticatedClient.forTesting(dio: http.dio);

  final container = ProviderContainer(
    overrides: [
      authenticatedClientProvider.overrideWithValue(client),
      gameServiceProvider.overrideWithValue(GameService(client: client)),
      gameWebSocketProvider.overrideWith((ref, gameId) => null),
      gameWebSocketStreamProvider.overrideWith((ref, gameId) => ws.stream),
    ],
  );

  return (container: container, http: http, ws: ws);
}

/// Boots the provider and fires a game_results WS event to trigger
/// _fetchResultsFallback, then waits for async work to complete.
Future<GameResult?> _triggerResultsFetch(
  ProviderContainer container,
  MockWebSocketChannel ws,
) async {
  container.listen(gameProvider('test-game-id'), (_, _) {});
  await container.read(gameProvider('test-game-id').future);

  ws.addServerEvent(jsonEncode({'type': 'game_results', 'data': {}}));

  // Allow the WS handler and async HTTP fetch to complete.
  await Future<void>.delayed(const Duration(milliseconds: 50));

  return container.read(gameProvider('test-game-id')).value?.results;
}

void main() {
  // ---------------------------------------------------------------------------
  // elimination_reason mapping
  // ---------------------------------------------------------------------------

  group('elimination_reason mapping', () {
    test('"vote" maps to EliminationReason.vote', () async {
      final (:container, :http, :ws) = _createTestSetup(
        resultsJson: {
          'winning_teams': ['village'],
          'players': [
            {
              'player_id': 1,
              'display_name': 'Alice',
              'original_role': 'werewolf',
              'final_role': 'werewolf',
              'team': 'werewolf',
              'is_eliminated': true,
              'outcome': 'loss',
              'elimination_reason': 'vote',
            },
          ],
        },
      );
      addTearDown(container.dispose);

      final results = await _triggerResultsFetch(container, ws);
      expect(results, isNotNull);
      expect(results!.players.first.eliminationReason, EliminationReason.vote);
    });

    test('"hunter_chain" maps to EliminationReason.hunterChain', () async {
      final (:container, :http, :ws) = _createTestSetup(
        resultsJson: {
          'winning_teams': ['village'],
          'players': [
            {
              'player_id': 2,
              'display_name': 'Bob',
              'original_role': 'villager',
              'final_role': 'villager',
              'team': 'village',
              'is_eliminated': true,
              'outcome': 'loss',
              'elimination_reason': 'hunter_chain',
            },
          ],
        },
      );
      addTearDown(container.dispose);

      final results = await _triggerResultsFetch(container, ws);
      expect(results, isNotNull);
      expect(
        results!.players.first.eliminationReason,
        EliminationReason.hunterChain,
      );
    });

    test('null elimination_reason maps to null', () async {
      final (:container, :http, :ws) = _createTestSetup(
        resultsJson: {
          'winning_teams': ['village'],
          'players': [
            {
              'player_id': 1,
              'display_name': 'Alice',
              'original_role': 'villager',
              'final_role': 'villager',
              'team': 'village',
              'is_eliminated': false,
              'outcome': 'win',
              'elimination_reason': null,
            },
          ],
        },
      );
      addTearDown(container.dispose);

      final results = await _triggerResultsFetch(container, ws);
      expect(results, isNotNull);
      expect(results!.players.first.eliminationReason, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // center_cards mapping
  // ---------------------------------------------------------------------------

  group('center_cards mapping', () {
    test('role strings map to RoleId enum values', () async {
      final (:container, :http, :ws) = _createTestSetup(
        resultsJson: {
          'winning_teams': ['village'],
          'players': [],
          'center_cards': ['werewolf', 'seer', 'villager'],
        },
      );
      addTearDown(container.dispose);

      final results = await _triggerResultsFetch(container, ws);
      expect(results, isNotNull);
      expect(
        results!.centerCards,
        equals([RoleId.werewolf, RoleId.seer, RoleId.villager]),
      );
    });

    test('unknown role strings are ignored', () async {
      final (:container, :http, :ws) = _createTestSetup(
        resultsJson: {
          'winning_teams': ['village'],
          'players': [],
          'center_cards': ['seer', 'unknown_role', 'robber'],
        },
      );
      addTearDown(container.dispose);

      final results = await _triggerResultsFetch(container, ws);
      expect(results, isNotNull);
      expect(results!.centerCards, equals([RoleId.seer, RoleId.robber]));
    });
  });

  // ---------------------------------------------------------------------------
  // vote_target_id → display name lookup
  // ---------------------------------------------------------------------------

  group('vote_target_id display name lookup', () {
    test('vote_target_id maps to display name from players list', () async {
      final (:container, :http, :ws) = _createTestSetup(
        resultsJson: {
          'winning_teams': ['village'],
          'players': [
            {
              'player_id': 1,
              'display_name': 'Alice',
              'original_role': 'villager',
              'final_role': 'villager',
              'team': 'village',
              'is_eliminated': false,
              'outcome': 'win',
              'vote_target_id': 2,
            },
          ],
        },
      );
      addTearDown(container.dispose);

      final results = await _triggerResultsFetch(container, ws);
      expect(results, isNotNull);
      final player = results!.players.first;
      expect(player.voteTargetId, '2');
      // Bob is player_id=2 in _defaultGameMeJson.
      expect(player.voteTargetName, 'Bob');
    });

    test('null vote_target_id means abstainer (no name lookup)', () async {
      final (:container, :http, :ws) = _createTestSetup(
        resultsJson: {
          'winning_teams': ['village'],
          'players': [
            {
              'player_id': 1,
              'display_name': 'Alice',
              'original_role': 'villager',
              'final_role': 'villager',
              'team': 'village',
              'is_eliminated': false,
              'outcome': 'win',
              'vote_target_id': null,
            },
          ],
        },
      );
      addTearDown(container.dispose);

      final results = await _triggerResultsFetch(container, ws);
      expect(results, isNotNull);
      final player = results!.players.first;
      expect(player.voteTargetId, isNull);
      expect(player.voteTargetName, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // outcome field → isWinner
  // ---------------------------------------------------------------------------

  group('outcome → isWinner mapping', () {
    test('"win" outcome sets isWinner=true', () async {
      final (:container, :http, :ws) = _createTestSetup(
        resultsJson: {
          'winning_teams': ['village'],
          'players': [
            {
              'player_id': 1,
              'display_name': 'Alice',
              'original_role': 'villager',
              'final_role': 'villager',
              'team': 'village',
              'is_eliminated': false,
              'outcome': 'win',
            },
          ],
        },
      );
      addTearDown(container.dispose);

      final results = await _triggerResultsFetch(container, ws);
      expect(results!.players.first.isWinner, true);
    });

    test('"loss" outcome sets isWinner=false', () async {
      final (:container, :http, :ws) = _createTestSetup(
        resultsJson: {
          'winning_teams': ['village'],
          'players': [
            {
              'player_id': 1,
              'display_name': 'Alice',
              'original_role': 'werewolf',
              'final_role': 'werewolf',
              'team': 'werewolf',
              'is_eliminated': true,
              'outcome': 'loss',
            },
          ],
        },
      );
      addTearDown(container.dispose);

      final results = await _triggerResultsFetch(container, ws);
      expect(results!.players.first.isWinner, false);
    });
  });

  // ---------------------------------------------------------------------------
  // winning_teams mapping
  // ---------------------------------------------------------------------------

  group('winning_teams mapping', () {
    test('maps team strings to TeamId enum values', () async {
      final (:container, :http, :ws) = _createTestSetup(
        resultsJson: {
          'winning_teams': ['village', 'independent'],
          'players': [],
        },
      );
      addTearDown(container.dispose);

      final results = await _triggerResultsFetch(container, ws);
      expect(results, isNotNull);
      expect(
        results!.winningTeams,
        equals([TeamId.village, TeamId.independent]),
      );
    });

    test('empty winning_teams maps to empty list (nobody wins)', () async {
      final (:container, :http, :ws) = _createTestSetup(
        resultsJson: {'winning_teams': [], 'players': []},
      );
      addTearDown(container.dispose);

      final results = await _triggerResultsFetch(container, ws);
      expect(results, isNotNull);
      expect(results!.winningTeams, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // votes list mapping
  // ---------------------------------------------------------------------------

  group('votes list mapping', () {
    test('maps votes list with abstainer (null target)', () async {
      final (:container, :http, :ws) = _createTestSetup(
        resultsJson: {
          'winning_teams': ['village'],
          'players': [],
          'votes': [
            {
              'voter_id': '1',
              'voter_name': 'Alice',
              'target_id': '2',
              'target_name': 'Bob',
            },
            {
              'voter_id': '3',
              'voter_name': 'Charlie',
              'target_id': null,
              'target_name': null,
            },
          ],
        },
      );
      addTearDown(container.dispose);

      final results = await _triggerResultsFetch(container, ws);
      expect(results, isNotNull);
      expect(results!.votes, hasLength(2));

      final alice = results.votes.firstWhere((v) => v.voterName == 'Alice');
      expect(alice.targetId, '2');
      expect(alice.targetName, 'Bob');

      final charlie = results.votes.firstWhere((v) => v.voterName == 'Charlie');
      expect(charlie.targetId, isNull);
      expect(charlie.targetName, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Phase transitions to 'results' and results stored in state
  // ---------------------------------------------------------------------------

  group('results phase and state storage', () {
    test(
      'game_results WS event triggers phase=results and stores GameResult',
      () async {
        final (:container, :http, :ws) = _createTestSetup(
          resultsJson: {
            'winning_teams': ['werewolf'],
            'players': [],
          },
        );
        addTearDown(container.dispose);

        final results = await _triggerResultsFetch(container, ws);

        final state = container.read(gameProvider('test-game-id')).value!;
        expect(state.phase, 'results');
        expect(results, isNotNull);
        expect(results!.winningTeams, equals([TeamId.werewolf]));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Title Case role names (backend sends Title Case, frontend expects lowercase)
  // ---------------------------------------------------------------------------

  group('Title Case role name handling', () {
    test('Title Case role names parse correctly in player results', () async {
      final (:container, :http, :ws) = _createTestSetup(
        resultsJson: {
          'winning_teams': ['village'],
          'players': [
            {
              'player_id': 1,
              'display_name': 'Alice',
              'original_role': 'Werewolf',
              'final_role': 'Robber',
              'team': 'werewolf',
              'is_eliminated': true,
              'outcome': 'loss',
            },
            {
              'player_id': 2,
              'display_name': 'Bob',
              'original_role': 'Troublemaker',
              'final_role': 'Troublemaker',
              'team': 'village',
              'is_eliminated': false,
              'outcome': 'win',
            },
          ],
        },
      );
      addTearDown(container.dispose);

      final results = await _triggerResultsFetch(container, ws);
      expect(results, isNotNull);
      expect(results!.players[0].originalRole, RoleId.werewolf);
      expect(results.players[0].finalRole, RoleId.robber);
      expect(results.players[1].originalRole, RoleId.troublemaker);
    });

    test('Title Case center cards parse correctly', () async {
      final (:container, :http, :ws) = _createTestSetup(
        resultsJson: {
          'winning_teams': ['village'],
          'players': [],
          'center_cards': ['Werewolf', 'Seer', 'Villager'],
        },
      );
      addTearDown(container.dispose);

      final results = await _triggerResultsFetch(container, ws);
      expect(results, isNotNull);
      expect(
        results!.centerCards,
        equals([RoleId.werewolf, RoleId.seer, RoleId.villager]),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Backend team name conventions (neutral/tanner → independent)
  // ---------------------------------------------------------------------------

  group('backend team name mapping', () {
    test('"neutral" team maps to TeamId.independent', () async {
      final (:container, :http, :ws) = _createTestSetup(
        resultsJson: {
          'winning_teams': ['village'],
          'players': [
            {
              'player_id': 1,
              'display_name': 'Alice',
              'original_role': 'tanner',
              'final_role': 'tanner',
              'team': 'neutral',
              'is_eliminated': false,
              'outcome': 'loss',
            },
          ],
        },
      );
      addTearDown(container.dispose);

      final results = await _triggerResultsFetch(container, ws);
      expect(results, isNotNull);
      expect(results!.players.first.team, TeamId.independent);
    });

    test('"tanner" in winning_teams maps to TeamId.independent', () async {
      final (:container, :http, :ws) = _createTestSetup(
        resultsJson: {
          'winning_teams': ['tanner', 'village'],
          'players': [],
        },
      );
      addTearDown(container.dispose);

      final results = await _triggerResultsFetch(container, ws);
      expect(results, isNotNull);
      expect(
        results!.winningTeams,
        equals([TeamId.independent, TeamId.village]),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // reason field mapping
  // ---------------------------------------------------------------------------

  group('reason field mapping', () {
    test('reason string from backend is stored in GameResult', () async {
      final (:container, :http, :ws) = _createTestSetup(
        resultsJson: {
          'winning_teams': ['village'],
          'reason': 'A Werewolf was eliminated.',
          'players': [],
        },
      );
      addTearDown(container.dispose);

      final results = await _triggerResultsFetch(container, ws);
      expect(results, isNotNull);
      expect(results!.reason, 'A Werewolf was eliminated.');
    });

    test('missing reason field defaults to empty string', () async {
      final (:container, :http, :ws) = _createTestSetup(
        resultsJson: {
          'winning_teams': ['village'],
          'players': [],
        },
      );
      addTearDown(container.dispose);

      final results = await _triggerResultsFetch(container, ws);
      expect(results, isNotNull);
      expect(results!.reason, '');
    });
  });
}
