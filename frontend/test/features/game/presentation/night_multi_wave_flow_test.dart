import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/night_action_prompt.dart';
import 'package:midnight_village/features/game/presentation/night_result_view.dart';
import 'package:midnight_village/features/game/presentation/seer_choice_view.dart';

import '../../../helpers/game_events.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

/// Lets a real (mock) HTTP submit finish, then settles the phase animation.
Future<void> _settleSubmit(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 401));
  // The state change lands during the pump above; the cross-fade then runs.
  await tester.pump(const Duration(milliseconds: 401));
}

void main() {
  group('Night two-window progression', () {
    testWidgets(
      'window 1 look then follow-up, window 2 submit then wait, results together, discussion',
      (tester) async {
        // A Doppelganger who copies the Seer: look (window 1), follow-up as
        // Seer (window 1), then she waits through window 2 like everyone else.
        final setup = await tester.pumpGameFlow(
          gameMeJson: GameMeJsonBuilder().withRole('doppelganger').build(),
        );
        addTearDown(setup.dispose);
        setup.registerActionSubmit();

        // --- Initial state: night waiting ---
        expect(find.text('The village sleeps\u2026'), findsOneWidget);

        // --- Window 1 opens and she is prompted for the look ---
        setup.ws.addServerEvent(GameEvents.waveStart(wave: 1));
        setup.ws.addServerEvent(
          GameEvents.actionPrompt(
            role: 'Doppelganger',
            actionTypes: ['peek_player'],
            validTargets: {
              'player_ids': [2, 3],
            },
            wave: 1,
          ),
        );
        await tester.pump();
        expect(find.byType(NightActionPrompt), findsOneWidget);

        // --- Her look result arrives at once, then the follow-up prompt ---
        setup.ws.addServerEvent(
          GameEvents.actionResult(
            wave: 1,
            revealedInfo: {
              'target_name': 'Bob',
              'role': 'seer',
              'copied_role': 'Seer',
            },
            actionType: 'peek_player',
          ),
        );
        setup.ws.addServerEvent(
          GameEvents.actionPrompt(
            role: 'Seer',
            actionTypes: ['peek_player', 'peek_center', 'skip'],
            validTargets: {
              'player_ids': [2, 3],
              'center_indices': [0, 1, 2],
            },
            wave: 1,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 401));

        // The result is readable: not replaced by the follow-up choice.
        expect(find.byType(NightResultView), findsOneWidget);
        expect(find.byType(SeerChoiceView), findsNothing);
        expect(find.text('Continue'), findsOneWidget);

        // --- Continue goes to the Seer choice, with a Skip for "do nothing" ---
        await tester.tap(find.text('Continue'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 401));
        expect(find.byType(SeerChoiceView), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);

        // --- Tap Skip: the server takes `skip`, she now just waits ---
        await tester.tap(find.text('Skip'));
        await _settleSubmit(tester);
        expect(find.byType(SeerChoiceView), findsNothing);
        expect(find.text('The village sleeps\u2026'), findsOneWidget);
        expect(
          setup.http.requests.last.path,
          '/onuw/games/test-game-id/action/',
        );
        expect(setup.http.requests.last.data, {
          'action_type': 'skip',
          'targets': <String, dynamic>{},
        });

        // --- Window 1 closes (her follow-up result), window 2 opens ---
        setup.ws.addServerEvent(
          GameEvents.actionResult(
            wave: 1,
            revealedInfo: {},
            actionType: 'skip',
          ),
        );
        setup.ws.addServerEvent(GameEvents.waveComplete(wave: 1));
        setup.ws.addServerEvent(GameEvents.waveStart(wave: 2));
        // She has nothing to do in window 2.
        setup.ws.addServerEvent(GameEvents.waveWaiting(wave: 2));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 401));

        // Her last result is still on screen: window 2 did not wipe it.
        expect(find.byType(NightResultView), findsOneWidget);
        expect(find.text('You did nothing.'), findsOneWidget);

        // --- Window 2 closes; the night ends and the discussion opens ---
        setup.ws.addServerEvent(GameEvents.waveComplete(wave: 2));
        setup.ws.addServerEvent(GameEvents.phaseChange(phase: 'discussion'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 401));

        // The result is shown first, with a way on to the discussion.
        expect(find.text('Roles in this game'), findsNothing);
        expect(find.text('Continue to discussion'), findsOneWidget);

        await tester.tap(find.text('Continue to discussion'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 401));
        expect(find.text('Roles in this game'), findsOneWidget);
      },
    );

    testWidgets(
      'submit then wait: no result until the window closes, results arrive together',
      (tester) async {
        final setup = await tester.pumpGameFlow(
          gameMeJson: GameMeJsonBuilder().withRole('robber').build(),
        );
        addTearDown(setup.dispose);
        setup.registerActionSubmit();

        // Window 2 opens; the Robber may rob someone or skip.
        setup.ws.addServerEvent(GameEvents.waveStart(wave: 2));
        setup.ws.addServerEvent(
          GameEvents.actionPrompt(
            role: 'Robber',
            actionTypes: ['swap_with_player', 'skip'],
            validTargets: {
              'player_ids': [2, 3],
            },
            wave: 2,
          ),
        );
        await tester.pump();

        // One real action plus skip is NOT a choice screen: straight to the
        // action prompt, with the "do nothing" control.
        expect(find.byType(SeerChoiceView), findsNothing);
        expect(find.byType(NightActionPrompt), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);

        // Pick Bob and confirm.
        await tester.tap(find.text('Bob'));
        await tester.pump();
        await tester.tap(find.text('Confirm'));
        await _settleSubmit(tester);

        // Submitted: she waits. Nothing is revealed while others still choose.
        expect(find.byType(NightActionPrompt), findsNothing);
        expect(find.byType(NightResultView), findsNothing);
        expect(find.text('The village sleeps\u2026'), findsOneWidget);
        expect(setup.http.requests.last.data, {
          'action_type': 'swap_with_player',
          'targets': {'player_id': 2},
        });

        // The window closes: result, wave_complete, then the discussion.
        setup.ws.addServerEvent(
          GameEvents.actionResult(
            wave: 2,
            revealedInfo: {'target_name': 'Bob', 'new_role': 'villager'},
            actionType: 'swap_with_player',
          ),
        );
        setup.ws.addServerEvent(GameEvents.waveComplete(wave: 2));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 401));
        expect(find.byType(NightResultView), findsOneWidget);
        expect(find.byType(NightActionPrompt), findsNothing);
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
