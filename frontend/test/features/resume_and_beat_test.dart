import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/healing/healing.dart';
import 'package:midnight_village/core/requests/player_request.dart';
import 'package:midnight_village/core/storage/token_storage.dart';
import 'package:midnight_village/core/websocket/reconnecting_websocket.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/lobby/data/lobby_service.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_notifier.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/contract/from_sample.dart';
import '../helpers/contract/server_json.dart';
import '../helpers/game_events.dart';
import '../helpers/live_game_setup.dart';
import '../helpers/mock_http_client.dart';
import '../helpers/mock_websocket.dart';

// The app coming back, with the real socket: a socket that missed its beat
// while the phone was away is reopened at once, and the screen is read once
// (by the new connection's "connected"); one hearing its beats is left alone
// and the screen is read once. Each would fail if the resume no longer asked
// the socket ([ReconnectingWebSocket.verify]): live_game.dart, lobby_seat.dart.

class _Tokens extends Mock implements TokenStorage {}

class _MockLobbyService extends Mock implements LobbyService {}

void main() {
  late DateTime wall;
  late List<MockWebSocketChannel> channels;
  late _Tokens tokens;

  setUpAll(() => registerFallbackValue(Door.forTest()));
  setUp(() {
    ReconnectingWebSocket.forgetTheBeat();
    wall = DateTime.utc(2026, 11, 28, 20);
    channels = [];
    tokens = _Tokens();
    when(() => tokens.accessToken).thenAnswer((_) async => 'jwt');
  });

  ReconnectingWebSocket realSocket(String path) {
    final ws = ReconnectingWebSocket(
      url: 'ws://localhost:8000$path',
      tokenStorage: tokens,
      now: () => wall,
      channelFactory: (_) => (channels..add(MockWebSocketChannel())).last,
    );
    addTearDown(ws.dispose);
    unawaited(ws.connect());
    return ws;
  }

  group('a game, back from the background', () {
    Future<LiveGameSetup> seated() async {
      final me = recordedMe('me_talk_ready');
      final socket = realSocket('/ws/game/${me['game_id']}/');
      final setup = LiveGameSetup.create(me, socket: socket);
      addTearDown(setup.dispose);
      await setup.load();
      await setup.settle();
      channels.single.addServerEvent(GameEvents.beat(phase: 'discussion'));
      await setup.settle();
      return setup;
    }

    test('its socket missed a beat: reopened at once, one read of each '
        'kind', () async {
      final setup = await seated();
      final me = setup.meFetches;
      final tables = setup.tableFetches;
      wall = wall.add(const Duration(minutes: 5)); // asleep: no timer ran
      setup.resume();
      await setup.settle();
      expect(channels, hasLength(2));
      expect(setup.meFetches, me + 1);
      expect(setup.tableFetches, tables + 1);
    });

    test('its socket is hearing its beats: left as it is, one read of each '
        'kind', () async {
      final setup = await seated();
      final me = setup.meFetches;
      final tables = setup.tableFetches;
      wall = wall.add(const Duration(seconds: 5));
      setup.resume();
      await setup.settle();
      expect(channels, hasLength(1));
      expect(setup.meFetches, me + 1);
      expect(setup.tableFetches, tables + 1);
    });
  });

  group('a lobby, back from the background', () {
    late _MockLobbyService service;
    late StreamController<int> resumes;
    const code = 'ABC123';
    final lobby = FromSample.lobby(serverLobby(code: code));

    Future<ProviderContainer> seated() async {
      service = _MockLobbyService();
      resumes = StreamController<int>.broadcast();
      addTearDown(resumes.close);
      final socket = realSocket('/ws/lobby/$code/');
      final container = ProviderContainer(
        overrides: [
          lobbyServiceProvider.overrideWithValue(service),
          lobbyWebSocketFactoryProvider.overrideWithValue((_) => socket),
          appResumesProvider.overrideWith((ref) => resumes.stream),
          authenticatedClientProvider.overrideWithValue(
            AuthenticatedClient.forTesting(dio: MockHttpClient().dio),
          ),
        ],
      );
      addTearDown(container.dispose);
      when(() => service.fetchLobby(code)).thenAnswer((_) async => lobby);
      final sub = container.listen(lobbyProvider(code), (_, _) {});
      addTearDown(sub.close);
      await container.read(lobbyProvider(code).future);
      await _settle();
      channels.single.addServerEvent(GameEvents.lobbyBeat(rev: lobby.rev!));
      await _settle();
      clearInteractions(service);
      return container;
    }

    test('its socket missed a beat: reopened at once, the lobby read '
        'once', () async {
      await seated();
      wall = wall.add(const Duration(minutes: 5));
      resumes.add(1);
      await _settle();
      expect(channels, hasLength(2));
      verify(() => service.fetchLobby(code)).called(1);
    });

    test('its socket is hearing its beats: left as it is, the lobby read '
        'once', () async {
      await seated();
      wall = wall.add(const Duration(seconds: 5));
      resumes.add(1);
      await _settle();
      expect(channels, hasLength(1));
      verify(() => service.fetchLobby(code)).called(1);
    });

    test('a beat at a later rev (a frame lost on a live socket: a deal, a '
        'change) reads the lobby once; the same rev reads nothing', () async {
      await seated();
      channels.single.addServerEvent(GameEvents.lobbyBeat(rev: lobby.rev!));
      await _settle();
      verifyNever(() => service.fetchLobby(code));
      for (var i = 0; i < 3; i++) {
        channels.single.addServerEvent(
          GameEvents.lobbyBeat(rev: lobby.rev! + 1),
        );
        await _settle();
      }
      verify(() => service.fetchLobby(code)).called(1);
    });
  });
}

Future<void> _settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
