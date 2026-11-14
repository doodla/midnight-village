import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/debug/debug_api_client.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:midnight_village/core/debug/debug_table_controller.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:mocktail/mocktail.dart';

class _MockDebugApiClient extends Mock implements DebugApiClient {}

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
      return {
        'access': 'access-$id',
        'refresh': 'refresh-$id',
        'user': {'id': id, 'display_name': name},
      };
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
        ).thenAnswer((_) async => {'code': 'ABCD'});
        when(
          () => client.post(
            any(that: contains('/join/')),
            token: any(named: 'token'),
          ),
        ).thenAnswer((_) async => const {});
        when(
          () => client.post(
            any(that: contains('/ready/')),
            token: any(named: 'token'),
          ),
        ).thenAnswer((_) async => const {});
        when(
          () => client.patch(
            '/lobbies/ABCD/',
            token: any(named: 'token'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => const {});
        when(
          () => client.post(
            '/onuw/lobbies/ABCD/start/',
            token: any(named: 'token'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => {'game_id': 'game-1', 'phase': 'night'});

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
      ).thenAnswer((_) async => {'phase': 'night', 'action_prompt': null});

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
        ).thenAnswer((_) async => const {});

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
            idempotent409: true,
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
      ).thenAnswer((_) async => const {});

      await controller.driveAs(
        controller.table!.playerById(1),
        const DebugAction.vote(voteTargetUserId: 2),
      );

      verify(
        () => client.post(
          '/onuw/games/g1/vote/',
          token: 'access-1',
          data: {'target_player_id': 2},
          idempotent409: true,
        ),
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
        (_) async => {
          'game_id': 'g2',
          'phase': 'night',
          'current_wave': 2,
          'center_cards': ['Werewolf', 'Minion', 'Drunk'],
          'players': [
            {
              'user_id': 1,
              'display_name': 'Alice',
              'is_host': true,
              'original_role': 'Werewolf',
              'current_role': 'Werewolf',
              'doppelganger_copied_role': null,
              'team': 'werewolf',
              'connected': true,
            },
          ],
          'night_actions_log': [],
          'votes': {'1': null, '2': null},
          'results': null,
        },
      );

      final state = await controller.oracle();
      expect(state.currentWave, 2);
      expect(state.playerById(1).team, 'werewolf');
      expect(state.votes, {1: null, 2: null});
    });

    test('fireTimer posts the timer key', () async {
      when(
        () => client.post(
          '/onuw/games/g2/debug-fire-timer/',
          token: any(named: 'token'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => {'fired': true, 'key': 'voting'});

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
      ).thenAnswer((_) async => {'fired': false, 'key': 'wave:2'});

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
  ).thenAnswer((_) async => {'code': code});
  when(
    () => client.post(
      any(that: contains('/join/')),
      token: any(named: 'token'),
    ),
  ).thenAnswer((_) async => const {});
  when(
    () => client.post(
      any(that: contains('/ready/')),
      token: any(named: 'token'),
    ),
  ).thenAnswer((_) async => const {});
  when(
    () => client.patch(
      '/lobbies/$code/',
      token: any(named: 'token'),
      data: any(named: 'data'),
    ),
  ).thenAnswer((_) async => const {});
  when(
    () => client.post(
      '/onuw/lobbies/$code/start/',
      token: any(named: 'token'),
      data: any(named: 'data'),
    ),
  ).thenAnswer((_) async => {'game_id': gameId, 'phase': 'night'});
}
