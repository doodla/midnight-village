import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/night_state.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import '../../../helpers/game_events.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

const _gameId = 'test-game-id';

Map<String, dynamic> _peekPlayer({int wave = 2, String target = 'Bob'}) => {
  'wave': wave,
  'action_type': 'peek_player',
  'revealed_info': {'target_name': target, 'role': 'werewolf'},
};

Map<String, dynamic> _swapWithPlayer({int wave = 2}) => {
  'wave': wave,
  'action_type': 'swap_with_player',
  'revealed_info': {'target_name': 'Charlie', 'new_role': 'villager'},
};

GameTestSetup _setup(Map<String, dynamic> me) =>
    GameTestSetup.create(gameMeJson: me);

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  group('A night result missed while the phone was away', () {
    test(
      'a closed window\'s result from /me/ is put on screen in discussion',
      () async {
        final setup = _setup(
          GameMeJsonBuilder().inPhase('discussion').withNightResults([
            _peekPlayer(),
          ]).build(),
        );
        addTearDown(setup.dispose);

        final state = await setup.readGameState();

        expect(state.lastActionResult, isNotNull);
        expect(state.lastActionResult!.wave, 2);
        expect(
          state.lastActionResult!.revealedInfo['action_type'],
          'peek_player',
        );
        expect(state.lastActionResult!.revealedInfo['target_name'], 'Bob');
        expect(state.nightResults, hasLength(1));
        expect(state.shownNightResults, hasLength(1));
      },
    );

    test('absent night_results is treated as none', () async {
      final setup = _setup(GameMeJsonBuilder().inPhase('discussion').build());
      addTearDown(setup.dispose);

      final state = await setup.readGameState();

      expect(state.nightResults, isEmpty);
      expect(state.lastActionResult, isNull);
    });

    test('a malformed entry is skipped, the rest still shown', () async {
      final setup = _setup(
        GameMeJsonBuilder().inPhase('discussion').withNightResults([
          {'wave': 'x'},
          _peekPlayer(),
        ]).build(),
      );
      addTearDown(setup.dispose);

      final state = await setup.readGameState();

      expect(state.nightResults, hasLength(1));
      expect(state.lastActionResult, isNotNull);
    });

    test('is shown from /me/ in the vote too, not in the results', () async {
      final voting = _setup(
        GameMeJsonBuilder().inPhase('voting').withNightResults([
          _peekPlayer(),
        ]).build(),
      );
      addTearDown(voting.dispose);
      expect((await voting.readGameState()).lastActionResult, isNotNull);

      final results = _setup(
        GameMeJsonBuilder().inPhase('results').withNightResults([
          _peekPlayer(),
        ]).build(),
      );
      addTearDown(results.dispose);
      results.registerResults(resultsJson: {'players': <dynamic>[]});
      final state = await results.readGameState();
      expect(state.lastActionResult, isNull);
      // Kept for the later "My night" feature.
      expect(state.nightResults, hasLength(1));
    });

    test(
      'at night only a window that has closed is shown (wave 1 while wave 2 '
      'is open); the open window\'s result is never shown from /me/',
      () async {
        final setup = _setup(
          GameMeJsonBuilder().withWave(2).withNightResults([
            _peekPlayer(wave: 1),
            _swapWithPlayer(wave: 2), // the server should not send this yet
          ]).build(),
        );
        addTearDown(setup.dispose);

        final state = await setup.readGameState();

        expect(state.lastActionResult!.wave, 1);
        expect(state.pendingNightResults, isEmpty);
        expect(state.nightSubView, NightSubView.actionResult);
      },
    );

    test('nothing is shown at night while no window has closed', () async {
      final setup = _setup(
        GameMeJsonBuilder().withWave(1).withNightResults([
          _peekPlayer(wave: 1),
        ]).build(),
      );
      addTearDown(setup.dispose);

      final state = await setup.readGameState();

      expect(state.lastActionResult, isNull);
      expect(state.nightSubView, NightSubView.waiting);
    });

    test(
      'is not shown again when the same result then arrives on the socket',
      () async {
        final setup = _setup(
          GameMeJsonBuilder().inPhase('discussion').withNightResults([
            _peekPlayer(),
          ]).build(),
        );
        addTearDown(setup.dispose);
        await setup.readGameState();

        // The player reads it and continues.
        setup.container
            .read(gameProvider(_gameId).notifier)
            .dismissNightResult();
        expect(setup.currentState.lastActionResult, isNull);

        setup.ws.addServerEvent(
          GameEvents.actionResult(
            wave: 2,
            actionType: 'peek_player',
            revealedInfo: {'target_name': 'Bob', 'role': 'werewolf'},
          ),
        );

        expect(setup.currentState.lastActionResult, isNull);
      },
    );

    test(
      'is not shown again when /me/ is fetched after the socket delivered it',
      () async {
        final me = GameMeJsonBuilder().withWave(2).build();
        final setup = _setup(me);
        addTearDown(setup.dispose);
        await setup.readGameState();

        setup.ws.addServerEvent(
          GameEvents.actionResult(
            wave: 1,
            actionType: 'peek_player',
            revealedInfo: {'target_name': 'Bob', 'role': 'werewolf'},
          ),
        );
        final notifier = setup.container.read(gameProvider(_gameId).notifier);
        notifier.dismissNightResult();
        expect(setup.currentState.lastActionResult, isNull);

        // The phone reconnects; the server now lists that closed window.
        setup.registerGameMe(
          GameMeJsonBuilder().withWave(2).withNightResults([
            _peekPlayer(wave: 1),
          ]).build(),
        );
        await notifier.refreshState();

        expect(setup.currentState.lastActionResult, isNull);
        expect(setup.currentState.nightResults, hasLength(1));
      },
    );

    test(
      'refreshing again does not show a shown result a second time',
      () async {
        final setup = _setup(
          GameMeJsonBuilder().inPhase('discussion').withNightResults([
            _peekPlayer(),
          ]).build(),
        );
        addTearDown(setup.dispose);
        await setup.readGameState();
        final notifier = setup.container.read(gameProvider(_gameId).notifier);

        notifier.dismissNightResult();
        await notifier.refreshState();

        expect(setup.currentState.lastActionResult, isNull);
      },
    );

    test('a refresh keeps the result the player is still reading', () async {
      final setup = _setup(
        GameMeJsonBuilder().inPhase('discussion').withNightResults([
          _peekPlayer(),
        ]).build(),
      );
      addTearDown(setup.dispose);
      await setup.readGameState();

      await setup.container.read(gameProvider(_gameId).notifier).refreshState();

      expect(setup.currentState.lastActionResult, isNotNull);
    });

    test('a window that closed while the socket was down is shown after the '
        'reconnect refresh', () async {
      final setup = _setup(GameMeJsonBuilder().withWave(1).build());
      addTearDown(setup.dispose);
      await setup.readGameState();
      expect(setup.currentState.lastActionResult, isNull);

      setup.registerGameMe(
        GameMeJsonBuilder().withWave(2).withNightResults([
          _peekPlayer(wave: 1),
        ]).build(),
      );
      await setup.container.read(gameProvider(_gameId).notifier).refreshState();

      expect(setup.currentState.lastActionResult!.wave, 1);
      expect(setup.currentState.nightSubView, NightSubView.actionResult);
    });

    test(
      'several results from one fetch queue up and come one after another',
      () async {
        final setup = _setup(
          GameMeJsonBuilder().inPhase('discussion').withNightResults([
            _peekPlayer(wave: 1),
            _swapWithPlayer(wave: 2),
          ]).build(),
        );
        addTearDown(setup.dispose);
        final state = await setup.readGameState();
        final notifier = setup.container.read(gameProvider(_gameId).notifier);

        expect(state.lastActionResult!.wave, 1);
        expect(state.pendingNightResults, hasLength(1));

        notifier.dismissNightResult();
        expect(setup.currentState.lastActionResult!.wave, 2);
        expect(setup.currentState.pendingNightResults, isEmpty);

        notifier.dismissNightResult();
        expect(setup.currentState.lastActionResult, isNull);
      },
    );

    test(
      'a result already on screen is not replaced; the missed one waits',
      () async {
        final setup = _setup(GameMeJsonBuilder().withWave(2).build());
        addTearDown(setup.dispose);
        await setup.readGameState();
        // Window 2's own result arrives live and is on screen.
        setup.ws.addServerEvent(
          GameEvents.actionResult(
            wave: 2,
            actionType: 'swap_with_player',
            revealedInfo: {'target_name': 'Charlie', 'new_role': 'villager'},
          ),
        );
        setup.registerGameMe(
          GameMeJsonBuilder().inPhase('discussion').withNightResults([
            _peekPlayer(wave: 1),
            _swapWithPlayer(wave: 2),
          ]).build(),
        );

        await setup.container
            .read(gameProvider(_gameId).notifier)
            .refreshState();

        expect(setup.currentState.lastActionResult!.wave, 2);
        expect(setup.currentState.pendingNightResults.single.wave, 1);
      },
    );

    test('the phase change after the night drops the queue', () async {
      final setup = _setup(
        GameMeJsonBuilder().inPhase('discussion').withNightResults([
          _peekPlayer(wave: 1),
          _swapWithPlayer(wave: 2),
        ]).build(),
      );
      addTearDown(setup.dispose);
      await setup.readGameState();

      setup.ws.addServerEvent(GameEvents.phaseChange(phase: 'voting'));
      await _pump();

      expect(setup.currentState.lastActionResult, isNull);
      expect(setup.currentState.pendingNightResults, isEmpty);
    });
  });

  group('parseNightResults', () {
    test('reads the action_result event shape and injects action_type', () {
      final results = parseNightResults([_peekPlayer(wave: 1)]);

      expect(results.single.wave, 1);
      expect(results.single.revealedInfo['action_type'], 'peek_player');
      expect(results.single.revealedInfo['role'], 'werewolf');
    });

    test('null and non-lists are empty', () {
      expect(parseNightResults(null), isEmpty);
      expect(parseNightResults('nope'), isEmpty);
    });
  });
}
