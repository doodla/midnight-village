import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/features/lobby/presentation/join_flow.dart';
import 'package:midnight_village/features/lobby/presentation/join_screen.dart';

import '../test/helpers/contract/contract_samples.dart';
import '../test/helpers/table_setup.dart';

// 01 Join, 02 Table, 03 Deck and 03b through the app's real routes and
// providers (test/helpers/table_setup.dart), every answer a recorded
// lobby payload, each state reached the way a player reaches it.
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

/// 01 on a fresh phone with the keyboard up (the name field is focused):
/// a phone keyboard's height at 390 wide.
Future<void> pumpJoinKeyboard(WidgetTester tester) =>
    TableSetup.pump(tester, keyboard: 336);

/// 01 after the game's table closed (a fetch answered 404).
Future<void> pumpJoinClosed(WidgetTester tester) async {
  await pumpJoinReturning(tester);
  ProviderScope.containerOf(
    tester.element(find.byType(JoinScreen)),
  ).read(joinFlowProvider.notifier).tableClosed();
  await tester.pump();
}

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

/// 01 from a table's link on a new phone, the name typed: "Join" open.
Future<void> pumpJoinLinkNamed(WidgetTester tester) async {
  await pumpJoinLink(tester);
  await tester.enterText(find.byType(TextField), 'Ben');
  await tester.pump();
}

/// A table's link opened by a player seated at another table.
Future<void> pumpJoinLinkElsewhere(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('detail_auto_deck_5'),
  viewer: 'Ben',
  route: '/join/W3XF7K',
);

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
      lobby: v2Lobby('detail_auto_deck_5'),
      viewer: 'Ana',
      textScale: textScale,
    );

/// 02, the host's: Kai's table of four, the Simple chip's cards.
Future<void> pumpTableHostFour(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('detail_deck_simple_4'),
  viewer: 'Kai',
);

/// 02, the host's: seven at the table, scrolled to the deck: the Chaos
/// chip and its ten cards face up.
Future<void> pumpTableHostChaos(WidgetTester tester) async {
  _setup = await TableSetup.pump(
    tester,
    lobby: v2Lobby('detail_deck_chaos_7'),
    viewer: 'Kai',
  );
  await tester.ensureVisible(find.text(TableCopy.editDeck));
  await tester.pumpAndSettle();
}

/// 02, the host's, alone at a new table: "Need 3 players".
Future<void> pumpTableHostAlone(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('created_with_defaults'),
  viewer: 'Ana',
);

/// 02, the host's, at nine with long names, the Chaos chip's twelve cards.
Future<void> pumpTableHostNine(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('detail_auto_deck_9', rename: longNames),
  viewer: 'Christopher',
);

/// 02, the host's, with her own deck of twelve for nine.
Future<void> pumpTableHostCustom(WidgetTester tester) async {
  _setup = await TableSetup.pump(
    tester,
    lobby: v2Lobby('detail_custom_deck'),
    viewer: 'Ana',
  );
}

/// 02, the host's own deck of ten, an eighth player in: "Add 1 card".
Future<void> pumpTableHostMismatch(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('detail_custom_deck_short', asRecorded: true),
  viewer: 'Kai',
);

/// 02, the host's: Noa's phone has dropped (her row dimmed, no words).
Future<void> pumpTableDropped(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('detail_member_dropped', asRecorded: true),
  viewer: 'Kai',
);

/// 02, a guest's: Ben at Ana's table.
Future<void> pumpTableGuest(WidgetTester tester, {double textScale = 1}) =>
    TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_auto_deck_5'),
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
  lobby: v2Lobby('detail_auto_deck_5'),
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

/// 03 on Kai's table of seven, the Chaos chip's cards face up.
Future<void> pumpDeckChaos(WidgetTester tester) async {
  await pumpTableHostChaos(tester);
  await _openDeck(tester);
}

/// 03 on the Chaos chip's cards, a Tanner tapped in: the deck is the
/// host's own now, for the seven here (its answer held: shown at once).
Future<void> pumpDeckEdit(WidgetTester tester) async {
  await pumpTableHostChaos(tester);
  await _openDeck(tester);
  _holdPatch('B7DH4Q');
  await _tapCard(tester, RoleId.tanner);
}

