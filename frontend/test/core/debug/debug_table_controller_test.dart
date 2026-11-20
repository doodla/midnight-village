import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/debug/debug_api_client.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:midnight_village/core/debug/debug_table_controller.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/contract/contract_samples.dart';
import '../../helpers/contract/contract_shape.dart';
import '../../helpers/contract/server_json.dart';
import '../../helpers/game_state_factory.dart';

class _MockDebugApiClient extends Mock implements DebugApiClient {}

/// What the server answers to [method] [path] with [status]: [body], checked
/// against the recorded samples like every mocked body (the debug client is
/// mocked here, so its answers do not pass through `MockHttpClient`).
Map<String, dynamic> _answer(
  String method,
  String path,
  int status,
  Map<String, dynamic> body,
) {
  checkHttpBody(method, path, status, body);
  return body;
}

/// The lobby body for table [code] before a deck is chosen, or with one.
Map<String, dynamic> _table(String code, {bool deck = false}) =>
    serverLobby(code: code, deck: deck);

/// `POST .../vote/`: the vote was taken.
Map<String, dynamic> _voted() => _answer(
  'POST',
  '/onuw/games/g1/vote/',
  200,
  ContractSamples.map('http/game/vote_submitted'),
);

/// `POST .../start/`: the dealt game [gameId].
Map<String, dynamic> _started(String gameId) =>
    withValues(ContractSamples.map('http/game/started'), {'game_id': gameId});

