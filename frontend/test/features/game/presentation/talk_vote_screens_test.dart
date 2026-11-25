import '../../../helpers/finger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/night/night_story_view.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/deck_pile.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/name_tag.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/progress_pips.dart';
import 'package:midnight_village/design_system/primitives/role_sheet_body.dart';
import 'package:midnight_village/design_system/primitives/sealed_note.dart';
import 'package:midnight_village/design_system/primitives/sheet_scaffold.dart';
import 'package:midnight_village/design_system/primitives/vote_slip.dart';
import 'package:midnight_village/design_system/primitives/square_sky.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_square.dart';
import 'package:midnight_village/features/game/presentation/shell/vote_screen.dart';

import '../../../helpers/component_sheet.dart' show holdDown;
import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/sheet/sheet_data.dart' as sheet;
import '../../../helpers/shell_setup.dart';
import '../../../helpers/truncated_text.dart';

// 08 Talk and 09 Vote through the real shell, on a phone of recorded game 7
// (Ana, the Seer and the host) unless a test says: every answer a recorded
// payload.

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

/// The vote's slip of [name].
VoteSlip _row(WidgetTester tester, String name) =>
    tester.widget<VoteSlip>(find.widgetWithText(VoteSlip, name));

DateTime _before(Map<String, dynamic> me, int seconds) => DateTime.parse(
  me['deadline'] as String,
).subtract(Duration(seconds: seconds));

const _everything = {...Cue.values};

/// The talk opens My night once and acknowledges the results as it does:
/// that POST is answered from the start.
void _answerAck(ShellSetup s) =>
    s.answerPost('/night-results/seen/', 'game/night_results_seen');

/// Puts My night away when it is up by itself as the talk opens: the first
/// touch anywhere (it is only that touch).
Future<void> _putAway(WidgetTester tester) async {
  await pressAtLikeAFinger(tester, const Offset(4, 400));
  await tester.pumpAndSettle();
}

/// Locked on [name]: that slip lifted and sealed, not dimmed; every other
/// slip dimmed and not picked.
void _expectLockedOn(WidgetTester tester, String name) {
  for (final row in tester.widgetList<VoteSlip>(find.byType(VoteSlip))) {
    final mine = row.name == name;
    expect(row.picked, mine, reason: row.name);
    expect(row.dimmed, !mine, reason: row.name);
  }
}

