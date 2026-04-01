import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/game/data/game_service.dart';
import 'package:midnight_village/features/game/domain/game_session_state.dart';
import 'package:midnight_village/features/game/domain/night_state.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import '../../../helpers/mock_http_client.dart';
import '../../../helpers/mock_websocket.dart';

/// Default game state JSON returned by the mock /me/ endpoint.
Map<String, dynamic> _defaultGameMeJson({
  String phase = 'night',
  int currentWave = 1,
}) => {
  'game_id': 'test-game-id',
  'phase': phase,
  'current_wave': currentWave,
  'deadline': null,
  'your_role': {'original_role': 'seer', 'has_acted': false},
  'players': [
    {'player_id': 1, 'display_name': 'Alice'},
    {'player_id': 2, 'display_name': 'Bob'},
    {'player_id': 3, 'display_name': 'Charlie'},
  ],
  'roles_in_game': [
    {'role': 'werewolf', 'count': 2},
    {'role': 'seer', 'count': 1},
  ],
};

/// Creates a test container with mocked dependencies and a WebSocket stream.
/// Returns the container, http mock, ws mock, and a subscription that keeps
/// the provider alive.
({ProviderContainer container, MockHttpClient http, MockWebSocketChannel ws})
_createTestSetup({Map<String, dynamic>? gameMeJson}) {
  final http = MockHttpClient();
  final ws = MockWebSocketChannel();

  // Register the /me/ endpoint.
  http
      .when(method: 'GET', path: '/onuw/games/test-game-id/me/')
      .thenReturn(
        Response(
          requestOptions: RequestOptions(path: '/onuw/games/test-game-id/me/'),
          statusCode: 200,
          data: gameMeJson ?? _defaultGameMeJson(),
        ),
      );

  final client = AuthenticatedClient.forTesting(dio: http.dio);

  final container = ProviderContainer(
    overrides: [
      authenticatedClientProvider.overrideWithValue(client),
      gameServiceProvider.overrideWithValue(GameService(client: client)),
      gameWebSocketStreamProvider.overrideWith((ref, gameId) => ws.stream),
    ],
  );

  return (container: container, http: http, ws: ws);
}

/// Reads the game state, keeping the provider alive.
Future<GameSessionState> _readGameState(ProviderContainer container) async {
  // Keep the provider alive with a subscription.
  container.listen(gameProvider('test-game-id'), (_, _) {});
  final state = await container.read(gameProvider('test-game-id').future);
  // Don't close the subscription -- let the caller's addTearDown handle it.
  return state;
}

