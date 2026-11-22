import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/value_stepper.dart';
import 'package:midnight_village/design_system/primitives/you_tag.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/table_setup.dart';

// Practice players (computer-filled seats) on the host's phone, every answer
// a recorded lobby body (`http/lobby/practice_*`, `detail_practice_guest`)
// with this table's values.
//
// What it catches:
// - The owner's decision: "hidden enable so it's not visible to everyone".
//   An ordinary host sees no word of it on 02 or 03; a tap on "Players"
//   does nothing; only a hold on it switches them on, and the Practice row
//   answers the hold at once, before the server does.
// - Once on, plain controls: the stepper seats them one at a time, each
//   step sent as the count wanted (safe to send twice), never past the
//   server's `practice.most`.
// - They show as not people: tagged "Practice" on 02 for the host and a
//   guest, never dimmed, and they count towards "Deal to {n}".
// - A hold again switches them off: the row goes and so do they.

/// The stand-in server: Pia's table, [count] practice players, switched
/// [on] or off. Its bodies are `practice_three`'s with this table's values.
class _Table {
  var on = false;
  var count = 0;

  static final _shape = ContractSamples.map('http/lobby/practice_three');
  static final _seated = (_shape['players'] as List)
      .cast<Map<String, dynamic>>();

  Map<String, dynamic> body() {
    final players = [_seated.first, ..._seated.skip(1).take(count)];
    final n = players.length;
    final settings = {...(_shape['settings'] as Map<String, dynamic>)};
    if (!on) settings.remove('practice');
    final body = withValues(_shape, {
      'settings': settings,
      'players': players,
      'seats_range': [math.max(3, n), 10],
      'deal': {
        'ok': n >= 3,
        'need': n + 3,
        'have': n >= 3 ? n + 3 : 0,
        'seats': null,
      },
    });
    // Sent only while switched on (a table that never used them: as before).
    if (!on) body.remove('practice');
    return body;
  }

  /// The server takes a practice change.
  void take(RequestOptions request) {
    final given = (request.data as Map).cast<String, dynamic>();
    if (given['on'] case final bool switched) {
      on = switched;
      if (!switched) count = 0;
    }
    if (given['count'] case final int wanted) {
      count = wanted;
      if (wanted > 0) on = true;
    }
  }
}

Finder _practiceRow() =>
    find.widgetWithText(LabelledStepper, DeckCopy.practice);

Finder _practiceGlyph(IconData icon) =>
    find.descendant(of: _practiceRow(), matching: find.byIcon(icon));

