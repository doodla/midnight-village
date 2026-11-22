import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/presentation/shell/count_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/vote_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/your_card_screen.dart';
import 'package:midnight_village/features/lobby/presentation/at_table_screen.dart';

import '../../../helpers/contract/server_json.dart' show serverMyTable;
import '../../../helpers/outcome_samples.dart';
import '../../../helpers/shell_setup.dart';

/// The dusk and the dawn through the real shell: the two changes of screen
/// that are a scene ([Motion.scene]); every other one stays a crossfade
/// ([Motion.settle]), and with reduce motion all are cuts. The moment of the
/// change is the one the shell shows the new screen in (a fetch answered).
const _ms = Duration(milliseconds: 1);

/// Pumps until [screen] is in the tree and the frame that starts its
/// change has been drawn: time zero of the change.
Future<void> _begun(WidgetTester tester, Finder screen) async {
  for (var i = 0; i < 40 && screen.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 5));
  }
  expect(screen, findsOneWidget);
  await tester.pump();
}

/// The paper edge of the sinking screen, while a scene runs.
Finder get _sceneArt => find.byKey(const ValueKey('scene'));

/// Where [button] of the arriving screen rests: where it is drawn less the
/// slide the arriving screen is still on (a touch lands where it will rest).
Offset _rest(WidgetTester tester, Finder button) {
  final slide = tester.widget<SlideTransition>(
    find.ancestor(of: button, matching: find.byType(SlideTransition)).first,
  );
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  return tester.getCenter(button) - Offset(0, slide.position.value.dy * height);
}

/// The arriving screen's primary button is fully uncovered (above the
/// leaving screen's top edge) by [share] of the scene.
Future<void> _buttonShownBy(
  WidgetTester tester, {
  required Finder button,
  required Finder leaving,
  required double share,
}) async {
  await tester.pump(Motion.scene * share);
  expect(
    tester.getRect(button).bottom,
    lessThanOrEqualTo(tester.getTopLeft(leaving).dy),
    reason: 'the button is uncovered by ${share * 100} % of the scene',
  );
}

Future<ShellSetup> _atNight(WidgetTester tester, {bool still = false}) async {
  final s = await ShellSetup.pump(
    tester,
    recordedMe('me_choose_prompt_seer'),
    learned: const {Cue.hold},
    disableAnimations: still,
    before: (s) => s.answerNightResultsSeen(),
  );
  await s.settle(tester);
  expect(find.byType(NightBoard), findsOneWidget);
  return s;
}

Future<ShellSetup> _atTable(WidgetTester tester, {bool still = false}) async {
  final s = await ShellSetup.pump(
    tester,
    recordedMe('me_look_stage'),
    disableAnimations: still,
  );
  await s.settle(tester);
  final code = s.me['lobby_code'] as String;
  s.answerLobby(code);
  s.answerTable(
    serverMyTable(code: code, isHost: true, gameId: s.gameId, phase: 'results'),
  );
  s.resume();
  await s.settle(tester);
  await s.settle(tester);
  expect(find.byType(AtTableScreen), findsOneWidget);
  return s;
}

