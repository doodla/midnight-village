import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import '../../../helpers/game_events.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

void main() {
  group('Game state recovery', () {
    test('notifier re-fetches state via refreshState()', () async {
      final setup = GameTestSetup.create(
        gameMeJson: GameMeJsonBuilder().inPhase('night').build(),
      );
      addTearDown(setup.dispose);

      // Read initial state — night phase, window 2.
      final initial = await setup.readGameState();
      expect(initial.phase, 'night');
      expect(initial.currentWave, 2);

      // Update HTTP mock to return voting phase before calling refreshState.
      setup.registerGameMe(
        GameMeJsonBuilder().inPhase('voting').hasVoted(false).build(),
      );

      final notifier = setup.container.read(
        gameProvider('test-game-id').notifier,
      );
      await notifier.refreshState();
      await Future<void>.delayed(Duration.zero);

      final updated = setup.currentState;
      expect(updated.phase, 'voting');
    });

    test('refreshState recovers vote progress in voting phase', () async {
      final setup = GameTestSetup.create(
        gameMeJson: GameMeJsonBuilder().inPhase('night').build(),
      );
      addTearDown(setup.dispose);

      await setup.readGameState();

      // Update HTTP mock to return voting phase with some players having voted.
      setup.registerGameMe(
        GameMeJsonBuilder()
            .inPhase('voting')
            .hasVoted(false)
            .withPlayersHavingVoted({2: true, 3: true})
            .build(),
      );

      final notifier = setup.container.read(
        gameProvider('test-game-id').notifier,
      );
      await notifier.refreshState();
      await Future<void>.delayed(Duration.zero);

      final updated = setup.currentState;
      expect(updated.phase, 'voting');
      // voteProgress is hydrated from server-provided player has_voted flags.
      expect(updated.voteProgress.playerVoted[2], isTrue);
      expect(updated.voteProgress.playerVoted[3], isTrue);
      expect(updated.voteProgress.playerVoted[1], isFalse);
      // Current player (Alice, player_id 1) has not voted.
      expect(updated.voteProgress.currentPlayerVoted, isFalse);
    });

    test(
      'refreshState fetches results when reconnecting to results phase',
      () async {
        final setup = GameTestSetup.create(
          gameMeJson: GameMeJsonBuilder().inPhase('night').build(),
        );
        addTearDown(setup.dispose);

        await setup.readGameState();

        // Update HTTP mock to return results phase.
        setup.registerGameMe(GameMeJsonBuilder().inPhase('results').build());

        // Register results endpoint BEFORE calling refreshState.
        setup
          ..registerResults()
          ..registerTable();

        final notifier = setup.container.read(
          gameProvider('test-game-id').notifier,
        );
        await notifier.refreshState();
        await Future<void>.delayed(Duration.zero);

        final updated = setup.currentState;
        expect(updated.phase, 'results');
        expect(updated.results, isNotNull);
      },
    );
  });

  group('WebSocket event recovery after reconnect', () {
    testWidgets('events received after reconnect are processed normally', (
      tester,
    ) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().inPhase('night').build(),
      );
      addTearDown(setup.dispose);

      // Verify initial night-waiting state.
      expect(find.text('The village sleeps\u2026'), findsOneWidget);

      // Inject wave_start — proves WS events are still processed.
      setup.ws.addServerEvent(GameEvents.waveStart(wave: 2));
      await tester.pump();

      // Still waiting — no prompt yet.
      expect(find.text('The village sleeps\u2026'), findsOneWidget);

      // Inject action_prompt — proves state updates correctly.
      setup.ws.addServerEvent(GameEvents.actionPrompt('seer'));
      await tester.pump();

      // Seer choice view shown — confirms WS event processing still works.
      expect(find.text("Look at a player's card"), findsOneWidget);
      expect(find.text('Look at two center cards'), findsOneWidget);
    });
  });
}
