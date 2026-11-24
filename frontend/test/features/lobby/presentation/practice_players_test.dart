import '../../../helpers/finger.dart';
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
// or a recorded refusal, with this table's values.
//
// What it catches:
// - The owner's decision: "hidden enable so it's not visible to everyone".
//   An ordinary host sees no word of it on 02 or 03; a tap on "Players"
//   does nothing; only a hold on the word itself switches them on (not the
//   room beside it), and the Practice row answers the hold at once.
// - A hold switches them off only with none seated: a resting thumb never
//   removes everyone.
// - Once on, plain controls: the stepper seats them one at a time, each
//   step sent as the count wanted, never past the server's `practice.most`.
// - Practice changes share the settings' lane (review, 22 November 2026):
//   Deal waits for one on its way; + + − on a slow network shows what the
//   server will end with and never loses the row; a refusal takes the change
//   back; "Not sent." and "Try again"; and a stale "Try again" never undoes a
//   newer change that got through on the same key (practice or a setting).
// - They show as not people: tagged "Practice" on 02 for the host and a
//   guest, never dimmed, and they count towards "Start the game".

/// The stand-in server: Pia's table, [count] practice players, switched
/// [on] or off, at most [most]. Its bodies are `practice_three`'s with this
/// table's values; a settings PATCH is merged as the server merges it.
class _Table {
  var on = false;
  var count = 0;
  var most = 9;
  final settings = <String, dynamic>{
    ...(_shape['settings'] as Map<String, dynamic>),
  }..remove('practice');
  final lengths = Map<String, dynamic>.of(
    _shape['lengths'] as Map<String, dynamic>,
  );

  /// The next practice change is refused with this recorded body and status.
  (String, int)? refuse;

  static final _shape = ContractSamples.map('http/lobby/practice_three');
  static final _seated = (_shape['players'] as List)
      .cast<Map<String, dynamic>>();

