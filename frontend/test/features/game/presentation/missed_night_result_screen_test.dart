import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/presentation/game_container_screen.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';
import 'package:midnight_village/features/game/presentation/night_result_view.dart';

import '../../../helpers/game_events.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

Map<String, dynamic> _peekBob({int wave = 2}) => {
  'wave': wave,
  'action_type': 'peek_player',
  'revealed_info': {'target_name': 'Bob', 'role': 'werewolf'},
};

Map<String, dynamic> _swapWithCharlie({int wave = 2}) => {
  'wave': wave,
  'action_type': 'swap_with_player',
  'revealed_info': {'target_name': 'Charlie', 'new_role': 'villager'},
};

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('A missed night result on screen', () {
    testWidgets(
      'is shown before the talk when the app is opened in discussion',
      (tester) async {
        await tester.pumpGameFlow(
          gameMeJson: GameMeJsonBuilder()
              .inPhase('discussion')
              .withNightResults([_peekBob()])
              .build(),
        );

        expect(find.byType(NightResultView), findsOneWidget);
        expect(find.text('You looked at Bob\'s card'), findsOneWidget);
        expect(find.text('Continue to discussion'), findsOneWidget);
        expect(find.text('Roles in this game'), findsNothing);
      },
    );

    testWidgets('then the talk shows once the player continues', (
      tester,
    ) async {
      await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().inPhase('discussion').withNightResults([
          _peekBob(),
        ]).build(),
      );

      await tester.tap(find.text('Continue to discussion'));
      await _settle(tester);

      expect(find.byType(NightResultView), findsNothing);
      expect(find.text('Roles in this game'), findsOneWidget);
    });

    testWidgets('is not shown a second time when the socket delivers it too', (
      tester,
    ) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().inPhase('discussion').withNightResults([
          _peekBob(),
        ]).build(),
      );
      await tester.tap(find.text('Continue to discussion'));
      await _settle(tester);

      setup.ws.addServerEvent(
        GameEvents.actionResult(
          wave: 2,
          actionType: 'peek_player',
          revealedInfo: {'target_name': 'Bob', 'role': 'werewolf'},
        ),
      );
      await _settle(tester);

      expect(find.byType(NightResultView), findsNothing);
      expect(find.text('Roles in this game'), findsOneWidget);
    });

    testWidgets('is shown before the vote when the app is opened then', (
      tester,
    ) async {
      await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().inPhase('voting').withNightResults([
          _peekBob(),
        ]).build(),
      );

      expect(find.byType(NightResultView), findsOneWidget);
      expect(find.text('Continue to the vote'), findsOneWidget);

      await tester.tap(find.text('Continue to the vote'));
      await _settle(tester);

      expect(find.text('0 of 3 voted'), findsOneWidget);
    });

    testWidgets('several missed results are read one after another', (
      tester,
    ) async {
      await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().inPhase('discussion').withNightResults([
          _peekBob(wave: 1),
          _swapWithCharlie(),
        ]).build(),
      );

      expect(find.text('You looked at Bob\'s card'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await _settle(tester);
      expect(find.text('You looked at Bob\'s card'), findsNothing);
      expect(find.byType(NightResultView), findsOneWidget);
      expect(find.text('Continue to discussion'), findsOneWidget);

      await tester.tap(find.text('Continue to discussion'));
      await _settle(tester);
      expect(find.text('Roles in this game'), findsOneWidget);
    });

    testWidgets('a window that closed while offline is shown after the '
        'reconnect refresh, and can be dismissed at night', (tester) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().withWave(1).build(),
      );
      expect(find.byType(NightResultView), findsNothing);

      setup.registerGameMe(
        GameMeJsonBuilder().withWave(2).withNightResults([
          _peekBob(wave: 1),
        ]).build(),
      );
      await tester.runAsync(
        () => ProviderScope.containerOf(
          tester.element(find.byType(GameContainerScreen)),
        ).read(gameProvider('test-game-id').notifier).refreshState(),
      );
      await _settle(tester);

      expect(find.byType(NightResultView), findsOneWidget);
      // Nothing is waiting behind it, but a closed window's result can be
      // put away.
      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await _settle(tester);
      expect(find.byType(NightResultView), findsNothing);
      expect(find.text('The village sleeps…'), findsOneWidget);
    });

    testWidgets('is never shown at night while that window is still open', (
      tester,
    ) async {
      await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().withWave(2).withNightResults([
          _peekBob(wave: 2),
        ]).build(),
      );

      expect(find.byType(NightResultView), findsNothing);
    });
  });
}
