import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/table_setup.dart';

// Leaving 02, every answer a recorded server payload. The owner's report
// ("If I leave the game it says 'Not sent, try again.'"): a leave that
// reached the server is never "Not sent.": an answer slower than the phone
// waits is checked with the server (`/me/table/`), a second
// leave that finds the phone gone counts as left, and with no answer at all
// `/me/table/` decides. A refusal says why in plain words. Off the table,
// the phone is at 01 Join.

Future<void> _tap(WidgetTester tester, TableSetup setup, Finder what) async {
  await tester.ensureVisible(what);
  await tester.pump();
  await tester.tap(what);
  await setup.settle(tester);
}

/// The host's Leave asks first; the guest's leaves at once. [then] runs
/// just before the tap that sends the leave (what the server says after).
Future<void> _leave(
  WidgetTester tester,
  TableSetup setup, {
  bool host = true,
  void Function()? then,
}) async {
  if (host) {
    await _tap(tester, setup, find.text(CommonCopy.leave).first);
    await tester.pumpAndSettle();
  }
  then?.call();
  await _tap(tester, setup, find.text(CommonCopy.leave).last);
}

void main() {
  void offTheTable(TableSetup setup) => setup.http.answer(
    'GET',
    '/me/table/',
    ContractSamples.map('http/lobby/my_table_none'),
  );

  testWidgets('the host alone leaves: the table closes and the phone is at '
      'Join, no "Not sent."', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('created_with_defaults'),
      viewer: 'Ana',
    );
    setup.http.answer(
      'POST',
      '/lobbies/R5ZD3H/leave/',
      ContractSamples.map('http/lobby/left_last_member'),
    );

    await _leave(tester, setup, then: () => offTheTable(setup));

    expect(setup.count('POST', '/lobbies/R5ZD3H/leave/'), 1);
    expect(find.text(BannerCopy.notSent), findsNothing);
    expect(find.text(JoinCopy.startTable), findsOneWidget);
    await setup.close(tester);
  });

  testWidgets('the host leaves with others there: the table passes on and '
      'the phone is at Join', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_auto_deck_5'),
      viewer: 'Ana',
    );
    setup.http.answer(
      'POST',
      '/lobbies/V9YC2J/leave/',
      ContractSamples.map('http/lobby/left_owner'),
    );

    await _leave(tester, setup, then: () => offTheTable(setup));

    expect(find.text(BannerCopy.notSent), findsNothing);
    expect(find.text(JoinCopy.startTable), findsOneWidget);
    await setup.close(tester);
  });

  testWidgets('a guest leaves: at Join', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_auto_deck_5'),
      viewer: 'Ben',
    );
    setup.http.answer(
      'POST',
      '/lobbies/V9YC2J/leave/',
      ContractSamples.map('http/lobby/left'),
    );

    await _leave(tester, setup, host: false, then: () => offTheTable(setup));

    expect(find.text(BannerCopy.notSent), findsNothing);
    expect(find.text(JoinCopy.startTable), findsOneWidget);
    await setup.close(tester);
  });

  testWidgets('Leave shows it is on its way at once; an answer slower than '
      'the phone waits (a waking server) is checked with the server, never '
      '"Not sent." when the leave got there', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_auto_deck_5'),
      viewer: 'Ben',
    );
    setup.http.hold(method: 'POST', path: '/lobbies/V9YC2J/leave/');
    setup.http.answer(
      'POST',
      '/lobbies/V9YC2J/leave/',
      ContractSamples.map('http/lobby/left'),
    );

    await tester.tap(find.text(CommonCopy.leave));
    await tester.pump();
    // At once: the turning mark beside "Leave", and a second tap is inert.
    expect(find.byType(BusyMark), findsOneWidget);
    await tester.tap(find.text(CommonCopy.leave));
    await tester.pump(const Duration(milliseconds: 100));
    expect(setup.count('POST', '/lobbies/V9YC2J/leave/'), 1);

    // The server got it (it now has the phone at no table) but its answer
    // comes after the phone stops waiting.
    offTheTable(setup);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(BannerCopy.notSent), findsNothing, reason: '${i}s');
    }
    await setup.settle(tester);

    expect(setup.count('GET', '/me/table/'), greaterThan(0));
    expect(find.text(BannerCopy.notSent), findsNothing);
    expect(find.text(JoinCopy.startTable), findsOneWidget);
    await setup.close(tester);
  });

  testWidgets('a leave that finds the phone already gone (an earlier tap got '
      'there) counts as left', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_auto_deck_5'),
      viewer: 'Ben',
    );
    setup.http.answer(
      'POST',
      '/lobbies/V9YC2J/leave/',
      ContractSamples.map('http/lobby/leave_not_member'),
      status: 400,
    );

    await _leave(tester, setup, host: false, then: () => offTheTable(setup));

    expect(find.text(BannerCopy.notSent), findsNothing);
    expect(find.text(JoinCopy.startTable), findsOneWidget);
    await setup.close(tester);
  });

  testWidgets('a leave to a table that is gone counts as left', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('created_with_defaults'),
      viewer: 'Ana',
    );
    setup.http.answer(
      'POST',
      '/lobbies/R5ZD3H/leave/',
      ContractSamples.map('http/lobby/leave_not_found'),
      status: 404,
    );

    await _leave(tester, setup, then: () => offTheTable(setup));

    expect(find.text(BannerCopy.notSent), findsNothing);
    expect(find.text(JoinCopy.startTable), findsOneWidget);
    await setup.close(tester);
  });

  testWidgets('refused because the deal came first: says so in plain words, '
      'never "Not sent."', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_auto_deck_5'),
      viewer: 'Ana',
    );
    setup.http.answer(
      'POST',
      '/lobbies/V9YC2J/leave/',
      ContractSamples.map('http/lobby/leave_owner_in_game'),
      status: 409,
    );

    await _leave(tester, setup);

    expect(find.text(BannerCopy.lobbyClosed), findsOneWidget);
    expect(find.text(BannerCopy.notSent), findsNothing);
    await setup.close(tester);
  });

  testWidgets('no answer, and the server still has the phone at the table: '
      '"Not sent." with Try again, which leaves', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_auto_deck_5'),
      viewer: 'Ben',
    );
    setup.http.answer(
      'POST',
      '/lobbies/V9YC2J/leave/',
      'Server Error',
      status: 503,
    );

    await _leave(tester, setup, host: false);
    expect(find.text(BannerCopy.notSent), findsOneWidget);

    setup.http.answer(
      'POST',
      '/lobbies/V9YC2J/leave/',
      ContractSamples.map('http/lobby/left'),
    );
    offTheTable(setup);
    await _tap(tester, setup, find.text(BannerCopy.tryAgain));

    expect(setup.count('POST', '/lobbies/V9YC2J/leave/'), 2);
    expect(find.text(JoinCopy.startTable), findsOneWidget);
    await setup.close(tester);
  });

  testWidgets('no answer, but the leave got there (the server has the phone '
      'at no table): left, no "Not sent."', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_auto_deck_5'),
      viewer: 'Ben',
    );
    setup.http.answer(
      'POST',
      '/lobbies/V9YC2J/leave/',
      'Server Error',
      status: 503,
    );

    await _leave(tester, setup, host: false, then: () => offTheTable(setup));

    expect(find.text(BannerCopy.notSent), findsNothing);
    expect(find.text(JoinCopy.startTable), findsOneWidget);
    await setup.close(tester);
  });
}
