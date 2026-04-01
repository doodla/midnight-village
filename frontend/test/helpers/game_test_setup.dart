import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/game/data/game_service.dart';
import 'package:midnight_village/features/game/domain/game_session_state.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import 'game_state_factory.dart';
import 'mock_http_client.dart';
import 'mock_websocket.dart';

/// Pre-wired test environment for GameNotifier tests.
///
/// Replaces the `_createTestSetup()` pattern duplicated across game test files.
/// Wires [GameNotifier] with [MockHttpClient] and [MockWebSocketChannel] so
/// tests can focus on behavior, not setup.
///
/// Usage:
/// ```dart
/// final setup = GameTestSetup.create();
/// addTearDown(setup.dispose);
///
/// final state = await setup.readGameState();
/// setup.ws.addServerEvent(GameEvents.waveStart(wave: 2));
/// ```
class GameTestSetup {
  GameTestSetup._({
    required this.container,
    required this.http,
    required this.ws,
    required this.gameId,
  });

  /// Creates a test setup with the GameNotifier wired to mock HTTP/WS.
  factory GameTestSetup.create({
    Map<String, dynamic>? gameMeJson,
    String gameId = 'test-game-id',
  }) {
    final http = MockHttpClient();
    final ws = MockWebSocketChannel();
    final json = gameMeJson ?? GameMeJsonBuilder().build();

    http
        .when(method: 'GET', path: '/onuw/games/$gameId/me/')
        .thenReturn(
          Response(
            requestOptions: RequestOptions(path: '/onuw/games/$gameId/me/'),
            statusCode: 200,
            data: json,
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

    return GameTestSetup._(
      container: container,
      http: http,
      ws: ws,
      gameId: gameId,
    );
  }

  final ProviderContainer container;
  final MockHttpClient http;
  final MockWebSocketChannel ws;
  final String gameId;

  ProviderSubscription<AsyncValue<GameSessionState>>? _subscription;

  Future<GameSessionState> readGameState() async {
    _subscription = container.listen(gameProvider(gameId), (_, _) {});
    return container.read(gameProvider(gameId).future);
  }

  GameSessionState get currentState =>
      container.read(gameProvider(gameId)).value!;

  void registerResults({required Map<String, dynamic> resultsJson}) {
    http
        .when(method: 'GET', path: '/onuw/games/$gameId/results/')
        .thenReturn(
          Response(
            requestOptions: RequestOptions(
              path: '/onuw/games/$gameId/results/',
            ),
            statusCode: 200,
            data: resultsJson,
          ),
        );
  }

  void registerActionSubmit({int statusCode = 200}) {
    http
        .when(method: 'POST', path: '/onuw/games/$gameId/action/')
        .thenReturn(
          Response(
            requestOptions: RequestOptions(path: '/onuw/games/$gameId/action/'),
            statusCode: statusCode,
            data: <String, dynamic>{},
          ),
        );
  }

  void registerVoteSubmit({int statusCode = 200}) {
    http
        .when(method: 'POST', path: '/onuw/games/$gameId/vote/')
        .thenReturn(
          Response(
            requestOptions: RequestOptions(path: '/onuw/games/$gameId/vote/'),
            statusCode: statusCode,
            data: <String, dynamic>{},
          ),
        );
  }

  void registerEndDiscussion({int statusCode = 200}) {
    http
        .when(method: 'POST', path: '/onuw/games/$gameId/end-discussion/')
        .thenReturn(
          Response(
            requestOptions: RequestOptions(
              path: '/onuw/games/$gameId/end-discussion/',
            ),
            statusCode: statusCode,
            data: <String, dynamic>{},
          ),
        );
  }

  void dispose() {
    _subscription?.close();
    container.dispose();
  }
}
