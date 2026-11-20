import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/game/presentation/shell/night_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/not_built_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/your_card_screen.dart';

import '../../../helpers/component_sheet.dart' show holdDown;
import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/sample_sets.dart';
import '../../../helpers/shell_setup.dart';

/// The label on the screen's one primary button.
String _button(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton).last).label;

ButtonPhase _phase(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton).last).phase;

/// [player]'s card on the night board.
Finder _seat(String name) => find.text(name).last;

void main() {
  group('the shell shows exactly the screen the table screen names', () {
    final cases = <String, Type>{
      'me_look_stage': YourCardScreen,
      'me_look_ready': YourCardScreen,
      'me_choose_prompt_seer': NightBoard,
      'me_choose_prompt_doppelganger_look': NightBoard,
      'me_choose_chosen': NightBoard,
    };
    for (final MapEntry(key: sample, value: type) in cases.entries) {
      testWidgets('$sample: ${protocolTwoScreens[sample]!.number}', (
        tester,
      ) async {
        final s = await ShellSetup.pump(tester, recordedMe(sample));
        await s.settle(tester);
        expect(find.byType(type), findsOneWidget);
        expect(find.byType(NotBuiltScreen), findsNothing);
        await s.close(tester);
      });
    }

    // Every recorded protocol-2 /me/ of a screen not rebuilt yet: its
    // placeholder, named by the brief, and nothing else.
    for (final MapEntry(key: sample, value: screen)
        in protocolTwoScreens.entries.where(
          (e) =>
              e.value != AppScreen.yourCard && e.value != AppScreen.nightBoard,
        )) {
      testWidgets('$sample: the ${screen.number} placeholder', (tester) async {
        final s = await ShellSetup.pump(tester, recordedMe(sample));
        await s.settle(tester);
        expect(
          tester.widget<NotBuiltScreen>(find.byType(NotBuiltScreen)).screen,
          screen,
        );
        expect(find.text('${screen.number} ${screen.briefName}'), findsOne);
        await s.close(tester);
      });
    }

    testWidgets('at no table: the 01 placeholder', (tester) async {
      final s = await ShellSetup.pump(tester, recordedMe('me_look_stage'));
      s.answerTable(ContractSamples.map('http/lobby/my_table_none'));
      s.resume();
      await s.settle(tester);
      expect(
        tester.widget<NotBuiltScreen>(find.byType(NotBuiltScreen)).screen,
        AppScreen.join,
      );
      await s.close(tester);
    });

    testWidgets('the night window opens: 04 gives way to the board, one fetch '
        'after the event, no navigation of its own', (tester) async {
      final s = await ShellSetup.pump(tester, recordedMe('me_look_ready'));
      await s.settle(tester);
      expect(find.byType(YourCardScreen), findsOneWidget);
      s.answerMe(recordedMe('me_choose_prompt_seer'));
      s.ws.addServerEvent(ContractSamples.map('ws/game/night_window_2'));
      await s.settle(tester);
      expect(find.byType(NightBoard), findsOneWidget);
      expect(find.byType(YourCardScreen), findsNothing);
      await s.close(tester);
    });

    testWidgets('with reduce motion the change of screen is instant', (
      tester,
    ) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_look_ready'),
        disableAnimations: true,
      );
      await s.settle(tester);
      s.answerMe(recordedMe('me_choose_prompt_seer'));
      s.resume();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 1));
      }
      expect(find.byType(YourCardScreen), findsNothing);
      expect(find.byType(NightBoard), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('keeps the screen awake while shown', (tester) async {
      final s = await ShellSetup.pump(tester, recordedMe('me_look_stage'));
      expect(s.wakelock.isEnabled, isTrue);
      await s.close(tester);
      expect(s.wakelock.isEnabled, isFalse);
    });

    testWidgets('"One moment" while the game socket is down, gone when back', (
      tester,
    ) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_choose_prompt_seer'),
      );
      await s.settle(tester);
      expect(find.text(BannerCopy.offline), findsNothing);
      s.socket(connected: false);
      await s.settle(tester);
      expect(find.text(BannerCopy.offline), findsOneWidget);
      s.socket(connected: true);
      await s.settle(tester);
      expect(find.text(BannerCopy.offline), findsNothing);
      await s.close(tester);
    });
  });

  group('04 Your card', () {
    testWidgets('"Ready" is locked until a 0.8 s hold; the hold shows the role '
        'text; the pips count who has looked, never who', (tester) async {
      final s = await ShellSetup.pump(tester, recordedMe('me_look_stage'));
      await s.settle(tester);
      expect(find.text(CardCopy.headline), findsOneWidget);
      expect(_button(tester), CardCopy.ready);
      expect(_phase(tester), ButtonPhase.locked);
      expect(find.text('0 of 5'), findsOneWidget);
      // First game: the plain hold ring.
      expect(find.text(CommonCopy.hold), findsOneWidget);

      // A locked tap sends nothing.
      await tester.tap(find.byType(PrimaryButton).last);
      await tester.pump();
      expect(s.posts('/ready/'), 0);

      final gesture = await holdDown(tester, find.byType(FaceDownCard));
      expect(find.text('Seer'), findsWidgets, reason: 'the held face');
      await gesture.up();
      await tester.pump();
      expect(_phase(tester), ButtonPhase.ready);
      await s.close(tester);
    });

    testWidgets('Ready shows "Ready ✓" on the tap and sends the stage', (
      tester,
    ) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_look_stage'),
        learned: Cue.values.toSet(),
      );
      await s.settle(tester);
      expect(find.text(CommonCopy.hold), findsNothing, reason: 'learned');
      final replies = s.http.hold(
        method: 'POST',
        path: '/onuw/games/${s.gameId}/ready/',
      );
      s.answerPost('/ready/', 'game/ready_look');
      final gesture = await holdDown(tester, find.byType(FaceDownCard));
      await gesture.up();
      await tester.pump();
      await tester.tap(find.byType(PrimaryButton).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      // Before any answer.
      expect(_button(tester), CommonCopy.readyDone);
      expect(_phase(tester), ButtonPhase.done);
      expect(s.lastBody('/ready/'), {
        'stage': recordedMe('me_look_stage')['stage'],
        'ready': true,
      });
      replies.releaseAll();
      await s.settle(tester);
      expect(_button(tester), CommonCopy.readyDone);
      // The count is the server's, from its event to every phone.
      expect(find.text('0 of 5'), findsOneWidget);
      s.ws.addServerEvent(ContractSamples.map('ws/game/progress_look'));
      await s.settle(tester);
      expect(find.text('1 of 5'), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('a restart after Ready opens at "Ready ✓"', (tester) async {
      final s = await ShellSetup.pump(tester, recordedMe('me_look_ready'));
      await s.settle(tester);
      expect(_button(tester), CommonCopy.readyDone);
      expect(s.posts('/ready/'), 0);
      await s.close(tester);
    });

    testWidgets('a Ready that got no answer: "Not sent." and Try again, '
        'which reads /me/ before sending again', (tester) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_look_stage'),
        learned: Cue.values.toSet(),
      );
      await s.settle(tester);
      s.failPost('/ready/');
      final gesture = await holdDown(tester, find.byType(FaceDownCard));
      await gesture.up();
      await tester.tap(find.byType(PrimaryButton).last);
      await s.settle(tester);
      expect(find.text(BannerCopy.notSent), findsOneWidget);
      expect(_button(tester), CommonCopy.readyDone, reason: 'still shown');

      s.answerPost('/ready/', 'game/ready_look');
      final fetched = s.meFetches;
      await tester.tap(find.text(BannerCopy.tryAgain));
      await s.settle(tester);
      expect(s.meFetches, greaterThan(fetched));
      expect(s.posts('/ready/'), 2);
      expect(find.text(BannerCopy.notSent), findsNothing);
      await s.close(tester);
    });
  });

  group('the night board', () {
    testWidgets('05 only while /me/ loads: the candle, no number', (
      tester,
    ) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_choose_prompt_seer'),
        holdMe: true,
      );
      await s.settle(tester);
      expect(find.byType(NightWaitScreen), findsOneWidget);
      expect(find.text(CommonCopy.nightTitle), findsOneWidget);
      expect(
        tester.widget<WorldTimer>(find.byType(WorldTimer)).secondsLeft,
        isNull,
      );
      s.meReplies!.releaseAll();
      await s.settle(tester);
      expect(find.byType(NightWaitScreen), findsNothing);
      expect(find.byType(NightBoard), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('fed from /me/: the seats, the prompt, and the seconds left '
        'by the server deadline', (tester) async {
      final me = recordedMe('me_choose_prompt_seer');
      final deadline = DateTime.parse(me['deadline'] as String);
      final s = await ShellSetup.pump(
        tester,
        me,
        clock: deadline.subtract(const Duration(seconds: 14)),
      );
      await s.settle(tester);
      final board = tester.widget<NightBoard>(find.byType(NightBoard));
      expect(board.selfId, me['player_id']);
      expect(board.seats, hasLength((me['players'] as List).length));
      expect(board.prompt.stage, me['stage']);
      expect(board.secondsLeft, 14);
      await s.close(tester);
    });

    testWidgets('Choose: "Chosen" at once, one choose with the stage, then '
        '/me/ again', (tester) async {
      final me = recordedMe('me_choose_prompt_seer');
      final s = await ShellSetup.pump(tester, me, learned: Cue.values.toSet());
      await s.settle(tester);
      s.answerPost('/action/', 'game/choose_submitted_seer');
      await tester.tap(_seat('Cleo'));
      await tester.pump();
      expect(_button(tester), 'Choose Cleo');
      final fetched = s.meFetches;
      s.answerMe(recordedMe('me_choose_chosen'));
      await tester.tap(find.byType(PrimaryButton).last);
      await tester.pump();
      expect(_button(tester), NightCopy.chosen);
      await s.settle(tester);
      expect(s.posts('/action/'), 1);
      final body = s.lastBody('/action/') as Map;
      expect(body['stage'], me['stage']);
      expect(body['action_type'], 'choose');
      expect(body['chosen'], 0);
      expect(s.meFetches, greaterThan(fetched), reason: 'after a taken choose');
      expect(_button(tester), NightCopy.chosen);
      expect(find.text(BannerCopy.tryAgain), findsNothing);
      await s.close(tester);
    });

    testWidgets('a 409 is not a failure: /me/ is fetched again, no Try again', (
      tester,
    ) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_choose_prompt_seer'),
        learned: Cue.values.toSet(),
      );
      await s.settle(tester);
      s.answerPost('/action/', 'game/choose_wrong_stage', status: 409);
      await tester.tap(_seat('Cleo'));
      await tester.pump();
      final fetched = s.meFetches;
      await tester.tap(find.byType(PrimaryButton).last);
      await s.settle(tester);
      expect(s.meFetches, greaterThan(fetched));
      expect(find.text(BannerCopy.tryAgain), findsNothing);
      expect(find.text(BannerCopy.notSent), findsNothing);
      await s.close(tester);
    });

    testWidgets('Try again only when no answer came; it sends the original '
        'choose once more', (tester) async {
      final me = recordedMe('me_choose_prompt_seer');
      final s = await ShellSetup.pump(tester, me, learned: Cue.values.toSet());
      await s.settle(tester);
      s.failPost('/action/');
      await tester.tap(_seat('Cleo'));
      await tester.pump();
      await tester.tap(find.byType(PrimaryButton).last);
      await s.settle(tester);
      expect(find.text(BannerCopy.notSent), findsOneWidget);
      expect(_button(tester), NightCopy.chosen);
      final first = s.lastBody('/action/');

      s.answerPost('/action/', 'game/choose_submitted_seer');
      await tester.tap(find.text(BannerCopy.tryAgain));
      await s.settle(tester);
      expect(s.posts('/action/'), 2);
      expect(s.lastBody('/action/'), first);
      expect(find.text(BannerCopy.notSent), findsNothing);
      await s.close(tester);
    });

    testWidgets('a refused choose (400) arms the board again', (tester) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_choose_prompt_seer'),
        learned: Cue.values.toSet(),
      );
      await s.settle(tester);
      s.answerPost('/action/', 'game/choose_bad_request', status: 400);
      await tester.tap(_seat('Cleo'));
      await tester.pump();
      await tester.tap(find.byType(PrimaryButton).last);
      await s.settle(tester);
      expect(_button(tester), 'Choose Cleo');
      expect(find.text(BannerCopy.tryAgain), findsNothing);
      await s.close(tester);
    });

    testWidgets('a restart mid-window after Choose lands on "Chosen"', (
      tester,
    ) async {
      final s = await ShellSetup.pump(tester, recordedMe('me_choose_chosen'));
      await s.settle(tester);
      expect(find.byType(NightBoard), findsOneWidget);
      expect(_button(tester), NightCopy.chosen);
      expect(s.posts('/action/'), 0);
      await s.close(tester);
    });

    testWidgets("the Doppelganger's look, then her follow-up on the same "
        'board: it arms again when /me/ brings the new turn', (tester) async {
      final look = recordedMe('me_choose_prompt_doppelganger_look');
      final s = await ShellSetup.pump(
        tester,
        look,
        learned: Cue.values.toSet(),
      );
      await s.settle(tester);
      final board = tester.widget<NightBoard>(find.byType(NightBoard));
      final other = board.seats.firstWhere((p) => p.id != board.selfId);
      s.answerPost('/action/', 'game/choose_submitted_doppelganger_look');
      s.answerMe(recordedMe('me_choose_doppelganger_followup'));
      await tester.tap(_seat(other.name));
      await tester.pump();
      await tester.tap(find.byType(PrimaryButton).last);
      await tester.pump();
      expect(_button(tester), NightCopy.chosen);
      await s.settle(tester);
      // Her follow-up turn: armed, nothing picked.
      expect(_button(tester), NightCopy.chooseNone);
      expect(tester.widget<NightBoard>(find.byType(NightBoard)).prompt.turn, 1);
      await s.close(tester);
    });
  });
}
