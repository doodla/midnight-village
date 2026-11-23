import '../../../helpers/finger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/features/lobby/presentation/where_am_i_provider.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/table_setup.dart';

// The owner's report ("If I leave the game it says 'Not sent, try again.'"):
// a failure of 01's own request is 01's. Once the phone is at a table it is
// gone, so it can never show up after a Leave as a failure of something
// that worked. (The other cause, a seat taken but reported as "Not sent."
// because a read was dropped mid-fetch, is in table_leave_test.dart.)

void main() {
  testWidgets('"Not sent." from a join that failed does not come back on '
      '01 after the phone sat at a table and left it', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      signedInAs: 'Ben',
      lastWon: false,
      before: (s) => s.http.answer(
        'POST',
        '/lobbies/V9YC2J/join/',
        'Server Error',
        status: 503,
      ),
    );
    await pressLikeAFinger(tester, find.text(JoinCopy.joinTable));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'V9YC2J');
    await tester.pump();
    await plainTap(
      tester,
      find.text(JoinCopy.join),
      why:
          'the 01 Join bug: pressed by a finger, a refused or unsent Join shows no refusal (fixed on branch fix-join-refusal)',
    );
    await setup.settle(tester);
    expect(find.text(BannerCopy.notSent), findsOneWidget);

    // The join had got there after all: the server seats the phone, and the
    // app follows it to 02.
    setup.sitAt(v2Lobby('detail_auto_deck_5'), 'Ben');
    ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    ).invalidate(myTableProvider);
    await setup.settle(tester);
    expect(find.text(JoinCopy.startTable), findsNothing, reason: 'at 02');
    expect(find.text(BannerCopy.notSent), findsNothing);

    // Leave: 01 again, with nothing left over.
    setup.http.answer(
      'POST',
      '/lobbies/${setup.code}/leave/',
      ContractSamples.load('http/lobby/left'),
    );
    setup.http.answer(
      'GET',
      '/me/table/',
      ContractSamples.map('http/lobby/my_table_none'),
    );
    await pressLikeAFinger(tester, find.text(CommonCopy.leave).last);
    await setup.settle(tester);
    expect(find.text(JoinCopy.startTable), findsOneWidget);
    expect(find.text(BannerCopy.notSent), findsNothing);
    expect(find.text(BannerCopy.tryAgain), findsNothing);
    await setup.close(tester);
  });

  testWidgets('"Start a table" shows busy on itself in the frame of the '
      'tap, sends once, and the other way in is dead meanwhile', (
    tester,
  ) async {
    late HeldReplies start;
    final setup = await TableSetup.pump(
      tester,
      signedInAs: 'Ben',
      timesOut: false,
      before: (s) {
        start = s.http.hold(method: 'POST', path: '/lobbies/');
        s.http.answer(
          'POST',
          '/lobbies/',
          v2Lobby('created_with_defaults'),
          status: 201,
        );
      },
    );
    await pressLikeAFinger(tester, find.text(JoinCopy.startTable));
    await tester.pump();
    final startButton = find.ancestor(
      of: find.text(JoinCopy.startTable),
      matching: find.byType(SecondaryButton),
    );
    expect(
      find.descendant(of: startButton, matching: find.byType(BusyMark)),
      findsOneWidget,
      reason: 'busy in the frame of the tap',
    );
    await pressLikeAFinger(tester, find.text(JoinCopy.startTable));
    await pressLikeAFinger(tester, find.text(JoinCopy.joinTable));
    await setup.settle(tester);
    expect(start.length, 1, reason: 'one request');
    expect(find.byType(TextField), findsOneWidget, reason: 'no code field');

    setup.sitAt(v2Lobby('created_with_defaults'), 'Ana');
    start.releaseAll();
    await setup.settle(tester);
    expect(find.text(TableCopy.scan), findsOneWidget);
    await setup.close(tester);
  });

  testWidgets('"Join" shows busy on itself and keeps the code that was '
      'typed (01 is not built again when a way in starts)', (tester) async {
    late HeldReplies join;
    final setup = await TableSetup.pump(
      tester,
      signedInAs: 'Ben',
      timesOut: false,
      before: (s) {
        join = s.http.hold(method: 'POST', path: '/lobbies/V9YC2J/join/');
        s.http.answer(
          'POST',
          '/lobbies/V9YC2J/join/',
          ContractSamples.map('http/lobby/joined'),
        );
      },
    );
    await pressLikeAFinger(tester, find.text(JoinCopy.joinTable));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'V9YC2J');
    await tester.pump();
    await pressLikeAFinger(tester, find.text(JoinCopy.join));
    await tester.pump();
    await setup.settle(tester);
    expect(find.text('V9YC2J'), findsOneWidget, reason: 'the code stays');
    final button = find.ancestor(
      of: find.text(JoinCopy.join),
      matching: find.byType(PrimaryButton),
    );
    expect(tester.widget<PrimaryButton>(button).busy, isTrue);
    expect(join.length, 1);
    await pressLikeAFinger(tester, find.text(JoinCopy.join));
    await setup.settle(tester);
    expect(join.length, 1, reason: 'one request');
    await setup.close(tester);
  });
}