void main() {
  group('the dawn: night to talk', () {
    testWidgets('runs for Motion.scene, not the crossfade, and finishes', (
      tester,
    ) async {
      final s = await _atNight(tester);
      s.answerMe(recordedMe('me_discussion_choose_seer'));
      s.resume();
      await _begun(tester, find.byType(TalkScreen));
      expect(find.byType(NightBoard), findsOneWidget, reason: 'leaving');
      expect(_sceneArt, findsOneWidget, reason: 'the paper edge');
      await tester.pump(Motion.settle + const Duration(milliseconds: 40));
      expect(
        find.byType(NightBoard),
        findsOneWidget,
        reason: 'a crossfade would be over by now',
      );
      await tester.pump(Motion.scene);
      await tester.pump();
      expect(find.byType(NightBoard), findsNothing);
      expect(find.byType(TalkScreen), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      await s.close(tester);
    });

    testWidgets('a tap in the first frames reaches the talk\'s own button', (
      tester,
    ) async {
      final s = await _atNight(tester);
      s.answerMe(recordedMe('me_discussion_choose_seer'));
      s.resume();
      await _begun(tester, find.byType(TalkScreen));
      await tester.pump(_ms * 60);
      expect(find.byType(NightBoard), findsOneWidget, reason: 'mid-scene');
      s.answerPost('/ready/', 'game/ready_talk');
      // The night board, still showing, has a button too: the talk's own.
      final ready = find.descendant(
        of: find.byType(TalkScreen),
        matching: find.byType(PrimaryButton),
      );
      await tester.tapAt(_rest(tester, ready));
      await tester.pump();
      expect(
        tester.widget<PrimaryButton>(ready).label,
        CommonCopy.readyDone,
        reason: 'on the tap, mid-scene',
      );
      await tester.pump(_ms * 20);
      expect(s.posts('/ready/'), 1, reason: 'sent mid-scene');
      expect(find.byType(NightBoard), findsOneWidget, reason: 'still going');
      await tester.pump(Motion.scene);
      await s.close(tester);
    });

    testWidgets('the Ready button is uncovered by 60% of the scene', (
      tester,
    ) async {
      final s = await _atNight(tester);
      s.answerMe(recordedMe('me_discussion_choose_seer'));
      s.resume();
      await _begun(tester, find.byType(TalkScreen));
      await _buttonShownBy(
        tester,
        button: find.descendant(
          of: find.byType(TalkScreen),
          matching: find.byType(PrimaryButton),
        ),
        leaving: find.byType(NightBoard),
        share: 0.6,
      );
      await tester.pump(Motion.scene);
      await s.close(tester);
    });

    testWidgets('with reduce motion it is a cut', (tester) async {
      final s = await _atNight(tester, still: true);
      s.answerMe(recordedMe('me_discussion_choose_seer'));
      s.resume();
      await _begun(tester, find.byType(TalkScreen));
      expect(find.byType(NightBoard), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
      await s.close(tester);
    });
  });

  group('the dusk: the deal to the night', () {
    testWidgets('runs for Motion.scene, the table sinking off the card, '
        'and finishes', (tester) async {
      final s = await _atTable(tester);
      s.answerMe(recordedMe('me_look_stage'));
      s.resume();
      await _begun(tester, find.byType(YourCardScreen));
      expect(find.byType(AtTableScreen), findsOneWidget, reason: 'leaving');
      expect(_sceneArt, findsOneWidget, reason: 'the paper edge');
      await tester.pump(Motion.settle + const Duration(milliseconds: 40));
      expect(find.byType(AtTableScreen), findsOneWidget);
      await tester.pump(Motion.scene);
      await tester.pump();
      expect(find.byType(AtTableScreen), findsNothing);
      expect(_sceneArt, findsNothing);
      await s.close(tester);
    });

    testWidgets('the Ready button is uncovered by 60% of the scene', (
      tester,
    ) async {
      final s = await _atTable(tester);
      s.answerMe(recordedMe('me_look_stage'));
      s.resume();
      await _begun(tester, find.byType(YourCardScreen));
      await _buttonShownBy(
        tester,
        button: find.descendant(
          of: find.byType(YourCardScreen),
          matching: find.byType(PrimaryButton),
        ),
        leaving: find.byType(AtTableScreen),
        share: 0.6,
      );
      await tester.pump(Motion.scene);
      await s.close(tester);
    });

    testWidgets('with reduce motion it is a cut', (tester) async {
      final s = await _atTable(tester, still: true);
      s.answerMe(recordedMe('me_look_stage'));
      s.resume();
      await _begun(tester, find.byType(YourCardScreen));
      expect(find.byType(AtTableScreen), findsNothing);
      expect(_sceneArt, findsNothing);
      await s.close(tester);
    });
  });

  group('every other change of screen is still a crossfade', () {
    testWidgets('talk to vote (day to day)', (tester) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_talk_ready'),
        before: (s) => s.answerNightResultsSeen(),
      );
      await s.settle(tester);
      expect(find.byType(TalkScreen), findsOneWidget);
      s.answerMe(recordedMe('me_voting_unpicked'));
      s.resume();
      await _begun(tester, find.byType(VoteScreen));
      expect(find.byType(TalkScreen), findsOneWidget, reason: 'leaving');
      expect(_sceneArt, findsNothing);
      await tester.pump(Motion.settle + _ms * 3);
      await tester.pump();
      expect(find.byType(TalkScreen), findsNothing);
      expect(find.byType(VoteScreen), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('vote to the count (no wipe, decided 22 Nov 2026)', (
      tester,
    ) async {
      final results = recordedResults('results_doppelganger');
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_voting_locked'),
        learned: Cue.values.toSet(),
        before: (s) => s.answerResults(results),
      );
      await s.settle(tester);
      expect(find.byType(VoteScreen), findsOneWidget);
      s.answerMe(resultsMeFor(results, viewer: 'Ben', host: 'Ana'));
      s.resume();
      await _begun(tester, find.byType(CountScreen));
      expect(find.byType(VoteScreen), findsOneWidget, reason: 'leaving');
      expect(_sceneArt, findsNothing);
      await tester.pump(Motion.settle + _ms * 3);
      await tester.pump();
      expect(find.byType(VoteScreen), findsNothing);
      await s.close(tester);
    });

    testWidgets('04 to the night board (night to night)', (tester) async {
      final s = await ShellSetup.pump(tester, recordedMe('me_look_ready'));
      await s.settle(tester);
      s.answerMe(recordedMe('me_choose_prompt_seer'));
      s.resume();
      await _begun(tester, find.byType(NightBoard));
      expect(_sceneArt, findsNothing);
      await tester.pump(Motion.settle + _ms * 3);
      await tester.pump();
      expect(find.byType(YourCardScreen), findsNothing);
      await s.close(tester);
    });
  });
}