  Map<String, dynamic> body() {
    final players = [_seated.first, ..._seated.skip(1).take(count)];
    final n = players.length;
    final body = withValues(_shape, {
      'settings': {...settings, if (on) 'practice': true},
      'players': players,
      'lengths': {...lengths},
      'seats_range': [math.max(3, n), 10],
      'practice': {'most': most},
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

  /// The server merges a settings PATCH.
  void patch(RequestOptions request) {
    final given = ((request.data as Map)['settings'] as Map)
        .cast<String, dynamic>();
    settings.addAll(given);
    for (final MapEntry(:key, :value) in given.entries) {
      if (lengths.containsKey(key)) lengths[key] = value;
    }
  }
}

Finder _practiceRow() =>
    find.widgetWithText(LabelledStepper, DeckCopy.practice);

Finder _glyph(Finder row, IconData icon) =>
    find.descendant(of: row, matching: find.byIcon(icon));

Finder _talkRow() => find.widgetWithText(LabelledStepper, DeckCopy.talk);

ValueStepper _practiceStepper(WidgetTester tester) => tester.widget(
  find.descendant(of: _practiceRow(), matching: find.byType(ValueStepper)),
);

void main() {
  Future<(TableSetup, _Table)> open(
    WidgetTester tester, {
    void Function(_Table table)? before,
  }) async {
    final table = _Table();
    before?.call(table);
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
        if (table.refuse case (final sample, final status)) {
          table.refuse = null;
          setup.http.answer(
            'POST',
            request.path,
            ContractSamples.map('http/lobby/$sample'),
            status: status,
          );
          return;
        }
        table.take(request);
        setup.http.answer('POST', request.path, table.body());
      },
    );
    setup.http.answerEach(
      method: 'PATCH',
      path: '/lobbies/$code/',
      answer: (request) {
        table.patch(request);
        setup.http.answer('PATCH', request.path, table.body());
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

  List<Object?> patchesSent(TableSetup setup) => [
    for (final r in setup.http.requests)
      if (r.method == 'PATCH') (r.data as Map)['settings'],
  ];

  String practicePath(TableSetup setup) => '/lobbies/${setup.code}/practice/';

  Future<void> toDeck(WidgetTester tester, TableSetup setup) async {
    final edit = find.text(TableCopy.editDeck);
    await tester.ensureVisible(edit);
    await tester.pump();
    await pressLikeAFinger(tester, edit);
    await setup.settle(tester);
    expect(find.text(DeckCopy.headline), findsOneWidget);
  }

  Future<void> backToTable(WidgetTester tester, TableSetup setup) async {
    final done = find.widgetWithText(PrimaryButton, DeckCopy.done);
    await tester.ensureVisible(done);
    await tester.pump();
    await pressLikeAFinger(tester, done);
    await setup.settle(tester);
  }

  Future<void> holdPlayers(WidgetTester tester, {bool settle = true}) async {
    final players = find.text(DeckCopy.players);
    await tester.ensureVisible(players);
    await tester.pump();
    await tester.longPress(players);
    await tester.pump();
  }

  Future<void> tapIn(
    WidgetTester tester,
    TableSetup setup,
    Finder row,
    IconData icon, {
    bool settle = true,
  }) async {
    final glyph = _glyph(row, icon);
    await tester.ensureVisible(glyph);
    await tester.pump();
    await pressLikeAFinger(tester, glyph);
    if (settle) {
      await setup.settle(tester);
    } else {
      await tester.pump();
    }
  }

  String? practiceShown(WidgetTester tester) =>
      _practiceRow().evaluate().isEmpty ? null : _practiceStepper(tester).value;

  testWidgets('nothing of practice players shows to an ordinary host; a tap '
      'on "Players" does nothing; a hold switches them on at once', (
    tester,
  ) async {
    final (setup, _) = await open(tester);
    expect(find.text(TableCopy.practice), findsNothing, reason: '02');
    await toDeck(tester, setup);
    expect(find.text(DeckCopy.practice), findsNothing, reason: '03');

    await pressLikeAFinger(tester, find.text(DeckCopy.players));
    await setup.settle(tester);
    expect(find.text(DeckCopy.practice), findsNothing);
    expect(practiceSent(setup), isEmpty);

    // The hold answers at once, before the server does.
    final held = setup.http.hold(method: 'POST', path: practicePath(setup));
    await holdPlayers(tester);
    expect(practiceShown(tester), '0');
    held.releaseAll();
    await setup.settle(tester);
    expect(practiceSent(setup), [
      {'on': true},
    ]);
    expect(practiceShown(tester), '0', reason: 'the server agreed');
  });

  testWidgets('a hold beside the word, in the room before the stepper, does '
      'nothing', (tester) async {
    final (setup, _) = await open(tester);
    await toDeck(tester, setup);
    final word = tester.getRect(find.text(DeckCopy.players));
    final stepper = tester.getRect(
      find.descendant(
        of: find.widgetWithText(LabelledStepper, DeckCopy.players),
        matching: find.byType(ValueStepper),
      ),
    );
    expect(stepper.left - word.right, greaterThan(16), reason: 'room to hold');
    await tester.longPressAt(
      Offset((word.right + stepper.left) / 2, word.center.dy),
    );
    await setup.settle(tester);
    expect(practiceSent(setup), isEmpty);
    expect(_practiceRow(), findsNothing);
  });

  testWidgets('the stepper seats them one at a time; on 02 each is tagged '
      '"Practice" on the name\'s line, never dimmed, and counts towards '
      '"Start the game"', (tester) async {
    final (setup, table) = await open(tester);
    await toDeck(tester, setup);
    await holdPlayers(tester);
    await setup.settle(tester);
    expect(_practiceStepper(tester).onLower, isNull, reason: 'none to take');

    await tapIn(tester, setup, _practiceRow(), Icons.add);
    await tapIn(tester, setup, _practiceRow(), Icons.add);
    expect(table.count, 2);
    expect(practiceSent(setup).skip(1), [
      {'count': 1},
      {'count': 2},
    ]);
    expect(practiceShown(tester), '2');

    await backToTable(tester, setup);
    expect(find.byType(PracticeTag), findsNWidgets(2));
    for (final name in ['Scarecrow', 'Teapot']) {
      final tag = find.descendant(
        of: find.widgetWithText(PlayerRow, name),
        matching: find.byType(PracticeTag),
      );
      expect(
        tester.getCenter(tag).dy,
        moreOrLessEquals(tester.getCenter(find.text(name)).dy, epsilon: 4),
        reason: '$name: the tag on the name\'s line',
      );
    }
    expect(find.text(TableCopy.start), findsOneWidget);
    // Never dimmed: a practice player has no phone to drop.
    final rows = tester.widgetList<PlayerRow>(find.byType(PlayerRow));
    expect(rows.where((r) => r.practice).map((r) => r.away), [false, false]);
  });

  testWidgets('the stepper stops at the most the server says may sit', (
    tester,
  ) async {
    final (setup, table) = await open(tester, before: (t) => t.most = 2);
    await toDeck(tester, setup);
    await holdPlayers(tester);
    await setup.settle(tester);
    await tapIn(tester, setup, _practiceRow(), Icons.add);
    expect(_practiceStepper(tester).onHigher, isNotNull, reason: '1 of 2');
    await tapIn(tester, setup, _practiceRow(), Icons.add);
    expect(table.count, 2);
    expect(_practiceStepper(tester).onHigher, isNull, reason: 'at the most');
    await pressLikeAFinger(tester, _glyph(_practiceRow(), Icons.add));
    await setup.settle(tester);
    expect(practiceSent(setup).length, 3, reason: 'nothing past the most');
  });

  testWidgets('with some seated a hold does nothing; at 0 it switches them '
      'off and the row goes', (tester) async {
    final (setup, table) = await open(tester);
    await toDeck(tester, setup);
    await holdPlayers(tester);
    await setup.settle(tester);
    await tapIn(tester, setup, _practiceRow(), Icons.add);
    expect(table.count, 1);

    await holdPlayers(tester);
    await setup.settle(tester);
    expect(practiceSent(setup).length, 2, reason: 'a resting thumb');
    expect(practiceShown(tester), '1');

    await tapIn(tester, setup, _practiceRow(), Icons.remove);
    await holdPlayers(tester);
    expect(_practiceRow(), findsNothing, reason: 'at once');
    await setup.settle(tester);
    expect(practiceSent(setup).last, {'on': false});
    expect(table.on, isFalse);
    expect(_practiceRow(), findsNothing);
  });

  testWidgets('Deal waits for a practice change on its way: it never deals '
      'the table before the change', (tester) async {
    final (setup, table) = await open(
      tester,
      before: (t) => t
        ..on = true
        ..count = 2,
    );
    Finder deal(int n) => find.widgetWithText(PrimaryButton, TableCopy.start);
    expect(tester.widget<PrimaryButton>(deal(3)).onPressed, isNotNull);

    final held = setup.http.hold(method: 'POST', path: practicePath(setup));
    await toDeck(tester, setup);
    await tapIn(tester, setup, _practiceRow(), Icons.add, settle: false);
    await backToTable(tester, setup);
    // Four as the host sees it, and locked until the server says so.
    expect(tester.widget<PrimaryButton>(deal(4)).onPressed, isNull);
    // `CanDealSoon`: it keeps its words, waiting, with a reason for a screen
    // reader (never an unexplained dimmed button).
    expect(tester.widget<PrimaryButton>(deal(4)).phase, ButtonPhase.waiting);
    expect(tester.widget<PrimaryButton>(deal(4)).reason, SpokenCopy.working);
    await tester.tap(deal(4), warnIfMissed: false);
    await setup.settle(tester);
    expect(setup.count('POST', '/onuw/lobbies/${setup.code}/start/'), 0);

    held.releaseAll();
    setup.http.stopHolding(method: 'POST', path: practicePath(setup));
    await setup.settle(tester);
    expect(table.count, 3);
    expect(tester.widget<PrimaryButton>(deal(4)).onPressed, isNotNull);
    expect(tester.widget<PrimaryButton>(deal(4)).phase, ButtonPhase.ready);
  });

  testWidgets('03 says "Not sent." only for its own changes, and its Try '
      'again never deals (review 2, finding 1)', (tester) async {
    final (setup, table) = await open(
      tester,
      before: (t) => t
        ..on = true
        ..count = 2,
    );
    final path = '/lobbies/${setup.code}/';
    final start = '/onuw/lobbies/${setup.code}/start/';
    void losing() {
      setup.http.answerEach(method: 'PATCH', path: path, answer: (_) {});
      setup.http.answer('PATCH', path, 'Server Error', status: 503);
    }

    // A length change is lost; back on 02 the host deals, and the deal
    // waits behind the change, sent again (held, then lost again).
    losing();
    await toDeck(tester, setup);
    await tapIn(tester, setup, _talkRow(), Icons.add);
    expect(find.text(BannerCopy.notSent), findsOneWidget);
    await backToTable(tester, setup);
    final held = setup.http.hold(method: 'PATCH', path: path);
    await pressLikeAFinger(
      tester,
      find.widgetWithText(PrimaryButton, TableCopy.start),
    );
    await tester.pump();
    // The set-up page meanwhile: a practice player added (it goes after the
    // length) keeps the deal back. That is the table's line, never 03's.
    await toDeck(tester, setup);
    await tapIn(tester, setup, _practiceRow(), Icons.add);
    expect(find.text(BannerCopy.notSent), findsNothing);

    held.releaseAll();
    setup.http.stopHolding(method: 'PATCH', path: path);
    await setup.settle(tester);
    expect(table.count, 3, reason: 'the practice player, after the length');
    expect(find.text(BannerCopy.notSent), findsOneWidget, reason: 'the length');
    // 03's Try again: the length again (lost once more), never the deal
    // (the deal goes through 02's own; see settings_lane_order_test).
    final patches = setup.count('PATCH', path);
    await pressLikeAFinger(tester, find.text(BannerCopy.tryAgain));
    await setup.settle(tester);
    expect(setup.count('PATCH', path), patches + 1);
    expect(setup.count('POST', start), 0, reason: "03's Try again never deals");

    // On 02 the held deal says so, with its own Try again.
    await backToTable(tester, setup);
    expect(find.text(BannerCopy.notSent), findsOneWidget);
    expect(setup.count('POST', start), 0);
  });

  testWidgets('+ + − with every answer held: shows 1 throughout, sends 1, 2, '
      '1 in order, and ends at 1', (tester) async {
    final (setup, table) = await open(tester);
    await toDeck(tester, setup);
    final held = setup.http.hold(method: 'POST', path: practicePath(setup));
    // The switch, then the taps, all before any answer: the row never goes.
    await holdPlayers(tester);
    await tapIn(tester, setup, _practiceRow(), Icons.add, settle: false);
    expect(practiceShown(tester), '1');
    await tapIn(tester, setup, _practiceRow(), Icons.add, settle: false);
    expect(practiceShown(tester), '2');
    await tapIn(tester, setup, _practiceRow(), Icons.remove, settle: false);
    expect(practiceShown(tester), '1');
    await tapIn(tester, setup, _practiceRow(), Icons.remove, settle: false);
    expect(practiceShown(tester), '0', reason: 'on its way: still on');
    await tapIn(tester, setup, _practiceRow(), Icons.add, settle: false);
    expect(practiceShown(tester), '1');
    for (var answered = 1; answered <= 6; answered++) {
      expect(held.length, 1, reason: 'one at a time, in order');
      held.release();
      await setup.settle(tester);
      expect(practiceShown(tester), '1', reason: 'after $answered answers');
    }
    expect(
      practiceSent(setup),
      [
        {'on': true},
        {'count': 1},
        {'count': 2},
        {'count': 1},
        {'count': 0},
        {'count': 1},
      ].take(6).toList(),
    );
    expect(table.count, 1);
  });

  for (final (sample, status) in [
    ('practice_full', 400),
    ('practice_in_game', 409),
    ('practice_not_host', 403),
  ]) {
    testWidgets('a refusal ($sample) takes the change back and reads the '
        'table again, with no "Not sent."', (tester) async {
      final (setup, table) = await open(
        tester,
        before: (t) => t
          ..on = true
          ..count = 1,
      );
      await toDeck(tester, setup);
      final reads = setup.count('GET', '/lobbies/${setup.code}/');
      table.refuse = (sample, status);
      await tapIn(tester, setup, _practiceRow(), Icons.add);
      expect(table.count, 1);
      expect(practiceShown(tester), '1');
      expect(find.text(BannerCopy.notSent), findsNothing);
      expect(setup.count('GET', '/lobbies/${setup.code}/'), greaterThan(reads));
    });
  }

  testWidgets('a practice change that does not get through says "Not '
      'sent."; Try again sends it', (tester) async {
    final (setup, table) = await open(tester, before: (t) => t.on = true);
    await toDeck(tester, setup);
    setup.http.answer('POST', practicePath(setup), 'Server Error', status: 503);
    final each = setup.http;
    each.answerEach(method: 'POST', path: practicePath(setup), answer: (_) {});
    await tapIn(tester, setup, _practiceRow(), Icons.add);
    expect(find.text(BannerCopy.notSent), findsOneWidget);
    expect(table.count, 0);
    expect(practiceShown(tester), '1', reason: 'the screen shows what goes');

    each.answerEach(
      method: 'POST',
      path: practicePath(setup),
      answer: (request) {
        table.take(request);
        each.answer('POST', request.path, table.body());
      },
    );
    await pressLikeAFinger(tester, find.text(BannerCopy.tryAgain));
    await setup.settle(tester);
    expect(find.text(BannerCopy.notSent), findsNothing);
    expect(table.count, 1);
    expect(practiceShown(tester), '1');
  });

  testWidgets('a stale Try again never undoes a newer practice count that '
      'got through', (tester) async {
    final (setup, table) = await open(
      tester,
      before: (t) => t
        ..on = true
        ..count = 1,
    );
    await toDeck(tester, setup);
    final path = practicePath(setup);
    void answering() => setup.http.answerEach(
      method: 'POST',
      path: path,
      answer: (request) {
        table.take(request);
        setup.http.answer('POST', request.path, table.body());
      },
    );
    void losing() {
      setup.http.answerEach(method: 'POST', path: path, answer: (_) {});
      setup.http.answer('POST', path, 'Server Error', status: 503);
    }

    // 2 does not get through: it stays shown, with "Not sent.".
    losing();
    await tapIn(tester, setup, _practiceRow(), Icons.add);
    expect(find.text(BannerCopy.notSent), findsOneWidget);
    expect(practiceShown(tester), '2', reason: 'the screen shows what goes');
    // The minus on the 2 shown: 1 gets through.
    answering();
    await tapIn(tester, setup, _practiceRow(), Icons.remove);
    expect(table.count, 1);
    expect(find.text(BannerCopy.notSent), findsNothing);
    final sent = practiceSent(setup).length;
    // 0 does not get through; Try again after it.
    losing();
    await tapIn(tester, setup, _practiceRow(), Icons.remove);
    expect(find.text(BannerCopy.notSent), findsOneWidget);
    answering();
    await pressLikeAFinger(tester, find.text(BannerCopy.tryAgain));
    await setup.settle(tester);
    // Only the 0 is sent again: the 2 was overtaken by the newer counts.
    expect(practiceSent(setup).skip(sent + 1), [
      {'count': 0},
    ]);
    expect(table.count, 0);
  });

  testWidgets('a stale Try again never undoes a newer setting that got '
      'through on the same key', (tester) async {
    final (setup, table) = await open(tester);
    await toDeck(tester, setup);
    final path = '/lobbies/${setup.code}/';
    final key = (_Table._shape['lengths'] as Map).keys.firstWhere(
      (k) => k == 'discussion_seconds',
    );
    final before = table.lengths[key] as int;
    // Talk up does not get through; then talk down does.
    setup.http.answerEach(method: 'PATCH', path: path, answer: (_) {});
    setup.http.answer('PATCH', path, 'Server Error', status: 503);
    await tapIn(tester, setup, _talkRow(), Icons.add);
    expect(find.text(BannerCopy.notSent), findsOneWidget);
    setup.http.answerEach(
      method: 'PATCH',
      path: path,
      answer: (request) {
        table.patch(request);
        setup.http.answer('PATCH', request.path, table.body());
      },
    );
    // The screen shows the lost talk up (what Try again would send): two
    // minuses go below where it began.
    await tapIn(tester, setup, _talkRow(), Icons.remove);
    await tapIn(tester, setup, _talkRow(), Icons.remove);
    final down = table.lengths[key] as int;
    expect(down, lessThan(before));
    final sent = patchesSent(setup).length;
    // A later loss on another key brings the banner back; Try again then.
    setup.http.answerEach(method: 'PATCH', path: path, answer: (_) {});
    setup.http.answer('PATCH', path, 'Server Error', status: 503);
    await tapIn(
      tester,
      setup,
      find.widgetWithText(LabelledStepper, DeckCopy.players),
      Icons.add,
    );
    expect(find.text(BannerCopy.notSent), findsOneWidget);
    setup.http.answerEach(
      method: 'PATCH',
      path: path,
      answer: (request) {
        table.patch(request);
        setup.http.answer('PATCH', request.path, table.body());
      },
    );
    await pressLikeAFinger(tester, find.text(BannerCopy.tryAgain));
    await setup.settle(tester);
    final again = patchesSent(setup).skip(sent + 1).toList();
    expect(again, [
      {'seats': 3},
    ], reason: 'the seats sent again, never the old talk');
    expect(table.lengths[key], down);
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
