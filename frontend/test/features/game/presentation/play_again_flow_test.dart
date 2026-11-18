import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/wakelock/wakelock_service.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import 'package:midnight_village/design_system/tokens/midnight_village_theme.dart';
import 'package:midnight_village/design_system/tokens/theme_bridge.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/game/data/game_service.dart';
import 'package:midnight_village/features/game/presentation/game_container_screen.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import '../../../helpers/fake_wakelock_service.dart';
import '../../../helpers/game_events.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

const _gameId = 'test-game-id';
const _code = 'ABC123';

Map<String, dynamic> _resultsJson() => {
  'winning_teams': ['village'],
  'reason': 'The werewolf was found.',
  'center_cards': <String>[],
  'players': [
    for (final (i, name) in ['Alice', 'Bob', 'Charlie'].indexed)
      {
        'player_id': i + 1,
        'display_name': name,
        'original_role': 'villager',
        'final_role': 'villager',
        'team': 'village',
        'is_eliminated': false,
        'outcome': 'win',
      },
  ],
  'votes': <dynamic>[],
};

Map<String, dynamic> _lobbyJson({String status = 'waiting'}) => {
  'code': _code,
  'host': {'id': 1, 'display_name': 'Alice'},
  'players': [
    for (final (i, name) in ['Alice', 'Bob', 'Charlie'].indexed)
      {
        'user': {'id': i + 1, 'display_name': name},
        'is_ready': true,
        'joined_at': '2026-03-31T00:00:00Z',
      },
  ],
  'status': status,
  'max_players': 10,
  'settings': {
    'roles': {'Werewolf': 2, 'Seer': 1, 'Villager': 3},
  },
};

/// Rejects every later POST with [statusCode], like the server saying no.
void _rejectPostsWith(GameTestSetup setup, int statusCode) {
  // First in line, ahead of the mock that answers every request.
  setup.http.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.method != 'POST') return handler.next(options);
        handler.reject(
          DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: statusCode,
              data: {'detail': 'no'},
            ),
            type: DioExceptionType.badResponse,
          ),
        );
      },
    ),
  );
}

class _Pumped {
  _Pumped(this.setup, this.router, this.wakelock);
  final GameTestSetup setup;
  final GoRouter router;
  final FakeWakelockService wakelock;

  String get location => router.state.uri.toString();
  List<RequestOptions> posts(String suffix) => setup.http.requests
      .where((r) => r.method == 'POST' && r.path.endsWith(suffix))
      .toList();
}

