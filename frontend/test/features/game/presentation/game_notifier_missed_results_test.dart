import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/night_state.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import '../../../helpers/contract/server_json.dart';
import '../../../helpers/game_events.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

const _gameId = 'test-game-id';

/// The Seer looked at Bob, a Werewolf (window 2).
Map<String, dynamic> _peekPlayer() => serverNightResult(
  'peek_player',
  info: {'target_name': 'Bob', 'role': 'werewolf'},
);

/// The Doppelganger's look at Bob, a Seer, then her follow-up as the Seer:
/// the only player with more than one result, both in window 1.
Map<String, dynamic> _look() => serverNightResult(
  'doppelganger_look',
  wave: 1,
  info: {'target_name': 'Bob'},
);
Map<String, dynamic> _followUp() => serverNightResult('peek_center', wave: 1);

/// `/me/` for the Doppelganger.
GameMeJsonBuilder _doppelganger() =>
    GameMeJsonBuilder().withRole('Doppelganger');

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

    test('an empty night_results shows nothing', () async {
      final setup = _setup(GameMeJsonBuilder().inPhase('discussion').build());
      addTearDown(setup.dispose);

      final state = await setup.readGameState();

      expect(state.nightResults, isEmpty);
      expect(state.lastActionResult, isNull);
    });

    test('a malformed entry is skipped, the rest still shown', () async {
      final setup = _setup(GameMeJsonBuilder().inPhase('discussion').build());
      addTearDown(setup.dispose);
      final me = GameMeJsonBuilder().inPhase('discussion').withNightResults([
        _peekPlayer(),
      ]).build();
      (me['night_results'] as List).insert(0, {'wave': 'x'});
      setup.registerGet('/onuw/games/$_gameId/me/', me, offContract: true);

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
      results.registerResults();
      final state = await results.readGameState();
      expect(state.lastActionResult, isNull);
      // Kept for the later "My night" feature.
      expect(state.nightResults, hasLength(1));
    });

    test(
      'at night, window 1\'s results are shown once window 2 is open',
      () async {
        final setup = _setup(
          _doppelganger().withWave(2).withNightResults([_look()]).build(),
        );
        addTearDown(setup.dispose);

        final state = await setup.readGameState();

        expect(state.lastActionResult!.wave, 1);
        expect(state.pendingNightResults, isEmpty);
        expect(state.nightSubView, NightSubView.actionResult);
      },
    );

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

        setup.ws.addServerEvent(GameEvents.actionResultOf(_peekPlayer()));

        expect(setup.currentState.lastActionResult, isNull);
      },
    );

    test(
      'is not shown again when /me/ is fetched after the socket delivered it',
      () async {
        final setup = _setup(_doppelganger().withWave(1).build());
        addTearDown(setup.dispose);
        await setup.readGameState();

        setup.ws.addServerEvent(GameEvents.actionResultOf(_look()));
        final notifier = setup.container.read(gameProvider(_gameId).notifier);
        notifier.dismissNightResult();
        expect(setup.currentState.lastActionResult, isNull);

        // The phone reconnects; the server now lists that closed window.
        setup.registerGameMe(
          _doppelganger().withWave(2).withNightResults([_look()]).build(),
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
      final setup = _setup(_doppelganger().withWave(1).build());
      addTearDown(setup.dispose);
      await setup.readGameState();
      expect(setup.currentState.lastActionResult, isNull);

      setup.registerGameMe(
        _doppelganger().withWave(2).withNightResults([_look()]).build(),
      );
      await setup.container.read(gameProvider(_gameId).notifier).refreshState();

      expect(setup.currentState.lastActionResult!.wave, 1);
      expect(setup.currentState.nightSubView, NightSubView.actionResult);
    });

    test(
      'several results from one fetch queue up and come one after another',
      () async {
        final setup = _setup(
          _doppelganger().inPhase('discussion').withNightResults([
            _look(),
            _followUp(),
          ]).build(),
        );
        addTearDown(setup.dispose);
        final state = await setup.readGameState();
        final notifier = setup.container.read(gameProvider(_gameId).notifier);

        expect(
          state.lastActionResult!.revealedInfo['action_type'],
          'peek_player',
        );
        expect(state.pendingNightResults, hasLength(1));

        notifier.dismissNightResult();
        expect(
          setup.currentState.lastActionResult!.revealedInfo['action_type'],
          'peek_center',
        );
        expect(setup.currentState.pendingNightResults, isEmpty);

        notifier.dismissNightResult();
        expect(setup.currentState.lastActionResult, isNull);
      },
    );

    test(
      'a result already on screen is not replaced; the missed one waits',
      () async {
        final setup = _setup(_doppelganger().withWave(1).build());
        addTearDown(setup.dispose);
        await setup.readGameState();
        // Her follow-up's result arrives live as window 1 closes, on screen.
        setup.ws.addServerEvent(GameEvents.actionResultOf(_followUp()));
        // The look, sent while the socket was down, is in the next /me/.
        setup.registerGameMe(
          _doppelganger().withWave(2).withNightResults([
            _look(),
            _followUp(),
          ]).build(),
        );

        await setup.container
            .read(gameProvider(_gameId).notifier)
            .refreshState();

        expect(
          setup.currentState.lastActionResult!.revealedInfo['action_type'],
          'peek_center',
        );
        expect(
          setup
              .currentState
              .pendingNightResults
              .single
              .revealedInfo['action_type'],
          'peek_player',
        );
      },
    );

    test('the phase change after the night drops the queue', () async {
      final setup = _setup(
        _doppelganger().inPhase('discussion').withNightResults([
          _look(),
          _followUp(),
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
      final results = parseNightResults([_look()]);

      expect(results.single.wave, 1);
      expect(results.single.revealedInfo['action_type'], 'peek_player');
      expect(results.single.revealedInfo['copied_role'], 'Seer');
    });

    test('null and non-lists are empty', () {
      expect(parseNightResults(null), isEmpty);
      expect(parseNightResults('nope'), isEmpty);
    });
  });
}
