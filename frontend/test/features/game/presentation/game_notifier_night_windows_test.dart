import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/night_state.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import '../../../helpers/contract/server_json.dart';
import '../../../helpers/game_events.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

const _gameId = 'test-game-id';

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  group('ActionPrompt choices (what the server offered)', () {
    test('Seer with skip needs a choice, skip is separate', () {
      final prompt = ActionPrompt.fromJson(serverPrompt('seer'));
      expect(prompt.needsActionChoice, isTrue);
      expect(prompt.canSkip, isTrue);
      expect(prompt.choiceTypes, ['peek_player', 'peek_center']);
      expect(prompt.primaryType, 'peek_player');
    });

    test('a lone action plus skip is not a choice', () {
      final prompt = ActionPrompt.fromJson(serverPrompt('robber'));
      expect(prompt.needsActionChoice, isFalse);
      expect(prompt.canSkip, isTrue);
      expect(prompt.primaryType, 'swap_with_player');
    });

    test('a prompt without skip offers no skip', () {
      final prompt = ActionPrompt.fromJson(serverPrompt('drunk'));
      expect(prompt.canSkip, isFalse);
      expect(prompt.needsActionChoice, isFalse);
    });
  });

  group('GameNotifier two-window night', () {
    test('Robber prompt with skip goes to the action prompt, not the Seer '
        'choice', () async {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);
      await setup.readGameState();

      setup.ws.addServerEvent(GameEvents.actionPrompt('robber'));
      await _pump();

      expect(setup.currentState.nightSubView, NightSubView.actionPrompt);
    });

    test('choosing a Seer action keeps skip on the prompt', () async {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);
      await setup.readGameState();

      setup.ws.addServerEvent(GameEvents.actionPrompt('seer'));
      await _pump();
      expect(setup.currentState.nightSubView, NightSubView.seerChoice);

      setup.container
          .read(gameProvider(_gameId).notifier)
          .selectSeerChoice('peek_center');

      final prompt = setup.currentState.actionPrompt!;
      expect(setup.currentState.nightSubView, NightSubView.actionPrompt);
      expect(prompt.actionTypes, ['peek_center', 'skip']);
      expect(prompt.canSkip, isTrue);
    });

    test('submitting shows waiting and no result arrives until the window '
        'closes', () async {
      final setup = GameTestSetup.create(
        gameMeJson: GameMeJsonBuilder()
            .withRole('Robber')
            .withPrompt('robber')
            .build(),
      );
      addTearDown(setup.dispose);
      setup.registerActionSubmit();
      await setup.readGameState();
      expect(setup.currentState.nightSubView, NightSubView.actionPrompt);

      await setup.container.read(gameProvider(_gameId).notifier).submitAction(
        'swap_with_player',
        {'player_id': 2},
      );

      expect(setup.http.requests.last.data, {
        'action_type': 'swap_with_player',
        'targets': {'player_id': 2},
      });
      expect(setup.currentState.nightSubView, NightSubView.waiting);
      expect(setup.currentState.actionPrompt, isNull);
      expect(setup.currentState.lastActionResult, isNull);

      // Window closes: every result arrives, then wave_complete, then the
      // discussion. The result must survive all three until dismissed.
      setup.ws.addServerEvent(
        GameEvents.actionResult(
          'swap_with_player',
          info: {'target_name': 'Bob', 'new_role': 'villager'},
        ),
      );
      setup.ws.addServerEvent(GameEvents.waveComplete(wave: 2));
      await _pump();
      expect(setup.currentState.nightSubView, NightSubView.actionResult);
      expect(setup.currentState.lastActionResult, isNotNull);

      setup.ws.addServerEvent(GameEvents.phaseChange(phase: 'discussion'));
      await _pump();
      expect(setup.currentState.phase, 'discussion');
      expect(
        setup.currentState.lastActionResult!.revealedInfo['new_role'],
        'villager',
      );

      setup.container.read(gameProvider(_gameId).notifier).dismissNightResult();
      expect(setup.currentState.lastActionResult, isNull);
    });

    test('skip submits the skip action with empty targets', () async {
      final setup = GameTestSetup.create(
        gameMeJson: GameMeJsonBuilder()
            .withRole('Seer')
            .withPrompt('seer')
            .build(),
      );
      addTearDown(setup.dispose);
      setup.registerActionSubmit();
      await setup.readGameState();

      await setup.container
          .read(gameProvider(_gameId).notifier)
          .submitAction('skip', {});

      expect(setup.http.requests.last.data, {
        'action_type': 'skip',
        'targets': <String, dynamic>{},
      });
      expect(setup.currentState.nightSubView, NightSubView.waiting);
    });

    test(
      'a rejected submission keeps the prompt so the player can retry',
      () async {
        final setup = GameTestSetup.create(
          gameMeJson: GameMeJsonBuilder()
              .withRole('Robber')
              .withPrompt('robber')
              .build(),
        );
        addTearDown(setup.dispose);
        await setup.readGameState();
        setup.registerActionSubmit(statusCode: 400);

        await expectLater(
          setup.container.read(gameProvider(_gameId).notifier).submitAction(
            'swap_with_player',
            {'player_id': 2},
          ),
          throwsA(anything),
        );

        expect(setup.currentState.nightSubView, NightSubView.actionPrompt);
        expect(setup.currentState.actionPrompt, isNotNull);
      },
    );

    test('a 409 (already submitted) also lands on waiting', () async {
      final setup = GameTestSetup.create(
        gameMeJson: GameMeJsonBuilder()
            .withRole('Robber')
            .withPrompt('robber')
            .build(),
      );
      addTearDown(setup.dispose);
      await setup.readGameState();
      setup.registerActionSubmit(statusCode: 409);

      await setup.container.read(gameProvider(_gameId).notifier).submitAction(
        'swap_with_player',
        {'player_id': 2},
      );

      expect(setup.currentState.nightSubView, NightSubView.waiting);
    });

    test('Doppelganger look result and follow-up prompt: result stays until '
        'Continue', () async {
      final setup = GameTestSetup.create(
        gameMeJson: GameMeJsonBuilder().withRole('Doppelganger').build(),
      );
      addTearDown(setup.dispose);
      await setup.readGameState();

      setup.ws.addServerEvent(
        GameEvents.actionResult(
          'doppelganger_look',
          wave: 1,
          info: {'target_name': 'Bob'},
        ),
      );
      setup.ws.addServerEvent(
        GameEvents.actionPrompt('doppelganger_followup', wave: 1),
      );
      await _pump();

      expect(setup.currentState.nightSubView, NightSubView.actionResult);
      expect(setup.currentState.actionPrompt!.roleActingAs, 'Seer');

      setup.container.read(gameProvider(_gameId).notifier).dismissNightResult();
      expect(setup.currentState.nightSubView, NightSubView.seerChoice);
      expect(setup.currentState.lastActionResult, isNull);
    });

    test('a follow-up prompt that arrives during the submit is not wiped '
        'by the late HTTP response', () async {
      final setup = GameTestSetup.create(
        gameMeJson: GameMeJsonBuilder()
            .withRole('Doppelganger')
            .withWave(1)
            .withPrompt('doppelganger')
            .build(),
      );
      addTearDown(setup.dispose);
      setup.registerActionSubmit();
      await setup.readGameState();
      final notifier = setup.container.read(gameProvider(_gameId).notifier);

      // The submit is in flight; the server's follow-up lands first.
      final submit = notifier.submitAction('peek_player', {'player_id': 2});
      setup.ws.addServerEvent(
        GameEvents.actionPrompt('doppelganger_followup', wave: 1),
      );
      await submit;
      await _pump();

      expect(setup.currentState.actionPrompt!.roleActingAs, 'Seer');
      expect(setup.currentState.nightSubView, NightSubView.seerChoice);
    });

    test('wave_start and wave_waiting keep a result the player has not '
        'dismissed (Doppelganger window 1 result, then window 2)', () async {
      final setup = GameTestSetup.create(
        gameMeJson: GameMeJsonBuilder().withRole('Doppelganger').build(),
      );
      addTearDown(setup.dispose);
      await setup.readGameState();

      setup.ws.addServerEvent(
        GameEvents.actionResult(
          'doppelganger_look',
          wave: 1,
          info: {
            'target_name': 'Bob',
            'role': 'villager',
            'copied_role': 'Villager',
          },
        ),
      );
      setup.ws.addServerEvent(GameEvents.waveComplete(wave: 1));
      setup.ws.addServerEvent(GameEvents.waveStart(wave: 2));
      setup.ws.addServerEvent(GameEvents.waveWaiting(wave: 2));
      await _pump();

      expect(setup.currentState.currentWave, 2);
      expect(setup.currentState.nightSubView, NightSubView.actionResult);
      expect(setup.currentState.lastActionResult, isNotNull);
    });

    test('phase_change to voting clears an undismissed night result', () async {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);
      await setup.readGameState();

      setup.ws.addServerEvent(
        GameEvents.actionResult(
          'insomniac',
          info: {'current_role': 'villager'},
        ),
      );
      setup.ws.addServerEvent(GameEvents.phaseChange(phase: 'discussion'));
      setup.ws.addServerEvent(GameEvents.phaseChange(phase: 'voting'));
      await _pump();

      expect(setup.currentState.phase, 'voting');
      expect(setup.currentState.lastActionResult, isNull);
    });

    test("Insomniac's result arrives in window 2 and carries the dealt-role "
        'info', () async {
      final setup = GameTestSetup.create(
        gameMeJson: GameMeJsonBuilder().withRole('Insomniac').build(),
      );
      addTearDown(setup.dispose);
      await setup.readGameState();

      setup.ws.addServerEvent(GameEvents.waveStart(wave: 2));
      setup.ws.addServerEvent(GameEvents.actionPrompt('insomniac'));
      await _pump();
      expect(setup.currentState.nightSubView, NightSubView.actionPrompt);

      setup.ws.addServerEvent(
        GameEvents.actionResult('insomniac', info: {'current_role': 'robber'}),
      );
      setup.ws.addServerEvent(GameEvents.waveComplete(wave: 2));
      await _pump();

      final result = setup.currentState.lastActionResult!;
      expect(result.wave, 2);
      expect(result.revealedInfo['action_type'], 'insomniac');
      expect(result.revealedInfo['current_role'], 'robber');
    });
  });

  group('GameNotifier resume and reconnection mid-night', () {
    test(
      'already submitted: no prompt from the server means waiting',
      () async {
        final setup = GameTestSetup.create(
          gameMeJson: GameMeJsonBuilder()
              .withRole('Seer', hasActed: true)
              .withWave(2)
              .build(),
        );
        addTearDown(setup.dispose);

        final state = await setup.readGameState();

        expect(state.currentWave, 2);
        expect(state.nightSubView, NightSubView.waiting);
      },
    );

    test(
      'not yet submitted in window 2: the prompt is restored, with skip',
      () async {
        final setup = GameTestSetup.create(
          gameMeJson: GameMeJsonBuilder()
              .withRole('Seer')
              .withWave(2)
              .withPrompt('seer')
              .build(),
        );
        addTearDown(setup.dispose);

        final state = await setup.readGameState();

        expect(state.nightSubView, NightSubView.seerChoice);
        expect(state.actionPrompt!.canSkip, isTrue);
      },
    );

    test('Robber prompt with skip is restored on the action screen', () async {
      final setup = GameTestSetup.create(
        gameMeJson: GameMeJsonBuilder()
            .withRole('Robber')
            .withWave(2)
            .withPrompt('robber')
            .build(),
      );
      addTearDown(setup.dispose);

      final state = await setup.readGameState();

      expect(state.nightSubView, NightSubView.actionPrompt);
    });

    test('refreshState keeps a result the player has not dismissed', () async {
      final setup = GameTestSetup.create(
        gameMeJson: GameMeJsonBuilder().withRole('Robber').withWave(2).build(),
      );
      addTearDown(setup.dispose);
      await setup.readGameState();

      setup.ws.addServerEvent(
        GameEvents.actionResult(
          'swap_with_player',
          info: {'target_name': 'Bob', 'new_role': 'villager'},
        ),
      );
      await _pump();

      // The server has moved on to discussion while the socket was down.
      setup.registerGameMe(
        GameMeJsonBuilder().inPhase('discussion').withRole('Robber').build(),
      );
      await setup.container.read(gameProvider(_gameId).notifier).refreshState();

      expect(setup.currentState.phase, 'discussion');
      expect(
        setup.currentState.lastActionResult!.revealedInfo['new_role'],
        'villager',
      );
    });
  });
}
