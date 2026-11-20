import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';

import '../test/helpers/contract/contract_samples.dart';
import '../test/helpers/table_setup.dart';

// 01 Join, 02 Table, 03 Deck and 03b through the app's real routes and
// providers (test/helpers/table_setup.dart), every answer a recorded
// protocol-2 lobby payload, each state reached the way a player reaches it.
// Ana sets the table up; Ben joins it.

/// Long names as a table has them, at most the server's 20 characters.
const longNames = {
  'Ana': 'Christopher',
  'Ben': 'Maximiliano',
  'Cleo': 'Rosalind Fairweather',
  'Dev': 'Esmeralda',
  'Esme': 'Bartholomew',
  'Fin': 'Ida',
  'Gus': 'Wolfgang Amadeus',
  'Hana': 'Penelope',
  'Ida': 'Jo',
  'Jo': 'Theodora',
};

// ---------------------------------------------------------------------------
// 01 Join
// ---------------------------------------------------------------------------

/// 01 on a phone that has never played: no name, nothing to say how it went.
Future<void> pumpJoinFresh(WidgetTester tester, {double textScale = 1}) =>
    TableSetup.pump(tester, textScale: textScale);

/// 01 for a player back after a game: their own name, how it went.
Future<void> pumpJoinReturning(WidgetTester tester) =>
    TableSetup.pump(tester, signedInAs: 'Ben', lastWon: false);

/// 01 with "Join a table" opened: the code and an amber "Join".
Future<void> pumpJoinCode(WidgetTester tester) async {
  await pumpJoinReturning(tester);
  await tester.tap(find.text(JoinCopy.joinTable));
  await tester.pump();
  await tester.enterText(find.byType(TextField).last, 'V9YC2J');
  await tester.pump();
}

/// 01 on a new phone with a name typed: both ways in open.
Future<void> pumpJoinNamed(WidgetTester tester) async {
  await pumpJoinFresh(tester);
  await tester.enterText(find.byType(TextField), 'Ana');
  await tester.pump();
}

/// 01 on a new phone: a name typed, "Join a table" opened, the code typed.
Future<void> pumpJoinCodeFresh(WidgetTester tester) async {
  await pumpJoinFresh(tester);
  await tester.enterText(find.byType(TextField), 'Ben');
  await tester.pump();
  await tester.tap(find.text(JoinCopy.joinTable));
  await tester.pump();
  await tester.enterText(find.byType(TextField).last, 'V9YC2J');
  await tester.pump();
}

/// 01 opened from a table's link (its QR code), signed out.
Future<void> pumpJoinLink(WidgetTester tester) =>
    TableSetup.pump(tester, route: '/join/V9YC2J');

// ---------------------------------------------------------------------------
// 02 Table
// ---------------------------------------------------------------------------

/// 02, the host's: Ana's table of five, the Classic chip.
Future<void> pumpTableHost(WidgetTester tester, {double textScale = 1}) =>
    TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_v2_auto_deck_5'),
      viewer: 'Ana',
      textScale: textScale,
    );

/// 02, the host's, at three: as few as the server deals to.
Future<void> pumpTableHostThree(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('detail_v2_auto_deck_5', players: 3),
  viewer: 'Ana',
);

/// 02, the host's, alone at a new table: "Need 3 players".
Future<void> pumpTableHostAlone(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('created_with_defaults'),
  viewer: 'Ana',
);

/// 02, the host's, at ten (as many as the server seats) with long names.
Future<void> pumpTableHostTen(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('detail_v2_auto_deck_9', players: 10, rename: longNames),
  viewer: 'Christopher',
);

/// 02, the host's, with her own deck of twelve for nine.
Future<void> pumpTableHostCustom(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('detail_v2_custom_deck'),
  viewer: 'Ana',
);

/// 02, the host's own deck, one player short of it: "Remove 1 cards".
Future<void> pumpTableHostMismatch(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('detail_v2_custom_deck', players: 8),
  viewer: 'Ana',
);

/// 02, a guest's: Ben at Ana's table.
Future<void> pumpTableGuest(WidgetTester tester, {double textScale = 1}) =>
    TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_v2_auto_deck_5'),
      viewer: 'Ben',
      textScale: textScale,
    );

/// 02 after a handover: Ben stands in for Ana, and his phone hosts.
Future<void> pumpTableHandover(WidgetTester tester) async {
  final setup = await pumpTableGuestSetup(tester);
  final handover = ContractSamples.map('ws/lobby/host_changed_handover');
  setup.event({
    ...handover,
    'host_id': setup.viewerId,
    'host_name': 'Ben',
    'original_host_id': memberId(setup.lobby!, 'Ana'),
  });
  await setup.settle(tester);
}

Future<TableSetup> pumpTableGuestSetup(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('detail_v2_auto_deck_5'),
  viewer: 'Ben',
);

// ---------------------------------------------------------------------------
// 03 Deck and 03b
// ---------------------------------------------------------------------------

/// 03 from the host's 02 ("Edit"): the chips, the Classic one chosen.
Future<void> pumpDeckChips(WidgetTester tester) async {
  await pumpTableHost(tester);
  await _openDeck(tester);
}

/// 03 with the grid open on the host's own deck.
Future<void> pumpDeckGrid(WidgetTester tester) async {
  await pumpTableHostCustom(tester);
  await _openDeck(tester);
}

/// 03 with the grid open and a card taken out: "Add 1 cards".
Future<void> pumpDeckGridShort(WidgetTester tester) async {
  await pumpDeckGrid(tester);
  await tester.tap(
    find.byWidgetPredicate((w) => w is RoleCard && w.role == RoleId.tanner),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

/// 03b: a card held on the grid.
Future<void> pumpDeckRole(WidgetTester tester) async {
  await pumpDeckGrid(tester);
  await tester.longPress(
    find.byWidgetPredicate(
      (w) => w is RoleCard && w.role == RoleId.troublemaker,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDeck(WidgetTester tester) async {
  final edit = find.text(TableCopy.editDeck);
  await tester.ensureVisible(edit);
  await tester.pumpAndSettle();
  await tester.tap(edit);
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
