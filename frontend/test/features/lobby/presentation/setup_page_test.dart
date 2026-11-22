import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/value_stepper.dart';

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
    settings.addAll(
      ((request.data as Map)['settings'] as Map).cast<String, dynamic>(),
    );
  }
}

const _direction = [
  'Add',
  'Remove',
  'more',
  'fewer',
  'missing',
  'short',
  'too many',
];

void main() {
  Future<(TableSetup, _Table)> open(WidgetTester tester, int present) async {
    final table = _Table(present);
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
      expect(find.text('$have / $need'), findsOneWidget, reason: step);
      expect(
        find.text(
          TableCopy.seated.fill({'d': table.present, 'n': table.seats!}),
        ),
        findsOneWidget,
        reason: step,
      );
    }
    // One label, greyed or live: live while the deck fits.
    final use = find.widgetWithText(PrimaryButton, DeckCopy.useDeck);
    expect(use, findsOneWidget, reason: step);
    final auto = table.settings['deck'] == 'auto';
    expect(
      tester.widget<PrimaryButton>(use).onPressed != null,
      auto || have == need,
      reason: step,
    );
    for (final word in _direction) {
      expect(find.textContaining(word), findsNothing, reason: '$step: $word');
    }
  }

  for (final seats in [3, 5, 8, 10]) {
    for (final present in [1, 2, 5]) {
      testWidgets('set for $seats with $present here: the counter is the '
          'server\'s at every tap, one label, no direction words; 02 deals '
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

        // Every tap went to the server, one change each.
        expect(setup.patches.length, greaterThan(need));

        // Back on 02: "Deal to {n}", live exactly when the server says ok.
        final use = find.widgetWithText(PrimaryButton, DeckCopy.useDeck);
        if (tester.widget<PrimaryButton>(use).onPressed != null) {
          await _tap(tester, setup, use);
          final deal = find.widgetWithText(
            PrimaryButton,
            TableCopy.deal.fill({'n': table.seats!}),
          );
          expect(deal, findsOneWidget);
          expect(
            tester.widget<PrimaryButton>(deal).onPressed != null,
            (table.body()['deal'] as Map)['ok'],
          );
          for (final word in _direction) {
            expect(find.textContaining(word), findsNothing);
          }
        }
        await setup.close(tester);
      });
    }
  }

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