void main() {
  // These run WITHOUT a backend: the §D2 client is mocked. They verify the
  // controller's orchestration, name→id re-keying, and switchTo wiring.
  late _MockDebugApiClient client;

  // Records the args passed to the injected callbacks.
  final adopted = <(User, String, String)>[];
  final invalidatedGameIds = <String>[];

  late DebugTableController controller;

  setUp(() {
    client = _MockDebugApiClient();
    adopted.clear();
    invalidatedGameIds.clear();
    controller = DebugTableController(
      client: client,
      adoptSession:
          (user, {required accessToken, required refreshToken}) async {
            adopted.add((user, accessToken, refreshToken));
          },
      invalidateGameProviders: invalidatedGameIds.add,
    );
  });

  /// Stubs guest creation to return sequential ids/tokens per display name.
  void stubGuests(Map<String, int> nameToId) {
    when(
      () => client.post(
        '/auth/guest/',
        token: any(named: 'token'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((invocation) async {
      final data = invocation.namedArguments[#data] as Map<String, dynamic>;
      final name = data['display_name'] as String;
      final id = nameToId[name]!;
      final created = ContractSamples.map('http/auth/guest_created');
      return _answer(
        'POST',
        '/auth/guest/',
        201,
        withValues(created, {
          'access': 'access-$id',
          'refresh': 'refresh-$id',
          'user': withValues((created['user'] as Map).cast(), {
            'id': id,
            'display_name': name,
          }),
        }),
      );
    });
  }

  group('createTable', () {
    test(
      'creates guests, hosts as first, re-keys forced roles by server id',
      () async {
        stubGuests({'Alice': 10, 'Bob': 11, 'Carol': 12});

        when(
          () => client.post(
            '/lobbies/',
            token: any(named: 'token'),
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async => _answer('POST', '/lobbies/', 201, _table('ABCD')),
        );
        when(
          () => client.post(
            any(that: contains('/join/')),
            token: any(named: 'token'),
          ),
        ).thenAnswer(
          (_) async =>
              _answer('POST', '/lobbies/ABCD/join/', 200, _table('ABCD')),
        );
        when(
          () => client.post(
            any(that: contains('/ready/')),
            token: any(named: 'token'),
          ),
        ).thenAnswer(
          (_) async =>
              _answer('POST', '/lobbies/ABCD/ready/', 200, _table('ABCD')),
        );
        when(
          () => client.patch(
            '/lobbies/ABCD/',
            token: any(named: 'token'),
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async => _answer(
            'PATCH',
            '/lobbies/ABCD/',
            200,
            _table('ABCD', deck: true),
          ),
        );
        when(
          () => client.post(
            '/onuw/lobbies/ABCD/start/',
            token: any(named: 'token'),
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async => _answer(
            'POST',
            '/onuw/lobbies/ABCD/start/',
            201,
            _started('game-1'),
          ),
        );

        final table = await controller.createTable(
          playerNames: ['Alice', 'Bob', 'Carol'],
          roleCounts: {'Werewolf': 1, 'Seer': 1, 'Robber': 1, 'Villager': 3},
          playerRolesByName: {
            'Alice': 'Werewolf',
            'Bob': 'Seer',
            'Carol': 'Robber',
          },
          centerCards: ['Villager', 'Villager', 'Villager'],
        );

        expect(table.gameId, 'game-1');
        expect(table.lobbyCode, 'ABCD');
        expect(table.host.displayName, 'Alice');
        expect(table.host.isHost, isTrue);
        expect(table.players.map((p) => p.userId), [10, 11, 12]);
        expect(table.playerById(11).role, 'Seer');

        // The forced assignment sent to start/ is keyed by STRINGIFIED user ids.
        final captured =
            verify(
                  () => client.post(
                    '/onuw/lobbies/ABCD/start/',
                    token: any(named: 'token'),
                    data: captureAny(named: 'data'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        final forced = (captured['debug'] as Map)['forced_assignment'] as Map;
        expect(forced['player_roles'], {
          '10': 'Werewolf',
          '11': 'Seer',
          '12': 'Robber',
        });
        expect(forced['center'], ['Villager', 'Villager', 'Villager']);
      },
    );

    test('PATCHes timer settings beside the roles when given', () async {
      stubGuests({'Alice': 10, 'Bob': 11});
      _stubLobbyFlow(client, code: 'TM', gameId: 'g-timers');

      await controller.createTable(
        playerNames: ['Alice', 'Bob'],
        roleCounts: {'Werewolf': 1, 'Villager': 4},
        playerRolesByName: {'Alice': 'Werewolf', 'Bob': 'Villager'},
        centerCards: ['Villager', 'Villager', 'Villager'],
        timerSettings: {
          'night_min_window_seconds': 0,
          'night_doppelganger_window_seconds': 0,
        },
      );

      final patched =
          verify(
                () => client.patch(
                  '/lobbies/TM/',
                  token: any(named: 'token'),
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(patched['settings'], {
        'roles': {'Werewolf': 1, 'Villager': 4},
        'night_min_window_seconds': 0,
        'night_doppelganger_window_seconds': 0,
      });
    });

    test('sends only the roles when no timer settings are given', () async {
      stubGuests({'Alice': 10, 'Bob': 11});
      _stubLobbyFlow(client, code: 'NT', gameId: 'g-no-timers');

      await controller.createTable(
        playerNames: ['Alice', 'Bob'],
        roleCounts: {'Werewolf': 1, 'Villager': 4},
        playerRolesByName: {'Alice': 'Werewolf', 'Bob': 'Villager'},
        centerCards: ['Villager', 'Villager', 'Villager'],
      );

      final patched =
          verify(
                () => client.patch(
                  '/lobbies/NT/',
                  token: any(named: 'token'),
                  data: captureAny(named: 'data'),
                ),
              ).captured.single
              as Map<String, dynamic>;
      expect(patched['settings'], {
        'roles': {'Werewolf': 1, 'Villager': 4},
      });
    });

    test('rejects duplicate player names', () async {
      expect(
        () => controller.createTable(
          playerNames: ['Alice', 'Alice'],
          roleCounts: const {},
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('playerView', () {
    test('reads /me/ with that player\'s own token', () async {
      stubGuests({'Alice': 1, 'Bob': 2});
      _stubLobbyFlow(client, code: 'PV', gameId: 'g-pv');
      final table = await controller.createTable(
        playerNames: ['Alice', 'Bob'],
        roleCounts: {'Werewolf': 1, 'Villager': 4},
        playerRolesByName: {'Alice': 'Werewolf', 'Bob': 'Villager'},
        centerCards: ['Villager', 'Villager', 'Villager'],
      );
      when(
        () => client.get('/onuw/games/g-pv/me/', token: 'access-2'),
      ).thenAnswer(
        (_) async => _answer(
          'GET',
          '/onuw/games/g-pv/me/',
          200,
          GameMeJsonBuilder().withGameId('g-pv').build(),
        ),
      );

      final view = await controller.playerView(table.playerById(2));

      expect(view['phase'], 'night');
      verify(
        () => client.get('/onuw/games/g-pv/me/', token: 'access-2'),
      ).called(1);
    });
  });

  group('switchTo', () {
    test('adopts the session and invalidates the game providers', () async {
      stubGuests({'Alice': 1, 'Bob': 2});
      _stubLobbyFlow(client, code: 'XY', gameId: 'g9');

      final table = await controller.createTable(
        playerNames: ['Alice', 'Bob'],
        roleCounts: {'Werewolf': 1, 'Villager': 4},
        playerRolesByName: {'Alice': 'Werewolf', 'Bob': 'Villager'},
        centerCards: ['Villager', 'Villager', 'Villager'],
      );

      await controller.switchTo(table.playerById(2));

      // adoptSession called with Bob's user + his ORIGINAL tokens (no refresh).
      expect(adopted, hasLength(1));
      final (user, access, refresh) = adopted.single;
      expect(user.id, 2);
      expect(access, 'access-2');
      expect(refresh, 'refresh-2');
      // The four game providers were invalidated (one call per gameId).
      expect(invalidatedGameIds, ['g9']);
    });
  });

  group('driveAs', () {
    setUp(() async {
      stubGuests({'Alice': 1, 'Bob': 2});
      _stubLobbyFlow(client, code: 'XY', gameId: 'g1');
      await controller.createTable(
        playerNames: ['Alice', 'Bob'],
        roleCounts: {'Werewolf': 1, 'Villager': 4},
        playerRolesByName: {'Alice': 'Werewolf', 'Bob': 'Villager'},
        centerCards: ['Villager', 'Villager', 'Villager'],
      );
    });

    test(
      'night action posts with the actor token (not the global one)',
      () async {
        when(
          () => client.post(
            '/onuw/games/g1/action/',
            token: any(named: 'token'),
            data: any(named: 'data'),
            idempotent409: any(named: 'idempotent409'),
          ),
        ).thenAnswer(
          (_) async => _answer(
            'POST',
            '/onuw/games/g1/action/',
            200,
            ContractSamples.map('http/game/action_submitted'),
          ),
        );

        final bob = controller.table!.playerById(2);
        await controller.driveAs(
          bob,
          const DebugAction.nightAction(
            actionType: 'peek_player',
            targets: {'player_id': 1},
          ),
        );

        verify(
          () => client.post(
            '/onuw/games/g1/action/',
            token: 'access-2',
            data: {
              'action_type': 'peek_player',
              'targets': {'player_id': 1},
            },
            idempotent409: false,
          ),
        ).called(1);
      },
    );

    test('vote posts the target_player_id', () async {
      when(
        () => client.post(
          '/onuw/games/g1/vote/',
          token: any(named: 'token'),
          data: any(named: 'data'),
          idempotent409: any(named: 'idempotent409'),
        ),
      ).thenAnswer((_) async => _voted());

      await controller.driveAs(
        controller.table!.playerById(1),
        const DebugAction.vote(voteTargetUserId: 2),
      );

      verify(
        () => client.post(
          '/onuw/games/g1/vote/',
          token: 'access-1',
          data: {'target_player_id': 2},
          idempotent409: false,
        ),
      ).called(1);
    });

    test(
      'lenient driving treats a 409 as already done (toolbar only)',
      () async {
        when(
          () => client.post(
            '/onuw/games/g1/vote/',
            token: any(named: 'token'),
            data: any(named: 'data'),
            idempotent409: any(named: 'idempotent409'),
          ),
        ).thenAnswer((_) async => _voted());

        await controller.driveAs(
          controller.table!.playerById(1),
          const DebugAction.vote(voteTargetUserId: 2),
          lenient: true,
        );

        verify(
          () => client.post(
            '/onuw/games/g1/vote/',
            token: 'access-1',
            data: {'target_player_id': 2},
            idempotent409: true,
          ),
        ).called(1);
      },
    );

    test('attachTable re-points driving at a later game', () async {
      // The only post here is the host ending the talk.
      when(
        () => client.post(
          any(),
          token: any(named: 'token'),
          data: any(named: 'data'),
          idempotent409: any(named: 'idempotent409'),
        ),
      ).thenAnswer(
        (_) async => _answer(
          'POST',
          '/onuw/games/g7/end-discussion/',
          200,
          ContractSamples.map('http/game/end_discussion'),
        ),
      );
      final old = controller.table!;
      controller.attachTable(
        DebugTable(
          gameId: 'g7',
          lobbyCode: old.lobbyCode,
          players: old.players,
        ),
      );

      await controller.driveAs(
        old.players.first,
        const DebugAction.endDiscussion(),
      );

      verify(
        () => client.post('/onuw/games/g7/end-discussion/', token: 'access-1'),
      ).called(1);
    });
  });

  group('oracle + fireTimer', () {
    setUp(() async {
      stubGuests({'Alice': 1, 'Bob': 2});
      _stubLobbyFlow(client, code: 'XY', gameId: 'g2');
      await controller.createTable(
        playerNames: ['Alice', 'Bob'],
        roleCounts: {'Werewolf': 1, 'Villager': 4},
        playerRolesByName: {'Alice': 'Werewolf', 'Bob': 'Villager'},
        centerCards: ['Villager', 'Villager', 'Villager'],
      );
    });

    test('oracle parses the debug-state projection', () async {
      when(
        () => client.get(
          '/onuw/games/g2/debug-state/',
          token: any(named: 'token'),
        ),
      ).thenAnswer(
        (_) async => _answer(
          'GET',
          '/onuw/games/g2/debug-state/',
          200,
          ContractSamples.map('http/debug/state_night'),
        ),
      );

      final state = await controller.oracle();
      final recorded = ContractSamples.map('http/debug/state_night');
      final first = (recorded['players'] as List).first as Map;
      expect(state.currentWave, recorded['current_wave']);
      expect(state.playerById(first['user_id'] as int).team, first['team']);
      expect(state.votes.values, everyElement(isNull));
      expect(state.votes, hasLength((recorded['votes'] as Map).length));
    });

    test('fireTimer posts the timer key', () async {
      when(
        () => client.post(
          '/onuw/games/g2/debug-fire-timer/',
          token: any(named: 'token'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _answer(
          'POST',
          '/onuw/games/g2/debug-fire-timer/',
          200,
          withValues(ContractSamples.map('http/debug/fire_timer'), {
            'key': 'voting',
          }),
        ),
      );

      final fired = await controller.fireTimer(TimerKey.voting);
      expect(fired, isTrue);

      verify(
        () => client.post(
          '/onuw/games/g2/debug-fire-timer/',
          token: any(named: 'token'),
          data: {'key': 'voting'},
        ),
      ).called(1);
    });
  });

  group('fireTimer result', () {
    test('reports false when no timer was pending', () async {
      stubGuests({'Alice': 1, 'Bob': 2});
      _stubLobbyFlow(client, code: 'FT', gameId: 'g-ft');
      await controller.createTable(
        playerNames: ['Alice', 'Bob'],
        roleCounts: {'Werewolf': 1, 'Villager': 4},
        playerRolesByName: {'Alice': 'Werewolf', 'Bob': 'Villager'},
        centerCards: ['Villager', 'Villager', 'Villager'],
      );
      when(
        () => client.post(
          '/onuw/games/g-ft/debug-fire-timer/',
          token: any(named: 'token'),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => _answer(
          'POST',
          '/onuw/games/g-ft/debug-fire-timer/',
          200,
          ContractSamples.map('http/debug/fire_timer_none'),
        ),
      );

      expect(await controller.fireTimer(TimerKey.wave(2)), isFalse);
    });
  });

  group('setConnected', () {
    test('tracks manual disconnect and invalidates providers', () async {
      stubGuests({'Alice': 1, 'Bob': 2});
      _stubLobbyFlow(client, code: 'XY', gameId: 'g3');
      final table = await controller.createTable(
        playerNames: ['Alice', 'Bob'],
        roleCounts: {'Werewolf': 1, 'Villager': 4},
        playerRolesByName: {'Alice': 'Werewolf', 'Bob': 'Villager'},
        centerCards: ['Villager', 'Villager', 'Villager'],
      );
      invalidatedGameIds.clear();

      await controller.setConnected(table.playerById(2), false);
      expect(controller.isManuallyDisconnected(2), isTrue);
      expect(invalidatedGameIds, ['g3']);

      await controller.setConnected(table.playerById(2), true);
      expect(controller.isManuallyDisconnected(2), isFalse);
    });
  });
}

/// Stubs the lobby create/join/ready/patch/start chain for a 2-player table.
void _stubLobbyFlow(
  _MockDebugApiClient client, {
  required String code,
  required String gameId,
}) {
  when(
    () => client.post(
      '/lobbies/',
      token: any(named: 'token'),
      data: any(named: 'data'),
    ),
  ).thenAnswer((_) async => _answer('POST', '/lobbies/', 201, _table(code)));
  when(
    () => client.post(
      any(that: contains('/join/')),
      token: any(named: 'token'),
    ),
  ).thenAnswer(
    (_) async => _answer('POST', '/lobbies/$code/join/', 200, _table(code)),
  );
  when(
    () => client.post(
      any(that: contains('/ready/')),
      token: any(named: 'token'),
    ),
  ).thenAnswer(
    (_) async => _answer('POST', '/lobbies/$code/ready/', 200, _table(code)),
  );
  when(
    () => client.patch(
      '/lobbies/$code/',
      token: any(named: 'token'),
      data: any(named: 'data'),
    ),
  ).thenAnswer(
    (_) async =>
        _answer('PATCH', '/lobbies/$code/', 200, _table(code, deck: true)),
  );
  when(
    () => client.post(
      '/onuw/lobbies/$code/start/',
      token: any(named: 'token'),
      data: any(named: 'data'),
    ),
  ).thenAnswer(
    (_) async =>
        _answer('POST', '/onuw/lobbies/$code/start/', 201, _started(gameId)),
  );
}
