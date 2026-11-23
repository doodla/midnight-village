import '../../../helpers/finger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/features/lobby/presentation/at_table_screen.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/live_game_setup.dart' show recordedMe;
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/table_setup.dart';

// The requests a way in sends, counted (audit, Part 3, "Requests in a
// row"): an answer that says where the player sits is used, never read
// again. Start = the guest account, then the table (its answer is the
// lobby); Join = the account, then the join; Deal = the start, then the
// table and the dealt game side by side (its answer does not say the phase,
// so the deal keeps main's two reads in one round trip). Every request the
// app sends is listed (a request with no mock fails the test), so a read
// added back fails here.

/// The requests sent from the [from]th on, as "METHOD path", leaving out
/// 01's home numbers (the players online, the last game), which are read
/// beside a way in, never in its row.
List<String> _sent(TableSetup setup, int from) => [
  for (final r in setup.http.requests.skip(from))
    if (r.path != '/stats/online/' && r.path != '/onuw/me/recent-games/')
      '${r.method} ${r.path}',
];

/// Pumps frames, no time passing (so no slow poll comes due), until [done].
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await tester.pump(Duration.zero);
  }
  expect(done(), isTrue, reason: 'never happened');
}

bool _shows(Finder finder) => finder.evaluate().isNotEmpty;

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pump();
  await pressLostToday(tester, find.text(text), why: lostPastTheSink);
}

/// The server's new guest account for [name], with id [id].
Map<String, dynamic> _guest(String name, int id) {
  final body = ContractSamples.map('http/auth/guest_created');
  (body['user'] as Map)
    ..['id'] = id
    ..['display_name'] = name;
  return body;
}

void main() {
  testWidgets('Start: the guest account, then the table, and 02 shows from '
      'its answer: two requests, nothing read after', (tester) async {
    final setup = await TableSetup.pump(tester, realAuth: true);
    final created = v2Lobby('created_with_defaults');
    (created['host'] as Map)['id'] = 1;
    ((created['players'] as List).first as Map)['user']['id'] = 1;
    setup.http
      ..answer('POST', '/auth/guest/', _guest('Ana', 1), status: 201)
      ..answer('POST', '/lobbies/', created, status: 201);
    setup.sitAt(created, 'Ana');
    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.pump();
    final from = setup.http.requests.length;

    await _tapText(tester, JoinCopy.startTable);
    await _until(tester, () => _shows(find.text(TableCopy.scan)));
    // A few frames more: nothing is read again as the table's screen takes
    // over from 01 (the seat is held across, never dropped and re-read).
    for (var i = 0; i < 10; i++) {
      await tester.pump(Duration.zero);
    }

    expect(_sent(setup, from), ['POST /auth/guest/', 'POST /lobbies/']);
    await setup.close(tester);
  });

  testWidgets('Join by code: the guest account, then the join, and 02 shows '
      'from its answer: two requests, nothing read after', (tester) async {
    final setup = await TableSetup.pump(tester, realAuth: true);
    final joined = ContractSamples.map('http/lobby/joined');
    final code = joined['code'] as String;
    final ben = memberId(joined, 'Ben');
    setup.http
      ..answer('POST', '/auth/guest/', _guest('Ben', ben), status: 201)
      ..answer('POST', '/lobbies/$code/join/', joined)
      // Where the server has Ben now (never asked: the join said it).
      ..answer('GET', '/me/table/', serverMyTable(code: code));
    await tester.enterText(find.byType(TextField), 'Ben');
    await tester.pump();
    await _tapText(tester, JoinCopy.joinTable);
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, code);
    await tester.pump();
    final from = setup.http.requests.length;

    await _tapText(tester, JoinCopy.join);
    await _until(
      tester,
      () => _shows(find.text(TableCopy.hostDeals.fill({'host': 'Ana'}))),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(Duration.zero);
    }

    expect(_sent(setup, from), [
      'POST /auth/guest/',
      'POST /lobbies/$code/join/',
    ]);
    await setup.close(tester);
  });

  testWidgets('a join with no seat in its answer (already at that table) '
      'asks where the player sits, and goes there', (tester) async {
    final setup = await TableSetup.pump(tester, signedInAs: 'Ben', userId: 42);
    final table = v2Lobby('detail_auto_deck_5');
    setup.http.answer(
      'POST',
      '/lobbies/V9YC2J/join/',
      ContractSamples.map('http/lobby/join_already_member'),
      status: 400,
    );
    setup.sitAt(table, 'Ben');
    await _tapText(tester, JoinCopy.joinTable);
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'V9YC2J');
    await tester.pump();
    final from = setup.http.requests.length;

    await _tapText(tester, JoinCopy.join);
    await _until(tester, () => _shows(find.byType(AtTableView)));

    expect(_sent(setup, from), [
      'POST /lobbies/V9YC2J/join/',
      'GET /me/table/',
      'GET /lobbies/V9YC2J/',
    ]);
    await setup.close(tester);
  });

  testWidgets('a join whose answer is lost says "Not sent."; Try again '
      'finds the player already there (the first got through): where they '
      'sit is read, and the table shows', (tester) async {
    final setup = await TableSetup.pump(tester, signedInAs: 'Ben', userId: 42);
    setup.http.answer(
      'POST',
      '/lobbies/V9YC2J/join/',
      'Server Error',
      status: 503,
    );
    await _tapText(tester, JoinCopy.joinTable);
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

    setup.http.answer(
      'POST',
      '/lobbies/V9YC2J/join/',
      ContractSamples.map('http/lobby/join_already_member'),
      status: 400,
    );
    setup.sitAt(v2Lobby('detail_auto_deck_5'), 'Ben');
    final from = setup.http.requests.length;
    await _tapText(tester, BannerCopy.tryAgain);
    await _until(tester, () => _shows(find.byType(AtTableView)));

    expect(_sent(setup, from), [
      'POST /lobbies/V9YC2J/join/',
      'GET /me/table/',
      'GET /lobbies/V9YC2J/',
    ]);
    await setup.close(tester);
  });

  testWidgets('Deal: the start, then the table and the dealt game read side '
      'by side (one round trip after the answer, as on main)', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_auto_deck_5'),
      viewer: 'Ana',
    );
    final started = ContractSamples.map('http/game/started_with_look');
    setup.http.answer(
      'POST',
      '/onuw/lobbies/V9YC2J/start/',
      started,
      status: 201,
    );
    setup.answerGame(recordedMe('me_look_stage'));
    final me = 'GET /onuw/games/${started['game_id']}/me/';
    final from = setup.http.requests.length;

    await _tapText(tester, TableCopy.start);
    await _until(tester, () {
      final sent = _sent(setup, from);
      return sent.contains(me) && sent.contains('GET /me/table/');
    });

    final sent = _sent(setup, from);
    expect(sent.first, 'POST /onuw/lobbies/V9YC2J/start/');
    expect(sent.skip(1).take(2).toSet(), {'GET /me/table/', me});
    await setup.close(tester);
  });
}