void main() {
  Future<(TableSetup, _Table)> open(WidgetTester tester) async {
    final table = _Table();
    final setup = await TableSetup.pump(
      tester,
      lobby: table.body(),
      viewer: 'Pia',
    );
    final code = setup.code;
    setup.http.answerEach(
      method: 'POST',
      path: '/lobbies/$code/practice/',
      answer: (request) {
        table.take(request);
        setup.http.answer('POST', request.path, table.body());
      },
    );
    setup.http.answerEach(
      method: 'GET',
      path: '/lobbies/$code/',
      answer: (request) => setup.http.answer('GET', request.path, table.body()),
    );
    return (setup, table);
  }

  List<Object?> practiceSent(TableSetup setup) => [
    for (final r in setup.http.requests)
      if (r.method == 'POST' && r.path.endsWith('/practice/')) r.data,
  ];

  Future<void> toDeck(WidgetTester tester, TableSetup setup) async {
    final edit = find.text(TableCopy.editDeck);
    await tester.ensureVisible(edit);
    await tester.pump();
    await tester.tap(edit);
    await setup.settle(tester);
    expect(find.text(DeckCopy.headline), findsOneWidget);
  }

  Future<void> tapGlyph(
    WidgetTester tester,
    TableSetup setup,
    IconData icon,
  ) async {
    final glyph = _practiceGlyph(icon);
    await tester.ensureVisible(glyph);
    await tester.pumpAndSettle();
    await tester.tap(glyph);
    await setup.settle(tester);
  }

  testWidgets('nothing of practice players shows to an ordinary host; a tap '
      'on "Players" does nothing; a hold switches them on at once', (
    tester,
  ) async {
    final (setup, _) = await open(tester);
    expect(find.text(TableCopy.practice), findsNothing, reason: '02');
    await toDeck(tester, setup);
    expect(find.text(DeckCopy.practice), findsNothing, reason: '03');

    await tester.tap(find.text(DeckCopy.players));
    await setup.settle(tester);
    expect(find.text(DeckCopy.practice), findsNothing);
    expect(practiceSent(setup), isEmpty);

    // The hold answers at once, before the server does.
    final held = setup.http.hold(
      method: 'POST',
      path: '/lobbies/${setup.code}/practice/',
    );
    await tester.longPress(find.text(DeckCopy.players));
    await tester.pump();
    expect(_practiceRow(), findsOneWidget);
    expect(
      find.descendant(of: _practiceRow(), matching: find.text('0')),
      findsOneWidget,
    );
    held.releaseAll();
    await setup.settle(tester);
    expect(practiceSent(setup), [
      {'on': true},
    ]);
    expect(_practiceRow(), findsOneWidget, reason: 'the server agreed');
  });

  testWidgets('the stepper seats them one at a time; on 02 each is tagged '
      '"Practice", never dimmed, and counts towards "Deal to {n}"', (
    tester,
  ) async {
    final (setup, table) = await open(tester);
    await toDeck(tester, setup);
    await tester.longPress(find.text(DeckCopy.players));
    await setup.settle(tester);

    // Nothing to take away yet.
    final minus = tester.widget<ValueStepper>(
      find.descendant(of: _practiceRow(), matching: find.byType(ValueStepper)),
    );
    expect(minus.onLower, isNull);

    await tapGlyph(tester, setup, Icons.add);
    await tapGlyph(tester, setup, Icons.add);
    expect(table.count, 2);
    expect(practiceSent(setup).skip(1), [
      {'count': 1},
      {'count': 2},
    ]);
    expect(
      find.descendant(of: _practiceRow(), matching: find.text('2')),
      findsOneWidget,
    );

    final done = find.widgetWithText(PrimaryButton, DeckCopy.done);
    await tester.ensureVisible(done);
    await tester.pumpAndSettle();
    await tester.tap(done);
    await setup.settle(tester);
    expect(find.byType(PracticeTag), findsNWidgets(2));
    expect(find.text('Scarecrow'), findsOneWidget);
    expect(find.text('Teapot'), findsOneWidget);
    expect(find.text(TableCopy.deal.fill({'n': 3})), findsOneWidget);
    // Never dimmed: a practice player has no phone to drop.
    final rows = tester.widgetList<PlayerRow>(find.byType(PlayerRow));
    expect(rows.where((r) => r.practice).map((r) => r.away), [false, false]);
  });

  testWidgets('the stepper stops at the most the server says may sit', (
    tester,
  ) async {
    final (setup, table) = await open(tester);
    await toDeck(tester, setup);
    await tester.longPress(find.text(DeckCopy.players));
    await setup.settle(tester);
    // The recorded table says nine may sit (one person, ten seats).
    final most =
        (ContractSamples.map('http/lobby/practice_three')['practice']
                as Map)['most']
            as int;
    for (var i = 0; i < 3; i++) {
      await tapGlyph(tester, setup, Icons.add);
    }
    expect(table.count, 3);
    final stepper = tester.widget<ValueStepper>(
      find.descendant(of: _practiceRow(), matching: find.byType(ValueStepper)),
    );
    expect(stepper.onHigher, table.count < most ? isNotNull : isNull);
  });

  testWidgets('a hold again switches them off: the row goes, and so do they', (
    tester,
  ) async {
    final (setup, table) = await open(tester);
    await toDeck(tester, setup);
    await tester.longPress(find.text(DeckCopy.players));
    await setup.settle(tester);
    await tapGlyph(tester, setup, Icons.add);
    expect(table.count, 1);

    await tester.ensureVisible(find.text(DeckCopy.players));
    await tester.pumpAndSettle();
    await tester.longPress(find.text(DeckCopy.players));
    await tester.pump();
    expect(_practiceRow(), findsNothing, reason: 'at once');
    await setup.settle(tester);
    expect(practiceSent(setup).last, {'on': false});
    expect(table.count, 0);
    expect(_practiceRow(), findsNothing);
  });

  testWidgets('a guest sees the practice players tagged and no way to seat '
      'them', (tester) async {
    await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_practice_guest'),
      viewer: 'Quin',
    );
    expect(find.byType(PracticeTag), findsNWidgets(2));
    expect(find.text(TableCopy.editDeck), findsNothing);
    expect(find.text(DeckCopy.players), findsNothing);
  });
}
