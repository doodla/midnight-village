import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/websocket/reconnecting_websocket.dart';
import 'package:midnight_village/core/wakelock/wakelock_service.dart';
import 'package:midnight_village/design_system/tokens/app_tokens.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import '../design_system/test_helpers/midnight_village_theme.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';
import 'package:midnight_village/design_system/skin/skins/shadow_paper.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/game/data/game_service.dart';
import 'package:midnight_village/features/game/domain/game_session_state.dart';
import 'package:midnight_village/features/game/presentation/game_container_screen.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import 'contract/contract_samples.dart';
import 'contract/server_json.dart';
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
  ///
  /// [gameMeJson] is the `/me/` answer (default: [GameMeJsonBuilder]). The
  /// player list (`GET .../players/`, where presence comes from) has the same
  /// players, all connected but [away]. [socket] stands in for the game's
  /// reconnecting socket (its connection state), when a test needs one.
  factory GameTestSetup.create({
    Map<String, dynamic>? gameMeJson,
    String gameId = 'test-game-id',
    int userId = 1,
    Set<int> away = const {},
    ReconnectingWebSocket? socket,
  }) {
    final http = MockHttpClient();
    final ws = MockWebSocketChannel();
    final client = AuthenticatedClient.forTesting(dio: http.dio);
    final setup = GameTestSetup._(
      container: ProviderContainer(
        overrides: [
          authProvider.overrideWithValue(
            AuthState.authenticated(User(id: userId, displayName: 'P$userId')),
          ),
          authenticatedClientProvider.overrideWithValue(client),
          gameServiceProvider.overrideWithValue(GameService(client: client)),
          gameWebSocketProvider.overrideWith((ref, gameId) => socket),
          gameWebSocketStreamProvider.overrideWith((ref, gameId) => ws.stream),
        ],
      ),
      http: http,
      ws: ws,
      gameId: gameId,
    );
    final me =
        gameMeJson ??
        (GameMeJsonBuilder()
              ..withGameId(gameId)
              ..forViewer(userId))
            .build();
    setup
      ..registerGameMe(me)
      ..registerPlayersOf(me, away: away);
    return setup;
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

  /// `GET .../results/` (default: [serverResults]).
  void registerResults({Map<String, dynamic>? resultsJson}) {
    registerGet('/onuw/games/$gameId/results/', resultsJson ?? serverResults());
  }

  /// `GET /lobbies/<code>/`: the table this game is played at, in [status]
  /// (`finished` once its game is over, `waiting` after play again). A phone
  /// that opens a finished game checks whether the table has moved on.
  void registerTable({String code = 'ABC123', String status = 'finished'}) {
    registerGet('/lobbies/$code/', serverLobby(code: code, status: status));
  }

  /// `POST .../action/` answering [statusCode] with the server's body for it.
  void registerActionSubmit({int statusCode = 200}) {
    registerPost(
      '/onuw/games/$gameId/action/',
      statusCode: statusCode,
      data: ContractSamples.map(switch (statusCode) {
        200 => 'http/game/action_submitted',
        409 => 'http/game/action_already_acted',
        _ => 'http/game/action_invalid',
      }),
    );
  }

  /// `POST .../vote/` answering [statusCode] with the server's body for it.
  void registerVoteSubmit({int statusCode = 200}) {
    registerPost(
      '/onuw/games/$gameId/vote/',
      statusCode: statusCode,
      data: ContractSamples.map(switch (statusCode) {
        200 => 'http/game/vote_submitted',
        409 => 'http/game/vote_already_voted',
        _ => 'http/game/vote_invalid_target',
      }),
    );
  }

  /// `POST .../end-discussion/` answering [statusCode] with the server's body.
  void registerEndDiscussion({int statusCode = 200}) {
    registerPost(
      '/onuw/games/$gameId/end-discussion/',
      statusCode: statusCode,
      data: ContractSamples.map(switch (statusCode) {
        200 => 'http/game/end_discussion',
        403 => 'http/game/end_discussion_not_host',
        _ => 'http/game/end_discussion_wrong_phase',
      }),
    );
  }

  /// Replaces the `/me/` response (a later fetch sees the new state).
  void registerGameMe(Map<String, dynamic> json) {
    registerGet('/onuw/games/$gameId/me/', json);
  }

  /// The player list for the players of the `/me/` body [me], all connected
  /// but [away] (in the vote, with each one's `has_voted`).
  void registerPlayersOf(Map<String, dynamic> me, {Set<int> away = const {}}) {
    final players = (me['players'] as List).cast<Map<String, dynamic>>();
    registerGet(
      '/onuw/games/$gameId/players/',
      serverPlayerList(
        seats: [
          for (final p in players)
            (id: p['player_id'] as int, name: p['display_name'] as String),
        ],
        away: away,
        hasVoted: me['phase'] == 'voting'
            ? {
                for (final p in players)
                  p['player_id'] as int: p['has_voted'] == true,
              }
            : null,
      ),
    );
  }

  /// The player list's `connected` flags, keyed by player id.
  void registerPresence(Map<int, bool> connected) {
    registerGet(
      '/onuw/games/$gameId/players/',
      serverPlayerList(
        seats: [for (final id in connected.keys) (id: id, name: 'P$id')],
        away: {
          for (final e in connected.entries)
            if (!e.value) e.key,
        },
      ),
    );
  }

  /// Answers `GET [path]`; [offContract] is for a body the server would
  /// never send (a test about malformed input).
  void registerGet(
    String path,
    dynamic data, {
    int statusCode = 200,
    bool offContract = false,
  }) {
    http
        .when(method: 'GET', path: path)
        .thenReturn(
          Response(
            requestOptions: RequestOptions(path: path),
            statusCode: statusCode,
            data: data,
          ),
          offContract: offContract,
        );
  }

  /// Answers `POST [path]` with [data], by default the server's recorded
  /// answer for that endpoint and status.
  void registerPost(String path, {dynamic data, int statusCode = 200}) {
    http
        .when(method: 'POST', path: path)
        .thenReturn(
          Response(
            requestOptions: RequestOptions(path: path),
            statusCode: statusCode,
            data:
                data ??
                ContractSamples.bodyFor('POST', path, status: statusCode),
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
    Set<int> away = const {},
    FakeWakelockService? wakelock,
    AppTokens theme = const MidnightVillageTheme(),
    List<Override>? extraOverrides,
  }) async {
    final setup = GameTestSetup.create(
      gameMeJson: gameMeJson,
      gameId: gameId,
      userId: userId,
      away: away,
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
          theme: skinTheme(shadowPaper),
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
