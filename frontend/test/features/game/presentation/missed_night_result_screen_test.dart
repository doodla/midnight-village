import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/presentation/game_container_screen.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';
import 'package:midnight_village/features/game/presentation/night_result_view.dart';

import '../../../helpers/contract/server_json.dart';
import '../../../helpers/game_events.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

/// The Seer looked at Bob, a Werewolf (window 2).
Map<String, dynamic> _peekBob() => serverNightResult(
  'peek_player',
  info: {'target_name': 'Bob', 'role': 'werewolf'},
);

/// The Doppelganger's look at Bob (window 1), and her follow-up as the copied
/// Seer: the only player with two results.
Map<String, dynamic> _lookAtBob() => serverNightResult(
  'doppelganger_look',
  wave: 1,
  info: {'target_name': 'Bob'},
);
Map<String, dynamic> _followUp() => serverNightResult('peek_center', wave: 1);

GameMeJsonBuilder _doppelganger() =>
    GameMeJsonBuilder().withRole('Doppelganger');

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

      setup.ws.addServerEvent(GameEvents.actionResultOf(_peekBob()));
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
        gameMeJson: _doppelganger().inPhase('discussion').withNightResults([
          _lookAtBob(),
          _followUp(),
        ]).build(),
      );

      final look = find.byType(NightResultView);
      final lookWidget = tester.widget<NightResultView>(look);
      expect(lookWidget.result.revealedInfo['action_type'], 'peek_player');
      expect(find.text('Next'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await _settle(tester);
      expect(
        tester
            .widget<NightResultView>(find.byType(NightResultView))
            .result
            .revealedInfo['action_type'],
        'peek_center',
      );
      expect(find.byType(NightResultView), findsOneWidget);
      expect(find.text('Continue to discussion'), findsOneWidget);

      await tester.tap(find.text('Continue to discussion'));
      await _settle(tester);
      expect(find.text('Roles in this game'), findsOneWidget);
    });

    testWidgets('a window that closed while offline is shown after the '
        'reconnect refresh, and can be dismissed at night', (tester) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: _doppelganger().withWave(1).build(),
      );
      expect(find.byType(NightResultView), findsNothing);

      setup.registerGameMe(
        _doppelganger().withWave(2).withNightResults([_lookAtBob()]).build(),
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
  });
}
