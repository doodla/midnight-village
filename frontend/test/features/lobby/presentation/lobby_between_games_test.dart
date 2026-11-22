import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/lobby/data/lobby_service.dart';
import 'package:midnight_village/features/game/domain/game_me.dart'
    show GamePhase;
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_notifier.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/game_events.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/mock_websocket.dart';

// A table runs several games one after another. The lobby names the game it
// has started (`startedGameId`); 02 reads `/me/table/` again on a new one and
// the shell opens it (table_screens_test.dart has the screens).

class _MockLobbyService extends Mock implements LobbyService {}

const _code = 'ABC123';

/// The table as the server returns it after "Play again": same players, same
/// deck, waiting.
LobbyState _lobby({String status = 'waiting'}) => FromSample.lobby(
  serverLobby(
    code: _code,
    seats: const [
      (id: 1, name: 'Alice'),
      (id: 2, name: 'Bob'),
      (id: 3, name: 'Carol'),
    ],
    status: status,
    roles: const {'Werewolf': 2, 'Seer': 1, 'Robber': 1, 'Villager': 2},
  ),
);

class _Table {
  _Table(this.container, this.service, this.ws);
  final ProviderContainer container;
  final _MockLobbyService service;
  final MockWebSocketChannel ws;

  LobbyState get lobby => container.read(lobbyProvider(_code)).value!;
  LobbyNotifier get notifier => container.read(lobbyProvider(_code).notifier);
}

Future<_Table> _open({
  LobbyState? lobby,
  String? runningGameId,
  String runningGameCode = _code,
  bool lookUpFails = false,
}) async {
  final service = _MockLobbyService();
  final ws = MockWebSocketChannel();
  when(
    () => service.fetchLobby(_code),
  ).thenAnswer((_) async => lobby ?? _lobby());
  if (lookUpFails) {
    when(() => service.activeGameIdAt(_code)).thenThrow(Exception('offline'));
  } else {
    when(
      () => service.activeGameIdAt(_code),
    ).thenAnswer((_) async => runningGameCode == _code ? runningGameId : null);
  }
  final container = ProviderContainer(
    overrides: [
      lobbyServiceProvider.overrideWithValue(service),
      lobbyWebSocketFactoryProvider.overrideWithValue((code) => ws),
      authenticatedClientProvider.overrideWithValue(
        AuthenticatedClient.forTesting(dio: MockHttpClient().dio),
      ),
    ],
  );
  addTearDown(container.dispose);
  final sub = container.listen(lobbyProvider(_code), (_, _) {});
  addTearDown(sub.close);
  await container.read(lobbyProvider(_code).future);
  // The running game is looked up after the first build.
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return _Table(container, service, ws);
}

void main() {
  group('The lobby between games', () {
    test('keeps the same players and the deck', () async {
      final t = await _open();

      expect(t.lobby.players.map((p) => p.displayName), [
        'Alice',
        'Bob',
        'Carol',
      ]);
      expect(t.lobby.roleConfig, isNotEmpty);
      expect(t.lobby.startedGameId, isNull);
    });

    test('names the next game when the table starts it', () async {
      final t = await _open();

      t.ws.addServerEvent(GameEvents.gameStarted(gameId: 'game-two'));
      await Future<void>.delayed(Duration.zero);

      expect(t.lobby.startedGameId, 'game-two');
      expect(t.lobby.status, 'in_game');
    });

    test('the host has the game from the start call, without waiting for the '
        'event', () async {
      final t = await _open();
      when(
        () => t.service.startGame(_code),
      ).thenAnswer((_) async => (id: 'game-two', phase: GamePhase.night));

      expect(await t.notifier.deal(), 'game-two');
      expect(t.lobby.startedGameId, 'game-two');
    });

    test('a third game is named too, not the second one again', () async {
      final t = await _open();
      t.ws.addServerEvent(GameEvents.gameStarted(gameId: 'game-two'));
      await Future<void>.delayed(Duration.zero);

      t.ws.addServerEvent(GameEvents.gameStarted(gameId: 'game-three'));
      await Future<void>.delayed(Duration.zero);

      expect(t.lobby.startedGameId, 'game-three');
    });

    test('finds a game that already started before the lobby opened', () async {
      final t = await _open(
        lobby: _lobby(status: 'in_game'),
        runningGameId: 'game-two',
      );

      expect(t.lobby.startedGameId, 'game-two');
    });

    test('ignores a running game that belongs to another table', () async {
      final t = await _open(
        lobby: _lobby(status: 'in_game'),
        runningGameId: 'elsewhere',
        runningGameCode: 'OTHER1',
      );

      expect(t.lobby.startedGameId, isNull);
    });

    test(
      'a failed look-up for the running game leaves the lobby as it is',
      () async {
        final t = await _open(
          lobby: _lobby(status: 'in_game'),
          lookUpFails: true,
        );

        expect(t.lobby.startedGameId, isNull);
        expect(t.lobby.status, 'in_game');
      },
    );

    test('a deal that does not reach the server says "Not sent." and Try '
        'again deals', () async {
      final t = await _open();
      var calls = 0;
      when(() => t.service.startGame(_code)).thenAnswer((_) async {
        if (calls++ == 0) throw Exception('offline');
        return (id: 'game-two', phase: GamePhase.night);
      });

      expect(await t.notifier.deal(), isNull);
      expect(t.lobby.notSent, isTrue);

      await t.notifier.retry();
      expect(t.lobby.startedGameId, 'game-two');
      expect(t.lobby.notSent, isFalse);
    });
  });
}
