import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/value_stepper.dart';
import 'package:midnight_village/features/lobby/presentation/deck_screen.dart'
    show deckFixWords;

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/table_setup.dart';

// The set-up page driven tap by tap, the host alone or with a few, setting
// the table for 3, 5, 8 and 10 and building a deck of their own for it.
// The server is a stand-in whose every answer is a recorded lobby body
// (`detail_seats_8_*`) with the values this table has: what the test checks
// is that the screen shows the answer, never its own arithmetic.
//
// What it catches (the owner's confusions, 21 November 2026):
// - "the card target followed whoever happened to be at the table and was
//   never shown": at every tap the counter is the server's `have / need`
//   for the number chosen, and the number is on screen.
// - "the only feedback was a greyed button flipping between 'Add N cards'
//   and 'Remove N cards'": no words of direction are ever on screen, and the
//   button's label never changes, greyed or live.
// - "I need to be able to edit everything and then wait for the number of
//   people": the number is set with nobody else there; back on 02 "Deal to
//   {n}" keeps its words and is live exactly when the server says `ok`.

/// The table the stand-in server keeps: Tia's, with [present] here.
class _Table {
  _Table(this.present);

  final int present;
  final settings = <String, dynamic>{
    'deck': 'auto',
    'deck_chip': 'simple',
    'card_look_seconds': 30,
    'night_protocol': 2,
  };

  static final _shape = ContractSamples.map(
    'http/lobby/detail_seats_8_four_here',
  );
  static final _people =
      (ContractSamples.map('http/lobby/detail_seats_8_seven_here')['players']
              as List)
          .cast<Map<String, dynamic>>();

  /// A legal deck of [cards] cards, in the grid's fill order (the stand-in's
  /// automatic deck; the values are the test's, the shape the server's).
  static Map<String, int> deckOf(int cards) {
    final deck = <String, int>{};
    var left = cards;
    for (final (role, most) in _fill) {
      if (left == 0) break;
      final take = math.min(most, left);
      if (role == 'Mason' && take < 2) continue;
      deck[role] = take;
      left -= take;
    }
    return deck;
  }

  static const _fill = [
    ('Werewolf', 2),
    ('Seer', 1),
    ('Robber', 1),
    ('Troublemaker', 1),
    ('Villager', 3),
    ('Minion', 1),
    ('Drunk', 1),
    ('Insomniac', 1),
    ('Mason', 2),
    ('Hunter', 1),
    ('Tanner', 1),
    ('Doppelganger', 1),
  ];

  int? get seats => settings['seats'] as int?;

  /// What the stand-in says each length runs with (`lengths`).
  final lengths = Map<String, dynamic>.of(
    _shape['lengths'] as Map<String, dynamic>,
  );

  Map<String, dynamic> body() {
    final size = seats ?? present;
    final auto = settings['deck'] == 'auto';
    final cards = auto
        ? deckOf(math.max(size, 3) + 3)
        : (settings['roles'] as Map).cast<String, int>();
    final need = size + 3;
    final have = auto
        ? (size >= 3 ? need : 0)
        : cards.values.fold(0, (a, b) => a + b);
    final full = seats == null ? present >= 3 : present == seats;
    return withValues(_shape, {
      'settings': {...settings},
      'players': [
        for (final p in _people.take(present)) {...p, 'connected': true},
      ],
      'deck_preview': auto && size >= 3 ? cards : null,
      'deck_cards': cards,
      'seats_range': [math.max(3, present), 10],
      'lengths': lengths,
      'deal': {
        'ok': full && have == need,
        'need': need,
        'have': have,
        'seats': seats,
      },
    });
  }

  /// The server merges a PATCH's settings over the stored ones.
  void patch(RequestOptions request) {
    final given = ((request.data as Map)['settings'] as Map)
        .cast<String, dynamic>();
    settings.addAll(given);
    // A length changed is what the game runs with.
    for (final MapEntry(:key, :value) in given.entries) {
      if (lengths.containsKey(key)) lengths[key] = value;
    }
  }
}

/// The count's line as 03 says it: "11 of 11", or with the difference, what to
/// add or remove ("10 of 11 · Add 1 card").
String _count(int have, int need) => have == need
    ? DeckCopy.count.fill({'picked': have, 'need': need})
    : DeckCopy.countFix.fill({
        'picked': have,
        'need': need,
        'fix': deckFixWords(have - need),
      });

