import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/wakelock/wakelock_service.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/vote_screen.dart';

import '../../helpers/fake_wakelock_service.dart';
import '../../helpers/shell_setup.dart';

void main() {
  group('Keeping the screen awake (the table shell)', () {
    testWidgets('is on while the shell is shown, off when it is left', (
      tester,
    ) async {
      final s = await ShellSetup.pump(tester, recordedMe('me_look_stage'));
      expect(s.wakelock.isEnabled, isTrue);
      expect(s.wakelock.enableCount, 1);
      expect(s.wakelock.disableCount, 0);
      await s.close(tester);
      expect(s.wakelock.isEnabled, isFalse);
      expect(s.wakelock.disableCount, 1);
    });

    testWidgets('stays on as the game moves from screen to screen', (
      tester,
    ) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_discussion_choose_seer'),
        before: (s) => s.answerNightResultsSeen(),
      );
      await s.settle(tester);
      expect(find.byType(TalkScreen), findsOneWidget);
      s.answerMe(recordedMe('me_voting_unpicked'));
      s.resume();
      await s.settle(tester);
      expect(find.byType(VoteScreen), findsOneWidget);
      expect(s.wakelock.isEnabled, isTrue);
      expect(s.wakelock.disableCount, 0);
      await s.close(tester);
    });

    testWidgets('is asked for again when the app comes back to the front', (
      tester,
    ) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_discussion_choose_seer'),
        before: (s) => s.answerNightResultsSeen(),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(s.wakelock.enableCount, 2);
      await s.close(tester);
    });

    testWidgets('a refusing platform changes nothing on screen', (
      tester,
    ) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_discussion_choose_seer'),
        before: (s) => s.answerNightResultsSeen(),
        wakelock: FakeWakelockService(failing: true),
      );
      await s.settle(tester);
      expect(find.byType(TalkScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await s.close(tester);
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
