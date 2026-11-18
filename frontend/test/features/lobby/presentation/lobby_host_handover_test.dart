import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_exception.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/host/host_change.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import 'package:midnight_village/design_system/tokens/midnight_village_theme.dart';
import 'package:midnight_village/design_system/tokens/theme_bridge.dart';
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
const _names = ['Ana', 'Ben', 'Cleo'];

LobbyState _lobby({int hostId = 1, int? originalHostId, bool acting = false}) =>
    LobbyState(
      code: _code,
      hostId: hostId,
      hostName: _names[hostId - 1],
      originalHostId: originalHostId ?? (acting ? 1 : null),
      isActingHost: acting,
      players: [
        for (final (i, n) in _names.indexed)
          LobbyPlayer(
            id: i + 1,
            displayName: n,
            isReady: true,
            joinedAt: DateTime.utc(2026, 3, 31, 0, i),
          ),
      ],
      status: 'waiting',
      maxPlayers: 10,
      roleConfig: const {'Werewolf': 2, 'Seer': 1, 'Robber': 1, 'Villager': 2},
    );

String _handover() =>
    GameEvents.hostChanged(hostId: 2, hostName: 'Ben', originalHostId: 1);

String _returned() => GameEvents.hostChanged(
  hostId: 1,
  hostName: 'Ana',
  originalHostId: 1,
  reason: 'returned',
);

class _Table {
  _Table(this.service, this.ws, this.server);
  final _MockLobbyService service;
  final MockWebSocketChannel ws;

  /// What the mock server answers to the next lobby fetch.
  LobbyState server;
}