/// 03 on the host's own deck.
Future<void> pumpDeckGrid(WidgetTester tester) async {
  await pumpTableHostCustom(tester);
  await _openDeck(tester);
}

/// 03 on the host's own deck with a card taken out (its minus): the count
/// under the need, "Use this deck" locked.
Future<void> pumpDeckGridShort(WidgetTester tester) async {
  await pumpDeckGrid(tester);
  _holdPatch(_setup!.code);
  final minus = find.bySemanticsLabel(
    DeckCopy.takeOut.fill({'role': RoleId.tanner.displayName}),
  );
  await tester.ensureVisible(minus);
  await tester.pumpAndSettle();
  await tester.tap(minus);
  await tester.pump(const Duration(milliseconds: 300));
}

/// 03 at Tia's table set for eight, four here, her own deck of eleven.
Future<void> pumpDeckSeats(WidgetTester tester) async {
  await _pumpHost(tester, 'detail_seats_8_four_here', 'Tia');
  await _openDeck(tester);
}

/// 03 alone at a new table: open ("Any"), the server's defaults filled in.
Future<void> pumpDeckAlone(WidgetTester tester, {double textScale = 1}) async {
  _setup = await TableSetup.pump(
    tester,
    lobby: v2Lobby('created_with_defaults'),
    viewer: 'Ana',
    textScale: textScale,
  );
  await _openDeck(tester);
}

/// 03 scrolled to its lengths, at a new table.
Future<void> pumpDeckLengths(WidgetTester tester) async {
  await pumpDeckAlone(tester);
  final last = find.text(DeckCopy.hostAway);
  await tester.ensureVisible(last);
  await tester.pumpAndSettle();
}

TableSetup? _setup;

Future<void> _pumpHost(
  WidgetTester tester,
  String sample,
  String viewer,
) async {
  _setup = await TableSetup.pump(
    tester,
    lobby: v2Lobby(sample),
    viewer: viewer,
  );
}

/// The next settings change is shown at once, its answer held.
void _holdPatch(String code) {
  final setup = _setup;
  if (setup == null) return;
  setup.http.hold(method: 'PATCH', path: '/lobbies/$code/');
  setup.answerPatch(ContractSamples.map('http/lobby/settings_deck_chip'));
}

Future<void> _tapCard(WidgetTester tester, RoleId role) async {
  final card = find.byWidgetPredicate((w) => w is RoleCard && w.role == role);
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await tester.tap(card);
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

// ---------------------------------------------------------------------------
// The cold-read pack's table (game 7): its own recorded lobby bodies
// ---------------------------------------------------------------------------

/// 02 on [viewer]'s phone at the table of `contract_samples/http/lobby/
/// [sample].json`.
Future<void> pumpTableOf(WidgetTester tester, String sample, String viewer) =>
    TableSetup.pump(tester, lobby: v2Lobby(sample), viewer: viewer);

/// 03 opened from that 02; with [role] a card of it held (03b).
Future<void> pumpDeckOf(
  WidgetTester tester,
  String sample,
  String viewer, {
  bool role = false,
}) async {
  await pumpTableOf(tester, sample, viewer);
  await _openDeck(tester);
  if (!role) return;
  await tester.longPress(
    find.byWidgetPredicate(
      (w) => w is RoleCard && w.role == RoleId.troublemaker,
    ),
  );
  await tester.pumpAndSettle();
}

/// 01 from the table's link, signed out; with [name] typed.
Future<void> pumpJoinLinkTo(
  WidgetTester tester,
  String code, {
  String? name,
}) async {
  await TableSetup.pump(tester, route: '/join/$code');
  if (name == null) return;
  await tester.enterText(find.byType(TextField), name);
  await tester.pump();
}

/// 01 on a new phone; with [name] typed.
Future<void> pumpJoinAs(WidgetTester tester, {String? name}) async {
  await pumpJoinFresh(tester);
  if (name == null) return;
  await tester.enterText(find.byType(TextField), name);
  await tester.pump();
}