void main() {
  group('08 Talk', () {
    testWidgets('fed from /me/: the seconds left by the deadline, the title '
        'spoken by the band, every player as a name tag, the deck, counts '
        'only (on the button); "Ready to vote" the one amber action and '
        'never locked', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final me = recordedMe('me_discussion_choose_seer');
      final s = await ShellSetup.pump(
        tester,
        me,
        clock: _before(me, 14),
        learned: _everything,
        before: _answerAck,
      );
      await s.settle(tester);
      expect(find.byType(TalkScreen), findsOneWidget);
      await _putAway(tester);
      final band = tester.widget<SquareSky>(find.byType(SquareSky));
      expect(band.countdown?.secondsNow, 14);
      expect(band.title, TalkCopy.headline);
      expect(find.text(TalkCopy.headline), findsNothing, reason: 'spoken');
      final parsed = GameMe.fromJson(me);
      final tags = tester.widgetList<NameTag>(find.byType(NameTag));
      expect(
        tags.map((t) => t.name),
        sheet.fiveSeats.map((s) => s.name),
        reason: 'every player, in seat order',
      );
      expect(tags.where((t) => t.you).map((t) => t.name), [
        parsed.seats.singleWhere((s) => s.id == parsed.playerId).name,
      ]);
      expect(find.byType(DeckPile), findsNWidgets(parsed.deck.length));

      expect(
        find.descendant(
          of: find.byType(PrimaryButton),
          matching: find.text('0 of 5 ready'),
        ),
        findsOneWidget,
        reason: 'the count is on the button; who is slow never shows',
      );
      expect(find.byType(ProgressPips), findsNothing);
      expect(_button(tester), TalkCopy.readyToVote);
      expect(_phase(tester), ButtonPhase.ready, reason: 'the one amber');

      s.ws.addServerEvent(ContractSamples.map('ws/game/progress_talk'));
      await s.settle(tester);
      expect(find.text('1 of 5 ready'), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('Ready, then not: each shows on the tap; the second waits for '
        'the first and they reach the server in tap order', (tester) async {
      final me = recordedMe('me_discussion_choose_seer');
      final s = await ShellSetup.pump(
        tester,
        me,
        learned: _everything,
        before: _answerAck,
      );
      await s.settle(tester);
      await _putAway(tester); // Ready is under the sheet it opened with
      final replies = s.http.hold(
        method: 'POST',
        path: '/onuw/games/${s.gameId}/ready/',
      );
      s.answerPost('/ready/', 'game/ready_talk');
      await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
      await tester.pump();
      expect(_button(tester), CommonCopy.readyDone, reason: 'before an answer');
      expect(_phase(tester), ButtonPhase.on, reason: 'never locked');
      expect(find.text('1 of 5 ready'), findsOneWidget, reason: 'counted');

      s.answerPost('/ready/', 'game/ready_talk_off');
      await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      expect(_button(tester), TalkCopy.readyToVote);
      expect(find.text('0 of 5 ready'), findsOneWidget);
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

    testWidgets('a count event while the tap is unconfirmed fetches /me/ '
        'instead of adding it again', (tester) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_discussion_choose_seer'),
        learned: _everything,
        before: _answerAck,
      );
      await s.settle(tester);
      await _putAway(tester); // Ready is under the sheet it opened with
      s.answerPost('/ready/', 'game/ready_talk');
      await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
      await s.settle(tester);
      expect(find.text('1 of 5 ready'), findsOneWidget);
      // The server now counts it, and says so in the event and in /me/.
      s.answerMe(recordedMe('me_talk_ready'));
      final fetched = s.meFetches;
      s.ws.addServerEvent(ContractSamples.map('ws/game/progress_talk'));
      await s.settle(tester);
      expect(s.meFetches, greaterThan(fetched));
      expect(find.text('1 of 5 ready'), findsOneWidget, reason: 'not 2');
      expect(_button(tester), CommonCopy.readyDone);
      await s.close(tester);
    });

    testWidgets('a restart mid-talk after Ready opens at "Ready ✓" and sends '
        'nothing', (tester) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_talk_ready'),
        before: _answerAck,
      );
      await s.settle(tester);
      await _putAway(tester); // Ready is under the sheet it opened with
      expect(_button(tester), CommonCopy.readyDone);
      expect(find.text('1 of 5 ready'), findsOneWidget);
      expect(s.posts('/ready/'), 0);
      // Tapped again: taken back.
      s.answerPost('/ready/', 'game/ready_talk_off');
      await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
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
        before: _answerAck,
      );
      await s.settle(tester);
      await _putAway(tester); // Ready is under the sheet it opened with
      s.answerPost('/ready/', 'game/ready_wrong_stage', status: 409);
      final fetched = s.meFetches;
      await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
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
        before: _answerAck,
      );
      await s.settle(tester);
      await _putAway(tester); // Ready is under the sheet it opened with
      s.failPost('/ready/');
      await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
      await s.settle(tester);
      expect(find.text(BannerCopy.notSent), findsOneWidget);
      expect(_button(tester), CommonCopy.readyDone, reason: 'still shown');

      s.answerPost('/ready/', 'game/ready_talk');
      final fetched = s.meFetches;
      await pressLikeAFinger(tester, find.text(BannerCopy.tryAgain));
      await s.settle(tester);
      expect(s.meFetches, greaterThan(fetched));
      final bodies = _bodies(s, '/ready/');
      expect(bodies, hasLength(2));
      expect(bodies.last, bodies.first);
      expect(find.text(BannerCopy.notSent), findsNothing);
      await s.close(tester);
    });

    testWidgets('a night that told something opens the talk with My night '
        'up on the board, no touch; the ack goes as it shows; the first touch '
        'puts it away; held, the note shows the same night again', (
      tester,
    ) async {
      final me = recordedMe('me_discussion_choose_seer');
      final s = await ShellSetup.pump(
        tester,
        me,
        learned: const {Cue.hold, Cue.nightChoose},
        before: _answerAck,
      );
      await s.settle(tester);
      expect(find.byType(MyNightPanel), findsOneWidget, reason: 'no touch');
      expect(find.byType(NightStoryView), findsOneWidget);
      expect(
        find.text("Cleo's card was the Werewolf.", findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(DeckPile), findsNothing, reason: "the deck's place");
      expect(find.byType(SheetScaffold), findsNothing, reason: 'not a sheet');
      expect(_bodies(s, '/night-results/seen/'), [
        {'seen': (me['night_results'] as List).length},
      ], reason: 'shown is seen');
      expect(find.text(CommonCopy.hold), findsNothing, reason: 'taught on 04');

      // The first touch only puts it away: Ready is not pressed by it.
      await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
      await tester.pumpAndSettle();
      expect(find.byType(NightStoryView), findsNothing);
      expect(find.byType(DeckPile), findsWidgets);
      expect(_button(tester), TalkCopy.readyToVote);

      // Ready works at once with it away.
      s.answerPost('/ready/', 'game/ready_talk');
      await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
      await tester.pump();
      expect(_button(tester), CommonCopy.readyDone);

      // Held later: the same face, the result first, only while held; no
      // second ack.
      final finger = await holdDown(tester, find.byType(SealedNote));
      expect(find.byType(NightStoryView), findsOneWidget);
      expect(
        find.text("Cleo's card was the Werewolf.", findRichText: true),
        findsOneWidget,
      );
      await finger.up();
      await tester.pump();
      expect(
        find.byType(NightStoryView),
        findsNothing,
        reason: 'only while held',
      );
      await s.settle(tester);
      expect(s.posts('/night-results/seen/'), 1);
      await s.close(tester);
    });

    testWidgets('My night shows in the same place wherever the note is held, '
        "from the board's top (the owner, 23 Nov 2026: \"it shows up in a "
        'different spot"; "the empty space up top")', (tester) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_talk_results_seen'),
        learned: _everything,
        before: _answerAck,
      );
      await s.settle(tester);
      final note = tester.getRect(find.byType(SealedNote));
      final board = tester.getRect(find.byType(SquareBoard));
      Rect? first;
      for (final at in [
        note.topLeft + const Offset(8, 8),
        note.center,
        note.bottomRight - const Offset(8, 8),
      ]) {
        final finger = await tester.startGesture(at);
        await tester.pump(HoldToReveal.holdDelay);
        await tester.pump(HoldToReveal.revealedAfter);
        final face = tester.getRect(find.byType(NightStoryView));
        expect(face.top - board.top, lessThan(Space.lg), reason: 'the top');
        expect(face, first ?? face, reason: 'where it was held: no matter');
        first ??= face;
        await finger.up();
        await tester.pump();
        expect(find.byType(NightStoryView), findsNothing, reason: 'let go');
      }
      await s.close(tester);
    });

    testWidgets('it opens once: a restart after the ack opens nothing', (
      tester,
    ) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_talk_results_seen'),
        learned: _everything,
      );
      await s.settle(tester);
      expect(find.byType(NightStoryView), findsNothing);
      expect(find.byType(SealedNote), findsOneWidget);
      expect(s.posts('/night-results/seen/'), 0);
      await s.close(tester);
    });

    testWidgets('a night that told nothing ("You slept.") opens nothing; the '
        'first hold of My night acknowledges, once', (tester) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_discussion_choose_villager'),
        learned: _everything,
        before: _answerAck,
      );
      await s.settle(tester);
      expect(find.byType(NightStoryView), findsNothing);
      expect(find.byType(SealedNote), findsOneWidget);
      expect(s.posts('/night-results/seen/'), 0);
      var finger = await holdDown(tester, find.byType(SealedNote));
      expect(find.text(NightCopy.slept, findRichText: true), findsOneWidget);
      await finger.up();
      await s.settle(tester);
      expect(s.posts('/night-results/seen/'), 1);
      finger = await holdDown(tester, find.byType(SealedNote));
      await finger.up();
      await s.settle(tester);
      expect(s.posts('/night-results/seen/'), 1);
      await s.close(tester);
    });

    testWidgets('a held deck portrait opens its role', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_discussion_choose_seer'),
        learned: _everything,
        before: _answerAck,
      );
      await s.settle(tester);
      await _putAway(tester);
      await tester.ensureVisible(find.byType(DeckPile).first);
      await tester.longPress(find.byType(DeckPile).first);
      await tester.pumpAndSettle();
      expect(find.byType(RoleSheetBody), findsOneWidget);
      await pressLikeAFinger(tester, find.text(RoleSheetCopy.close));
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
      final sky = tester.widget<SquareSky>(find.byType(SquareSky));
      expect((sky.countdown?.secondsNow, sky.clock), (14, SkyClock.vote));
      final rows = tester.widgetList<VoteSlip>(find.byType(VoteSlip));
      // Every other player; this phone's own name is never listed.
      expect(rows.map((r) => r.name), ['Ben', 'Cleo', 'Dev', 'Esme']);
      expect(rows.any((r) => r.picked), isFalse, reason: 'nothing chosen');
      expect(_button(tester), VoteCopy.pickName);
      expect(_phase(tester), ButtonPhase.locked, reason: 'says what unlocks');
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
      // Ana settles on Cleo: the recorded pick that names her.
      s.answerPost('/vote/', 'game/vote_repicked');
      await pressLikeAFinger(tester, find.text(sheet.cleo.name));
      await tester.pump();
      expect(_row(tester, sheet.cleo.name).picked, isTrue);
      expect(_button(tester), 'Lock in Cleo');
      expect(_phase(tester), ButtonPhase.ready);

      s.answerPost('/vote/', 'game/vote_locked');
      await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
      expect(_button(tester), VoteCopy.locked);
      expect(_phase(tester), ButtonPhase.done);
      _expectLockedOn(tester, sheet.cleo.name);
      expect(find.text('1 of 5 locked'), findsOneWidget, reason: 'counted');
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
      await pressLikeAFinger(tester, find.text(sheet.ben.name));
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
      // The recorded pick, then the recorded re-pick: whom each names.
      seat(String sample) => sheet.fiveSeats.firstWhere(
        (p) =>
            p.id ==
            ContractSamples.map('http/game/$sample')['target_player_id'],
      );
      final first = seat('vote_picked');
      final other = seat('vote_repicked');
      s.answerPost('/vote/', 'game/vote_picked');
      await pressLikeAFinger(tester, find.text(first.name));
      await s.settle(tester);
      s.answerPost('/vote/', 'game/vote_repicked');
      await pressLikeAFinger(tester, find.text(other.name));
      await s.settle(tester);
      expect(_row(tester, other.name).picked, isTrue);
      expect(_row(tester, first.name).picked, isFalse);
      expect(_button(tester), 'Lock in ${other.name}');
      await s.close(tester);
    });

    testWidgets('a restart reads its own vote from /me/: picked, or locked', (
      tester,
    ) async {
      var s = await ShellSetup.pump(tester, recordedMe('me_voting_picked'));
      await s.settle(tester);
      expect(_row(tester, sheet.cleo.name).picked, isTrue);
      expect(_button(tester), 'Lock in Cleo');
      await s.close(tester);

      s = await ShellSetup.pump(tester, recordedMe('me_voting_locked'));
      await s.settle(tester);
      expect(_button(tester), VoteCopy.locked);
      _expectLockedOn(tester, sheet.cleo.name);
      expect(find.text('1 of 5 locked'), findsOneWidget, reason: 'the server');
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
      await pressLikeAFinger(tester, find.text(sheet.cleo.name));
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
      await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
      await s.settle(tester);
      expect(find.text(BannerCopy.notSent), findsOneWidget);
      expect(_button(tester), VoteCopy.locked, reason: 'still shown');

      s.answerPost('/vote/', 'game/vote_locked');
      await pressLikeAFinger(tester, find.text(BannerCopy.tryAgain));
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
      await pressLikeAFinger(tester, find.text(sheet.cleo.name));
      await s.settle(tester);
      expect(_button(tester), VoteCopy.pickName);
      expect(find.text(BannerCopy.tryAgain), findsNothing);
      await s.close(tester);
    });
  });

  group('the talk on a small phone', () {
    // The playtest: the deck's last chips ran under the fade (the
    // Troublemaker read as not in play), and the open card's words fell
    // below the fold. Every chip and every word above the count, nothing
    // faded over them: game 7's deck at the gallery's phones, text x1 and
    // x1.3; a nine-role deck (ten at the table) at text x1. (Nine roles at
    // 320 x1.3, or a phone as short as 640, still scroll the deck.)
    Map<String, dynamic> five() => recordedMe('me_discussion_choose_seer');
    Map<String, dynamic> ten() => sheet.tableOf(
      recordedMe('me_discussion_choose_drunk'),
      add: 1,
      rename: sheet.longNames,
    );
    for (final (width, scale, label, me) in [
      for (final width in [320.0, 360.0, 390.0]) ...[
        (width, 1.0, 'five', five),
        (width, 1.3, 'five', five),
        (width, 1.0, 'ten, nine roles', ten),
      ],
    ]) {
      const height = 844.0;
      {
        final size = '${width.toInt()} x ${height.toInt()}, text x$scale';
        Future<ShellSetup> pump(WidgetTester tester) async {
          tester.view.physicalSize = Size(width, height);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final s = await ShellSetup.pump(
            tester,
            me(),
            textScale: scale,
            learned: _everything,
            before: _answerAck,
          );
          await s.settle(tester);
          return s;
        }

        // A fade over the body's foot (the sun's own fade into the ground,
        // in the band, is the picture's).
        bool faded() {
          final fades = find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).gradient is LinearGradient &&
                (w.decoration as BoxDecoration).gradient!.colors.first.a == 0,
          );
          final inBand = find
              .descendant(of: find.byType(SquareSky), matching: fades)
              .evaluate()
              .toSet();
          return fades.evaluate().any((e) => !inBand.contains(e));
        }

        testWidgets('$label, $size: the open card\'s words are all above the '
            'note, on the board', (tester) async {
          final s = await pump(tester);
          final count = tester.getRect(find.byType(SealedNote)).top;
          final words = find.descendant(
            of: find.byType(NightStoryView),
            matching: find.byType(RichText),
          );
          expect(words, findsWidgets);
          for (final element in words.evaluate()) {
            final rect = tester.getRect(
              find.byElementPredicate((e) => e == element),
            );
            expect(rect.bottom, lessThanOrEqualTo(count));
          }
          expect(faded(), isFalse);
          await s.close(tester);
        });

        testWidgets('$label, $size: put away, every pile of the deck and '
            'every name tag is whole above the note, none faded', (
          tester,
        ) async {
          final s = await pump(tester);
          await _putAway(tester);
          final count = tester.getRect(find.byType(SealedNote)).top;
          final chips = find.byWidgetPredicate(
            (w) => w is DeckPile || w is NameTag,
          );
          final parsed = GameMe.fromJson(me());
          expect(
            chips,
            findsNWidgets(parsed.deck.length + parsed.seats.length),
          );
          // Ten long names on the narrowest phone are more than the board
          // holds: it scrolls there, and its end comes into view whole.
          final scrolls = width < 360 && label != 'five';
          if (scrolls) {
            await tester.drag(find.byType(SquareBoard), const Offset(0, -3000));
            await tester.pumpAndSettle();
            final last = tester.getRect(find.byType(NameTag).last);
            expect(last.bottom, lessThanOrEqualTo(count));
          } else {
            for (final element in chips.evaluate()) {
              final rect = tester.getRect(
                find.byElementPredicate((e) => e == element),
              );
              expect(rect.bottom, lessThanOrEqualTo(count));
            }
            expect(faded(), isFalse);
          }
          expect(truncatedText(tester), isEmpty);
          await s.close(tester);
        });
      }
    }
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
              before: _answerAck,
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
