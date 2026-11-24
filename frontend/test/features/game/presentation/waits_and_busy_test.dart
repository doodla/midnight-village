import '../../../helpers/finger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/square_sky.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/waiting_sign.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/design_system/primitives/paper_scrap.dart';
import 'package:midnight_village/features/game/presentation/end/end_board_view.dart';
import 'package:midnight_village/features/game/presentation/shell/count_screen.dart'
    show EndWaiting;
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/waits.dart';
import 'package:midnight_village/features/lobby/presentation/at_table_screen.dart';
import 'package:midnight_village/features/lobby/presentation/join_screen.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/outcome_samples.dart';
import '../../../helpers/shell_setup.dart';

// What the phone shows while something is on its way (issue 10): a tapped
// control answers in its own frame and is not live again until the screen it
// leads to is up; a game screen whose data is not here is its own frame with
// the one waiting body in it, never a bare ground, never a flash when the
// answer is quick; losing the server keeps the seat and says one line.

/// How much of the sign is seen (the most of any: while a wait gives way to
/// another screen, both are on screen for one crossfade).
double _sign(WidgetTester tester) => tester
    .widgetList<AnimatedOpacity>(
      find.descendant(
        of: find.byType(WaitingSign),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .fold(0.0, (most, o) => o.opacity > most ? o.opacity : most);

/// The clock moves on by [d] in frames of 50 ms (a screen that arrives
/// starts its crossfade on the frame it is built), and one frame more.
Future<void> _wait(WidgetTester tester, Duration d) async {
  for (
    var left = d;
    left > Duration.zero;
    left -= const Duration(milliseconds: 50)
  ) {
    await tester.pump(
      left < const Duration(milliseconds: 50)
          ? left
          : const Duration(milliseconds: 50),
    );
  }
  await tester.pump();
}

Future<ShellSetup> _end(
  WidgetTester tester, {
  String viewer = 'Ana',
  void Function(ShellSetup s)? before,
}) async {
  final results = recordedResults('results');
  final s = await ShellSetup.pump(
    tester,
    resultsMeFor(results, viewer: viewer, host: 'Ana'),
    learned: Cue.values.toSet(),
    before: (s) {
      s.answerResults(results);
      before?.call(s);
    },
  );
  await s.settle(tester);
  return s;
}

String _code(ShellSetup s) => s.me['lobby_code'] as String;

int _posts(ShellSetup s, String endpoint) => s.http.requests
    .where(
      (r) => r.method == 'POST' && r.path == '/lobbies/${_code(s)}/$endpoint/',
    )
    .length;

void main() {
  group('the end board: a tapped control is busy in its own frame, and not '
      'live again until 02 is up', () {
    testWidgets('Play again: its own button busy, the others dead, one '
        'request, busy until its answer puts the phone at 02', (tester) async {
      final s = await _end(tester);
      final path = '/lobbies/${_code(s)}/play-again/';
      s.http.answer('POST', path, s.playedAgain());
      s.answerLobby(_code(s));
      s.answerTable(
        serverMyTable(
          code: _code(s),
          isHost: true,
          gameId: s.gameId,
          phase: 'results',
        ),
      );
      // A slow network: the table's own reads are held throughout.
      final reads = s.http.hold(method: 'GET', path: '/me/table/');
      final answers = s.http.hold(method: 'POST', path: path);

      await pressLikeAFinger(tester, find.text(EndCopy.playAgain));
      await tester.pump();
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton).last).busy,
        isTrue,
        reason: 'busy in the frame of the tap, before any answer',
      );
      await s.settle(tester);
      expect(_posts(s, 'play-again'), 1);

      // Sent, not answered: nothing is live.
      await pressLikeAFinger(tester, find.text(EndCopy.playAgain));
      await pressLikeAFinger(tester, find.text(EndCopy.editDeck));
      await s.settle(tester);
      expect(_posts(s, 'play-again'), 1, reason: 'never sent twice');
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton).last).busy,
        isTrue,
      );
      expect(s.screenOn(tester), AppScreen.end);

      // The answer is the table and where this phone sits: 02 follows it,
      // waiting on no table read, and none is sent after it.
      s.http.stopHolding(method: 'POST', path: path);
      final answered = s.http.requests.length;
      answers.releaseAll();
      // Frames only, no time passing (the table's slow poll never comes due).
      for (
        var i = 0;
        i < 200 && find.byType(AtTableView).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(Duration.zero);
      }
      expect(s.screenOn(tester), AppScreen.table);
      expect([
        for (final r in s.http.requests.skip(answered)) r.path,
      ], isNot(contains('/me/table/')));
      s.http.stopHolding(method: 'GET', path: '/me/table/');
      reads.releaseAll();
      await s.close(tester);
    });

    testWidgets('Edit deck shows busy on itself, not on Play again', (
      tester,
    ) async {
      final s = await _end(tester);
      final path = '/lobbies/${_code(s)}/play-again/';
      s.http.answer(
        'POST',
        path,
        ContractSamples.load('http/lobby/play_again'),
      );
      s.http.hold(method: 'POST', path: path);
      await pressLikeAFinger(tester, find.text(EndCopy.editDeck));
      await s.settle(tester);
      expect(
        find.descendant(
          of: find.byType(PaperScrap),
          matching: find.byType(BusyMark),
        ),
        findsOneWidget,
      );
      // Play again is not silently dead: it says what it waits for.
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton).last).phase,
        ButtonPhase.waiting,
      );
      expect(
        tester.widget<PrimaryButton>(find.byType(PrimaryButton).last).busy,
        isFalse,
        reason: 'it is not what was tapped',
      );
      await s.close(tester);
    });

    testWidgets('a refusal says why, with no "Try again"; "Not sent." with '
        'one only when no answer came; the failure is the control\'s own: '
        'it is gone with the screen', (tester) async {
      final s = await _end(tester);
      final path = '/lobbies/${_code(s)}/play-again/';
      s.http.answer(
        'POST',
        path,
        ContractSamples.load('http/lobby/play_again_not_finished'),
        status: 409,
      );
      await pressLikeAFinger(tester, find.text(EndCopy.playAgain));
      await s.settle(tester);
      expect(find.text(BannerCopy.cannotDeal), findsOneWidget);
      expect(find.text(BannerCopy.tryAgain), findsNothing);
      expect(find.text(BannerCopy.notSent), findsNothing);

      s.http.answer('POST', path, 'Server Error', status: 503);
      await pressLikeAFinger(tester, find.text(EndCopy.playAgain));
      await s.settle(tester);
      expect(find.text(BannerCopy.notSent), findsOneWidget);
      expect(find.text(BannerCopy.tryAgain), findsOneWidget);
      expect(_posts(s, 'play-again'), 2);

      // The table moves on by itself (someone else dealt): the phone is at
      // 02, and what failed on the end board is not carried there.
      s.answerLobby(_code(s));
      s.answerTable(
        serverMyTable(
          code: _code(s),
          isHost: true,
          gameId: s.gameId,
          phase: 'results',
        ),
      );
      s.http.answer(
        'POST',
        path,
        ContractSamples.load('http/lobby/play_again'),
      );
      await pressLikeAFinger(tester, find.text(BannerCopy.tryAgain));
      await s.settle(tester);
      expect(s.screenOn(tester), AppScreen.table);
      expect(find.text(BannerCopy.notSent), findsNothing);
      await s.close(tester);
    });

    testWidgets('a guest\'s Leave: busy on the word itself; a phone already '
        'off the table counts as left', (tester) async {
      final s = await _end(tester, viewer: 'Ben');
      final path = '/lobbies/${_code(s)}/leave/';
      s.http.answer(
        'POST',
        path,
        ContractSamples.load('http/lobby/leave_not_member'),
        status: 400,
      );
      s.http.answer(
        'GET',
        '/me/table/',
        ContractSamples.map('http/lobby/my_table_none'),
      );
      s.answerHome();
      final leave = find.text(EndCopy.leave);
      await plainTap(
        tester,
        leave,
        why: 'the busy mark is read in the frame of the tap',
      );
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(PaperScrap),
          matching: find.byType(BusyMark),
        ),
        findsOneWidget,
        reason: 'busy on the scrap itself, in the frame of the tap',
      );
      await s.settle(tester);
      expect(find.byType(JoinScreen), findsOneWidget);
      expect(find.text(BannerCopy.notSent), findsNothing);
      await s.close(tester);
    });
  });

  group('a game screen whose data is not here is its own frame, with the '
      'waiting body in it', () {
    testWidgets('08: the sky and its headline, never a bare ground; no sign '
        'before the first moment, the lanterns after it, one line when it '
        'is slow', (tester) async {
      final me = recordedMe('me_discussion_choose_seer');
      final s = await ShellSetup.pump(tester, me, holdMe: true);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.byType(TalkWait), findsOneWidget);
      expect(find.byType(GameWait), findsNothing);
      expect(
        tester.widget<SquareSky>(find.byType(SquareSky)).title,
        TalkCopy.headline,
      );
      expect(_sign(tester), 0, reason: 'a quick answer shows no sign');

      await _wait(tester, Motion.signAfter + Motion.settle);
      expect(_sign(tester), 1);
      expect(find.text(BannerCopy.slow), findsNothing);

      await _wait(tester, Motion.slowAfter);
      expect(find.text(BannerCopy.slow), findsOneWidget);

      s.answerNightResultsSeen();
      s.meReplies!.releaseAll();
      await s.settle(tester);
      expect(find.byType(TalkView), findsOneWidget);
      expect(find.byType(Waiting), findsNothing);
      await s.close(tester);
    });

    testWidgets('an answer that comes in the first moment never shows a '
        'sign, and nothing is held back for it', (tester) async {
      final me = recordedMe('me_discussion_choose_seer');
      final s = await ShellSetup.pump(tester, me, holdMe: true);
      s.answerNightResultsSeen();
      for (var ms = 0; ms < 100; ms += 20) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(_sign(tester), 0);
      }
      s.meReplies!.releaseAll();
      // The screen is there within a few frames of the answer, long before
      // a sign would have come: no minimum time on content.
      var frames = 0;
      while (find.byType(TalkView).evaluate().isEmpty && frames < 10) {
        await tester.pump(const Duration(milliseconds: 16));
        frames++;
      }
      expect(find.byType(TalkView), findsOneWidget);
      expect(frames * 16, lessThan(Motion.signAfter.inMilliseconds));
      expect(_sign(tester), 0, reason: 'a sign was never seen');
      await s.settle(tester);
      expect(find.byType(WaitingSign), findsNothing);
      await s.close(tester);
    });

    testWidgets('a game that cannot be read: "One moment" in the frame, '
        'with "Try again" that reads it now', (tester) async {
      final me = recordedMe('me_discussion_choose_seer');
      final s = await ShellSetup.pump(tester, me, before: (s) => s.failMe());
      await s.settle(tester);
      expect(find.byType(TalkWait), findsOneWidget);
      expect(find.text(BannerCopy.offline), findsOneWidget);
      final asked = s.http.requests
          .where((r) => r.path.endsWith('/me/') && r.method == 'GET')
          .length;
      s.answerMe(me);
      s.answerNightResultsSeen();
      await pressLikeAFinger(tester, find.text(BannerCopy.tryAgain));
      await s.settle(tester);
      expect(
        s.http.requests
            .where((r) => r.path.endsWith('/me/') && r.method == 'GET')
            .length,
        greaterThan(asked),
      );
      expect(find.byType(TalkView), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('the end board: the results being read is the screen\'s '
        'ground and the waiting body', (tester) async {
      final results = recordedResults('results');
      late HeldReplies held;
      final s = await ShellSetup.pump(
        tester,
        resultsMeFor(results, viewer: 'Ben', host: 'Ana'),
        before: (s) {
          s.answerResults(results);
          held = s.http.hold(
            method: 'GET',
            path: '/onuw/games/${s.gameId}/results/',
          );
        },
      );
      await _wait(tester, Motion.signAfter + Motion.settle);
      expect(find.byType(EndWaiting), findsOneWidget);
      expect(find.byType(Waiting), findsOneWidget);
      held.releaseAll();
      await s.settle(tester);
      expect(find.byType(EndBoardView), findsOneWidget);
      await s.close(tester);
    });
  });

  group('losing the server keeps the seat and says one line', () {
    testWidgets('fetches failing with the socket up: "One moment" over the '
        'same screen; back, it goes', (tester) async {
      final me = recordedMe('me_choose_prompt_seer');
      final s = await ShellSetup.pump(tester, me);
      await s.settle(tester);
      expect(find.text(BannerCopy.offline), findsNothing);
      final screen = s.screenOn(tester);

      s.failMe();
      s.resume();
      await s.settle(tester);
      expect(find.text(BannerCopy.offline), findsOneWidget);
      expect(s.screenOn(tester), screen, reason: 'the seat and the screen');

      s.answerMe(me);
      await s.settle(tester);
      expect(find.text(BannerCopy.offline), findsNothing);
      await s.close(tester);
    });

    testWidgets('the socket down alone changes nothing', (tester) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_choose_prompt_seer'),
      );
      await s.settle(tester);
      s.socket(connected: false);
      await s.settle(tester);
      expect(find.text(BannerCopy.offline), findsNothing);
      await s.close(tester);
    });

    testWidgets('with reduce motion the line is cut in', (tester) async {
      final me = recordedMe('me_choose_prompt_seer');
      final s = await ShellSetup.pump(tester, me, disableAnimations: true);
      await s.settle(tester);
      s.failMe();
      s.resume();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      final line = find.text(BannerCopy.offline);
      expect(line, findsOneWidget);
      expect(
        tester
            .widget<Opacity>(
              find.ancestor(of: line, matching: find.byType(Opacity)).first,
            )
            .opacity,
        1,
      );
      await s.close(tester);
    });
  });
}
