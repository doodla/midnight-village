import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/primitives/band.dart';
import 'package:midnight_village/design_system/primitives/panels.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/player_token.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/progress_pips.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/role_sheet_body.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/vote_screen.dart';

import '../../../helpers/component_sheet.dart' show holdDown, holdAndLetGo;
import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/sheet/sheet_data.dart' as sheet;
import '../../../helpers/shell_setup.dart';
import '../../../helpers/truncated_text.dart';

// 08 Talk and 09 Vote through the real shell, on a phone of recorded game 7
// (Ana, the Seer and the host) unless a test says: every answer a recorded
// protocol-2 payload.

PrimaryButton _primary(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton).last);

String _button(WidgetTester tester) => _primary(tester).label;

ButtonPhase _phase(WidgetTester tester) => _primary(tester).phase;

/// The bodies of every POST to [endpoint], in the order they went.
List<Object?> _bodies(ShellSetup s, String endpoint) => [
  for (final r in s.http.requests)
    if (r.method == 'POST' && r.path == '/onuw/games/${s.gameId}$endpoint')
      r.data,
];

/// The vote row of [name].
PlayerRow _row(WidgetTester tester, String name) =>
    tester.widget<PlayerRow>(find.widgetWithText(PlayerRow, name));

DateTime _before(Map<String, dynamic> me, int seconds) => DateTime.parse(
  me['deadline'] as String,
).subtract(Duration(seconds: seconds));

const _everything = {...Cue.values};

