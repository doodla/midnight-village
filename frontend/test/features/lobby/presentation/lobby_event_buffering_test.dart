import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_exception.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/lobby/data/lobby_service.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_notifier.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/mock_http_client.dart';
import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/game_events.dart';
import '../../../helpers/mock_websocket.dart';

class _MockLobbyService extends Mock implements LobbyService {}

const _code = 'ABC123';
const _names = ['Ana', 'Ben', 'Cleo'];

LobbyState _lobby({int hostId = 1}) => FromSample.lobby(
  serverLobby(
    code: _code,
    seats: [for (final (i, n) in _names.indexed) (id: i + 1, name: n)],
    hostId: hostId,
    notReady: {for (var i = 1; i <= _names.length; i++) i},
    roles: const {'Werewolf': 2},
  ),
);

Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late _MockLobbyService service;
  late MockWebSocketChannel ws;
  late ProviderContainer container;

  setUp(() {
    service = _MockLobbyService();
    ws = MockWebSocketChannel();
    container = ProviderContainer(
      overrides: [
        lobbyServiceProvider.overrideWithValue(service),
        lobbyWebSocketFactoryProvider.overrideWithValue((code) => ws),
        authenticatedClientProvider.overrideWithValue(
          AuthenticatedClient.forTesting(dio: MockHttpClient().dio),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  LobbyState current() => container.read(lobbyProvider(_code)).value!;

  group('Events that arrive while the first load is in flight', () {
    test('host_changed is applied on top of the older lobby', () async {
      final fetch = Completer<LobbyState>();
      when(() => service.fetchLobby(_code)).thenAnswer((_) => fetch.future);
      final sub = container.listen(lobbyProvider(_code), (_, _) {});
      addTearDown(sub.close);

      await _tick();
      ws.addServerEvent(
        GameEvents.hostChanged(hostId: 2, hostName: 'Ben', originalHostId: 1),
      );
      fetch.complete(_lobby());
      await container.read(lobbyProvider(_code).future);

      expect(current().hostId, 2);
      expect(current().isActingHost, isTrue);
    });

    test('game_started is not lost and opens the game', () async {
      final fetch = Completer<LobbyState>();
      when(() => service.fetchLobby(_code)).thenAnswer((_) => fetch.future);
      final sub = container.listen(lobbyProvider(_code), (_, _) {});
      addTearDown(sub.close);

      await _tick();
      ws.addServerEvent(GameEvents.gameStarted(gameId: 'game-two'));
      fetch.complete(_lobby());
      await container.read(lobbyProvider(_code).future);

      expect(current().startedGameId, 'game-two');
      expect(current().status, 'in_game');
    });

    test('player_ready and lobby_update are applied in order', () async {
      final fetch = Completer<LobbyState>();
      when(() => service.fetchLobby(_code)).thenAnswer((_) => fetch.future);
      final sub = container.listen(lobbyProvider(_code), (_, _) {});
      addTearDown(sub.close);

      await _tick();
      // lobby_update is the whole lobby (everyone ready in it); the flags
      // after it are applied on top, in order.
      ws
        ..addServerEvent(GameEvents.lobbyUpdate(roleConfig: {'Seer': 1}))
        ..addServerEvent(GameEvents.playerReady(playerId: 2, isReady: true))
        ..addServerEvent(GameEvents.playerReady(playerId: 2, isReady: false));
      fetch.complete(_lobby());
      await container.read(lobbyProvider(_code).future);

      expect(current().players[1].isReady, isFalse);
      expect(current().roleConfig, {'Seer': 1});
    });

    test(
      'a host handover then a return leaves the original host in charge',
      () async {
        final fetch = Completer<LobbyState>();
        when(() => service.fetchLobby(_code)).thenAnswer((_) => fetch.future);
        final sub = container.listen(lobbyProvider(_code), (_, _) {});
        addTearDown(sub.close);

        await _tick();
        ws
          ..addServerEvent(
            GameEvents.hostChanged(
              hostId: 2,
              hostName: 'Ben',
              originalHostId: 1,
            ),
          )
          ..addServerEvent(
            GameEvents.hostChanged(
              hostId: 1,
              hostName: 'Ana',
              originalHostId: 1,
              reason: 'returned',
            ),
          );
        fetch.complete(_lobby());
        await container.read(lobbyProvider(_code).future);

        expect(current().hostId, 1);
        expect(current().isActingHost, isFalse);
      },
    );
  });

  group('Events that arrive while a refetch is in flight', () {
    test('host_changed is not overwritten by the older snapshot', () async {
      when(() => service.fetchLobby(_code)).thenAnswer((_) async => _lobby());
      final sub = container.listen(lobbyProvider(_code), (_, _) {});
      addTearDown(sub.close);
      await container.read(lobbyProvider(_code).future);
      final notifier = container.read(lobbyProvider(_code).notifier);

      final fetch = Completer<LobbyState>();
      when(() => service.fetchLobby(_code)).thenAnswer((_) => fetch.future);
      final refreshing = notifier.refreshLobby();
      await _tick();
      ws.addServerEvent(
        GameEvents.hostChanged(hostId: 2, hostName: 'Ben', originalHostId: 1),
      );
      fetch.complete(_lobby()); // the older snapshot: Ana still hosts
      await refreshing;

      expect(current().hostId, 2);
    });

    test('a player_ready during a player_joined refetch survives it', () async {
      when(() => service.fetchLobby(_code)).thenAnswer((_) async => _lobby());
      final sub = container.listen(lobbyProvider(_code), (_, _) {});
      addTearDown(sub.close);
      await container.read(lobbyProvider(_code).future);

      final fetch = Completer<LobbyState>();
      when(() => service.fetchLobby(_code)).thenAnswer((_) => fetch.future);
      ws.addServerEvent(GameEvents.playerJoined());
      await _tick();
      ws.addServerEvent(GameEvents.playerReady(playerId: 3, isReady: true));
      fetch.complete(_lobby());
      await _tick();
      await _tick();

      expect(current().players[2].isReady, isTrue);
    });

    test('a game_started during a refetch is not lost', () async {
      when(() => service.fetchLobby(_code)).thenAnswer((_) async => _lobby());
      final sub = container.listen(lobbyProvider(_code), (_, _) {});
      addTearDown(sub.close);
      await container.read(lobbyProvider(_code).future);
      final notifier = container.read(lobbyProvider(_code).notifier);

      final fetch = Completer<LobbyState>();
      when(() => service.fetchLobby(_code)).thenAnswer((_) => fetch.future);
      final refreshing = notifier.refreshLobby();
      await _tick();
      ws.addServerEvent(GameEvents.gameStarted(gameId: 'game-two'));
      fetch.complete(_lobby());
      await refreshing;

      expect(current().startedGameId, 'game-two');
    });

    test('a failed refetch still applies the events held meanwhile', () async {
      when(() => service.fetchLobby(_code)).thenAnswer((_) async => _lobby());
      final sub = container.listen(lobbyProvider(_code), (_, _) {});
      addTearDown(sub.close);
      await container.read(lobbyProvider(_code).future);
      final notifier = container.read(lobbyProvider(_code).notifier);

      final fetch = Completer<LobbyState>();
      when(() => service.fetchLobby(_code)).thenAnswer((_) => fetch.future);
      final refreshing = notifier.refreshLobby();
      await _tick();
      ws.addServerEvent(
        GameEvents.hostChanged(hostId: 2, hostName: 'Ben', originalHostId: 1),
      );
      fetch.completeError(Exception('offline'));
      await refreshing;

      expect(current().hostId, 2);
    });

    test('a refetch that gets 404 marks the table closed', () async {
      when(() => service.fetchLobby(_code)).thenAnswer((_) async => _lobby());
      final sub = container.listen(lobbyProvider(_code), (_, _) {});
      addTearDown(sub.close);
      await container.read(lobbyProvider(_code).future);
      when(() => service.fetchLobby(_code)).thenThrow(NotFoundException('x'));

      await container.read(lobbyProvider(_code).notifier).refreshLobby();

      expect(current().tableClosed, isTrue);
    });
  });
}
