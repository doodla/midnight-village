import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import '../../../design_system/test_helpers/midnight_village_theme.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';
import 'package:midnight_village/design_system/skin/skins/shadow_paper.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/lobby/data/lobby_service.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_notifier.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/game_events.dart';
import '../../../helpers/mock_websocket.dart';

class _MockLobbyService extends Mock implements LobbyService {}

class _MockAuthenticatedClient extends Mock implements AuthenticatedClient {}

const _code = 'ABC123';

/// The table as the server returns it after "Play again": same players, same
/// deck, waiting.
LobbyState _waitingLobby({String status = 'waiting'}) => LobbyState(
  code: _code,
  hostId: 1,
  players: [
    for (final (i, name) in ['Alice', 'Bob', 'Carol'].indexed)
      LobbyPlayer(
        id: i + 1,
        displayName: name,
        isReady: true,
        joinedAt: DateTime.utc(2026, 3, 31, 0, i),
      ),
  ],
  status: status,
  maxPlayers: 10,
  roleConfig: const {'Werewolf': 2, 'Seer': 1, 'Robber': 1, 'Villager': 2},
);

class _Table {
  _Table(this.service, this.sockets, this.router);
  final _MockLobbyService service;

  /// One socket per lobby screen that was opened (each closes with its screen).
  final List<MockWebSocketChannel> sockets;
  final GoRouter router;

  MockWebSocketChannel get ws => sockets.last;

  String get location => router.state.uri.toString();
}

Future<_Table> _pumpLobby(
  WidgetTester tester, {
  int userId = 1,
  LobbyState? lobby,
  String? runningGameId,
  String runningGameCode = _code,
}) async {
  final service = _MockLobbyService();
  final sockets = <MockWebSocketChannel>[];
  when(
    () => service.fetchLobby(_code),
  ).thenAnswer((_) async => lobby ?? _waitingLobby());
  when(
    () => service.activeGameIdAt(_code),
  ).thenAnswer((_) async => runningGameCode == _code ? runningGameId : null);

  final router = GoRouter(
    initialLocation: '/lobby/$_code',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME SCREEN')),
      ),
      GoRoute(
        path: '/lobby/:code',
        builder: (_, state) => LobbyScreen(code: state.pathParameters['code']!),
      ),
      GoRoute(
        path: '/game/:gameId',
        builder: (_, state) => Scaffold(
          body: Text(
            'GAME ${state.pathParameters['gameId']} '
            'AT ${state.uri.queryParameters['lobby']}',
          ),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeThemeProvider.overrideWithValue(const MidnightVillageTheme()),
        authProvider.overrideWithValue(
          AuthState.authenticated(User(id: userId, displayName: 'Me')),
        ),
        authenticatedClientProvider.overrideWithValue(
          _MockAuthenticatedClient(),
        ),
        lobbyServiceProvider.overrideWithValue(service),
        lobbyWebSocketFactoryProvider.overrideWithValue((code) {
          final ws = MockWebSocketChannel();
          sockets.add(ws);
          return ws;
        }),
      ],
      child: MaterialApp.router(
        theme: skinTheme(shadowPaper),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Table(service, sockets, router);
}

void main() {
  group('The lobby between games', () {
    testWidgets('shows the same players, the deck and the host\'s controls', (
      tester,
    ) async {
      await _pumpLobby(tester);

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Carol'), findsOneWidget);
      expect(find.text('Role Configuration'), findsOneWidget);
      expect(find.text('Start Game'), findsOneWidget);
    });

    testWidgets('shows a player who is not the host the deck and a wait line', (
      tester,
    ) async {
      await _pumpLobby(tester, userId: 2);

      expect(find.text('Roles in Game'), findsOneWidget);
      expect(find.text('Waiting for host to start...'), findsOneWidget);
      expect(find.text('Start Game'), findsNothing);
    });

    testWidgets('opens the next game when the table starts it', (tester) async {
      final t = await _pumpLobby(tester, userId: 2);

      t.ws.addServerEvent(GameEvents.gameStarted(gameId: 'game-two'));
      await tester.pumpAndSettle();

      expect(t.location, '/game/game-two?lobby=$_code');
      expect(find.text('GAME game-two AT $_code'), findsOneWidget);
    });

    testWidgets('the host opens the game from the start call, without waiting '
        'for the event', (tester) async {
      final t = await _pumpLobby(tester);
      when(
        () => t.service.startGame(_code),
      ).thenAnswer((_) async => 'game-two');

      await tester.ensureVisible(find.text('Start Game'));
      await tester.pump();
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      expect(t.location, '/game/game-two?lobby=$_code');
    });

    testWidgets('a third game opens too, not the second one again', (
      tester,
    ) async {
      final t = await _pumpLobby(tester, userId: 2);
      t.ws.addServerEvent(GameEvents.gameStarted(gameId: 'game-two'));
      await tester.pumpAndSettle();

      // The second game ends and the table is reopened.
      t.router.go('/lobby/$_code');
      await tester.pumpAndSettle();
      expect(find.text('Waiting for host to start...'), findsOneWidget);

      t.ws.addServerEvent(GameEvents.gameStarted(gameId: 'game-three'));
      await tester.pumpAndSettle();

      expect(t.location, '/game/game-three?lobby=$_code');
    });

    testWidgets('finds a game that already started before the lobby opened', (
      tester,
    ) async {
      final t = await _pumpLobby(
        tester,
        userId: 2,
        lobby: _waitingLobby(status: 'in_game'),
        runningGameId: 'game-two',
      );

      expect(t.location, '/game/game-two?lobby=$_code');
    });

    testWidgets('ignores a running game that belongs to another table', (
      tester,
    ) async {
      final t = await _pumpLobby(
        tester,
        userId: 2,
        lobby: _waitingLobby(status: 'in_game'),
        runningGameId: 'elsewhere',
        runningGameCode: 'OTHER1',
      );

      expect(t.location, '/lobby/$_code');
    });

    test(
      'a failed look-up for the running game leaves the lobby as it is',
      () async {
        final service = _MockLobbyService();
        when(
          () => service.fetchLobby(_code),
        ).thenAnswer((_) async => _waitingLobby(status: 'in_game'));
        when(
          () => service.activeGameIdAt(_code),
        ).thenThrow(Exception('offline'));

        final container = ProviderContainer(
          overrides: [
            lobbyServiceProvider.overrideWithValue(service),
            lobbyWebSocketFactoryProvider.overrideWithValue(
              (code) => MockWebSocketChannel(),
            ),
            authenticatedClientProvider.overrideWithValue(
              _MockAuthenticatedClient(),
            ),
          ],
        );
        addTearDown(container.dispose);
        final sub = container.listen(lobbyProvider(_code), (_, _) {});
        addTearDown(sub.close);

        final lobby = await container.read(lobbyProvider(_code).future);
        await Future<void>.delayed(Duration.zero);

        expect(lobby.status, 'in_game');
        expect(
          container.read(lobbyProvider(_code)).value?.startedGameId,
          isNull,
        );
      },
    );
  });
}
