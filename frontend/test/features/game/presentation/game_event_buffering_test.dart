import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import '../../../helpers/game_events.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

const _gameId = 'test-game-id';

/// Holds every GET to a path ending in [suffix] until [gate] completes, like a
/// slow server; the caller decides what the response says by registering it.
void _hold(GameTestSetup setup, String suffix, Completer<void> gate) {
  setup.http.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.method == 'GET' && options.path.endsWith(suffix)) {
          gate.future.then((_) => handler.next(options));
        } else {
          handler.next(options);
        }
      },
    ),
  );
}

/// Fails every GET to a path ending in [suffix] with [statusCode].
void _failGets(GameTestSetup setup, String suffix, int statusCode) {
  setup.http.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.method == 'GET' && options.path.endsWith(suffix)) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: statusCode,
                data: {'detail': 'x'},
              ),
              type: DioExceptionType.badResponse,
            ),
          );
        } else {
          handler.next(options);
        }
      },
    ),
  );
}

bool _connected(GameTestSetup s, int id) =>
    s.currentState.players.firstWhere((p) => p.playerId == id).connected;

Map<String, dynamic> _peek() => {
  'wave': 2,
  'action_type': 'peek_player',
  'revealed_info': {'target_name': 'Bob', 'role': 'werewolf'},
};

Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  group('Events that arrive while the first load is in flight', () {
    test(
      'a presence event is applied on top of the older player list',
      () async {
        final setup = GameTestSetup.create();
        addTearDown(setup.dispose);
        // The player list read says Bob is away...
        setup.registerPresence({1: true, 2: false, 3: true});
        final gate = Completer<void>();
        _hold(setup, '/players/', gate);

        final loading = setup.readGameState();
        await _tick();
        // ...but he came back while the list was on its way.
        setup.ws.addServerEvent(
          GameEvents.playerPresence(playerId: 2, connected: true),
        );
        gate.complete();
        await loading;

        expect(_connected(setup, 2), isTrue);
      },
    );

    test(
      'a presence event is not lost for want of state to apply it to',
      () async {
        final setup = GameTestSetup.create();
        addTearDown(setup.dispose);
        final gate = Completer<void>();
        _hold(setup, '/me/', gate);

        final loading = setup.readGameState();
        await _tick();
        setup.ws.addServerEvent(
          GameEvents.playerPresence(playerId: 3, connected: false),
        );
        gate.complete();
        await loading;

        expect(_connected(setup, 3), isFalse);
      },
    );

    test('held events are replayed in the order they arrived', () async {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);
      final gate = Completer<void>();
      _hold(setup, '/players/', gate);

      final loading = setup.readGameState();
      await _tick();
      setup.ws
        ..addServerEvent(
          GameEvents.playerPresence(playerId: 2, connected: false),
        )
        ..addServerEvent(
          GameEvents.playerPresence(playerId: 2, connected: true),
        )
        ..addServerEvent(
          GameEvents.playerPresence(playerId: 3, connected: true),
        )
        ..addServerEvent(
          GameEvents.playerPresence(playerId: 3, connected: false),
        );
      gate.complete();
      await loading;

      expect(_connected(setup, 2), isTrue);
      expect(_connected(setup, 3), isFalse);
    });

    test('every kind of event is held, not only presence', () async {
      final setup = GameTestSetup.create(
        gameMeJson: GameMeJsonBuilder().inPhase('voting').build(),
      );
      addTearDown(setup.dispose);
      final gate = Completer<void>();
      _hold(setup, '/me/', gate);

      final loading = setup.readGameState();
      await _tick();
      setup.ws.addServerEvent(GameEvents.voteSubmitted(playerId: 3));
      setup.ws.addServerEvent(
        GameEvents.hostChanged(hostId: 2, hostName: 'Bob', originalHostId: 1),
      );
      gate.complete();
      final state = await loading;

      expect(state.voteProgress.playerVoted[3], isTrue);
      expect(state.hostId, 2);
    });

    test('a night result already in /me/ is not shown twice when its socket '
        'event was held meanwhile', () async {
      final setup = GameTestSetup.create(
        gameMeJson: GameMeJsonBuilder().inPhase('discussion').withNightResults([
          _peek(),
        ]).build(),
      );
      addTearDown(setup.dispose);
      final gate = Completer<void>();
      _hold(setup, '/me/', gate);

      final loading = setup.readGameState();
      await _tick();
      setup.ws.addServerEvent(
        GameEvents.actionResult(
          wave: 2,
          actionType: 'peek_player',
          revealedInfo: {'target_name': 'Bob', 'role': 'werewolf'},
        ),
      );
      gate.complete();
      final state = await loading;

      expect(state.lastActionResult, isNotNull);
      expect(state.shownNightResults, hasLength(1));
      expect(state.pendingNightResults, isEmpty);
      setup.container.read(gameProvider(_gameId).notifier).dismissNightResult();
      expect(setup.currentState.lastActionResult, isNull);
    });

    test(
      'a night result that only the socket delivered is shown once',
      () async {
        final setup = GameTestSetup.create(
          gameMeJson: GameMeJsonBuilder().withWave(2).build(),
        );
        addTearDown(setup.dispose);
        final gate = Completer<void>();
        _hold(setup, '/me/', gate);

        final loading = setup.readGameState();
        await _tick();
        setup.ws.addServerEvent(
          GameEvents.actionResult(
            wave: 1,
            actionType: 'peek_player',
            revealedInfo: {'target_name': 'Bob', 'role': 'werewolf'},
          ),
        );
        gate.complete();
        final state = await loading;

        expect(state.lastActionResult?.wave, 1);
        expect(state.shownNightResults, hasLength(1));
      },
    );
  });

  group('Events that arrive while a refresh is in flight', () {
    test(
      'a fresher presence event is not overwritten by the older snapshot',
      () async {
        final setup = GameTestSetup.create();
        addTearDown(setup.dispose);
        await setup.readGameState();
        setup.registerPresence({1: true, 2: true, 3: true});
        final gate = Completer<void>();
        _hold(setup, '/players/', gate);
        final notifier = setup.container.read(gameProvider(_gameId).notifier);

        final refreshing = notifier.refreshState();
        await _tick();
        setup.ws.addServerEvent(
          GameEvents.playerPresence(playerId: 2, connected: false),
        );
        gate.complete();
        await refreshing;

        expect(_connected(setup, 2), isFalse);
      },
    );

    test('held events keep their order across a refresh', () async {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);
      await setup.readGameState();
      final gate = Completer<void>();
      _hold(setup, '/me/', gate);
      final notifier = setup.container.read(gameProvider(_gameId).notifier);

      final refreshing = notifier.refreshState();
      await _tick();
      setup.ws
        ..addServerEvent(
          GameEvents.playerPresence(playerId: 2, connected: false),
        )
        ..addServerEvent(
          GameEvents.playerPresence(playerId: 2, connected: true),
        );
      gate.complete();
      await refreshing;

      expect(_connected(setup, 2), isTrue);
    });

    test(
      'a result shown before the refresh is not shown again after it',
      () async {
        final setup = GameTestSetup.create(
          gameMeJson: GameMeJsonBuilder().withWave(2).build(),
        );
        addTearDown(setup.dispose);
        await setup.readGameState();
        final notifier = setup.container.read(gameProvider(_gameId).notifier);
        setup.registerGameMe(
          GameMeJsonBuilder().withWave(2).withNightResults([
            {
              'wave': 1,
              'action_type': 'peek_player',
              'revealed_info': {'target_name': 'Bob', 'role': 'werewolf'},
            },
          ]).build(),
        );
        final gate = Completer<void>();
        _hold(setup, '/me/', gate);

        final refreshing = notifier.refreshState();
        await _tick();
        // The same result also arrives live while /me/ is on its way.
        setup.ws.addServerEvent(
          GameEvents.actionResult(
            wave: 1,
            actionType: 'peek_player',
            revealedInfo: {'target_name': 'Bob', 'role': 'werewolf'},
          ),
        );
        gate.complete();
        await refreshing;

        expect(setup.currentState.shownNightResults, hasLength(1));
        expect(setup.currentState.pendingNightResults, isEmpty);
        notifier.dismissNightResult();
        expect(setup.currentState.lastActionResult, isNull);
      },
    );

    test('a failed refresh still applies the events held meanwhile', () async {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);
      await setup.readGameState();
      final gate = Completer<void>();
      _hold(setup, '/me/', gate);
      final notifier = setup.container.read(gameProvider(_gameId).notifier);
      // Once released the fetch fails.
      setup.http.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.endsWith('/me/')) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                ),
              );
            } else {
              handler.next(options);
            }
          },
        ),
      );

      final refreshing = notifier.refreshState();
      await _tick();
      setup.ws.addServerEvent(
        GameEvents.playerPresence(playerId: 3, connected: false),
      );
      gate.complete();
      await refreshing;

      expect(_connected(setup, 3), isFalse);
      // And later events apply live again.
      setup.ws.addServerEvent(
        GameEvents.playerPresence(playerId: 3, connected: true),
      );
      expect(_connected(setup, 3), isTrue);
    });

    test('events apply live again after a refresh', () async {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);
      await setup.readGameState();
      await setup.container.read(gameProvider(_gameId).notifier).refreshState();

      setup.ws.addServerEvent(
        GameEvents.playerPresence(playerId: 2, connected: false),
      );

      expect(_connected(setup, 2), isFalse);
    });

    test(
      'two refreshes at once run one after the other and both finish',
      () async {
        final setup = GameTestSetup.create();
        addTearDown(setup.dispose);
        await setup.readGameState();
        final notifier = setup.container.read(gameProvider(_gameId).notifier);
        final before = setup.http.requests
            .where((r) => r.path.endsWith('/me/'))
            .length;

        await Future.wait([notifier.refreshState(), notifier.refreshState()]);

        final after = setup.http.requests
            .where((r) => r.path.endsWith('/me/'))
            .length;
        expect(after - before, 2);
      },
    );
  });

  group('When the table is gone (404)', () {
    test('a refresh that gets 404 marks the table closed', () async {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);
      await setup.readGameState();
      _failGets(setup, '/me/', 404);

      await setup.container.read(gameProvider(_gameId).notifier).refreshState();

      expect(setup.currentState.tableClosed, isTrue);
    });

    test('a refresh that fails otherwise does not', () async {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);
      await setup.readGameState();
      _failGets(setup, '/me/', 500);

      await setup.container.read(gameProvider(_gameId).notifier).refreshState();

      expect(setup.currentState.tableClosed, isFalse);
    });
  });
}