void main() {
  group('08 Talk', () {
    testWidgets('fed from /me/: the seconds left by the deadline, everyone in '
        'seat order with whole names, the deck, counts only; "Ready to vote" '
        'outlined and never locked', (tester) async {
      final me = recordedMe('me_discussion_choose_seer');
      final s = await ShellSetup.pump(
        tester,
        me,
        clock: _before(me, 14),
        learned: _everything,
      );
      await s.settle(tester);
      expect(find.byType(TalkScreen), findsOneWidget);
      expect(find.text(TalkCopy.headline), findsOneWidget);
      expect(tester.widget<TimerBand>(find.byType(TimerBand)).secondsLeft, 14);

      final names = tester.widget<TableNames>(find.byType(TableNames));
      expect(names.seats.map((p) => p.name), [
        'Ana',
        'Ben',
        'Cleo',
        'Dev',
        'Esme',
      ]);
      expect(
        find.byType(RoleCard),
        findsNWidgets((me['roles_in_game'] as List).length),
      );

      expect(find.text('0 of 5 ready'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ProgressPips),
          matching: find.byType(PlayerToken),
        ),
        findsNothing,
        reason: 'who is slow never shows',
      );
      expect(_button(tester), TalkCopy.readyToVote);
      expect(_phase(tester), ButtonPhase.quiet);

      s.ws.addServerEvent(ContractSamples.map('ws/game/progress_talk'));
      await s.settle(tester);
      expect(find.text('1 of 5 ready'), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('Ready, then not: each shows on the tap; the second waits for '
        'the first and they reach the server in tap order', (tester) async {
      final me = recordedMe('me_discussion_choose_seer');
      final s = await ShellSetup.pump(tester, me, learned: _everything);
      await s.settle(tester);
      final replies = s.http.hold(
        method: 'POST',
        path: '/onuw/games/${s.gameId}/ready/',
      );
      s.answerPost('/ready/', 'game/ready_talk');
      await tester.tap(find.byType(PrimaryButton).last);
      await tester.pump();
      expect(_button(tester), CommonCopy.readyDone, reason: 'before an answer');
      expect(_phase(tester), ButtonPhase.quiet, reason: 'never locked');

      s.answerPost('/ready/', 'game/ready_talk_off');
      await tester.tap(find.byType(PrimaryButton).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      expect(_button(tester), TalkCopy.readyToVote);
      expect(s.posts('/ready/'), 1, reason: 'one in flight at a time');

      replies.release();
      await s.settle(tester);
      expect(s.posts('/ready/'), 2);
      replies.releaseAll();
      await s.settle(tester);
      expect(_bodies(s, '/ready/'), [
        {'ready': true, 'stage': me['stage']},
        {'ready': false, 'stage': me['stage']},
      ]);
      expect(_button(tester), TalkCopy.readyToVote);
      await s.close(tester);
    });

    testWidgets('a restart mid-talk after Ready opens at "Ready ✓" and sends '
        'nothing', (tester) async {
      final s = await ShellSetup.pump(tester, recordedMe('me_talk_ready'));
      await s.settle(tester);
      expect(_button(tester), CommonCopy.readyDone);
      expect(find.text('1 of 5 ready'), findsOneWidget);
      expect(s.posts('/ready/'), 0);
      // Tapped again: taken back.
      s.answerPost('/ready/', 'game/ready_talk_off');
      await tester.tap(find.byType(PrimaryButton).last);
      await s.settle(tester);
      expect(_bodies(s, '/ready/').single, {
        'ready': false,
        'stage': recordedMe('me_talk_ready')['stage'],
      });
      await s.close(tester);
    });

    testWidgets('a 409 is not a failure: /me/ is fetched again, no Try again', (
      tester,
    ) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_discussion_choose_seer'),
        learned: _everything,
      );
      await s.settle(tester);
      s.answerPost('/ready/', 'game/ready_wrong_stage', status: 409);
      final fetched = s.meFetches;
      await tester.tap(find.byType(PrimaryButton).last);
      await s.settle(tester);
      expect(s.meFetches, greaterThan(fetched));
      expect(find.text(BannerCopy.notSent), findsNothing);
      expect(find.text(BannerCopy.tryAgain), findsNothing);
      await s.close(tester);
    });

    testWidgets('Try again only when no answer came; it reads /me/ and sends '
        'the original again', (tester) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_discussion_choose_seer'),
        learned: _everything,
      );
      await s.settle(tester);
      s.failPost('/ready/');
      await tester.tap(find.byType(PrimaryButton).last);
      await s.settle(tester);
      expect(find.text(BannerCopy.notSent), findsOneWidget);
      expect(_button(tester), CommonCopy.readyDone, reason: 'still shown');

      s.answerPost('/ready/', 'game/ready_talk');
      final fetched = s.meFetches;
      await tester.tap(find.text(BannerCopy.tryAgain));
      await s.settle(tester);
      expect(s.meFetches, greaterThan(fetched));
      final bodies = _bodies(s, '/ready/');
      expect(bodies, hasLength(2));
      expect(bodies.last, bodies.first);
      expect(find.text(BannerCopy.notSent), findsNothing);
      await s.close(tester);
    });

    testWidgets('My night: the hold cue in a first game; held, the result '
        'first; the first reveal acknowledges the results, once', (
      tester,
    ) async {
      final me = recordedMe('me_discussion_choose_seer');
      final s = await ShellSetup.pump(
        tester,
        me,
        learned: const {Cue.hold, Cue.holdYou, Cue.nightChoose},
      );
      await s.settle(tester);
      expect(find.text(CommonCopy.hold), findsOneWidget, reason: 'first talk');
      s.answerPost('/night-results/seen/', 'game/night_results_seen');

      final gesture = await holdDown(tester, find.byType(PeekBox));
      expect(find.byType(HeldFace), findsOneWidget);
      expect(find.text("Cleo's card: Werewolf."), findsOneWidget);
      await gesture.up();
      await s.settle(tester);
      expect(_bodies(s, '/night-results/seen/'), [
        {'seen': (me['night_results'] as List).length},
      ]);
      expect(find.text(CommonCopy.hold), findsNothing, reason: 'learned');

      await holdAndLetGo(tester, find.byType(PeekBox));
      await s.settle(tester);
      expect(s.posts('/night-results/seen/'), 1);
      await s.close(tester);
    });

    testWidgets('a held deck portrait opens its role', (tester) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_discussion_choose_seer'),
        learned: _everything,
      );
      await s.settle(tester);
      await tester.ensureVisible(find.byType(RoleCard).first);
      await tester.longPress(find.byType(RoleCard).first);
      await tester.pumpAndSettle();
      expect(find.byType(RoleSheetBody), findsOneWidget);
      await tester.tap(find.text(RoleSheetCopy.close));
      await tester.pumpAndSettle();
      expect(find.byType(RoleSheetBody), findsNothing);
      await s.close(tester);
    });
  });

  group('09 Vote', () {
    testWidgets('as the vote opens: every other player, none picked; "Pick a '
        'name"; counts only; the seconds by the deadline', (tester) async {
      final me = recordedMe('me_voting_unpicked');
      final s = await ShellSetup.pump(
        tester,
        me,
        clock: _before(me, 14),
        learned: _everything,
      );
      await s.settle(tester);
      expect(find.byType(VoteScreen), findsOneWidget);
      expect(find.text(VoteCopy.headline), findsOneWidget);
      expect(tester.widget<TimerBand>(find.byType(TimerBand)).secondsLeft, 14);
      final rows = tester.widgetList<PlayerRow>(find.byType(PlayerRow));
      expect(rows.map((r) => r.name), ['Ben', 'Cleo', 'Dev', 'Esme']);
      expect(rows.any((r) => r.picked), isFalse, reason: 'nothing chosen');
      expect(_button(tester), VoteCopy.pickName);
      expect(_phase(tester), ButtonPhase.waiting);
      expect(find.text('0 of 5 locked'), findsOneWidget);

      s.ws.addServerEvent(ContractSamples.map('ws/game/progress_vote'));
      await s.settle(tester);
      expect(find.text('1 of 5 locked'), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('pick, then lock: both show on the tap; the lock goes after '
        'the pick; "Locked" dims every row alike; the cue is learned', (
      tester,
    ) async {
      final me = recordedMe('me_voting_unpicked');
      final s = await ShellSetup.pump(
        tester,
        me,
        learned: _everything.difference({Cue.voteLock}),
      );
      await s.settle(tester);
      final replies = s.http.hold(
        method: 'POST',
        path: '/onuw/games/${s.gameId}/vote/',
      );
      s.answerPost('/vote/', 'game/vote_picked');
      await tester.tap(find.text(sheet.cleo.name));
      await tester.pump();
      expect(_row(tester, sheet.cleo.name).picked, isTrue);
      expect(_button(tester), 'Lock in Cleo');
      expect(_phase(tester), ButtonPhase.ready);

      s.answerPost('/vote/', 'game/vote_locked_v2');
      await tester.tap(find.byType(PrimaryButton).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      expect(_button(tester), VoteCopy.locked);
      expect(_phase(tester), ButtonPhase.done);
      final rows = tester.widgetList<PlayerRow>(find.byType(PlayerRow));
      expect(rows.every((r) => r.dimmed && !r.picked), isTrue);
      expect(s.posts('/vote/'), 1, reason: 'the lock waits for the pick');

      replies.release();
      await s.settle(tester);
      replies.releaseAll();
      await s.settle(tester);
      expect(_bodies(s, '/vote/'), [
        {
          'target_player_id': sheet.cleo.id,
          'lock': false,
          'stage': me['stage'],
        },
        {'target_player_id': sheet.cleo.id, 'lock': true, 'stage': me['stage']},
      ]);
      expect(_button(tester), VoteCopy.locked);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(VoteScreen)),
      );
      expect(container.read(learnedCuesProvider), contains(Cue.voteLock));

      // Locked is final: a tap on a row sends nothing.
      await tester.tap(find.text(sheet.ben.name));
      await s.settle(tester);
      expect(s.posts('/vote/'), 2);
      await s.close(tester);
    });

    testWidgets('a tap on another row moves the pick', (tester) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_voting_unpicked'),
        learned: _everything,
      );
      await s.settle(tester);
      s.answerPost('/vote/', 'game/vote_picked');
      await tester.tap(find.text(sheet.cleo.name));
      await s.settle(tester);
      s.answerPost('/vote/', 'game/vote_repicked');
      final repick = ContractSamples.map('http/game/vote_repicked');
      final other = sheet.fiveSeats.firstWhere(
        (p) => p.id == repick['target_player_id'],
      );
      await tester.tap(find.text(other.name));
      await s.settle(tester);
      expect(_row(tester, other.name).picked, isTrue);
      expect(_row(tester, sheet.cleo.name).picked, isFalse);
      expect(_button(tester), 'Lock in ${other.name}');
      await s.close(tester);
    });

    testWidgets('a restart reads its own vote from /me/: picked, or locked', (
      tester,
    ) async {
      var s = await ShellSetup.pump(tester, recordedMe('me_voting_picked'));
      await s.settle(tester);
      expect(_row(tester, sheet.dev.name).picked, isTrue);
      expect(_button(tester), 'Lock in Dev');
      await s.close(tester);

      s = await ShellSetup.pump(tester, recordedMe('me_voting_locked'));
      await s.settle(tester);
      expect(_button(tester), VoteCopy.locked);
      final rows = tester.widgetList<PlayerRow>(find.byType(PlayerRow));
      expect(rows.every((r) => r.dimmed && !r.picked), isTrue);
      expect(find.text('1 of 5 locked'), findsOneWidget);
      expect(s.posts('/vote/'), 0);
      await s.close(tester);
    });

    testWidgets('a 409 (the vote was revealed) fetches /me/ again, no Try '
        'again', (tester) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_voting_unpicked'),
        learned: _everything,
      );
      await s.settle(tester);
      s.answerPost('/vote/', 'game/vote_after_reveal', status: 409);
      final fetched = s.meFetches;
      await tester.tap(find.text(sheet.cleo.name));
      await s.settle(tester);
      expect(s.meFetches, greaterThan(fetched));
      expect(find.text(BannerCopy.tryAgain), findsNothing);
      await s.close(tester);
    });

    testWidgets('a lock that got no answer: "Not sent." and Try again, which '
        'sends the same lock once more', (tester) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_voting_picked'),
        learned: _everything,
      );
      await s.settle(tester);
      s.failPost('/vote/');
      await tester.tap(find.byType(PrimaryButton).last);
      await s.settle(tester);
      expect(find.text(BannerCopy.notSent), findsOneWidget);
      expect(_button(tester), VoteCopy.locked, reason: 'still shown');

      s.answerPost('/vote/', 'game/vote_locked_v2');
      await tester.tap(find.text(BannerCopy.tryAgain));
      await s.settle(tester);
      final bodies = _bodies(s, '/vote/');
      expect(bodies, hasLength(2));
      expect(bodies.last, bodies.first);
      expect(find.text(BannerCopy.notSent), findsNothing);
      await s.close(tester);
    });

    testWidgets('a refused pick (400) is dropped; nothing to try again', (
      tester,
    ) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_voting_unpicked'),
        learned: _everything,
      );
      await s.settle(tester);
      s.answerPost('/vote/', 'game/vote_invalid_target', status: 400);
      await tester.tap(find.text(sheet.cleo.name));
      await s.settle(tester);
      expect(_button(tester), VoteCopy.pickName);
      expect(find.text(BannerCopy.tryAgain), findsNothing);
      await s.close(tester);
    });
  });

  group('names are never cut', () {
    for (final (width, height) in [
      (320.0, 568.0),
      (360.0, 640.0),
      (390.0, 844.0),
    ]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final (label, me) in [
          (
            'talk at ten',
            () => sheet.tableOf(
              recordedMe('me_discussion_choose_drunk'),
              add: 1,
              rename: sheet.longNames,
            ),
          ),
          (
            'vote at ten',
            () => sheet.tableOf(
              recordedMe('me_voting_unpicked'),
              add: 5,
              rename: const {
                'Ana': 'Christopher',
                'Ben': 'Maximiliano',
                'Seat 33': 'Rosalind Fairweather',
                'Seat 34': 'Bartholomew',
              },
            ),
          ),
          (
            'vote at three',
            () => sheet.tableOf(
              recordedMe('me_voting_unpicked'),
              leave: {sheet.dev.name, sheet.esme.name},
            ),
          ),
        ]) {
          testWidgets('$label, ${width.toInt()} x ${height.toInt()}, text '
              'x$scale', (tester) async {
            tester.view.physicalSize = Size(width, height);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            final s = await ShellSetup.pump(
              tester,
              me(),
              textScale: scale,
              learned: _everything,
            );
            await s.settle(tester);
            expect(tester.takeException(), isNull);
            expect(truncatedText(tester), isEmpty);
            await s.close(tester);
          });
        }
      }
    }
  });
}
