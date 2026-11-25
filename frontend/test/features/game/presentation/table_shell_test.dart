import '../../../helpers/finger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/lobby/presentation/join_screen.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/game/presentation/shell/end_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/night_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/vote_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/your_card_screen.dart';

import '../../../helpers/component_sheet.dart' show holdDown;
import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/sample_sets.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/shell_setup.dart';
import '../../../helpers/truncated_text.dart';

/// The label on the screen's one primary button.
String _button(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton).last).label;

ButtonPhase _phase(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton).last).phase;

/// The talk opens a night that told this phone something and acknowledges
/// it: that POST is answered.
void _ack(ShellSetup s) => s.answerNightResultsSeen();

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
      'me_discussion_choose_seer': TalkScreen,
      'me_talk_ready': TalkScreen,
      'me_voting_unpicked': VoteScreen,
      'me_voting_locked': VoteScreen,
      'me_results': EndScreen,
    };
    for (final MapEntry(key: sample, value: type) in cases.entries) {
      testWidgets('$sample: ${meScreens[sample]!.number}', (tester) async {
        final s = await ShellSetup.pump(
          tester,
          recordedMe(sample),
          before: _ack,
        );
        await s.settle(tester);
        expect(find.byType(type), findsOneWidget);
        await s.close(tester);
      });
    }

    // Every recorded /me/: the screen stated for it, the real one (every
    // screen is built; there is no placeholder).
    const built = <AppScreen, Type>{
      AppScreen.yourCard: YourCardScreen,
      AppScreen.nightBoard: NightScreen,
      AppScreen.talk: TalkScreen,
      AppScreen.vote: VoteScreen,
      AppScreen.end: EndScreen,
    };
    for (final MapEntry(key: sample, value: screen) in meScreens.entries) {
      testWidgets('$sample: the real ${screen.number}', (tester) async {
        final s = await ShellSetup.pump(
          tester,
          recordedMe(sample),
          before: _ack,
        );
        await s.settle(tester);
        expect(find.byType(built[screen]!), findsOneWidget);
        await s.close(tester);
      });
    }

    testWidgets('a /me/ without its stage is a failed fetch: fetched again '
        'until a good answer, then its screen', (tester) async {
      final me = recordedMe('me_discussion_choose_seer');
      final path = '/onuw/games/${me['game_id']}/me/';
      final s = await ShellSetup.pump(
        tester,
        me,
        before: (s) {
          _ack(s);
          s.http.answer(
            'GET',
            path,
            Map.of(me)..remove('stage'),
            offContract: true,
          );
        },
      );
      await s.settle(tester);
      expect(find.byType(TalkScreen), findsNothing);
      final fetched = s.meFetches;
      await tester.pump(const Duration(minutes: 1));
      expect(
        s.meFetches,
        greaterThan(fetched),
        reason: 'healed: fetched again',
      );

      s.http.answer('GET', path, me);
      await tester.pump(const Duration(minutes: 1));
      await s.settle(tester);
      expect(find.byType(TalkScreen), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('the game is gone (404, its table closed): 01, which says so', (
      tester,
    ) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_discussion_choose_seer'),
        before: _ack,
      );
      await s.settle(tester);
      expect(find.byType(TalkScreen), findsOneWidget);
      s.refuseMe();
      s.answerTable(ContractSamples.map('http/lobby/my_table_none'));
      s.answerHome();
      s.resume();
      await s.settle(tester);
      expect(find.byType(JoinScreen), findsOneWidget);
      expect(find.text(BannerCopy.tableClosed), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('the table ahead of /me/ (the vote named, the talk\'s /me/ '
        'held): the vote waits on its ground, never with the talk\'s values', (
      tester,
    ) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_talk_ready'),
        before: _ack,
      );
      await s.settle(tester);
      expect(find.byType(TalkScreen), findsOneWidget);
      final vote = recordedMe('me_voting_unpicked');
      final held = s.http.hold(
        method: 'GET',
        path: '/onuw/games/${s.gameId}/me/',
      );
      s.answerMe(vote);
      s.resume();
      await s.settle(tester);
      expect(s.screenOn(tester), AppScreen.vote);
      expect(find.byType(TalkScreen), findsNothing);
      expect(find.byType(VoteScreen), findsNothing);
      expect(find.byType(PrimaryButton), findsNothing, reason: 'nothing on it');
      held.releaseAll();
      await s.settle(tester);
      expect(find.byType(VoteScreen), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('at no table: 01 Join', (tester) async {
      // Answered from the start: the shell's first read of where the phone
      // sits leaves in the first frame.
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_look_stage'),
        before: (s) {
          s.answerTable(ContractSamples.map('http/lobby/my_table_none'));
          s.http
            ..answer('GET', '/stats/online/', serverOnlineStats())
            ..answer(
              'GET',
              '/onuw/me/recent-games/',
              ContractSamples.map('http/game/recent_games_none'),
            );
        },
      );
      s.resume();
      await s.settle(tester);
      expect(find.byType(JoinScreen), findsOneWidget);
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

    testWidgets('"One moment" while the socket is down and the fetches fail '
        'too; a refused socket alone changes nothing', (tester) async {
      final me = recordedMe('me_choose_prompt_seer');
      final s = await ShellSetup.pump(tester, me);
      await s.settle(tester);
      s.socket(connected: false);
      await s.settle(tester);
      expect(
        find.text(BannerCopy.offline),
        findsNothing,
        reason: 'fetches work',
      );

      s.failMe();
      s.resume();
      await s.settle(tester);
      expect(find.text(BannerCopy.offline), findsOneWidget);

      // Back: the next retry lands.
      s.answerMe(me);
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
      expect(_button(tester), CardCopy.readyLocked);
      expect(_phase(tester), ButtonPhase.locked);
      expect(find.text('0 of 5 ready'), findsOneWidget);
      // First game: the plain hold ring.
      expect(find.text(CommonCopy.hold), findsOneWidget);

      // A locked tap sends nothing.
      await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
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
      await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
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
      // This phone's own Ready is counted at once; then the server's count,
      // read with this phone's flag from one /me/ (the event, arriving
      // before that is confirmed, fetches it): still one, never two.
      expect(find.text('1 of 5 ready'), findsOneWidget);
      s.answerMe(recordedMe('me_look_ready'));
      s.ws.addServerEvent(ContractSamples.map('ws/game/progress_look'));
      await s.settle(tester);
      expect(find.text('1 of 5 ready'), findsOneWidget);
      expect(_button(tester), CommonCopy.readyDone);
      await s.close(tester);
    });

    testWidgets('a restart after Ready opens at "Ready ✓"', (tester) async {
      final s = await ShellSetup.pump(tester, recordedMe('me_look_ready'));
      await s.settle(tester);
      expect(_button(tester), CommonCopy.readyDone);
      expect(s.posts('/ready/'), 0);
      await s.close(tester);
    });

    testWidgets('a restart after seeing the card but before Ready: Ready is '
        'open without another hold (this device kept the stage)', (
      tester,
    ) async {
      final look = recordedMe('me_look_stage');
      var s = await ShellSetup.pump(tester, look);
      await s.settle(tester);
      final gesture = await holdDown(tester, find.byType(FaceDownCard));
      await gesture.up();
      await s.settle(tester);
      expect(_phase(tester), ButtonPhase.ready);
      await s.close(tester);

      s = await ShellSetup.pump(tester, look, sameDevice: true);
      await s.settle(tester);
      expect(_phase(tester), ButtonPhase.ready);
      await s.close(tester);

      // Another device (or another stage) still holds first.
      s = await ShellSetup.pump(tester, look);
      await s.settle(tester);
      expect(_phase(tester), ButtonPhase.locked);
      await s.close(tester);
    });

    testWidgets("another player's phone (a /debug perspective switch) does "
        "not carry this player's reveal", (tester) async {
      final look = recordedMe('me_look_stage');
      final s = await ShellSetup.pump(tester, look);
      await s.settle(tester);
      final gesture = await holdDown(tester, find.byType(FaceDownCard));
      await gesture.up();
      await s.settle(tester);
      expect(_phase(tester), ButtonPhase.ready);

      // The same look stage, as the next seat's phone has it.
      final next = recordedMe('me_look_stage');
      next['player_id'] = ((next['players'] as List)[1] as Map)['player_id'];
      s.answerMe(next);
      s.resume();
      await s.settle(tester);
      expect(_phase(tester), ButtonPhase.locked);
      await s.close(tester);
    });

    testWidgets('while held, the card turns over in its own frame', (
      tester,
    ) async {
      final s = await ShellSetup.pump(tester, recordedMe('me_look_stage'));
      await s.settle(tester);
      final frame = tester.getRect(find.byType(FaceDownCard));
      final gesture = await holdDown(tester, find.byType(FaceDownCard));
      await tester.pump(HoldToReveal.flip);
      expect(tester.getRect(find.byType(HeldFace)), frame);
      await gesture.up();
      // The turn back: its first frame, then the flip.
      await tester.pump();
      await tester.pump(HoldToReveal.flip);
      await tester.pump(HoldToReveal.flip);
      expect(find.byType(HeldFace), findsNothing);
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
      await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
      await s.settle(tester);
      expect(find.text(BannerCopy.notSent), findsOneWidget);
      expect(_button(tester), CommonCopy.readyDone, reason: 'still shown');

      s.answerPost('/ready/', 'game/ready_look');
      final fetched = s.meFetches;
      await pressLikeAFinger(tester, find.text(BannerCopy.tryAgain));
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
      // The candle: the share of the window left, from the server's own
      // `stage_started_at` and deadline, the same as the talk's sun.
      final parsed = GameMe.fromJson(me);
      final length = parsed.deadline!
          .difference(parsed.stageStartedAt!)
          .inMilliseconds;
      expect(board.share, closeTo(14000 / length, 1e-9));
      expect(
        tester.widget<WorldTimer>(find.byType(WorldTimer)).share,
        board.share,
      );
      await s.close(tester);
    });

    for (final (left, shown) in [(9, '9 s'), (59, '59 s'), (600, '10:00')]) {
      testWidgets('the candle reads $shown with ${left}s left, whole, on a '
          '320 phone at text x1.3', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final me = recordedMe('me_choose_prompt_seer');
        final deadline = DateTime.parse(me['deadline'] as String);
        final s = await ShellSetup.pump(
          tester,
          me,
          clock: deadline.subtract(Duration(seconds: left)),
          textScale: 1.3,
        );
        await s.settle(tester);
        expect(find.text(shown), findsOneWidget);
        expect(truncatedText(tester), isEmpty);
        expect(tester.takeException(), isNull);
        await s.close(tester);
      });
    }

    testWidgets('Choose: "Chosen" at once, one choose with the stage, then '
        '/me/ again', (tester) async {
      final me = recordedMe('me_choose_prompt_seer');
      final s = await ShellSetup.pump(tester, me, learned: Cue.values.toSet());
      await s.settle(tester);
      s.answerPost('/action/', 'game/choose_submitted_seer');
      await pressLikeAFinger(tester, _seat('Cleo'));
      await tester.pump();
      expect(_button(tester), 'See Cleo');
      final fetched = s.meFetches;
      s.answerMe(recordedMe('me_choose_chosen'));
      await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
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
      await pressLikeAFinger(tester, _seat('Cleo'));
      await tester.pump();
      final fetched = s.meFetches;
      await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
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
      await pressLikeAFinger(tester, _seat('Cleo'));
      await tester.pump();
      await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
      await s.settle(tester);
      expect(find.text(BannerCopy.notSent), findsOneWidget);
      expect(_button(tester), NightCopy.chosen);
      final first = s.lastBody('/action/');

      s.answerPost('/action/', 'game/choose_submitted_seer');
      await pressLikeAFinger(tester, find.text(BannerCopy.tryAgain));
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
      await pressLikeAFinger(tester, _seat('Cleo'));
      await tester.pump();
      await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
      await s.settle(tester);
      expect(_button(tester), 'See Cleo');
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
      await pressLikeAFinger(tester, _seat(other.name));
      await tester.pump();
      await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
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
