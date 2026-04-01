import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/center_cards.dart';
import 'package:midnight_village/design_system/components/game/night_action_prompt.dart';

import '../../../helpers/game_events.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

void main() {
  group('Night action flow — Seer peek player', () {
    testWidgets(
      'wave_start → action_prompt → select peek_player → submit → action_result → wave_complete',
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
        setup.ws.addServerEvent(
          GameEvents.actionPrompt(
            role: 'Seer',
            actionTypes: ['peek_player', 'peek_center'],
            validTargets: {
              'peek_player': {
                'players': [2, 3],
              },
              'peek_center': {
                'card_indices': [0, 1, 2],
              },
            },
            wave: 2,
          ),
        );
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

        // --- Step 5: Server sends action_result ---
        setup.ws.addServerEvent(
          GameEvents.actionResult(
            wave: 2,
            revealedInfo: {
              'action_type': 'peek_player',
              'target_player_id': 2,
              'role': 'Werewolf',
            },
            actionType: 'peek_player',
          ),
        );
        await tester.pump();

        // Night result view shows the revealed role.
        expect(find.textContaining('Werewolf'), findsAtLeastNWidgets(1));

        // --- Step 6: Server sends wave_complete ---
        setup.ws.addServerEvent(GameEvents.waveComplete(wave: 2));
        await tester.pump();

        // Back to waiting.
        expect(find.text('The village sleeps\u2026'), findsOneWidget);
      },
    );

    testWidgets(
      'wave_start → action_prompt → select peek_center → CenterCards shown',
      (tester) async {
        final setup = await tester.pumpGameFlow();
        addTearDown(setup.dispose);

        // Server sends wave and action prompt.
        setup.ws.addServerEvent(GameEvents.waveStart(wave: 2));
        setup.ws.addServerEvent(
          GameEvents.actionPrompt(
            role: 'Seer',
            actionTypes: ['peek_player', 'peek_center'],
            validTargets: {
              'peek_player': {
                'players': [2, 3],
              },
              'peek_center': {
                'card_indices': [0, 1, 2],
              },
            },
            wave: 2,
          ),
        );
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
          gameMeJson: GameMeJsonBuilder().withRole('robber').build(),
        );
        addTearDown(setup.dispose);

        // Server sends action prompt with single action type.
        setup.ws.addServerEvent(
          GameEvents.actionPrompt(
            role: 'Robber',
            actionTypes: ['swap_with_player'],
            validTargets: {
              'swap_with_player': {
                'players': [1, 3],
              },
            },
            wave: 2,
          ),
        );
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
