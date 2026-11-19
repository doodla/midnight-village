import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/wakelock/wakelock_service.dart';
import 'package:midnight_village/features/game/presentation/game_container_screen.dart';

import '../../helpers/fake_wakelock_service.dart';
import '../../helpers/game_events.dart';
import '../../helpers/game_state_factory.dart';
import '../../helpers/game_test_setup.dart';

void main() {
  group('Keeping the screen awake', () {
    testWidgets('is turned on while a game is on screen', (tester) async {
      final wakelock = FakeWakelockService();
      await tester.pumpGameFlow(wakelock: wakelock);

      expect(wakelock.isEnabled, isTrue);
      expect(wakelock.enableCount, 1);
      expect(wakelock.disableCount, 0);
    });

    testWidgets('stays on through every phase of the game', (tester) async {
      final wakelock = FakeWakelockService();
      final setup = await tester.pumpGameFlow(wakelock: wakelock);

      setup.ws.addServerEvent(GameEvents.phaseChange(phase: 'discussion'));
      await tester.pump();
      setup.ws.addServerEvent(GameEvents.phaseChange(phase: 'voting'));
      await tester.pump();

      expect(wakelock.isEnabled, isTrue);
      expect(wakelock.disableCount, 0);
    });

    testWidgets('is turned off when the game screen is left', (tester) async {
      final wakelock = FakeWakelockService();
      await tester.pumpGameFlow(wakelock: wakelock);

      await tester.pumpWidget(const SizedBox());

      expect(wakelock.isEnabled, isFalse);
      expect(wakelock.disableCount, 1);
    });

    testWidgets('is asked for again when the app comes back to the front', (
      tester,
    ) async {
      final wakelock = FakeWakelockService();
      await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().inPhase('discussion').build(),
        wakelock: wakelock,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(wakelock.enableCount, 2);
    });

    testWidgets('a refusing platform changes nothing on screen', (
      tester,
    ) async {
      final wakelock = FakeWakelockService(failing: true);
      await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().inPhase('discussion').build(),
        wakelock: wakelock,
      );

      expect(find.byType(GameContainerScreen), findsOneWidget);
      expect(find.text('End Discussion'), findsNothing); // not host
      expect(tester.takeException(), isNull);
    });
  });

  group('PluginWakelockService', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('swallows a missing plugin instead of throwing', () async {
      const service = PluginWakelockService();

      await service.enable();
      await service.disable();
    });
  });
}
