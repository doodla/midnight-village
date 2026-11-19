import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/wakelock/wakelock_service.dart';
import 'package:midnight_village/design_system/tokens/app_tokens.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import 'package:midnight_village/design_system/tokens/midnight_village_theme.dart';
import 'package:midnight_village/design_system/tokens/theme_bridge.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/game/data/game_service.dart';
import 'package:midnight_village/features/game/domain/game_session_state.dart';
import 'package:midnight_village/features/game/presentation/game_container_screen.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import 'fake_wakelock_service.dart';
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
    int userId = 1,
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

    // The `/me/` players, everyone connected unless a player there is marked
    // away or a test says otherwise (registerPresence).
    http
        .when(method: 'GET', path: '/onuw/games/$gameId/players/')
        .thenReturn(
          Response(
            requestOptions: RequestOptions(
              path: '/onuw/games/$gameId/players/',
            ),
            statusCode: 200,
            data: <String, dynamic>{
              'players': [
                for (final p in (json['players'] as List).cast<Map>())
                  {...p, 'connected': p['connected'] ?? true},
              ],
            },
          ),
        );

    final client = AuthenticatedClient.forTesting(dio: http.dio);

    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWithValue(
          AuthState.authenticated(User(id: userId, displayName: 'P$userId')),
        ),
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

  /// Replaces the `/me/` response (a later fetch sees the new state).
  void registerGameMe(Map<String, dynamic> json) {
    registerGet('/onuw/games/$gameId/me/', json);
  }

  /// The player list's `connected` flags, keyed by player id.
  void registerPresence(Map<int, bool> connected) {
    registerGet('/onuw/games/$gameId/players/', {
      'players': [
        for (final e in connected.entries)
          {
            'player_id': e.key,
            'display_name': 'P${e.key}',
            'connected': e.value,
          },
      ],
    });
  }

  void registerGet(String path, dynamic data, {int statusCode = 200}) {
    http
        .when(method: 'GET', path: path)
        .thenReturn(
          Response(
            requestOptions: RequestOptions(path: path),
            statusCode: statusCode,
            data: data,
          ),
        );
  }

  void registerPost(String path, {dynamic data, int statusCode = 200}) {
    http
        .when(method: 'POST', path: path)
        .thenReturn(
          Response(
            requestOptions: RequestOptions(path: path),
            statusCode: statusCode,
            data: data ?? <String, dynamic>{},
          ),
        );
  }

  void dispose() {
    _subscription?.close();
    container.dispose();
  }
}

/// Extension for pumping [GameContainerScreen] with full mock wiring.
extension GameFlowTestExtension on WidgetTester {
  /// Pumps [GameContainerScreen] with mocked [GameNotifier] backed by real
  /// HTTP/WS mocks. Returns the [GameTestSetup] for event injection and
  /// state inspection.
  ///
  /// [theme] defaults to the test theme ([MidnightVillageTheme], system font);
  /// pass the app's own theme to see the screen as players do.
  Future<GameTestSetup> pumpGameFlow({
    String gameId = 'test-game-id',
    Map<String, dynamic>? gameMeJson,
    String playerName = 'TestPlayer',
    int userId = 1,
    FakeWakelockService? wakelock,
    AppTokens theme = const MidnightVillageTheme(),
    List<Override>? extraOverrides,
  }) async {
    final setup = GameTestSetup.create(
      gameMeJson: gameMeJson,
      gameId: gameId,
      userId: userId,
    );

    await pumpWidget(
      ProviderScope(
        overrides: [
          activeThemeProvider.overrideWithValue(theme),
          authProvider.overrideWithValue(
            AuthState.authenticated(User(id: userId, displayName: playerName)),
          ),
          authenticatedClientProvider.overrideWithValue(
            AuthenticatedClient.forTesting(dio: setup.http.dio),
          ),
          gameServiceProvider.overrideWithValue(
            GameService(
              client: AuthenticatedClient.forTesting(dio: setup.http.dio),
            ),
          ),
          gameWebSocketProvider.overrideWith((ref, gameId) => null),
          gameWebSocketStreamProvider.overrideWith(
            (ref, gameId) => setup.ws.stream,
          ),
          // Never touch the wakelock plugin from a widget test.
          wakelockServiceProvider.overrideWithValue(
            wakelock ?? FakeWakelockService(),
          ),
          ...?extraOverrides,
        ],
        child: MaterialApp(
          theme: generateThemeData(theme),
          home: GameContainerScreen(gameId: gameId),
        ),
      ),
    );

    // Let the async provider resolve. pumpAndSettle() cannot be used here
    // because NightWaitingView has an infinite pulse animation that never
    // settles. Instead, use pump() calls to drain the microtask queue and
    // rebuild the widget tree after the Future resolves.
    await pump();
    await pump(const Duration(milliseconds: 50));

    return setup;
  }
}
