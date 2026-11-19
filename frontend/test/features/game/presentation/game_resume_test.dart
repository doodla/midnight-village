import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/websocket/websocket_channel.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import '../../../design_system/test_helpers/midnight_village_theme.dart';
import 'package:midnight_village/features/game/data/game_resume_service.dart';
import 'package:midnight_village/features/game/presentation/reconnection_notifier.dart';

import '../../../helpers/mock_http_client.dart';

void main() {
  group('CurrentGameResponse', () {
    test('parses response with active game', () {
      final response = CurrentGameResponse.fromJson({
        'game_id': '550e8400-e29b-41d4-a716-446655440000',
        'phase': 'night',
        'lobby_code': 'ABC123',
      });

      expect(response.hasActiveGame, isTrue);
      expect(response.gameId, '550e8400-e29b-41d4-a716-446655440000');
      expect(response.phase, 'night');
      expect(response.lobbyCode, 'ABC123');
    });

    test('parses response with no active game', () {
      final response = CurrentGameResponse.fromJson({'game': null});

      expect(response.hasActiveGame, isFalse);
      expect(response.gameId, isNull);
      expect(response.phase, isNull);
      expect(response.lobbyCode, isNull);
    });

    test('handles nested game object', () {
      final response = CurrentGameResponse.fromJson({
        'game': {'game_id': 'abc-123', 'phase': 'voting', 'lobby_code': 'XYZ'},
      });

      expect(response.hasActiveGame, isTrue);
      expect(response.gameId, 'abc-123');
      expect(response.phase, 'voting');
    });
  });

  group('GameResumeService', () {
    late MockHttpClient mockHttp;
    late GameResumeService service;

    setUp(() {
      mockHttp = MockHttpClient();
      service = GameResumeService(
        apiClient: AuthenticatedClient.forTesting(dio: mockHttp.dio),
      );
    });

    test('returns active game when server has one', () async {
      mockHttp
          .when(method: 'GET', path: '/onuw/me/current-game/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(path: '/onuw/me/current-game/'),
              statusCode: 200,
              data: {
                'game_id': 'game-42',
                'phase': 'night',
                'lobby_code': 'ABC',
              },
            ),
          );

      final result = await service.checkCurrentGame();

      expect(result.hasActiveGame, isTrue);
      expect(result.gameId, 'game-42');
    });

    test('returns no game when server reports null', () async {
      mockHttp
          .when(method: 'GET', path: '/onuw/me/current-game/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(path: '/onuw/me/current-game/'),
              statusCode: 200,
              data: {'game': null},
            ),
          );

      final result = await service.checkCurrentGame();

      expect(result.hasActiveGame, isFalse);
    });

    test('caches result and returns cached on second call', () async {
      mockHttp
          .when(method: 'GET', path: '/onuw/me/current-game/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(path: '/onuw/me/current-game/'),
              statusCode: 200,
              data: {'game_id': 'game-1', 'phase': 'night', 'lobby_code': 'A'},
            ),
          );

      final first = await service.checkCurrentGame();
      expect(first.gameId, 'game-1');

      // Second call should return cached result.
      expect(service.hasChecked, isTrue);
      final second = await service.checkCurrentGame();
      expect(second.gameId, 'game-1');
    });

    test('force refresh bypasses cache', () async {
      mockHttp
          .when(method: 'GET', path: '/onuw/me/current-game/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(path: '/onuw/me/current-game/'),
              statusCode: 200,
              data: {'game_id': 'game-2', 'phase': 'voting', 'lobby_code': 'B'},
            ),
          );

      await service.checkCurrentGame();
      final result = await service.checkCurrentGame(force: true);

      expect(result.gameId, 'game-2');
    });

    test('clearCache resets cached state', () async {
      mockHttp
          .when(method: 'GET', path: '/onuw/me/current-game/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(path: '/onuw/me/current-game/'),
              statusCode: 200,
              data: {'game_id': 'game-3', 'phase': 'night', 'lobby_code': 'C'},
            ),
          );

      await service.checkCurrentGame();
      expect(service.hasChecked, isTrue);

      service.clearCache();
      expect(service.hasChecked, isFalse);
      expect(service.cachedResult, isNull);
    });
  });

  group('ReconnectionState', () {
    test('showOverlay is true when disconnected', () {
      const state = ReconnectionState(
        connectionState: WebSocketConnectionState.disconnected,
        needsStateRefresh: false,
        wasDisconnected: true,
      );

      expect(state.showOverlay, isTrue);
    });

    test('showOverlay is true when reconnecting', () {
      const state = ReconnectionState(
        connectionState: WebSocketConnectionState.reconnecting,
        needsStateRefresh: false,
        wasDisconnected: true,
      );

      expect(state.showOverlay, isTrue);
    });

    test('showOverlay is false when connected', () {
      const state = ReconnectionState(
        connectionState: WebSocketConnectionState.connected,
        needsStateRefresh: false,
        wasDisconnected: false,
      );

      expect(state.showOverlay, isFalse);
    });

    test('showOverlay is false when connecting', () {
      const state = ReconnectionState(
        connectionState: WebSocketConnectionState.connecting,
        needsStateRefresh: false,
        wasDisconnected: false,
      );

      expect(state.showOverlay, isFalse);
    });

    test('copyWith preserves unmodified fields', () {
      const original = ReconnectionState(
        connectionState: WebSocketConnectionState.connected,
        needsStateRefresh: true,
        wasDisconnected: false,
      );

      final copied = original.copyWith(needsStateRefresh: false);

      expect(copied.connectionState, WebSocketConnectionState.connected);
      expect(copied.needsStateRefresh, isFalse);
      expect(copied.wasDisconnected, isFalse);
    });

    test('equality works correctly', () {
      const a = ReconnectionState(
        connectionState: WebSocketConnectionState.connected,
        needsStateRefresh: false,
        wasDisconnected: false,
      );

      const b = ReconnectionState(
        connectionState: WebSocketConnectionState.connected,
        needsStateRefresh: false,
        wasDisconnected: false,
      );

      const c = ReconnectionState(
        connectionState: WebSocketConnectionState.disconnected,
        needsStateRefresh: false,
        wasDisconnected: false,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('ReconnectionNotifier (unit logic)', () {
    // Test the state machine logic that the notifier implements.
    // Uses a pure function that mirrors the notifier's _onStateChange.

    test('connected after disconnected sets needsStateRefresh', () {
      // connecting -> connected -> disconnected -> connected
      var state = const ReconnectionState(
        connectionState: WebSocketConnectionState.connecting,
        needsStateRefresh: false,
        wasDisconnected: false,
      );

      // Initial connect -- no refresh needed
      state = _applyTransition(state, WebSocketConnectionState.connected);
      expect(state.needsStateRefresh, isFalse);
      expect(state.showOverlay, isFalse);

      // Disconnect
      state = _applyTransition(state, WebSocketConnectionState.disconnected);
      expect(state.showOverlay, isTrue);
      expect(state.wasDisconnected, isTrue);

      // Reconnecting
      state = _applyTransition(state, WebSocketConnectionState.reconnecting);
      expect(state.showOverlay, isTrue);

      // Reconnected -- should flag for refresh
      state = _applyTransition(state, WebSocketConnectionState.connected);
      expect(state.needsStateRefresh, isTrue);
      expect(state.showOverlay, isFalse);
    });

    test('initial connection does not set needsStateRefresh', () {
      var state = const ReconnectionState(
        connectionState: WebSocketConnectionState.connecting,
        needsStateRefresh: false,
        wasDisconnected: false,
      );

      state = _applyTransition(state, WebSocketConnectionState.connected);
      expect(state.needsStateRefresh, isFalse);
    });

    test('acknowledgeRefresh clears the flag', () {
      const state = ReconnectionState(
        connectionState: WebSocketConnectionState.connected,
        needsStateRefresh: true,
        wasDisconnected: false,
      );

      final acknowledged = state.copyWith(needsStateRefresh: false);
      expect(acknowledged.needsStateRefresh, isFalse);
      expect(acknowledged.connectionState, WebSocketConnectionState.connected);
    });

    test('multiple disconnects only trigger one refresh on reconnect', () {
      var state = const ReconnectionState(
        connectionState: WebSocketConnectionState.connected,
        needsStateRefresh: false,
        wasDisconnected: false,
      );

      // Several disconnect/reconnecting cycles
      state = _applyTransition(state, WebSocketConnectionState.disconnected);
      state = _applyTransition(state, WebSocketConnectionState.reconnecting);
      state = _applyTransition(state, WebSocketConnectionState.disconnected);
      state = _applyTransition(state, WebSocketConnectionState.reconnecting);

      // Finally reconnect
      state = _applyTransition(state, WebSocketConnectionState.connected);
      expect(state.needsStateRefresh, isTrue);
      expect(state.wasDisconnected, isFalse);
    });

    test('reconnect after initial failure triggers refresh', () {
      // connecting -> disconnected -> reconnecting -> connected
      var state = const ReconnectionState(
        connectionState: WebSocketConnectionState.connecting,
        needsStateRefresh: false,
        wasDisconnected: false,
      );

      // Initial connection fails
      state = _applyTransition(state, WebSocketConnectionState.disconnected);
      expect(state.wasDisconnected, isTrue);

      // Attempting reconnect
      state = _applyTransition(state, WebSocketConnectionState.reconnecting);

      // Successfully connects (this is technically a "reconnect" since we
      // were disconnected)
      state = _applyTransition(state, WebSocketConnectionState.connected);
      expect(state.needsStateRefresh, isTrue);
    });
  });

  group('GameStateResponse', () {
    test('parses full response from server', () {
      final response = GameStateResponse.fromJson({
        'phase': 'night',
        'current_wave': 'wave_1',
        'deadline': '2026-03-31T10:00:00Z',
        'your_role': 'werewolf',
        'action_prompt': {'type': 'view', 'targets': []},
        'players': [
          {'id': '1', 'display_name': 'Alice'},
          {'id': '2', 'display_name': 'Bob'},
        ],
        'has_voted': false,
        'has_acted': false,
      });

      expect(response.phase, 'night');
      expect(response.currentWave, 'wave_1');
      expect(response.deadline, '2026-03-31T10:00:00Z');
      expect(response.yourRole, 'werewolf');
      expect(response.actionPrompt, isNotNull);
      expect(response.players, hasLength(2));
      expect(response.hasVoted, isFalse);
      expect(response.hasActed, isFalse);
    });

    test('parses player who has already acted', () {
      final response = GameStateResponse.fromJson({
        'phase': 'night',
        'has_acted': true,
        'action_prompt': null,
        'players': [],
        'has_voted': false,
      });

      expect(response.hasActed, isTrue);
      expect(response.actionPrompt, isNull);
    });

    test('parses player who has already voted', () {
      final response = GameStateResponse.fromJson({
        'phase': 'voting',
        'has_voted': true,
        'has_acted': true,
        'action_prompt': null,
        'players': [
          {'id': '1', 'display_name': 'Alice', 'has_voted': true},
        ],
      });

      expect(response.hasVoted, isTrue);
      expect(response.phase, 'voting');
    });

    test('handles missing optional fields gracefully', () {
      final response = GameStateResponse.fromJson({
        'phase': 'discussion',
        'has_voted': false,
        'has_acted': true,
      });

      expect(response.phase, 'discussion');
      expect(response.currentWave, isNull);
      expect(response.deadline, isNull);
      expect(response.yourRole, isNull);
      expect(response.actionPrompt, isNull);
      expect(response.players, isEmpty);
    });
  });

  group('GameResumeService.getGameState', () {
    late MockHttpClient mockHttp;
    late GameResumeService service;

    setUp(() {
      mockHttp = MockHttpClient();
      service = GameResumeService(
        apiClient: AuthenticatedClient.forTesting(dio: mockHttp.dio),
      );
    });

    test('calls /onuw/games/<id>/me/ and returns parsed state', () async {
      mockHttp
          .when(method: 'GET', path: '/onuw/games/game-42/me/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(path: '/onuw/games/game-42/me/'),
              statusCode: 200,
              data: {
                'phase': 'night',
                'has_acted': false,
                'action_prompt': {'type': 'view'},
                'players': [],
                'has_voted': false,
              },
            ),
          );

      final state = await service.getGameState('game-42');

      expect(state.phase, 'night');
      expect(state.hasActed, isFalse);
      expect(state.actionPrompt, isNotNull);
    });

    test(
      'reconnection state: has_acted true, no action_prompt → waiting',
      () async {
        mockHttp
            .when(method: 'GET', path: '/onuw/games/game-42/me/')
            .thenReturn(
              Response(
                requestOptions: RequestOptions(path: '/onuw/games/game-42/me/'),
                statusCode: 200,
                data: {
                  'phase': 'night',
                  'has_acted': true,
                  'action_prompt': null,
                  'players': [],
                  'has_voted': false,
                },
              ),
            );

        final state = await service.getGameState('game-42');

        // When has_acted is true and no action_prompt, the player is in
        // the waiting sub-view (they already completed their night action).
        expect(state.hasActed, isTrue);
        expect(state.actionPrompt, isNull);
      },
    );

    test(
      'reconnection state: has_voted true → locked vote submission',
      () async {
        mockHttp
            .when(method: 'GET', path: '/onuw/games/game-42/me/')
            .thenReturn(
              Response(
                requestOptions: RequestOptions(path: '/onuw/games/game-42/me/'),
                statusCode: 200,
                data: {
                  'phase': 'voting',
                  'has_voted': true,
                  'has_acted': true,
                  'action_prompt': null,
                  'players': [
                    {'id': '1', 'display_name': 'Alice', 'has_voted': true},
                  ],
                },
              ),
            );

        final state = await service.getGameState('game-42');

        // When has_voted is true, the VoteSubmission should appear locked.
        expect(state.hasVoted, isTrue);
        expect(state.phase, 'voting');
      },
    );

    test('phase changed during disconnect is reflected in response', () async {
      mockHttp
          .when(method: 'GET', path: '/onuw/games/game-42/me/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(path: '/onuw/games/game-42/me/'),
              statusCode: 200,
              data: {
                'phase': 'discussion',
                'has_voted': false,
                'has_acted': true,
                'action_prompt': null,
                'players': [],
              },
            ),
          );

      // When the game advanced to discussion while the player was disconnected,
      // the re-fetched state reflects the new phase — not the pre-disconnect state.
      final state = await service.getGameState('game-42');
      expect(state.phase, 'discussion');
    });
  });

  group('Router startup detection', () {
    // These tests verify the redirect logic that the app router uses to
    // navigate authenticated users to an in-progress game on startup.

    test('redirect logic returns /game/:id when active game exists', () async {
      final mockHttp = MockHttpClient();
      mockHttp
          .when(method: 'GET', path: '/onuw/me/current-game/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(path: '/onuw/me/current-game/'),
              statusCode: 200,
              data: {
                'game_id': 'game-42',
                'phase': 'night',
                'lobby_code': 'ABC',
              },
            ),
          );

      final service = GameResumeService(
        apiClient: AuthenticatedClient.forTesting(dio: mockHttp.dio),
      );
      final result = await service.checkCurrentGame();

      // The app router redirect function returns this path when hasActiveGame.
      final redirect = result.hasActiveGame ? '/game/${result.gameId}' : null;
      expect(redirect, '/game/game-42');
    });

    test('redirect logic returns null when no active game', () async {
      final mockHttp = MockHttpClient();
      mockHttp
          .when(method: 'GET', path: '/onuw/me/current-game/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(path: '/onuw/me/current-game/'),
              statusCode: 200,
              data: {'game': null},
            ),
          );

      final service = GameResumeService(
        apiClient: AuthenticatedClient.forTesting(dio: mockHttp.dio),
      );
      final result = await service.checkCurrentGame();

      final redirect = result.hasActiveGame ? '/game/${result.gameId}' : null;
      expect(redirect, isNull);
    });

    testWidgets('router navigates to /game/:id when active game exists', (
      tester,
    ) async {
      final mockHttp = MockHttpClient();
      mockHttp
          .when(method: 'GET', path: '/onuw/me/current-game/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(path: '/onuw/me/current-game/'),
              statusCode: 200,
              data: {
                'game_id': 'game-42',
                'phase': 'night',
                'lobby_code': 'ABC',
              },
            ),
          );

      final service = GameResumeService(
        apiClient: AuthenticatedClient.forTesting(dio: mockHttp.dio),
      );

      // Use a lightweight test router with stub routes — avoids pulling in
      // GameContainerScreen's WebSocket infrastructure.
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/game/:gameId',
            builder: (context, state) =>
                Scaffold(body: Text('Game ${state.pathParameters['gameId']}')),
          ),
        ],
        redirect: (context, state) async {
          if (state.matchedLocation != '/') return null;
          try {
            final result = await service.checkCurrentGame();
            if (result.hasActiveGame) return '/game/${result.gameId}';
          } catch (_) {}
          return null;
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeThemeProvider.overrideWithValue(const MidnightVillageTheme()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Game game-42'), findsOneWidget);
    });

    testWidgets('router stays on home when no active game', (tester) async {
      final mockHttp = MockHttpClient();
      mockHttp
          .when(method: 'GET', path: '/onuw/me/current-game/')
          .thenReturn(
            Response(
              requestOptions: RequestOptions(path: '/onuw/me/current-game/'),
              statusCode: 200,
              data: {'game': null},
            ),
          );

      final service = GameResumeService(
        apiClient: AuthenticatedClient.forTesting(dio: mockHttp.dio),
      );

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(
            path: '/game/:gameId',
            builder: (context, state) =>
                Scaffold(body: Text('Game ${state.pathParameters['gameId']}')),
          ),
        ],
        redirect: (context, state) async {
          if (state.matchedLocation != '/') return null;
          try {
            final result = await service.checkCurrentGame();
            if (result.hasActiveGame) return '/game/${result.gameId}';
          } catch (_) {}
          return null;
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeThemeProvider.overrideWithValue(const MidnightVillageTheme()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.textContaining('Game'), findsNothing);
    });
  });
}

/// Applies the same state transition logic that ReconnectionNotifier uses.
///
/// Mirrors the _onStateChange method for unit testing the state machine
/// without needing a Riverpod container.
ReconnectionState _applyTransition(
  ReconnectionState current,
  WebSocketConnectionState newConnectionState,
) {
  final wasDisconnected =
      current.wasDisconnected ||
      current.connectionState == WebSocketConnectionState.disconnected ||
      current.connectionState == WebSocketConnectionState.reconnecting;

  if (newConnectionState == WebSocketConnectionState.connected &&
      wasDisconnected) {
    return ReconnectionState(
      connectionState: newConnectionState,
      needsStateRefresh: true,
      wasDisconnected: false,
    );
  } else {
    final isDisconnected =
        newConnectionState == WebSocketConnectionState.disconnected ||
        newConnectionState == WebSocketConnectionState.reconnecting;

    return ReconnectionState(
      connectionState: newConnectionState,
      needsStateRefresh: false,
      wasDisconnected: wasDisconnected || isDisconnected,
    );
  }
}