void main() {
  group('GameNotifier initial load', () {
    test('fetches initial state from GameService', () async {
      final (:container, :http, :ws) = _createTestSetup();
      addTearDown(container.dispose);

      final state = await _readGameState(container);
      expect(state.gameId, 'test-game-id');
      expect(state.phase, 'night');
      expect(state.players.length, 3);
      expect(state.yourRole.originalRole, 'seer');
    });

    test(
      'derives nightSubView from initial state with action_prompt',
      () async {
        final (:container, :http, :ws) = _createTestSetup(
          gameMeJson: {
            ..._defaultGameMeJson(),
            'action_prompt': {
              'role_acting_as': 'Seer',
              'action_types': ['peek_player', 'peek_center'],
              'valid_targets': {
                'peek_player': {
                  'players': [2, 3],
                },
                'peek_center': {
                  'card_indices': [0, 1, 2],
                },
              },
              'wave': 2,
            },
          },
        );
        addTearDown(container.dispose);

        final state = await _readGameState(container);
        expect(state.nightSubView, NightSubView.seerChoice);
      },
    );

    test('derives nightSubView as waiting when no action_prompt', () async {
      final (:container, :http, :ws) = _createTestSetup();
      addTearDown(container.dispose);

      final state = await _readGameState(container);
      expect(state.nightSubView, NightSubView.waiting);
    });
  });

  group('GameNotifier initial load in voting phase', () {
    test('hydrates voteProgress from server has_voted data', () async {
      final (:container, :http, :ws) = _createTestSetup(
        gameMeJson: {
          ..._defaultGameMeJson(phase: 'voting'),
          'has_voted': false,
          'players': [
            {'player_id': 1, 'display_name': 'Alice', 'has_voted': true},
            {'player_id': 2, 'display_name': 'Bob', 'has_voted': true},
            {'player_id': 3, 'display_name': 'Charlie', 'has_voted': false},
          ],
        },
      );
      addTearDown(container.dispose);

      final state = await _readGameState(container);
      expect(state.voteProgress.playerVoted[1], true);
      expect(state.voteProgress.playerVoted[2], true);
      expect(state.voteProgress.playerVoted[3], false);
      expect(state.voteProgress.currentPlayerVoted, false);
    });

    test('hydrates currentPlayerVoted when player already voted', () async {
      final (:container, :http, :ws) = _createTestSetup(
        gameMeJson: {
          ..._defaultGameMeJson(phase: 'voting'),
          'has_voted': true,
          'players': [
            {'player_id': 1, 'display_name': 'Alice', 'has_voted': true},
            {'player_id': 2, 'display_name': 'Bob', 'has_voted': false},
            {'player_id': 3, 'display_name': 'Charlie', 'has_voted': false},
          ],
        },
      );
      addTearDown(container.dispose);

      final state = await _readGameState(container);
      expect(state.voteProgress.currentPlayerVoted, true);
      expect(state.voteProgress.playerVoted[1], true);
    });

    test('leaves voteProgress empty when not in voting phase', () async {
      final (:container, :http, :ws) = _createTestSetup();
      addTearDown(container.dispose);

      final state = await _readGameState(container);
      expect(state.voteProgress.playerVoted, isEmpty);
      expect(state.voteProgress.currentPlayerVoted, false);
    });
  });

  group('GameNotifier WS event: wave_start', () {
    test('updates currentWave and deadline', () async {
      final (:container, :http, :ws) = _createTestSetup();
      addTearDown(container.dispose);

      await _readGameState(container);

      ws.addServerEvent(
        jsonEncode({
          'type': 'wave_start',
          'wave': 3,
          'deadline': '2026-03-31T06:10:00.000Z',
        }),
      );

      await Future<void>.delayed(Duration.zero);

      final state = container.read(gameProvider('test-game-id')).value!;
      expect(state.currentWave, 3);
      expect(state.deadline, isNotNull);
      expect(state.actionPrompt, isNull);
      expect(state.lastActionResult, isNull);
    });
  });

  group('GameNotifier WS event: action_prompt', () {
    test('sets nightSubView to seerChoice for multi-action types', () async {
      final (:container, :http, :ws) = _createTestSetup();
      addTearDown(container.dispose);

      await _readGameState(container);

      ws.addServerEvent(
        jsonEncode({
          'type': 'action_prompt',
          'wave': 2,
          'role_acting_as': 'Seer',
          'action_types': ['peek_player', 'peek_center'],
          'valid_targets': {
            'peek_player': {
              'players': [2, 3],
            },
            'peek_center': {
              'card_indices': [0, 1, 2],
            },
          },
        }),
      );

      await Future<void>.delayed(Duration.zero);

      final state = container.read(gameProvider('test-game-id')).value!;
      expect(state.nightSubView, NightSubView.seerChoice);
      expect(state.actionPrompt, isNotNull);
      expect(state.actionPrompt!.roleActingAs, 'Seer');
      expect(state.actionPrompt!.actionTypes, hasLength(2));
    });

    test('sets nightSubView to actionPrompt for single action type', () async {
      final (:container, :http, :ws) = _createTestSetup();
      addTearDown(container.dispose);

      await _readGameState(container);

      ws.addServerEvent(
        jsonEncode({
          'type': 'action_prompt',
          'wave': 2,
          'role_acting_as': 'Robber',
          'action_types': ['swap_with_player'],
          'valid_targets': {
            'swap_with_player': {
              'players': [1, 3],
            },
          },
        }),
      );

      await Future<void>.delayed(Duration.zero);

      final state = container.read(gameProvider('test-game-id')).value!;
      expect(state.nightSubView, NightSubView.actionPrompt);
      expect(state.actionPrompt!.actionTypes, ['swap_with_player']);
    });
  });

  group('GameNotifier WS event: action_result', () {
    test('stores result and transitions to actionResult subview', () async {
      final (:container, :http, :ws) = _createTestSetup();
      addTearDown(container.dispose);

      await _readGameState(container);

      ws.addServerEvent(
        jsonEncode({
          'type': 'action_result',
          'wave': 2,
          'revealed_info': {
            'action_type': 'peek_player',
            'target_player_id': 3,
            'role': 'werewolf',
          },
        }),
      );

      await Future<void>.delayed(Duration.zero);

      final state = container.read(gameProvider('test-game-id')).value!;
      expect(state.nightSubView, NightSubView.actionResult);
      expect(state.lastActionResult, isNotNull);
      expect(state.lastActionResult!.wave, 2);
      expect(state.lastActionResult!.revealedInfo['role'], 'werewolf');
    });
  });

  group('GameNotifier WS event: wave_complete', () {
    test('clears prompt and result, sets waiting', () async {
      final (:container, :http, :ws) = _createTestSetup();
      addTearDown(container.dispose);

      await _readGameState(container);

      // First send an action_result to set state.
      ws.addServerEvent(
        jsonEncode({
          'type': 'action_result',
          'wave': 2,
          'revealed_info': {'action_type': 'peek_player', 'role': 'seer'},
        }),
      );
      await Future<void>.delayed(Duration.zero);

      // Then wave_complete.
      ws.addServerEvent(jsonEncode({'type': 'wave_complete', 'wave': 2}));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(gameProvider('test-game-id')).value!;
      expect(state.nightSubView, NightSubView.waiting);
      expect(state.actionPrompt, isNull);
      expect(state.lastActionResult, isNull);
    });
  });

  group('GameNotifier WS event: wave_waiting', () {
    test('sets nightSubView to waiting', () async {
      final (:container, :http, :ws) = _createTestSetup();
      addTearDown(container.dispose);

      await _readGameState(container);

      ws.addServerEvent(jsonEncode({'type': 'wave_waiting', 'wave': 2}));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(gameProvider('test-game-id')).value!;
      expect(state.nightSubView, NightSubView.waiting);
    });
  });

  group('GameNotifier WS event: phase_change', () {
    test('updates phase and deadline', () async {
      final (:container, :http, :ws) = _createTestSetup();
      addTearDown(container.dispose);

      await _readGameState(container);

      ws.addServerEvent(
        jsonEncode({
          'type': 'phase_change',
          'phase': 'discussion',
          'deadline': '2026-03-31T06:15:00.000Z',
        }),
      );

      await Future<void>.delayed(Duration.zero);

      final state = container.read(gameProvider('test-game-id')).value!;
      expect(state.phase, 'discussion');
      expect(state.deadline, isNotNull);
      expect(state.actionPrompt, isNull);
      expect(state.lastActionResult, isNull);
      expect(state.nightSubView, NightSubView.waiting);
    });

    test('handles null deadline (e.g., results phase)', () async {
      final (:container, :http, :ws) = _createTestSetup();
      addTearDown(container.dispose);

      await _readGameState(container);

      ws.addServerEvent(
        jsonEncode({
          'type': 'phase_change',
          'phase': 'results',
          'deadline': null,
        }),
      );

      await Future<void>.delayed(Duration.zero);

      final state = container.read(gameProvider('test-game-id')).value!;
      expect(state.phase, 'results');
      expect(state.deadline, isNull);
    });
  });

  group('GameNotifier WS event: vote_submitted', () {
    test('marks player as voted in VoteProgress', () async {
      final (:container, :http, :ws) = _createTestSetup();
      addTearDown(container.dispose);

      await _readGameState(container);

      ws.addServerEvent(jsonEncode({'type': 'vote_submitted', 'player_id': 2}));

      await Future<void>.delayed(Duration.zero);

      final state = container.read(gameProvider('test-game-id')).value!;
      expect(state.voteProgress.playerVoted[2], true);
    });

    test('accumulates multiple vote_submitted events', () async {
      final (:container, :http, :ws) = _createTestSetup();
      addTearDown(container.dispose);

      await _readGameState(container);

      ws.addServerEvent(jsonEncode({'type': 'vote_submitted', 'player_id': 1}));
      await Future<void>.delayed(Duration.zero);

      ws.addServerEvent(jsonEncode({'type': 'vote_submitted', 'player_id': 2}));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(gameProvider('test-game-id')).value!;
      expect(state.voteProgress.playerVoted[1], true);
      expect(state.voteProgress.playerVoted[2], true);
    });
  });

  group('GameNotifier WS event: vote_reveal', () {
    test('stores vote mapping and computes tally', () async {
      final (:container, :http, :ws) = _createTestSetup();
      addTearDown(container.dispose);

      await _readGameState(container);

      ws.addServerEvent(
        jsonEncode({
          'type': 'vote_reveal',
          'votes': {'1': 3, '2': 3, '3': 1},
        }),
      );

      await Future<void>.delayed(Duration.zero);

      final state = container.read(gameProvider('test-game-id')).value!;
      expect(state.voteRevealData, isNotNull);
      expect(state.voteRevealData!.votes['1'], 3);
      expect(state.voteRevealData!.votes['2'], 3);
      expect(state.voteRevealData!.tally['3'], 2);
      expect(state.voteRevealData!.tally['1'], 1);
    });

    test('handles null (abstain) votes', () async {
      final (:container, :http, :ws) = _createTestSetup();
      addTearDown(container.dispose);

      await _readGameState(container);

      ws.addServerEvent(
        jsonEncode({
          'type': 'vote_reveal',
          'votes': {'1': 3, '2': null},
        }),
      );

      await Future<void>.delayed(Duration.zero);

      final state = container.read(gameProvider('test-game-id')).value!;
      expect(state.voteRevealData!.votes['2'], isNull);
      expect(state.voteRevealData!.tally['3'], 1);
    });
  });

  group('GameNotifier WS event: game_results', () {
    test('transitions to results phase', () async {
      final (:container, :http, :ws) = _createTestSetup();
      addTearDown(container.dispose);

      // Register the results endpoint.
      http
          .when(method: 'GET', path: '/onuw/games/test-game-id/results/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(
                path: '/onuw/games/test-game-id/results/',
              ),
              statusCode: 200,
              data: {
                'winning_teams': ['village'],
                'players': [],
              },
            ),
          );

      await _readGameState(container);

      ws.addServerEvent(
        jsonEncode({
          'type': 'game_results',
          'data': {
            'winning_teams': ['village'],
            'eliminated_player_ids': [3],
          },
        }),
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(gameProvider('test-game-id')).value!;
      expect(state.phase, 'results');
    });
  });

  group('GameNotifier full night wave cycle', () {
    test(
      'wave_start -> action_prompt -> action_result -> wave_complete',
      () async {
        final (:container, :http, :ws) = _createTestSetup();
        addTearDown(container.dispose);

        await _readGameState(container);

        // Step 1: wave_start
        ws.addServerEvent(
          jsonEncode({
            'type': 'wave_start',
            'wave': 2,
            'deadline': '2026-03-31T06:05:00.000Z',
          }),
        );
        await Future<void>.delayed(Duration.zero);

        var state = container.read(gameProvider('test-game-id')).value!;
        expect(state.currentWave, 2);

        // Step 2: action_prompt
        ws.addServerEvent(
          jsonEncode({
            'type': 'action_prompt',
            'wave': 2,
            'role_acting_as': 'Robber',
            'action_types': ['swap_with_player'],
            'valid_targets': {
              'swap_with_player': {
                'players': [1, 3],
              },
            },
          }),
        );
        await Future<void>.delayed(Duration.zero);

        state = container.read(gameProvider('test-game-id')).value!;
        expect(state.nightSubView, NightSubView.actionPrompt);
        expect(state.actionPrompt, isNotNull);

        // Step 3: action_result
        ws.addServerEvent(
          jsonEncode({
            'type': 'action_result',
            'wave': 2,
            'revealed_info': {
              'action_type': 'swap_with_player',
              'target_player_id': 3,
              'new_role': 'werewolf',
            },
          }),
        );
        await Future<void>.delayed(Duration.zero);

        state = container.read(gameProvider('test-game-id')).value!;
        expect(state.nightSubView, NightSubView.actionResult);
        expect(state.lastActionResult!.revealedInfo['new_role'], 'werewolf');

        // Step 4: wave_complete
        ws.addServerEvent(jsonEncode({'type': 'wave_complete', 'wave': 2}));
        await Future<void>.delayed(Duration.zero);

        state = container.read(gameProvider('test-game-id')).value!;
        expect(state.nightSubView, NightSubView.waiting);
        expect(state.actionPrompt, isNull);
        expect(state.lastActionResult, isNull);
      },
    );
  });

  group('GameNotifier vote_reveal 5-second timeout', () {
    test('marks voteRevealData when vote_reveal event is received', () async {
      // Verifies the intermediate state before the timeout fires.
      // The widget-test coverage for the 5-second fallback is in
      // voting_flow_test.dart (testWidgets advances fake time via tester.pump).
      final (:container, :http, :ws) = _createTestSetup();
      addTearDown(container.dispose);

      http
          .when(method: 'GET', path: '/onuw/games/test-game-id/results/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(
                path: '/onuw/games/test-game-id/results/',
              ),
              statusCode: 200,
              data: {
                'winning_teams': ['village'],
                'players': [],
              },
            ),
          );

      await _readGameState(container);

      ws.addServerEvent(
        jsonEncode({
          'type': 'vote_reveal',
          'votes': {'1': 2, '2': 3},
        }),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(gameProvider('test-game-id')).value!;
      expect(state.voteRevealData, isNotNull);
      expect(state.voteRevealData!.votes['1'], 2);
      expect(state.voteRevealData!.votes['2'], 3);
    });
  });

  group('GameNotifier Doppelganger multi-step', () {
    test(
      'action_result followed by another action_prompt in same wave',
      () async {
        final (:container, :http, :ws) = _createTestSetup();
        addTearDown(container.dispose);

        await _readGameState(container);

        // Doppelganger's initial action_prompt.
        ws.addServerEvent(
          jsonEncode({
            'type': 'action_prompt',
            'wave': 1,
            'role_acting_as': 'Doppelganger',
            'action_types': ['peek_player'],
            'valid_targets': {
              'peek_player': {
                'players': [2, 3],
              },
            },
          }),
        );
        await Future<void>.delayed(Duration.zero);

        var state = container.read(gameProvider('test-game-id')).value!;
        expect(state.nightSubView, NightSubView.actionPrompt);
        expect(state.actionPrompt!.roleActingAs, 'Doppelganger');

        // Doppelganger's action_result (copied Seer).
        ws.addServerEvent(
          jsonEncode({
            'type': 'action_result',
            'wave': 1,
            'revealed_info': {
              'action_type': 'peek_player',
              'role': 'seer',
              'copied_role': 'seer',
            },
          }),
        );
        await Future<void>.delayed(Duration.zero);

        state = container.read(gameProvider('test-game-id')).value!;
        expect(state.nightSubView, NightSubView.actionResult);

        // Follow-up action_prompt (now acting as Seer).
        ws.addServerEvent(
          jsonEncode({
            'type': 'action_prompt',
            'wave': 1,
            'role_acting_as': 'Seer',
            'action_types': ['peek_player', 'peek_center'],
            'valid_targets': {
              'peek_player': {
                'players': [2, 3],
              },
              'peek_center': {
                'card_indices': [0, 1, 2],
              },
            },
          }),
        );
        await Future<void>.delayed(Duration.zero);

        state = container.read(gameProvider('test-game-id')).value!;
        expect(state.nightSubView, NightSubView.seerChoice);
        expect(state.actionPrompt!.roleActingAs, 'Seer');
      },
    );
  });
}
