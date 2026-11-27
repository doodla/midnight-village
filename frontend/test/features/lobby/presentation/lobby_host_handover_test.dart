import 'package:midnight_village/core/requests/player_request.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_exception.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/host/host_change.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/lobby/data/lobby_service.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_notifier.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/game_events.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/mock_websocket.dart';

// The host role in the lobby: who the server says hosts is who hosts, from
// the body, `host_changed` and every refetch. 02 shows the host's layout to
// whoever that is, with no words (table_screens_test.dart).

class _MockLobbyService extends Mock implements LobbyService {}

const _code = 'ABC123';
const _names = ['Ana', 'Ben', 'Cleo'];

/// The server's lobby body: Ana (1), Ben (2) and Cleo (3), all ready, with
/// [hostId] hosting (standing in for Ana when [acting]).
LobbyState _lobby({int hostId = 1, bool acting = false}) => FromSample.lobby(
  serverLobby(
    code: _code,
    seats: [for (final (i, n) in _names.indexed) (id: i + 1, name: n)],
    hostId: hostId,
    originalHostId: acting ? 1 : hostId,
    roles: const {'Werewolf': 2, 'Seer': 1, 'Robber': 1, 'Villager': 2},
  ),
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
  _Table(this.container, this.service, this.ws);
  final ProviderContainer container;
  final _MockLobbyService service;
  final MockWebSocketChannel ws;

  /// What the mock server answers to the next lobby fetch.
  late LobbyState server;

  LobbyState get lobby => container.read(lobbyProvider(_code)).value!;
  LobbyNotifier get notifier => container.read(lobbyProvider(_code).notifier);
}

Future<_Table> _open({LobbyState? lobby}) async {
  final service = _MockLobbyService();
  final ws = MockWebSocketChannel();
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
  final table = _Table(container, service, ws)..server = lobby ?? _lobby();
  when(() => service.fetchLobby(_code)).thenAnswer((_) async => table.server);
  final sub = container.listen(lobbyProvider(_code), (_, _) {});
  addTearDown(sub.close);
  await container.read(lobbyProvider(_code).future);
  return table;
}

Future<void> _settle() async {
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUpAll(() => registerFallbackValue(Door.forTest()));
  group('Lobby detail', () {
    test('reads the effective host, original_host_id and is_acting_host', () {
      final body = ContractSamples.map('http/lobby/detail_acting_host');
      final lobby = LobbyState.fromJson(body);

      expect(lobby.hostId, body['host']['id']);
      expect(lobby.hostName, body['host']['display_name']);
      expect(lobby.originalHostId, body['original_host_id']);
      expect(lobby.hostId, isNot(lobby.originalHostId));
      expect(lobby.isActingHost, isTrue);
    });

    test('a table hosted by its owner names the owner twice', () {
      final body = ContractSamples.map('http/lobby/detail_waiting');
      final lobby = LobbyState.fromJson(body);

      expect(lobby.originalHostId, lobby.hostId);
      expect(lobby.isActingHost, isFalse);
    });
  });

  group('The host follows host_changed', () {
    test('a handover makes the stand-in the host', () async {
      final t = await _open();

      t.ws.addServerEvent(_handover());
      await _settle();

      expect(t.lobby.hostId, 2);
      expect(t.lobby.hostName, 'Ben');
      expect(t.lobby.isActingHost, isTrue);
    });

    test('on the return the role goes back to the owner', () async {
      final t = await _open(lobby: _lobby(hostId: 2, acting: true));

      t.ws.addServerEvent(_returned());
      await _settle();

      expect(t.lobby.hostId, 1);
      expect(t.lobby.isActingHost, isFalse);
    });

    test('a transfer makes the next member the owner for good', () async {
      final t = await _open();

      t.ws.addServerEvent(
        GameEvents.hostChanged(
          hostId: 2,
          hostName: 'Ben',
          originalHostId: 2,
          reason: 'transferred',
        ),
      );
      await _settle();

      expect(t.lobby.hostId, 2);
      expect(t.lobby.originalHostId, 2);
      expect(t.lobby.isActingHost, isFalse);
    });
  });

  group('Refreshing the lobby', () {
    test('picks up the effective host from the server, healing a missed '
        'event', () async {
      final t = await _open();

      t.server = _lobby(hostId: 2, acting: true);
      await t.notifier.refreshLobby();

      expect(t.lobby.hostId, 2);
    });

    test(
      'a player_joined reads nothing: the lobby_update sent with it is the table',
      () async {
        final t = await _open();
        clearInteractions(t.service);

        // The server agrees with the phone: the host has not moved.
        t.ws.addServerEvent(GameEvents.playerJoined());
        await _settle();

        verifyNever(() => t.service.fetchLobby(any()));
        expect(t.lobby.hostId, t.server.hostId);
      },
    );
  });

  group('A host action refused because the role moved (403)', () {
    test('the deal reads the lobby again and says nothing: the phone is a '
        'guest now', () async {
      final t = await _open();
      when(
        () => t.service.startGame(any(), _code),
      ).thenThrow(const ForbiddenException());
      t.server = _lobby(hostId: 2, acting: true);

      expect(await t.notifier.deal(), isNull);

      expect(t.lobby.hostId, 2);
      expect(t.lobby.notSent, isFalse);
      expect(t.lobby.hostActionNotice, kNoLongerHostMessage);
    });

    test('a deck change is taken back, with no "Not sent."', () async {
      final t = await _open();
      when(
        () => t.service.patchSettings(any(), _code, any()),
      ).thenThrow(const ForbiddenException());
      t.server = _lobby(hostId: 2, acting: true);

      await t.notifier.chooseChip(DeckChip.chaos);

      expect(t.lobby.hostId, 2);
      expect(t.lobby.table.deckChip, isNull);
      expect(t.lobby.notSent, isFalse);
    });
  });

  group('When the table is gone (404)', () {
    test('the lobby says it has closed', () async {
      final t = await _open();
      when(() => t.service.fetchLobby(_code)).thenThrow(NotFoundException('x'));

      await t.notifier.refreshLobby();

      expect(t.lobby.tableClosed, isTrue);
    });
  });

  setUpAll(() => registerFallbackValue(<String, Object>{}));
}
