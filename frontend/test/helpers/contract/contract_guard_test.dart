import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/helpers/server_bodies.dart';
import '../game_events.dart';
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
      final kinds = <String>{};
      for (final info in ContractSamples.index) {
        kinds.add(info.kind);
        final body = ContractSamples.load(info.name);
        switch (info.kind) {
          case 'http':
            checkHttpBody(info.method!, info.path!, info.status!, body);
          case 'ws':
            expect(
              (body as Map)['type'],
              info.type,
              reason: '${info.name}: the index names another event type',
            );
            checkSocketEvent(body);
          case 'ws_sequence':
            // A list of event types per seat, not an event: validated as that.
            _checkSequence(info);
          default:
            fail(
              '${info.name}: sample kind "${info.kind}" is not known to the '
              'guard. Teach contract_guard_test.dart and contract_shape.dart '
              'what it is; do not skip it.',
            );
        }
      }
      expect(
        kinds,
        containsAll(['http', 'ws', 'ws_sequence']),
        reason: 'the kinds the guard has to know',
      );
    });

    test('every ws_sequence is a list of known event types per seat', () {
      final sequences = ContractSamples.index.where((s) => s.isSequence);
      expect(sequences, isNotEmpty);
      for (final info in sequences) {
        _checkSequence(info);
      }
    });

    test('a sequence naming an event the server never sends is refused', () {
      final heard = ContractSamples.sequence('ws_sequence/window_1');
      heard.values.first.add('wave_skipped');
      expect(
        () => _checkSequenceBody(heard, 'probe'),
        throwsA(isA<TestFailure>()),
      );
      expect(
        () => _checkSequenceBody({'Ana': <String>[]}, 'probe'),
        throwsA(isA<TestFailure>()),
        reason: 'a seat that heard nothing is not a recording',
      );
      expect(
        () => _checkSequenceBody(<String, List<String>>{}, 'probe'),
        throwsA(isA<TestFailure>()),
      );
    });

    test('every recorded /me/ names its stage', () {
      for (final info in ContractSamples.index.where(
        (s) =>
            s.isHttp && s.status == 200 && s.matchesPath('/onuw/games/g/me/'),
      )) {
        expect(
          ContractSamples.map(info.name),
          contains('stage'),
          reason: info.name,
        );
      }
    });
  });

  group('a /me/ is the one the server sends', () {
    Map<String, dynamic> sample(String name) => ContractSamples.map(name);
    void check(Map<String, dynamic> body) =>
        checkHttpBody('GET', '/onuw/games/g/me/', 200, body);
    void refused(dynamic Function() fn) =>
        expect(fn, throwsA(isA<OffContractPayload>()));

    test('a /me/ without its stage is refused', () {
      refused(() => check(sample('http/game/me_look_stage')..remove('stage')));
    });

    test('what the server always sends cannot be left out', () {
      check(sample('http/game/me_voting_picked'));
      for (final key in ['stage', 'my_vote', 'ready', 'progress']) {
        refused(() => check(sample('http/game/me_voting_picked')..remove(key)));
      }
    });

    test("the samples' own bodies pass", () {
      check(sample('http/game/me_choose_prompt_seer'));
      check(sample('http/game/me_discussion_choose_seer'));
      check(sample('http/game/me_look_stage'));
    });
  });

  test('a dictionary may be empty: a deck with every card taken out', () {
    final lobby = ContractSamples.map('http/lobby/detail_seats_8_four_here');
    (lobby['settings'] as Map)['roles'] = <String, dynamic>{};
    lobby['deck_cards'] = <String, dynamic>{};
    checkHttpBody('GET', '/lobbies/D3GL6S/', 200, lobby);
  });

  group('the check refuses', () {
    Map<String, dynamic> me() =>
        ContractSamples.map('http/game/me_choose_prompt_seer');
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
        'player_ids': {
          'players': [2, 3],
        },
      };
      expect(() => check(body), throwsA(isA<OffContractPayload>()));
    });

    test('an always-sent key left out', () {
      for (final key in ['stage', 'action_prompt', 'night_results']) {
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

    group('a key of another situation (variants, not a union)', () {
      Map<String, dynamic> sample(String name) => ContractSamples.map(name);
      void refused(dynamic Function() check) =>
          expect(check, throwsA(isA<OffContractPayload>()));

      test('a night /me/ with the results-only current_role', () {
        final body = sample('http/game/me_choose_prompt_seer');
        body['your_role']['current_role'] = 'Seer';
        refused(() => check(body));
      });

      test('a discussion /me/ with a Seer prompt', () {
        final body = sample('http/game/me_discussion_choose_seer')
          ..['action_prompt'] = sample(
            'http/game/me_choose_prompt_seer',
          )['action_prompt'];
        refused(() => check(body));
      });

      test('a Seer prompt with a team view target', () {
        final body = sample('http/game/me_choose_prompt_seer');
        body['action_prompt']['valid_targets']['see_team'] = [2];
        refused(() => check(body));
      });

      test('a Seer result carrying a team view', () {
        final body = sample('http/game/me_discussion_choose_seer');
        body['night_results'][0]['revealed_info']['teammate_names'] = ['Bob'];
        refused(() => check(body));
      });

      test("a Minion team view with a lone Werewolf's centre card", () {
        final body = sample('http/game/me_discussion_choose_minion');
        body['night_results'][0]['revealed_info']['center_card'] = {
          'index': 0,
          'role': 'Seer',
        };
        refused(() => check(body));
      });

      test("but each situation's own sample passes", () {
        check(sample('http/game/me_choose_prompt_seer'));
        check(sample('http/game/me_discussion_choose_seer'));
        check(sample('http/game/me_discussion_choose_werewolf_lone'));
      });
    });

    test('an error body for an endpoint with no such error recorded', () {
      expect(
        () => checkHttpBody('POST', '/onuw/games/g/action/', 404, {
          'detail': 'Game not found.',
        }),
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
    checkHttpBody('GET', '/stats/online/', 200, ServerBodies.onlineStats);
    checkHttpBody('GET', '/me/table/', 200, ServerBodies.myTableNone);
    checkHttpBody(
      'GET',
      '/onuw/me/recent-games/',
      200,
      ServerBodies.recentGamesNone,
    );
  });

  group('every builder output is on contract', () {
    test('GameEvents, every factory', () {
      final events = [
        GameEvents.phaseChange(phase: 'discussion'),
        GameEvents.phaseChange(
          phase: 'voting',
          deadline: '2026-11-19T21:00:30Z',
        ),
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
        GameEvents.lobbyUpdate(roleConfig: {'Werewolf': 2, 'Seer': 1}),
        GameEvents.gameStarted(gameId: 'g'),
      ];
      events.forEach(checkSocketEvent);
    });

    test('where am I, recent games and players at tables', () {
      checkHttpBody('GET', '/me/table/', 200, serverMyTable());
      for (final phase in ['night', 'discussion', 'voting', 'results']) {
        checkHttpBody(
          'GET',
          '/me/table/',
          200,
          serverMyTable(
            code: 'ABC123',
            status: phase == 'results' ? 'finished' : 'in_game',
            isHost: true,
            seat: 3,
            gameId: 'g',
            phase: phase,
          ),
        );
      }
      checkHttpBody('GET', '/me/table/', 200, serverMyTable(code: 'ABC123'));
      checkHttpBody(
        'GET',
        '/onuw/me/recent-games/',
        200,
        serverRecentGames([
          (
            gameId: 'g',
            playerCount: 5,
            winningTeams: ['werewolf'],
            youWon: false,
            seat: 4,
          ),
        ]),
      );
      checkHttpBody(
        'GET',
        '/onuw/me/recent-games/',
        200,
        serverRecentGames(const []),
      );
      checkHttpBody(
        'GET',
        '/stats/online/',
        200,
        serverOnlineStats(players: 0, tables: 0),
      );
    });

    test('results and lobby', () {
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

/// A `ws_sequence` sample is a map of seat -> the event types it heard, each
/// type one the server sends as a `ws` sample.
void _checkSequence(SampleInfo info) {
  expect(info.socket, isNotNull, reason: '${info.name}: no socket named');
  _checkSequenceBody(ContractSamples.sequence(info.name), info.name);
}

void _checkSequenceBody(Map<String, List<String>> heard, String name) {
  expect(heard, isNotEmpty, reason: '$name: no seat recorded');
  final known = {
    for (final s in ContractSamples.index)
      if (s.isEvent) s.type,
  };
  for (final MapEntry(key: seat, value: types) in heard.entries) {
    expect(types, isNotEmpty, reason: '$name: $seat heard nothing');
    for (final type in types) {
      expect(
        known,
        contains(type),
        reason: '$name: $seat heard "$type", which has no ws sample',
      );
    }
  }
}
