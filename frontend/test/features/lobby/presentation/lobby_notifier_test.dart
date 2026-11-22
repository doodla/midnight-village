import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/lobby/data/lobby_service.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_notifier.dart';
import 'package:mocktail/mocktail.dart';

import 'package:midnight_village/core/api/api_exception.dart';
import 'package:midnight_village/design_system/copy/copy.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/game_events.dart';
import '../../../helpers/mock_websocket.dart';

class MockLobbyService extends Mock implements LobbyService {}

/// The server's lobby body: Alice (1) and Bob (2) unless [seats] are given,
/// parsed as the app parses it.
LobbyState _testLobbyState({
  String code = 'ABC123',
  int hostId = 1,
  List<Seat> seats = const [(id: 1, name: 'Alice'), (id: 2, name: 'Bob')],
  String status = 'waiting',
  Map<String, int>? roleConfig,
}) => FromSample.lobby(
  serverLobby(
    code: code,
    seats: seats,
    hostId: hostId,
    status: status,
    roles: roleConfig ?? {'Werewolf': 2, 'Seer': 1},
  ),
);

void main() {
  late MockLobbyService mockService;
  late MockWebSocketChannel mockWebSocket;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(<String, Object>{}));

  setUp(() {
    mockService = MockLobbyService();
    mockWebSocket = MockWebSocketChannel();

    // Default: fetchLobby returns test lobby state
    when(
      () => mockService.fetchLobby('ABC123'),
    ).thenAnswer((_) async => _testLobbyState());
  });

  ProviderContainer createContainer() {
    final c = ProviderContainer(
      overrides: [
        lobbyServiceProvider.overrideWithValue(mockService),
        lobbyWebSocketFactoryProvider.overrideWithValue(
          (code) => mockWebSocket,
        ),
        // Override authenticatedClientProvider since lobbyServiceProvider
        // is already overridden and won't use it.
        authenticatedClientProvider.overrideWithValue(
          AuthenticatedClient.forTesting(dio: MockHttpClient().dio),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('LobbyNotifier', () {
    group('build', () {
      test('fetches initial lobby state and connects WebSocket', () async {
        container = createContainer();

        // Read the provider to trigger build
        final future = container.read(lobbyProvider('ABC123').future);
        final lobby = await future;

        expect(lobby.code, 'ABC123');
        expect(lobby.players, hasLength(2));
        verify(() => mockService.fetchLobby('ABC123')).called(1);
      });

      test('sets error state when fetchLobby fails', () async {
        when(
          () => mockService.fetchLobby('ABC123'),
        ).thenThrow(Exception('Network error'));

        container = createContainer();

        // The provider should be in an error state
        await expectLater(
          container.read(lobbyProvider('ABC123').future),
          throwsA(anything),
        );
      });
    });

    group('WebSocket events', () {
      test('player_joined triggers re-fetch of lobby state', () async {
        container = createContainer();

        // Keep a listener alive so the auto-dispose provider stays active
        final sub = container.listen(lobbyProvider('ABC123'), (_, _) {});
        addTearDown(sub.close);

        // Wait for initial build
        await container.read(lobbyProvider('ABC123').future);

        // Set up re-fetch with updated players
        final refetchCompleter = Completer<LobbyState>();
        final updatedState = _testLobbyState(
          seats: [
            (id: 1, name: 'Alice'),
            (id: 2, name: 'Bob'),
            (id: 3, name: 'Charlie'),
          ],
        );
        when(() => mockService.fetchLobby('ABC123')).thenAnswer((_) async {
          final result = updatedState;
          if (!refetchCompleter.isCompleted) {
            refetchCompleter.complete(result);
          }
          return result;
        });

        // Simulate player_joined event
        mockWebSocket.addServerEvent(GameEvents.playerJoined());

        // Wait for the re-fetch to complete
        await refetchCompleter.future;
        await Future<void>.delayed(Duration.zero);

        final state = container.read(lobbyProvider('ABC123'));
        expect(state.value?.players, hasLength(3));
      });

      test('player_left triggers re-fetch of lobby state', () async {
        container = createContainer();

        final sub = container.listen(lobbyProvider('ABC123'), (_, _) {});
        addTearDown(sub.close);

        await container.read(lobbyProvider('ABC123').future);

        final refetchCompleter = Completer<LobbyState>();
        final updatedState = _testLobbyState(seats: [(id: 1, name: 'Alice')]);
        when(() => mockService.fetchLobby('ABC123')).thenAnswer((_) async {
          final result = updatedState;
          if (!refetchCompleter.isCompleted) {
            refetchCompleter.complete(result);
          }
          return result;
        });

        mockWebSocket.addServerEvent(GameEvents.playerLeft());

        await refetchCompleter.future;
        await Future<void>.delayed(Duration.zero);

        final state = container.read(lobbyProvider('ABC123'));
        expect(state.value?.players, hasLength(1));
      });

      test('lobby_update updates role configuration', () async {
        container = createContainer();
        await container.read(lobbyProvider('ABC123').future);

        mockWebSocket.addServerEvent(
          GameEvents.lobbyUpdate(
            roleConfig: {
              'Werewolf': 2,
              'Seer': 1,
              'Robber': 1,
              'Troublemaker': 1,
              'Villager': 3,
            },
          ),
        );

        final state = container.read(lobbyProvider('ABC123'));
        expect(state.value?.roleConfig, {
          'Werewolf': 2,
          'Seer': 1,
          'Robber': 1,
          'Troublemaker': 1,
          'Villager': 3,
        });
      });

      test('game_started extracts game_id and updates status', () async {
        container = createContainer();
        await container.read(lobbyProvider('ABC123').future);

        mockWebSocket.addServerEvent(
          GameEvents.gameStarted(
            gameId: '550e8400-e29b-41d4-a716-446655440000',
          ),
        );

        final notifier = container.read(lobbyProvider('ABC123').notifier);
        expect(notifier.gameId, '550e8400-e29b-41d4-a716-446655440000');

        final state = container.read(lobbyProvider('ABC123'));
        expect(state.value?.status, 'in_game');
      });

      test('handles Map messages (not just JSON strings)', () async {
        container = createContainer();
        await container.read(lobbyProvider('ABC123').future);
        clearInteractions(mockService);

        // Send as Map directly (some WS implementations do this)
        mockWebSocket.addServerEvent(
          jsonDecode(GameEvents.lobbyUpdate(roleConfig: {'Seer': 1})),
        );

        final state = container.read(lobbyProvider('ABC123'));
        expect(state.value?.roleConfig, {'Seer': 1});
      });

      test('ignores unknown event types without error', () async {
        container = createContainer();
        await container.read(lobbyProvider('ABC123').future);

        // Should not throw
        mockWebSocket.addOffContractEvent(
          json.encode({'type': 'unknown_event', 'data': 'something'}),
        );

        final state = container.read(lobbyProvider('ABC123'));
        expect(state.value, isNotNull);
      });
    });

    group('public methods', () {
      test('startGame calls service.startGame and returns game ID', () async {
        container = createContainer();
        await container.read(lobbyProvider('ABC123').future);

        when(
          () => mockService.startGame('ABC123'),
        ).thenAnswer((_) async => '550e8400-e29b-41d4-a716-446655440000');

        final notifier = container.read(lobbyProvider('ABC123').notifier);
        final gameId = await notifier.startGame();

        expect(gameId, '550e8400-e29b-41d4-a716-446655440000');
      });

      test('leave calls service.leaveLobby', () async {
        container = createContainer();
        await container.read(lobbyProvider('ABC123').future);

        when(() => mockService.leaveLobby('ABC123')).thenAnswer((_) async {});

        final notifier = container.read(lobbyProvider('ABC123').notifier);
        await notifier.leave();

        verify(() => mockService.leaveLobby('ABC123')).called(1);
      });

      test('a deck chip shows at once, before the answer, and the answer is '
          'the server\'s lobby', () async {
        container = createContainer();
        container.listen(lobbyProvider('ABC123'), (_, _) {});
        await container.read(lobbyProvider('ABC123').future);
        final answer = Completer<LobbyState>();
        when(
          () => mockService.patchSettings('ABC123', {
            'deck': 'auto',
            'deck_chip': 'chaos',
          }),
        ).thenAnswer((_) => answer.future);

        final notifier = container.read(lobbyProvider('ABC123').notifier);
        final sent = notifier.chooseChip(DeckChip.chaos);
        await Future<void>.delayed(Duration.zero);

        final shown = container.read(lobbyProvider('ABC123')).value!.table;
        expect(shown.autoDeck, isTrue);
        expect(shown.deckChip, DeckChip.chaos);

        answer.complete(
          FromSample.lobby(
            ContractSamples.map('http/lobby/settings_deck_chip'),
          ),
        );
        await sent;
        final after = container.read(lobbyProvider('ABC123')).value!;
        expect(after.table.deckChip, DeckChip.simple);
        expect(after.notSent, isFalse);
      });

      test('a refused change is taken back and says "Not sent."; Try again '
          'sends it again', () async {
        container = createContainer();
        container.listen(lobbyProvider('ABC123'), (_, _) {});
        await container.read(lobbyProvider('ABC123').future);
        when(
          () => mockService.patchSettings('ABC123', any()),
        ).thenThrow(const NetworkException('offline'));

        final notifier = container.read(lobbyProvider('ABC123').notifier);
        await notifier.setLength('discussion_seconds', 180);

        final lobby = container.read(lobbyProvider('ABC123')).value!;
        expect(lobby.notSent, isTrue);
        expect(lobby.table.raw.containsKey('discussion_seconds'), isFalse);

        await notifier.retry();
        verify(
          () =>
              mockService.patchSettings('ABC123', {'discussion_seconds': 180}),
        ).called(2);
      });

      test(
        'lobby_update is the whole lobby: settings, players and host',
        () async {
          container = createContainer();
          container.listen(lobbyProvider('ABC123'), (_, _) {});
          await container.read(lobbyProvider('ABC123').future);

          final update = ContractSamples.map(
            'ws/lobby/lobby_update_auto_deck_9',
          );
          mockWebSocket.addServerEvent(update);
          await Future<void>.delayed(Duration.zero);

          final lobby = container.read(lobbyProvider('ABC123')).value!;
          expect(lobby.table.deckChip, DeckChip.chaos);
          expect(lobby.players, hasLength(9));
        },
      );
    });

    group('dispose', () {
      test('closes WebSocket on provider disposal', () async {
        container = createContainer();
        await container.read(lobbyProvider('ABC123').future);

        expect(mockWebSocket.isClosed, isFalse);

        // Invalidate the provider to trigger dispose
        container.invalidate(lobbyProvider('ABC123'));

        // Allow microtasks to complete
        await Future<void>.delayed(Duration.zero);

        expect(mockWebSocket.isClosed, isTrue);
      });
    });
  });

  group('a refused deal, in the player\'s words', () {
    // The server's refusal words (apps/onuw/deal.py, validate_onuw_settings).
    ({bool answered, String? why}) refused(String detail) =>
        LobbyNotifier.dealRefusal(
          ValidationException({
            'detail': [detail],
          }),
        );

    test('a table no longer waiting', () {
      expect(refused('Lobby is not in waiting state.'), (
        answered: true,
        why: BannerCopy.lobbyClosed,
      ));
    });

    test('too few at the table', () {
      expect(refused('At least 3 players required, got 2.'), (
        answered: true,
        why: TableCopy.needPlayers,
      ));
    });

    test('a deck that does not fit', () {
      expect(
        refused(
          'Total role count must be 10 (players + 3 center cards), got 9.',
        ),
        (answered: true, why: BannerCopy.deckDoesNotFit),
      );
      expect(
        refused(
          'Masons must be used in pairs \u2014 include 0 or 2 Mason cards, '
          'not 1.',
        ),
        (answered: true, why: BannerCopy.deckDoesNotFit),
      );
    });

    test('no reason worth saying: nothing is said', () {
      final body = ContractSamples.map('http/game/start_bad_seed');
      expect(
        LobbyNotifier.dealRefusal(ValidationException(parseServerErrors(body))),
        (answered: true, why: null),
      );
    });

    test('no answer: "Not sent."', () {
      expect(LobbyNotifier.dealRefusal(Exception('offline')), (
        answered: false,
        why: null,
      ));
    });
  });
}