Future<_Table> _pump(
  WidgetTester tester, {
  required int userId,
  LobbyState? lobby,
}) async {
  final service = _MockLobbyService();
  final ws = MockWebSocketChannel();
  final table = _Table(service, ws, lobby ?? _lobby());
  when(() => service.fetchLobby(_code)).thenAnswer((_) async => table.server);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeThemeProvider.overrideWithValue(const MidnightVillageTheme()),
        authProvider.overrideWithValue(
          AuthState.authenticated(
            User(id: userId, displayName: _names[userId - 1]),
          ),
        ),
        authenticatedClientProvider.overrideWithValue(
          _MockAuthenticatedClient(),
        ),
        lobbyServiceProvider.overrideWithValue(service),
        lobbyWebSocketFactoryProvider.overrideWithValue((code) => ws),
      ],
      child: MaterialApp(
        theme: generateThemeData(const MidnightVillageTheme()),
        home: const LobbyScreen(code: _code),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return table;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('Lobby detail', () {
    test('reads the effective host, original_host_id and is_acting_host', () {
      final lobby = LobbyState.fromJson({
        'code': _code,
        'host': {'id': 2, 'display_name': 'Ben'},
        'original_host_id': 1,
        'is_acting_host': true,
        'players': <dynamic>[],
        'status': 'waiting',
        'max_players': 10,
        'settings': {'roles': <String, dynamic>{}},
      });

      expect(lobby.hostId, 2);
      expect(lobby.hostName, 'Ben');
      expect(lobby.originalHostId, 1);
      expect(lobby.isActingHost, isTrue);
    });

    test('treats both new fields as optional', () {
      final lobby = LobbyState.fromJson({
        'code': _code,
        'host': {'id': 1, 'display_name': 'Ana'},
        'players': <dynamic>[],
        'status': 'waiting',
        'max_players': 10,
      });

      expect(lobby.originalHostId, isNull);
      expect(lobby.isActingHost, isFalse);
    });
  });

  group('Host controls follow host_changed', () {
    testWidgets('the old host loses Start Game and the deck on a handover', (
      tester,
    ) async {
      final t = await _pump(tester, userId: 1);
      expect(find.text('Start Game'), findsOneWidget);
      expect(find.text('Role Configuration'), findsOneWidget);

      t.ws.addServerEvent(_handover());
      await _settle(tester);

      expect(find.text('Start Game'), findsNothing);
      expect(find.text('Role Configuration'), findsNothing);
      expect(find.text('Waiting for host to start...'), findsOneWidget);
      expect(find.text('Ben is hosting while you are away'), findsOneWidget);
    });

    testWidgets('the new host gets them, and "You are hosting while Ana is '
        'away"', (tester) async {
      final t = await _pump(tester, userId: 2);
      expect(find.text('Start Game'), findsNothing);

      t.ws.addServerEvent(_handover());
      await _settle(tester);

      expect(find.text('Start Game'), findsOneWidget);
      expect(find.text('Role Configuration'), findsOneWidget);
      expect(find.text('You are hosting while Ana is away'), findsOneWidget);
    });

    testWidgets('a bystander reads "Ben is hosting while Ana is away"', (
      tester,
    ) async {
      final t = await _pump(tester, userId: 3);

      t.ws.addServerEvent(_handover());
      await _settle(tester);

      expect(find.text('Ben is hosting while Ana is away'), findsOneWidget);
      expect(find.text('Start Game'), findsNothing);
    });

    testWidgets('the handover line stays while the role is acting', (
      tester,
    ) async {
      final t = await _pump(tester, userId: 3);
      t.ws.addServerEvent(_handover());
      await _settle(tester);

      await tester.pump(const Duration(minutes: 5));

      expect(find.text('Ben is hosting while Ana is away'), findsOneWidget);
    });

    testWidgets(
      'a lobby opened while someone is acting shows the line from the '
      'lobby detail',
      (tester) async {
        await _pump(tester, userId: 3, lobby: _lobby(hostId: 2, acting: true));

        expect(find.text('Ben is hosting while Ana is away'), findsOneWidget);
      },
    );

    testWidgets('on the return the controls go back to the original host', (
      tester,
    ) async {
      final t = await _pump(tester, userId: 1);
      t.ws.addServerEvent(_handover());
      await _settle(tester);
      expect(find.text('Start Game'), findsNothing);

      t.ws.addServerEvent(_returned());
      await _settle(tester);

      expect(find.text('Start Game'), findsOneWidget);
      expect(find.text('You are hosting again'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('the acting host loses the controls on the return', (
      tester,
    ) async {
      final t = await _pump(
        tester,
        userId: 2,
        lobby: _lobby(hostId: 2, acting: true),
      );
      expect(find.text('Start Game'), findsOneWidget);

      t.ws.addServerEvent(_returned());
      await _settle(tester);

      expect(find.text('Start Game'), findsNothing);
      expect(find.text('Ana is hosting again'), findsOneWidget);
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('"Ana is hosting again" goes after a few seconds', (
      tester,
    ) async {
      final t = await _pump(
        tester,
        userId: 3,
        lobby: _lobby(hostId: 2, acting: true),
      );

      t.ws.addServerEvent(_returned());
      await _settle(tester);
      expect(find.text('Ana is hosting again'), findsOneWidget);
      expect(find.text('Ben is hosting while Ana is away'), findsNothing);

      await tester.pump(const Duration(seconds: 7));
      expect(find.textContaining('hosting'), findsNothing);
    });
  });

  group('Refreshing the lobby', () {
    testWidgets('picks up the effective host from the server, healing a missed '
        'event', (tester) async {
      final t = await _pump(tester, userId: 1);
      expect(find.text('Start Game'), findsOneWidget);

      t.server = _lobby(hostId: 2, acting: true);
      await tester.runAsync(
        () => ProviderScope.containerOf(
          tester.element(find.byType(LobbyScreen)),
        ).read(lobbyProvider(_code).notifier).refreshLobby(),
      );
      await _settle(tester);

      expect(find.text('Start Game'), findsNothing);
      expect(find.text('Ben is hosting while you are away'), findsOneWidget);
    });

    testWidgets('a player_joined refetch also takes the host from the server', (
      tester,
    ) async {
      final t = await _pump(tester, userId: 2);
      t.server = _lobby(hostId: 2, acting: true);

      t.ws.addServerEvent(
        GameEvents.playerJoined(playerId: 3, displayName: 'Cleo'),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await _settle(tester);

      expect(find.text('Start Game'), findsOneWidget);
    });
  });

  group('A host action refused because the role moved (403)', () {
    testWidgets(
      'says "You are no longer the host." and takes the controls away',
      (tester) async {
        final t = await _pump(tester, userId: 1);
        when(
          () => t.service.startGame(_code),
        ).thenThrow(const ForbiddenException());
        t.server = _lobby(hostId: 2, acting: true);

        await tester.ensureVisible(find.text('Start Game'));
        await tester.pump();
        await tester.tap(find.text('Start Game'));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await _settle(tester);
        await _settle(tester);

        expect(find.text(kNoLongerHostMessage), findsOneWidget);
        expect(find.text('Start Game'), findsNothing);
        await tester.pump(const Duration(seconds: 7));
        expect(find.text(kNoLongerHostMessage), findsNothing);
      },
    );
  });
}