void main() {
  Future<(TableSetup, _Table)> open(
    WidgetTester tester,
    int present, {
    void Function(_Table table)? stored,
  }) async {
    final table = _Table(present);
    stored?.call(table);
    final setup = await TableSetup.pump(
      tester,
      lobby: table.body(),
      viewer: 'Tia',
    );
    void answer(RequestOptions request) {
      if (request.method == 'PATCH') table.patch(request);
      setup.http.answer(request.method, request.path, table.body());
    }

    for (final method in ['GET', 'PATCH']) {
      setup.http.answerEach(
        method: method,
        path: '/lobbies/D3GL6S/',
        answer: answer,
      );
    }
    await _tap(tester, setup, find.text(TableCopy.editDeck));
    expect(find.text(DeckCopy.headline), findsOneWidget);
    return (setup, table);
  }

  void check(WidgetTester tester, _Table table, String step) {
    final deal = table.body()['deal'] as Map<String, dynamic>;
    final need = deal['need'] as int;
    final have = deal['have'] as int;
    if (table.seats != null) {
      expect(find.text(_count(have, need)), findsOneWidget, reason: step);
      expect(
        find.text(
          TableCopy.seated.fill({'d': table.present, 'n': table.seats!}),
        ),
        findsOneWidget,
        reason: step,
      );
    }
    // Always live, never dimmed, always "Done" (with the wrong number of
    // cards the first tap shows the count).
    final done = find.widgetWithText(PrimaryButton, DeckCopy.done);
    expect(done, findsOneWidget, reason: step);
    expect(tester.widget<PrimaryButton>(done).onPressed, isNotNull);
    // The Doppelganger's length only while the deck holds the card.
    final cards = table.body()['deck_cards'] as Map<String, dynamic>;
    expect(
      find.widgetWithText(LabelledStepper, 'Doppelganger'),
      cards.containsKey('Doppelganger') ? findsOneWidget : findsNothing,
      reason: step,
    );
  }

  for (final seats in [3, 5, 8, 10]) {
    for (final present in [1, 2, 5]) {
      testWidgets('set for $seats with $present here: the counter is the '
          'server\'s at every tap, no direction words; 02 deals '
          'exactly on ok', (tester) async {
        final (setup, table) = await open(tester, present);
        check(tester, table, 'opened');

        // The number, from "Any", one tap at a time; never below who is
        // here.
        final target = math.max(seats, present);
        while (table.seats != target) {
          final before = table.seats;
          await _tap(tester, setup, _players(Icons.add));
          expect(table.seats, isNot(before), reason: 'the + took');
          check(tester, table, 'players ${table.seats}');
        }
        if (present > 3) {
          // Below who is here the minus does nothing.
          final least = find.descendant(
            of: _playersRow(),
            matching: find.byIcon(Icons.remove),
          );
          while (table.seats! > present) {
            await _tap(tester, setup, least);
          }
          await _tap(tester, setup, least);
          expect(table.seats, present, reason: 'never below who is here');
          if (target != present) {
            while (table.seats != target) {
              await _tap(tester, setup, _players(Icons.add));
            }
          }
        }
        final need = (table.body()['deal'] as Map)['need'] as int;

        // Every card out, one minus at a time (the first makes the deck
        // the host's own).
        for (var guard = 0; guard < 20; guard++) {
          final lit = tester
              .widgetList<RoleCard>(find.byType(RoleCard))
              .where((c) => c.lit)
              .map((c) => c.role)
              .firstOrNull;
          if (lit == null) break;
          await _tap(
            tester,
            setup,
            find.descendant(
              of: _role(lit),
              matching: find.byIcon(Icons.remove),
            ),
          );
          check(tester, table, 'took one ${lit.displayName} out');
        }
        expect(table.settings['deck'], 'custom');
        expect(table.body()['deck_cards'], isEmpty);

        // And back in, one tap at a time, to the need and one past it.
        final wanted = _Table.deckOf(need + 1);
        for (final MapEntry(key: name, value: count) in wanted.entries) {
          final role = RoleId.fromServer(name)!;
          final step = role == RoleId.mason ? 2 : 1;
          for (var i = 0; i < count; i += step) {
            await _tap(tester, setup, _role(role));
            check(tester, table, 'put a $name in');
          }
        }
        final have = (table.body()['deal'] as Map)['have'] as int;
        expect(have, greaterThan(need), reason: 'one past the need');
        // One out again: it fits.
        final last = RoleId.fromServer(wanted.keys.last)!;
        await _tap(
          tester,
          setup,
          find.descendant(of: _role(last), matching: find.byIcon(Icons.remove)),
        );
        check(tester, table, 'one ${last.displayName} out again');

        // The Doppelganger in: its length appears; out again: it goes.
        await _tap(tester, setup, _role(RoleId.doppelganger));
        check(tester, table, 'the Doppelganger in');
        await _tap(
          tester,
          setup,
          find.descendant(
            of: _role(RoleId.doppelganger),
            matching: find.byIcon(Icons.remove),
          ),
        );
        check(tester, table, 'the Doppelganger out');

        // Every tap went to the server, one change each.
        expect(setup.patches.length, greaterThan(need));

        // Back on 02: "Start the game", live exactly when the server says ok.
        await _tap(tester, setup, find.text(DeckCopy.done));
        // The one primary button: "Start the game", live, when the server says ok;
        // else it says what is missing or leads to the fix (never dimmed
        // under the same words).
        final deal = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
        expect(
          deal.label == TableCopy.start && deal.onPressed != null,
          (table.body()['deal'] as Map)['ok'],
        );
        await setup.close(tester);
      });
    }
  }

  group('while changes are on their way (the answers held)', () {
    testWidgets('three taps on Players: the number, "3 of N" and the count '
        'are the new number at once; 02 says "Start the game"', (tester) async {
      final (setup, table) = await open(tester, 3);
      await _tap(tester, setup, _players(Icons.add)); // Any to 3, answered
      final held = setup.http.hold(method: 'PATCH', path: '/lobbies/D3GL6S/');
      for (var i = 0; i < 3; i++) {
        await _tap(tester, setup, _players(Icons.add));
      }
      // One change at a time: the first is out, the other two wait their
      // turn on the phone; nothing is answered yet.
      expect(held.length, 1);
      expect(
        find.descendant(of: _playersRow(), matching: find.text('6')),
        findsOneWidget,
      );
      expect(
        find.text(TableCopy.seated.fill({'d': 3, 'n': 6})),
        findsOneWidget,
      );
      // Never the new number beside the old need.
      expect(find.text(_count(9, 9)), findsOneWidget);
      expect(find.text(_count(6, 6)), findsNothing);

      await _tap(tester, setup, find.text(DeckCopy.done));
      // Set for 6 with 3 here: it says how many more, never "Start the game".
      expect(
        find.widgetWithText(PrimaryButton, TableCopy.needMore.fill({'n': 3})),
        findsOneWidget,
      );
      expect(find.text(TableCopy.start), findsNothing);

      // Answers from now on: the held one, then the two waiting their turn.
      setup.http.stopHolding(method: 'PATCH', path: '/lobbies/D3GL6S/');
      held.releaseAll();
      await setup.settle(tester);
      expect(table.seats, 6);
      expect(
        find.text(TableCopy.seated.fill({'d': 3, 'n': 6})),
        findsOneWidget,
      );
      await setup.close(tester);
    });

    testWidgets('a length stepped twice shows at once; the others keep the '
        "server's values, never a stored one", (tester) async {
      // A stored look the server does not run with (past its most, older
      // code): the body's `lengths` says what runs (no look).
      final (setup, _) = await open(
        tester,
        1,
        stored: (table) {
          table.settings['card_look_seconds'] = 999;
          table.lengths['card_look_seconds'] = 0;
        },
      );
      setup.http.hold(method: 'PATCH', path: '/lobbies/D3GL6S/');
      final talk = find.descendant(
        of: find.widgetWithText(LabelledStepper, DeckCopy.talk),
        matching: find.byIcon(Icons.add),
      );
      await _tap(tester, setup, talk);
      await _tap(tester, setup, talk);

      expect(find.text('7 min'), findsOneWidget, reason: 'talk, two steps');
      final look = find.widgetWithText(LabelledStepper, DeckCopy.look);
      expect(
        find.descendant(of: look, matching: find.text(DeckCopy.off)),
        findsOneWidget,
        reason: "the server's look, not the stored 999",
      );
      await setup.close(tester);
    });
  });

  testWidgets('a guest\'s table shows the same roles face up as the '
      'host\'s, and follows a change', (tester) async {
    Map<RoleId, int> faceUp() => {
      for (final c in tester.widgetList<RoleCard>(find.byType(RoleCard)))
        c.role: c.count,
    };
    final host = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_seats_8_four_here'),
      viewer: 'Tia',
    );
    final hosts = faceUp();
    await host.close(tester);

    final guest = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_seats_8_four_here'),
      viewer: 'Ugo',
    );
    await tester.ensureVisible(find.byType(RoleCard).first);
    await tester.pumpAndSettle();
    expect(faceUp(), hosts);
    expect(find.text(TableCopy.seated.fill({'d': 4, 'n': 8})), findsOneWidget);

    // The host goes back to a starter deck: the guest's cards follow.
    final update = ContractSamples.map('ws/lobby/lobby_update_seats_joined');
    final back = v2Lobby('settings_back_to_auto');
    guest.event({...update, 'data': back});
    await guest.settle(tester);
    expect(faceUp(), {
      for (final MapEntry(:key, :value)
          in (back['deck_cards'] as Map<String, dynamic>).entries)
        RoleId.fromServer(key)!: value as int,
    });
    await guest.close(tester);
  });
}

Future<void> _tap(WidgetTester tester, TableSetup setup, Finder what) async {
  await tester.ensureVisible(what);
  await tester.pump();
  await tester.tap(what);
  await setup.settle(tester);
}

Finder _playersRow() => find.ancestor(
  of: find.text(DeckCopy.players),
  matching: find.byType(LabelledStepper),
);

Finder _players(IconData glyph) =>
    find.descendant(of: _playersRow(), matching: find.byIcon(glyph));

Finder _role(RoleId role) =>
    find.byWidgetPredicate((w) => w is RoleCard && w.role == role);
