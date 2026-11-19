import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/helpers/server_bodies.dart';
import '../game_events.dart';
import '../game_state_factory.dart';
import 'contract_samples.dart';
import 'contract_shape.dart';
import 'server_json.dart';

/// The fixtures the tests use cannot claim what the server does not send.
///
/// The guarantee: every body a test registers on `MockHttpClient` and every
/// event it pushes through `MockWebSocketChannel.addServerEvent` is checked
/// against the recorded samples (key paths, JSON types, always-sent keys;
/// see contract_shape.dart), and every builder starts from a sample. These
/// tests prove the check bites and that every builder output passes it.
void main() {
  group('the samples', () {
    test('every indexed sample exists and matches its own contract', () {
      expect(ContractSamples.index, isNotEmpty);
      for (final info in ContractSamples.index) {
        final body = ContractSamples.load(info.name);
        if (info.isHttp) {
          checkHttpBody(info.method!, info.path!, info.status!, body);
        } else {
          checkSocketEvent(body);
        }
      }
    });
  });

  group('the check refuses', () {
    Map<String, dynamic> me() => GameMeJsonBuilder().withPrompt('seer').build();
    void check(Map<String, dynamic> body) =>
        checkHttpBody('GET', '/onuw/games/g/me/', 200, body);

    test('a key the server never sends', () {
      final body = me();
      (body['players'] as List).first['connected'] = true;
      expect(() => check(body), throwsA(isA<OffContractPayload>()));
    });

    test('nested targets where the server sends them flat', () {
      final body = me();
      body['action_prompt']['valid_targets'] = {
        'peek_player': {
          'players': [2, 3],
        },
      };
      expect(() => check(body), throwsA(isA<OffContractPayload>()));
    });

    test('an always-sent key left out', () {
      for (final key in ['has_voted', 'action_prompt', 'night_results']) {
        expect(
          () => check(me()..remove(key)),
          throwsA(isA<OffContractPayload>()),
          reason: key,
        );
      }
    });

    test('a value of another type', () {
      expect(
        () => check(me()..['current_wave'] = '2'),
        throwsA(isA<OffContractPayload>()),
      );
    });

    test('a results body with a votes list', () {
      expect(
        () => checkHttpBody('GET', '/onuw/games/g/results/', 200, {
          ...serverResults(),
          'votes': <dynamic>[],
        }),
        throwsA(isA<OffContractPayload>()),
      );
    });

    test('an event type the server never sends', () {
      expect(
        () => checkSocketEvent({'type': 'wave_skipped'}),
        throwsA(isA<OffContractPayload>()),
      );
    });

    test('an endpoint with no recorded sample', () {
      expect(
        () => checkHttpBody('GET', '/onuw/games/g/secrets/', 200, {}),
        throwsA(isA<OffContractPayload>()),
      );
    });
  });

  test('the web integration test serves server bodies', () {
    checkHttpBody('POST', '/auth/guest/', 201, ServerBodies.guestCreated);
    checkHttpBody(
      'POST',
      '/auth/token/refresh/',
      401,
      ServerBodies.refreshRefused,
    );
  });

  group('every builder output is on contract', () {
    test('GameMeJsonBuilder, in every phase and with every prompt', () {
      for (final phase in ['night', 'discussion', 'voting', 'results']) {
        GameMeJsonBuilder().inPhase(phase).asHost().build();
      }
      for (final kind in promptKinds) {
        GameMeJsonBuilder()
            .withDeck({
              'Doppelganger': 1,
              'Werewolf': 2,
              'Seer': 1,
              'Villager': 2,
            })
            .withWave(kind.startsWith('doppelganger') ? 1 : 2)
            .withPrompt(kind)
            .build();
      }
      GameMeJsonBuilder()
          .inPhase('voting')
          .hasVoted(true)
          .withPlayersHavingVoted({2: true})
          .build();
      GameMeJsonBuilder().inPhase('discussion').withNightResults([
        for (final kind in nightResultKinds) serverNightResult(kind),
      ]).build();
    });

    test('GameEvents, every factory', () {
      final events = [
        GameEvents.waveStart(wave: 2, deadline: '2026-11-19T21:00:30+00:00'),
        GameEvents.waveStart(wave: 1),
        for (final kind in promptKinds) GameEvents.actionPrompt(kind),
        for (final kind in nightResultKinds) GameEvents.actionResult(kind),
        GameEvents.waveComplete(),
        GameEvents.waveWaiting(),
        GameEvents.phaseChange(phase: 'discussion'),
        GameEvents.phaseChange(
          phase: 'voting',
          deadline: '2026-11-19T21:00:30+00:00',
        ),
        GameEvents.voteSubmitted(playerId: 2),
        GameEvents.voteReveal(votes: {'1': 2, '2': null}),
        GameEvents.gameResults(eliminatedPlayers: [2]),
        GameEvents.playerPresence(playerId: 2, connected: false),
        for (final reason in ['handover', 'returned', 'transferred'])
          GameEvents.hostChanged(
            hostId: 2,
            hostName: 'Bob',
            originalHostId: 1,
            reason: reason,
          ),
        GameEvents.playAgain(lobbyCode: 'ABC123'),
        GameEvents.playerJoined(),
        GameEvents.playerLeft(),
        GameEvents.playerReady(playerId: 2, isReady: false),
        GameEvents.lobbyUpdate(roleConfig: {'Werewolf': 2, 'Seer': 1}),
        GameEvents.gameStarted(gameId: 'g'),
      ];
      events.forEach(checkSocketEvent);
    });

    test('player list, results and lobby', () {
      checkHttpBody(
        'GET',
        '/onuw/games/g/players/',
        200,
        serverPlayerList(away: {2}),
      );
      checkHttpBody(
        'GET',
        '/onuw/games/g/players/',
        200,
        serverPlayerList(hasVoted: {1: true}),
      );
      checkHttpBody(
        'GET',
        '/onuw/games/g/results/',
        200,
        serverResults(
          players: [
            ResultSeat(
              defaultSeats[0],
              originalRole: 'Werewolf',
              team: 'werewolf',
              won: false,
              eliminatedBy: 'vote',
              votedFor: 2,
            ),
          ],
        ),
      );
      checkHttpBody('GET', '/lobbies/ABC123/', 200, serverLobby());
      checkHttpBody(
        'GET',
        '/lobbies/ABC123/',
        200,
        serverLobby(hostId: 2, originalHostId: 1, status: 'in_game'),
      );
    });
  });
}
