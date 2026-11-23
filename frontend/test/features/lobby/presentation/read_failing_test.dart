import '../../../helpers/finger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/waiting_sign.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/design_system/primitives/text_action.dart';
import 'package:midnight_village/features/lobby/presentation/join_screen.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/outcome_samples.dart';
import '../../../helpers/shell_setup.dart';
import '../../../helpers/table_setup.dart';

// A tap that leads to another screen is freed when its write has been
// answered and the read of the next screen is failing: the phone says "One
// moment" with "Try again" (the first read of a cold start says it too),
// instead of a control that spins for as long as the phone is out of reach.
// The request is never sent twice for it.

void failTable(TableSetup s) =>
    s.http.answer('GET', '/me/table/', 'Server Error', status: 503);

void main() {
  testWidgets('the app\'s first /me/table/ failing: "One moment" with "Try '
      'again", which reads it now (signed in, no link)', (tester) async {
    late TableSetup setup;
    setup = await TableSetup.pump(
      tester,
      signedInAs: 'Ben',
      before: (s) => failTable(s),
    );
    await setup.settle(tester);
    expect(find.text(BannerCopy.offline), findsOneWidget);
    expect(find.text(JoinCopy.startTable), findsNothing, reason: 'not 01');
    final reads = setup.count('GET', '/me/table/');

    setup.answerTable();
    await pressLikeAFinger(tester, find.text(BannerCopy.tryAgain));
    await setup.settle(tester);
    expect(setup.count('GET', '/me/table/'), greaterThan(reads));
    expect(find.text(JoinCopy.startTable), findsOneWidget, reason: '01');
    expect(find.text(BannerCopy.offline), findsNothing);
    await setup.close(tester);
  });

  for (final (way, tap) in [
    ('Start a table', JoinCopy.startTable),
    ('Join', JoinCopy.join),
  ]) {
    testWidgets('$way: answered, then the seat cannot be read: the button is '
        'freed and the app says "One moment" with "Try again"; sent once', (
      tester,
    ) async {
      final start = way == 'Start a table';
      final lobby = v2Lobby(
        start ? 'created_with_defaults' : 'detail_auto_deck_5',
      );
      final setup = await TableSetup.pump(
        tester,
        signedInAs: 'Ben',
        timesOut: false,
      );
      if (start) {
        setup.http.answer('POST', '/lobbies/', lobby, status: 201);
      } else {
        setup.http.answer(
          'POST',
          '/lobbies/V9YC2J/join/',
          ContractSamples.map('http/lobby/joined'),
        );
        await pressLikeAFinger(tester, find.text(JoinCopy.joinTable));
        await tester.pump();
        await tester.enterText(find.byType(TextField).last, 'V9YC2J');
        await tester.pump();
      }
      failTable(setup);
      await pressLikeAFinger(tester, find.text(tap).last);
      await setup.settle(tester);
      await setup.settle(tester);

      expect(find.text(BannerCopy.offline), findsOneWidget);
      expect(find.text(BannerCopy.tryAgain), findsOneWidget);
      expect(
        find.byType(JoinScreen),
        findsNothing,
        reason: 'the form is not left spinning',
      );
      expect(
        setup.http.requests.where((r) => r.method == 'POST').length,
        1,
        reason: 'the write is sent once',
      );
      await setup.close(tester);
    });
  }

  testWidgets('Deal: answered, then the table cannot be read: Deal is freed '
      'and "One moment" says so; sent once', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_auto_deck_5'),
      viewer: 'Ana',
      timesOut: false,
    );
    final started = ContractSamples.map('http/game/started_with_look');
    setup.http.answer(
      'POST',
      '/onuw/lobbies/${setup.code}/start/',
      started,
      status: 201,
    );
    setup.answerGame(recordedMe('me_look_stage'));
    failTable(setup);
    await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
    await setup.settle(tester);
    await setup.settle(tester);
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton).last).busy,
      isFalse,
    );
    expect(find.text(BannerCopy.offline), findsOneWidget);
    expect(setup.count('POST', '/onuw/lobbies/${setup.code}/start/'), 1);
    await setup.close(tester);
  });

  testWidgets('Leave at 02: busy until 01 is named (no live gap after the '
      'answer); answered, then the seat cannot be read: Leave is freed and '
      '"One moment" with "Try again" reads again, never leaving twice', (
    tester,
  ) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_auto_deck_5'),
      viewer: 'Ben',
      timesOut: false,
    );
    final path = '/lobbies/${setup.code}/leave/';
    setup.http.answer('POST', path, ContractSamples.load('http/lobby/left'));
    final reads = setup.http.hold(method: 'GET', path: '/me/table/');
    setup.http.answer('GET', '/me/table/', 'Server Error', status: 503);
    TextAction leave() =>
        tester.widget<TextAction>(find.byType(TextAction).last);

    await pressLikeAFinger(tester, find.text(CommonCopy.leave).last);
    await tester.pump();
    expect(leave().busy, isTrue, reason: 'busy in the frame of the tap');
    await setup.settle(tester);
    expect(setup.count('POST', path), 1);
    // Answered; where the phone sits is not named yet: still busy, and a
    // tap sends nothing.
    expect(leave().busy, isTrue);
    await pressLikeAFinger(tester, find.text(CommonCopy.leave).last);
    await setup.settle(tester);
    expect(setup.count('POST', path), 1);

    // The read fails instead: Leave is freed and says so.
    setup.http.stopHolding(method: 'GET', path: '/me/table/');
    reads.releaseAll();
    await setup.settle(tester);
    await setup.settle(tester);
    expect(find.text(BannerCopy.offline), findsWidgets);
    expect(find.text(BannerCopy.tryAgain), findsWidgets);
    expect(setup.count('POST', path), 1);
    await setup.close(tester);
  });

  testWidgets('02 and 03 wait with the lanterns, in their own place: never a '
      'bare ground', (tester) async {
    late HeldReplies lobby;
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_auto_deck_5'),
      viewer: 'Ana',
      timesOut: false,
      before: (s) =>
          lobby = s.http.hold(method: 'GET', path: '/lobbies/${s.code}/'),
    );
    await tester.pump(Motion.signAfter + Motion.settle);
    expect(find.byType(Waiting), findsOneWidget, reason: '02 waits');
    lobby.releaseAll();
    await setup.settle(tester);
    expect(find.byType(Waiting), findsNothing);
    await setup.close(tester);
  });

  testWidgets('Play again at 11: the answer is the table and where the host '
      'sits: 02 at once, nothing read after it (a failing /me/table/ is never '
      'asked), and the request is sent once', (tester) async {
    final results = recordedResults('results');
    final s = await ShellSetup.pump(
      tester,
      resultsMeFor(results, viewer: 'Ana', host: 'Ana'),
      before: (s) => s.answerResults(results),
    );
    await s.settle(tester);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await pressLikeAFinger(tester, find.text(CountCopy.seeWhoWon));
    await s.settle(tester);
    final code = s.me['lobby_code'] as String;
    final path = '/lobbies/$code/play-again/';
    s.http.answer('POST', path, s.playedAgain());
    s.http.answer('GET', '/me/table/', 'Server Error', status: 503);
    final reads = s.http.requests.where((r) => r.path == '/me/table/').length;

    await pressLostToday(
      tester,
      find.text(ResultsCopy.playAgain),
      why: lostPastTheSink,
    );
    // Frames only, no time passing: the table's slow poll never comes due.
    for (var i = 0; i < 200 && s.screenOn(tester) != AppScreen.table; i++) {
      await tester.pump(Duration.zero);
    }
    expect(s.screenOn(tester), AppScreen.table);
    expect(find.text(BannerCopy.offline), findsNothing);
    expect(
      s.http.requests.where((r) => r.path == '/me/table/').length,
      reads,
      reason: 'the seat is the answer',
    );
    expect(
      s.http.requests.where((r) => r.method == 'POST' && r.path == path),
      hasLength(1),
    );
    await s.close(tester);
  });

  testWidgets('01 goes straight to 02: the opening is never shown between '
      'them, and the seat is not read (the answer is the seat)', (
    tester,
  ) async {
    final lobby = v2Lobby('created_with_defaults');
    final setup = await TableSetup.pump(
      tester,
      signedInAs: 'Ana',
      userId: memberId(lobby, 'Ana'),
      timesOut: false,
    );
    setup.http.answer('POST', '/lobbies/', lobby, status: 201);
    setup.sitAt(lobby, 'Ana');
    final before = setup.count('GET', '/me/table/');
    await pressLikeAFinger(tester, find.text(JoinCopy.startTable));
    int? reads;
    for (var i = 0; i < 60 && reads == null; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        find.byType(OpeningWait),
        findsNothing,
        reason: 'frame $i: 01 is not left for the opening before 02',
      );
      if (find.text(TableCopy.scan).evaluate().isNotEmpty) {
        reads = setup.count('GET', '/me/table/') - before;
      }
    }
    expect(reads, isNotNull, reason: '02 came');
    expect(reads, 0, reason: 'the answer is the seat; 02 mounting reads none');
    await setup.close(tester);
  });
}
