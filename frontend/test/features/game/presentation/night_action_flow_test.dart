import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/center_cards.dart';
import 'package:midnight_village/design_system/components/game/night_action_prompt.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import '../../../helpers/game_events.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

void main() {
  group('Night action flow — Seer peek player', () {
    testWidgets(
      'wave_start → action_prompt → peek_player → submit → the window closes',
      (tester) async {
        // Start in night phase, waiting (no action prompt yet).
        final setup = await tester.pumpGameFlow();
        addTearDown(setup.dispose);

        // --- Step 1: Verify initial state is night waiting ---
        expect(find.text('The village sleeps\u2026'), findsOneWidget);

        // --- Step 2: Server sends wave_start for wave 2 ---
        setup.ws.addServerEvent(GameEvents.waveStart(wave: 2));
        await tester.pump();

        // Still waiting — no prompt yet.
        expect(find.text('The village sleeps\u2026'), findsOneWidget);

        // --- Step 3: Server sends action_prompt for Seer ---
        setup.ws.addServerEvent(GameEvents.actionPrompt('seer'));
        await tester.pump();

        // Seer choice view shown with two options.
        expect(find.text("Look at a player's card"), findsOneWidget);
        expect(find.text('Look at two center cards'), findsOneWidget);

        // --- Step 4: Player selects peek_player ---
        await tester.tap(find.text("Look at a player's card"));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // NightActionPrompt should now be shown for peek_player.
        expect(find.byType(NightActionPrompt), findsOneWidget);

        // --- Step 5: The player looks at Bob; nothing comes back yet ---
        setup.registerActionSubmit();
        await tester.runAsync(
          () =>
              ProviderScope.containerOf(
                tester.element(find.byType(NightActionPrompt)),
              ).read(gameProvider('test-game-id').notifier).submitAction(
                'peek_player',
                {'player_id': 2},
              ),
        );
        await tester.pump();
        expect(find.text('The village sleeps\u2026'), findsOneWidget);

        // --- Step 6: The window closes: the result, then wave_complete ---
        setup.ws
          ..addServerEvent(
            GameEvents.actionResult(
              'peek_player',
              info: {'target_name': 'Bob', 'role': 'werewolf'},
            ),
          )
          ..addServerEvent(GameEvents.waveComplete());
        await tester.pump();
        // Past the screen's 400 ms transition.
        await tester.pump(const Duration(milliseconds: 401));

        // The result stays on screen: it is what the player learned.
        expect(find.textContaining('Werewolf'), findsAtLeastNWidgets(1));
        expect(find.text('The village sleeps\u2026'), findsNothing);
      },
    );

    testWidgets(
      'wave_start → action_prompt → select peek_center → CenterCards shown',
      (tester) async {
        final setup = await tester.pumpGameFlow();
        addTearDown(setup.dispose);

        // Server sends wave and action prompt.
        setup.ws.addServerEvent(GameEvents.waveStart(wave: 2));
        setup.ws.addServerEvent(GameEvents.actionPrompt('seer'));
        await tester.pump();

        // Select peek_center.
        await tester.tap(find.text('Look at two center cards'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // CenterCards widget should be shown for selecting center cards.
        expect(find.byType(CenterCards), findsOneWidget);
      },
    );
  });

  group('Night action flow — Robber swap', () {
    testWidgets(
      'single-action prompt goes directly to NightActionPrompt (no choice screen)',
      (tester) async {
        final setup = await tester.pumpGameFlow(
          gameMeJson: GameMeJsonBuilder().withRole('Robber').build(),
        );
        addTearDown(setup.dispose);

        // Server sends action prompt with single action type.
        setup.ws.addServerEvent(GameEvents.actionPrompt('robber'));
        await tester.pump();

        // Should go directly to NightActionPrompt, not SeerChoiceView.
        expect(find.byType(NightActionPrompt), findsOneWidget);
        expect(find.text("Look at a player's card"), findsNothing);
      },
    );
  });

  group('Night action flow — phase transition', () {
    testWidgets('phase_change to discussion transitions out of night', (
      tester,
    ) async {
      final setup = await tester.pumpGameFlow();
      addTearDown(setup.dispose);

      // Verify starting in night.
      expect(find.text('The village sleeps\u2026'), findsOneWidget);

      // Server transitions to discussion.
      setup.ws.addServerEvent(GameEvents.phaseChange(phase: 'discussion'));
      await tester.pump();

      // The AnimatedSwitcher in GameContainerScreen uses a 400ms transition.
      // Advance past it so the outgoing NightWaitingView is fully removed.
      await tester.pump(const Duration(milliseconds: 401));

      // Night waiting text should be gone.
      expect(find.text('The village sleeps\u2026'), findsNothing);
    });
  });
}
