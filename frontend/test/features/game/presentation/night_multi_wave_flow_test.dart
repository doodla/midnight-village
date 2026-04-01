import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/night_action_prompt.dart';
import 'package:midnight_village/features/game/presentation/seer_choice_view.dart';

import '../../../helpers/game_events.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

void main() {
  group('Night multi-wave progression', () {
    testWidgets(
      'wave 1 action → wave 2 action → phase transition to discussion',
      (tester) async {
        final setup = await tester.pumpGameFlow(
          gameMeJson: GameMeJsonBuilder().withRole('seer').build(),
        );
        addTearDown(setup.dispose);
        setup.registerActionSubmit();

        // --- Initial state: night waiting ---
        expect(find.text('The village sleeps\u2026'), findsOneWidget);

        // --- Wave 1 starts ---
        setup.ws.addServerEvent(GameEvents.waveStart(wave: 1));
        await tester.pump();

        // Still waiting — no prompt yet.
        expect(find.text('The village sleeps\u2026'), findsOneWidget);

        // --- Action prompt for Seer (wave 1, multi-action) ---
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
            wave: 1,
          ),
        );
        await tester.pump();

        // SeerChoiceView shown with two options.
        expect(find.byType(SeerChoiceView), findsOneWidget);
        expect(find.text("Look at a player's card"), findsOneWidget);
        expect(find.text('Look at two center cards'), findsOneWidget);

        // --- Tap "Look at a player's card" ---
        await tester.tap(find.text("Look at a player's card"));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // NightActionPrompt shown for peek_player.
        expect(find.byType(NightActionPrompt), findsOneWidget);

        // --- Action result (wave 1, peek_player, reveals Werewolf) ---
        setup.ws.addServerEvent(
          GameEvents.actionResult(
            wave: 1,
            revealedInfo: {
              'action_type': 'peek_player',
              'target_player_id': 2,
              'role': 'Werewolf',
            },
            actionType: 'peek_player',
          ),
        );
        await tester.pump();

        // Result view shows the revealed role.
        expect(find.textContaining('Werewolf'), findsAtLeastNWidgets(1));

        // --- Wave 1 complete → back to waiting ---
        setup.ws.addServerEvent(GameEvents.waveComplete(wave: 1));
        await tester.pump();

        expect(find.text('The village sleeps\u2026'), findsOneWidget);

        // --- Wave 2 starts ---
        setup.ws.addServerEvent(GameEvents.waveStart(wave: 2));
        await tester.pump();

        // Still waiting.
        expect(find.text('The village sleeps\u2026'), findsOneWidget);

        // --- Action prompt for Robber (wave 2, single action) ---
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

        // Single action → NightActionPrompt shown directly (no choice screen).
        expect(find.byType(NightActionPrompt), findsOneWidget);
        expect(find.text("Look at a player's card"), findsNothing);

        // --- Action result (wave 2, swap_with_player) ---
        setup.ws.addServerEvent(
          GameEvents.actionResult(
            wave: 2,
            revealedInfo: {
              'action_type': 'swap_with_player',
              'target_player_id': 3,
              'new_role': 'Villager',
            },
            actionType: 'swap_with_player',
          ),
        );
        await tester.pump();

        // Result view is shown (NightResultView replaced the action prompt).
        // Pump past the AnimatedSwitcher 400ms transition so the outgoing
        // NightActionPrompt is fully removed from the widget tree.
        await tester.pump(const Duration(milliseconds: 401));
        expect(find.byType(NightActionPrompt), findsNothing);

        // --- Wave 2 complete → back to waiting ---
        setup.ws.addServerEvent(GameEvents.waveComplete(wave: 2));
        await tester.pump();

        expect(find.text('The village sleeps\u2026'), findsOneWidget);

        // --- Phase change to discussion ---
        setup.ws.addServerEvent(GameEvents.phaseChange(phase: 'discussion'));
        await tester.pump();

        // AnimatedSwitcher 400ms transition clears the outgoing NightWaitingView.
        await tester.pump(const Duration(milliseconds: 401));

        // Night waiting text is gone; discussion view is present.
        expect(find.text('The village sleeps\u2026'), findsNothing);
        expect(find.text('Roles in this game'), findsOneWidget);
      },
    );

    testWidgets('wave_waiting skips wave for non-acting player', (
      tester,
    ) async {
      final setup = await tester.pumpGameFlow();
      addTearDown(setup.dispose);

      // --- Initial state: night waiting ---
      expect(find.text('The village sleeps\u2026'), findsOneWidget);

      // --- Wave 1 starts ---
      setup.ws.addServerEvent(GameEvents.waveStart(wave: 1));
      await tester.pump();

      expect(find.text('The village sleeps\u2026'), findsOneWidget);

      // --- wave_waiting: no action for this player in wave 1 ---
      setup.ws.addServerEvent(GameEvents.waveWaiting(wave: 1));
      await tester.pump();

      // No action prompt shown; still waiting.
      expect(find.text('The village sleeps\u2026'), findsOneWidget);
      expect(find.byType(NightActionPrompt), findsNothing);
      expect(find.text("Look at a player's card"), findsNothing);

      // --- Wave 1 complete ---
      setup.ws.addServerEvent(GameEvents.waveComplete(wave: 1));
      await tester.pump();

      expect(find.text('The village sleeps\u2026'), findsOneWidget);

      // --- Wave 2 starts ---
      setup.ws.addServerEvent(GameEvents.waveStart(wave: 2));
      await tester.pump();

      expect(find.text('The village sleeps\u2026'), findsOneWidget);

      // --- Action prompt for Seer in wave 2 ---
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

      // SeerChoiceView shown for wave 2 action.
      expect(find.byType(SeerChoiceView), findsOneWidget);
      expect(find.text("Look at a player's card"), findsOneWidget);
      expect(find.text('Look at two center cards'), findsOneWidget);
    });

    testWidgets(
      'rapid wave progression (no action in any wave) stays waiting throughout',
      (tester) async {
        final setup = await tester.pumpGameFlow();
        addTearDown(setup.dispose);

        // --- Initial state: night waiting ---
        expect(find.text('The village sleeps\u2026'), findsOneWidget);

        // --- Inject all wave events rapidly ---
        setup.ws.addServerEvent(GameEvents.waveStart(wave: 1));
        setup.ws.addServerEvent(GameEvents.waveWaiting(wave: 1));
        setup.ws.addServerEvent(GameEvents.waveComplete(wave: 1));
        setup.ws.addServerEvent(GameEvents.waveStart(wave: 2));
        setup.ws.addServerEvent(GameEvents.waveWaiting(wave: 2));
        setup.ws.addServerEvent(GameEvents.waveComplete(wave: 2));
        await tester.pump();

        // Still in night waiting throughout; no action prompts shown.
        expect(find.text('The village sleeps\u2026'), findsOneWidget);
        expect(find.byType(NightActionPrompt), findsNothing);
        expect(find.byType(SeerChoiceView), findsNothing);

        // --- Phase change to discussion ---
        setup.ws.addServerEvent(GameEvents.phaseChange(phase: 'discussion'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 401));

        // Night waiting text is gone; discussion view is present.
        expect(find.text('The village sleeps\u2026'), findsNothing);
        expect(find.text('Roles in this game'), findsOneWidget);
      },
    );
  });
}