/// Pumps the game screen on the results phase inside a small router that has
/// a home and a lobby stub, so navigation can be asserted.
Future<_Pumped> _pumpResults(
  WidgetTester tester, {
  bool isHost = true,
  String? lobbyCode = _code,
  Map<String, dynamic>? lobbyAfterwards,
}) async {
  final me = GameMeJsonBuilder().inPhase('results');
  if (isHost) me.asHost();
  final setup = GameTestSetup.create(gameMeJson: me.build());
  setup.registerResults(resultsJson: _resultsJson());
  if (lobbyAfterwards != null) {
    setup.registerGet('/lobbies/$_code/', lobbyAfterwards);
  }
  final wakelock = FakeWakelockService();
  final client = AuthenticatedClient.forTesting(dio: setup.http.dio);
  const theme = MidnightVillageTheme();

  final router = GoRouter(
    initialLocation:
        '/game/$_gameId${lobbyCode != null ? '?lobby=$lobbyCode' : ''}',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME SCREEN')),
      ),
      GoRoute(
        path: '/lobby/:code',
        builder: (_, state) => Scaffold(
          body: Text('LOBBY SCREEN ${state.pathParameters['code']}'),
        ),
      ),
      GoRoute(
        path: '/game/:gameId',
        builder: (_, state) => GameContainerScreen(
          gameId: state.pathParameters['gameId']!,
          lobbyCode: state.uri.queryParameters['lobby'],
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeThemeProvider.overrideWithValue(theme),
        authProvider.overrideWithValue(
          AuthState.authenticated(User(id: 1, displayName: 'Alice')),
        ),
        authenticatedClientProvider.overrideWithValue(client),
        gameServiceProvider.overrideWithValue(GameService(client: client)),
        gameWebSocketProvider.overrideWith((ref, gameId) => null),
        gameWebSocketStreamProvider.overrideWith(
          (ref, gameId) => setup.ws.stream,
        ),
        wakelockServiceProvider.overrideWithValue(wakelock),
      ],
      child: MaterialApp.router(
        theme: generateThemeData(theme),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  addTearDown(setup.dispose);
  return _Pumped(setup, router, wakelock);
}

/// Taps a button that may be below the fold of the scrolling results.
Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('Results screen controls', () {
    testWidgets('the host gets a Play Again button and Leave', (tester) async {
      await _pumpResults(tester);

      expect(find.text('Play Again'), findsOneWidget);
      expect(find.text('Leave'), findsOneWidget);
      expect(
        find.text('Waiting for the host to start another game.'),
        findsNothing,
      );
    });

    testWidgets('a player who is not the host has no Play Again button and is '
        'told to wait', (tester) async {
      await _pumpResults(tester, isHost: false);

      expect(find.text('Play Again'), findsNothing);
      expect(find.text('Leave'), findsOneWidget);
      expect(
        find.text('Waiting for the host to start another game.'),
        findsOneWidget,
      );
    });
  });

  group('Play Again (host)', () {
    testWidgets('calls the endpoint and takes the host to the lobby', (
      tester,
    ) async {
      final p = await _pumpResults(tester);
      p.setup.registerPost('/lobbies/$_code/play-again/', data: _lobbyJson());

      await _tap(tester, 'Play Again');
      await _settle(tester);

      expect(p.posts('/lobbies/$_code/play-again/'), hasLength(1));
      expect(p.location, '/lobby/$_code');
      expect(find.text('LOBBY SCREEN $_code'), findsOneWidget);
    });

    testWidgets('says plainly that only the host can, on a 403', (
      tester,
    ) async {
      final p = await _pumpResults(tester);
      _rejectPostsWith(p.setup, 403);

      await _tap(tester, 'Play Again');
      await _settle(tester);

      expect(
        find.text('Only the host can start another game.'),
        findsOneWidget,
      );
      expect(p.location, startsWith('/game/'));
    });

    testWidgets('says the game is not over yet, on a 409', (tester) async {
      final p = await _pumpResults(tester);
      _rejectPostsWith(p.setup, 409);

      await _tap(tester, 'Play Again');
      await _settle(tester);

      expect(
        find.text('The game is not finished yet. Try again in a moment.'),
        findsOneWidget,
      );
    });

    testWidgets('shows a plain error line when the call fails, and allows '
        'another try', (tester) async {
      final p = await _pumpResults(tester);

      // No play-again route is mocked: the call fails.
      await _tap(tester, 'Play Again');
      await _settle(tester);
      expect(
        find.text('Could not start another game. Try again.'),
        findsOneWidget,
      );
      expect(p.location, startsWith('/game/'));

      p.setup.registerPost('/lobbies/$_code/play-again/', data: _lobbyJson());
      await _tap(tester, 'Play Again');
      await _settle(tester);

      expect(p.location, '/lobby/$_code');
    });

    testWidgets('without a known table it says so instead of doing nothing', (
      tester,
    ) async {
      final p = await _pumpResults(tester, lobbyCode: null);

      await _tap(tester, 'Play Again');
      await _settle(tester);

      expect(
        find.text('Could not start another game. Try again.'),
        findsOneWidget,
      );
      expect(p.setup.http.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    test('uses the lobby code the server gives when it gives one', () async {
      final me = GameMeJsonBuilder()
          .inPhase('results')
          .asHost()
          .withLobbyCode('SRV999')
          .build();
      final setup = GameTestSetup.create(gameMeJson: me);
      addTearDown(setup.dispose);
      setup.registerResults(resultsJson: _resultsJson());
      setup.registerPost(
        '/lobbies/SRV999/play-again/',
        data: {..._lobbyJson(), 'code': 'SRV999'},
      );

      // The code comes from the state, not from the route.
      final container = setup.container;
      await setup.readGameState();
      await container.read(gameProvider(_gameId).notifier).playAgain();

      expect(setup.currentState.playAgainLobbyCode, 'SRV999');
    });
  });

  group('play_again event', () {
    testWidgets('takes a player who is not the host to the lobby', (
      tester,
    ) async {
      final p = await _pumpResults(tester, isHost: false);

      p.setup.ws.addServerEvent(GameEvents.playAgain(lobbyCode: _code));
      await _settle(tester);

      expect(p.location, '/lobby/$_code');
      expect(find.text('LOBBY SCREEN $_code'), findsOneWidget);
    });

    testWidgets('clears the finished game: its state and screen are gone, and '
        'the screen no longer holds the wake lock', (tester) async {
      final p = await _pumpResults(tester, isHost: false);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GameContainerScreen)),
      );
      expect(container.exists(gameProvider(_gameId)), isTrue);

      p.setup.ws.addServerEvent(GameEvents.playAgain(lobbyCode: _code));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(GameContainerScreen), findsNothing);
      expect(container.exists(gameProvider(_gameId)), isFalse);
      expect(p.wakelock.isEnabled, isFalse);
    });

    testWidgets('an event without a table code is ignored', (tester) async {
      final p = await _pumpResults(tester, isHost: false);

      p.setup.ws.addServerEvent({'type': 'play_again'});
      await _settle(tester);

      expect(p.location, startsWith('/game/'));
    });
  });

  group('Leave', () {
    testWidgets('leaves the table and goes to the home screen', (tester) async {
      final p = await _pumpResults(tester, isHost: false);
      p.setup.registerPost('/lobbies/$_code/leave/');

      await _tap(tester, 'Leave');
      await _settle(tester);

      expect(p.posts('/lobbies/$_code/leave/'), hasLength(1));
      expect(p.location, '/');
      expect(find.text('HOME SCREEN'), findsOneWidget);
    });

    testWidgets('still goes home when the server cannot be reached', (
      tester,
    ) async {
      final p = await _pumpResults(tester, isHost: false);

      await _tap(tester, 'Leave');
      await _settle(tester);

      expect(p.location, '/');
    });

    testWidgets('goes home without a call when the table is not known', (
      tester,
    ) async {
      final p = await _pumpResults(tester, isHost: false, lobbyCode: null);

      await _tap(tester, 'Leave');
      await _settle(tester);

      expect(p.location, '/');
      expect(p.setup.http.requests.where((r) => r.method == 'POST'), isEmpty);
    });
  });

  group('Opening a finished game after the table moved on', () {
    testWidgets('goes to the lobby when the table is waiting again', (
      tester,
    ) async {
      final p = await _pumpResults(
        tester,
        isHost: false,
        lobbyAfterwards: _lobbyJson(status: 'waiting'),
      );
      await _settle(tester);

      expect(p.location, '/lobby/$_code');
    });

    testWidgets('stays on the results while the table is still in that game', (
      tester,
    ) async {
      final p = await _pumpResults(
        tester,
        isHost: false,
        lobbyAfterwards: _lobbyJson(status: 'in_game'),
      );
      await _settle(tester);

      expect(p.location, startsWith('/game/'));
      expect(find.text('Leave'), findsOneWidget);
    });

    testWidgets('stays on the results when the table cannot be checked', (
      tester,
    ) async {
      final p = await _pumpResults(tester, isHost: false);
      await _settle(tester);

      expect(p.location, startsWith('/game/'));
    });
  });
}
