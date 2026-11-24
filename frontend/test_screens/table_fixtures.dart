import '../test/helpers/finger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/lobby/presentation/join_flow.dart';
import 'package:midnight_village/design_system/primitives/viewfinder.dart';
import 'package:midnight_village/features/lobby/presentation/where_am_i_provider.dart';
import 'package:midnight_village/features/game/presentation/table_screen.dart';
import 'package:midnight_village/features/lobby/presentation/join_screen.dart';
import 'package:midnight_village/features/lobby/presentation/scan/code_scanner.dart';

import '../test/helpers/contract/contract_samples.dart';
import '../test/helpers/fake_code_scanner.dart';
import '../test/helpers/mock_http_client.dart';
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

/// 01 in an Android browser: the quiet "Get the app" at its foot.
Future<void> pumpJoinAndroidWeb(WidgetTester tester, {double textScale = 1}) =>
    TableSetup.pump(
      tester,
      signedInAs: 'Ben',
      lastWon: true,
      androidWeb: true,
      textScale: textScale,
    );

/// 01 in an Android browser, on a new phone (no numbers to say how it went).
Future<void> pumpJoinAndroidWebFresh(WidgetTester tester) =>
    TableSetup.pump(tester, androidWeb: true);

/// 01 in an Android browser, on a new phone with the keyboard up.
Future<void> pumpJoinAndroidWebKeyboard(WidgetTester tester) =>
    TableSetup.pump(tester, androidWeb: true, keyboard: 336);

/// Home while this device's saved account is read back: the game opening
/// (01's village and title), never 01's form.
Future<void> pumpHomeReading(WidgetTester tester) =>
    TableSetup.pump(tester, authState: const AuthState.initial());

/// The same once a try got no answer (it is made again by itself): "One
/// moment" under the title.
Future<void> pumpHomeUnanswered(WidgetTester tester) => TableSetup.pump(
  tester,
  authState: const AuthState.initial(unanswered: true),
);

/// The opening in its first frame: the village and the title, and not yet a
/// sign (an answer that comes now shows none, so nothing flashes).
Future<void> pumpHomeFirstFrame(WidgetTester tester) => TableSetup.pump(
  tester,
  authState: const AuthState.initial(),
  settle: false,
);

/// The opening after [Motion.slowAfter] with nothing failed: "The village is
/// waking.".
Future<void> pumpHomeSlow(WidgetTester tester) async {
  await pumpHomeReading(tester);
  await tester.pump(Motion.slowAfter);
}

/// The first `/me/table/` is slow (signed in; the player's seat is not known
/// yet): the opening again, the same place.
Future<void> pumpHomeSeatUnknown(WidgetTester tester) async {
  late HeldReplies table;
  await TableSetup.pump(
    tester,
    signedInAs: 'Ben',
    timesOut: false,
    before: (s) => table = s.http.hold(method: 'GET', path: '/me/table/'),
  );
  addTearDown(table.releaseAll);
}

/// "Start a table" tapped, the server not answered yet: its own button
/// busy, the other way in dim.
Future<void> pumpJoinStarting(WidgetTester tester) async {
  final setup = await TableSetup.pump(
    tester,
    signedInAs: 'Ben',
    lastWon: false,
    timesOut: false,
    before: (s) => s.http
      ..hold(method: 'POST', path: '/lobbies/')
      ..answer(
        'POST',
        '/lobbies/',
        v2Lobby('created_with_defaults'),
        status: 201,
      ),
  );
  await plainTap(
    tester,
    find.text(JoinCopy.startTable),
    why: 'the gallery\'s picture of a busy button is timed from the tap',
  );
  await setup.settle(tester);
}

/// [timed]: the picture is of the busy Join, timed from the tap.
Future<void> _typeCodeAndJoin(
  WidgetTester tester,
  TableSetup setup, {
  bool timed = false,
}) async {
  await pressLikeAFinger(tester, find.text(JoinCopy.joinTable));
  await tester.pump();
  await tester.enterText(find.byType(TextField).last, 'V9YC2J');
  await tester.pump();
  if (timed) {
    await plainTap(
      tester,
      find.text(JoinCopy.join),
      why: 'the gallery\'s picture of a busy button is timed from the tap',
    );
  } else {
    await pressLikeAFinger(tester, find.text(JoinCopy.join));
  }
  await setup.settle(tester);
}

/// "Join" tapped with a code typed, the server not answered yet.
Future<void> pumpJoinJoining(WidgetTester tester) async {
  final setup = await TableSetup.pump(
    tester,
    signedInAs: 'Ben',
    lastWon: false,
    timesOut: false,
    before: (s) => s.http
      ..hold(method: 'POST', path: '/lobbies/V9YC2J/join/')
      ..answer(
        'POST',
        '/lobbies/V9YC2J/join/',
        ContractSamples.map('http/lobby/joined'),
      ),
  );
  await _typeCodeAndJoin(tester, setup, timed: true);
}

/// A join that got no answer: "Not sent." with "Try again", on 01.
Future<void> pumpJoinNotSent(WidgetTester tester) async {
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
  await _typeCodeAndJoin(tester, setup);
}

/// A join the server refused, with its reason: no "Try again".
Future<void> pumpJoinRefused(
  WidgetTester tester, {
  String sample = 'join_not_found',
  int status = 404,
}) async {
  final setup = await TableSetup.pump(
    tester,
    signedInAs: 'Ben',
    lastWon: false,
    before: (s) => s.http.answer(
      'POST',
      '/lobbies/V9YC2J/join/',
      ContractSamples.load('http/lobby/$sample'),
      status: status,
    ),
  );
  await _typeCodeAndJoin(tester, setup);
}

/// A table started with no answer: "Not sent." with "Try again", on 01.
Future<void> pumpStartNotSent(WidgetTester tester) async {
  final setup = await TableSetup.pump(
    tester,
    signedInAs: 'Ben',
    lastWon: false,
    before: (s) =>
        s.http.answer('POST', '/lobbies/', 'Server Error', status: 503),
  );
  await pressLikeAFinger(tester, find.text(JoinCopy.startTable));
  await setup.settle(tester);
}

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

/// 01 with "Join a table" opened and no code yet: "Join" locked, saying
/// "Code"; "Start a table" still the amber plaque.
Future<void> pumpJoinCodeOpen(WidgetTester tester) async {
  await pumpJoinReturning(tester);
  await pressLikeAFinger(tester, find.text(JoinCopy.joinTable));
  await tester.pump();
}

/// 01 with "Join a table" opened and the code typed: "Join" the amber
/// plaque, "Start a table" a scrap.
Future<void> pumpJoinCode(WidgetTester tester) async {
  await pumpJoinReturning(tester);
  await pressLikeAFinger(tester, find.text(JoinCopy.joinTable));
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
  await pressLikeAFinger(tester, find.text(JoinCopy.joinTable));
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

/// 01 for a player with a name, the scan action tapped: the camera looking
/// (a picture of a table with a code on it stands in), the light on offer.
Future<void> pumpScanLooking(
  WidgetTester tester, {
  double textScale = 1,
}) async {
  await TableSetup.pump(
    tester,
    signedInAs: 'Ben',
    lastWon: false,
    textScale: textScale,
    scanner: () => FakeCodeScanner(lit: LightState.off),
  );
  await _openScanner(tester);
}

/// The same, the code seen: the window's corners are in, the code stands in
/// it and the join is on its way (its answer is held).
Future<void> pumpScanFound(WidgetTester tester) async {
  final setup = await TableSetup.pump(
    tester,
    signedInAs: 'Ben',
    lastWon: false,
    // The held join is never answered, and never given up on.
    timesOut: false,
    scanner: () => FakeCodeScanner(lit: LightState.off),
  );
  setup.http
    ..answer(
      'POST',
      '/lobbies/V9YC2J/join/',
      ContractSamples.map('http/lobby/joined'),
    )
    ..hold(method: 'POST', path: '/lobbies/V9YC2J/join/');
  setup.sitAt(v2Lobby('detail_auto_deck_5'), 'Ben');
  await _openScanner(tester);
  setup.scanners.single.see('https://midnight.example/join/V9YC2J');
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The camera was refused: one calm line, and the way on.
Future<void> pumpScanRefused(WidgetTester tester) async {
  await TableSetup.pump(
    tester,
    signedInAs: 'Ben',
    lastWon: false,
    scanner: () => FakeCodeScanner(problem: ScanProblem.refused),
  );
  await _openScanner(tester);
}

Future<void> _openScanner(WidgetTester tester) async {
  await pressLikeAFinger(
    tester,
    find.byWidgetPredicate(
      (w) => w is GlyphButton && w.semanticLabel == ScanCopy.scan,
    ),
  );
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

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
    timesOut: false,
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
Future<void> pumpTableHostNine(WidgetTester tester, {double textScale = 1}) =>
    TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_auto_deck_9', rename: longNames),
      viewer: 'Christopher',
      textScale: textScale,
    );

/// 02, the host's, with her own deck of twelve for nine.
Future<void> pumpTableHostCustom(WidgetTester tester) async {
  _setup = await TableSetup.pump(
    tester,
    lobby: v2Lobby('detail_custom_deck'),
    viewer: 'Ana',
    timesOut: false,
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

/// 02 at Tia's table set for eight before anyone came: she alone, her own
/// deck of eleven, seven empty places.
Future<void> pumpTableSeatsAlone(WidgetTester tester, {double textScale = 1}) =>
    TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_seats_8_custom_alone'),
      viewer: 'Tia',
      textScale: textScale,
    );

/// 02 at a table set for eight, four here: "4 of 8", four empty places,
/// the deck face up, "Need 4 more".
Future<void> pumpTableSeatsFour(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('detail_seats_8_four_here'),
  viewer: 'Tia',
);

/// The same table on a guest's phone: the same count, the same roles.
Future<void> pumpTableSeatsGuest(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('detail_seats_8_four_here'),
  viewer: 'Ugo',
);

/// Three of eight here (the recorded table of four, its last member not
/// come yet): [viewer]'s phone, the host's or a guest's.
Future<void> pumpTableSeatsThree(WidgetTester tester, {String viewer = 'Tia'}) {
  final lobby = v2Lobby('detail_seats_8_four_here');
  (lobby['players'] as List).removeLast();
  return TableSetup.pump(tester, lobby: lobby, viewer: viewer);
}

/// Seven of eight came: "Play with 7".
Future<void> pumpTableSeatsSeven(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('detail_seats_8_seven_here'),
  viewer: 'Tia',
);

/// "Play with 7" tapped: set for seven, the deck for eight now one over.
Future<void> pumpTableSeatsLowered(WidgetTester tester) async {
  final setup = await TableSetup.pump(
    tester,
    lobby: v2Lobby('detail_seats_8_seven_here'),
    viewer: 'Tia',
  );
  setup.answerPatch(v2Lobby('settings_seats_lowered'));
  final play = find.text(TableCopy.playWith.fill({'n': 7}));
  await tester.ensureVisible(play);
  await tester.pumpAndSettle();
  await pressLikeAFinger(tester, play);
  await setup.settle(tester);
}

/// 02 at the blocked table, the host's: set for seven, her own deck of eleven
/// one over: "Remove 1 card", no "Edit", no second count.
Future<void> pumpTableLowered(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('settings_seats_lowered'),
  viewer: 'Tia',
);

/// The same blocked table on a guest's phone (set for seven, the host's deck
/// of eleven one over): the same places and cards, no button to fix it.
Future<void> pumpTableLoweredGuest(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('settings_seats_lowered'),
  viewer: 'Ugo',
);

/// Eight of eight, the automatic deck: "Start the game" live.
Future<void> pumpTableSeatsFull(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('detail_seats_8_full'),
  viewer: 'Tia',
);

/// 02 while the table's lobby is read (the seat is known, the lobby not).
Future<void> pumpTableWaiting(WidgetTester tester) async {
  late HeldReplies lobby;
  await TableSetup.pump(
    tester,
    lobby: v2Lobby('detail_auto_deck_5'),
    viewer: 'Ana',
    timesOut: false,
    before: (s) =>
        lobby = s.http.hold(method: 'GET', path: '/lobbies/${s.code}/'),
  );
  addTearDown(lobby.releaseAll);
}

/// 02 while the lobby cannot be read: "One moment".
Future<void> pumpTableOffline(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('detail_auto_deck_5'),
  viewer: 'Ana',
  lobbyDown: true,
);

/// The host's "Start the game" tapped, the server not answered yet.
Future<void> pumpTableDealing(WidgetTester tester) async {
  final setup = await TableSetup.pump(
    tester,
    lobby: v2Lobby('detail_auto_deck_5'),
    viewer: 'Ana',
    timesOut: false,
    before: (s) => s.http
      ..hold(method: 'POST', path: '/onuw/lobbies/${s.code}/start/')
      ..answer(
        'POST',
        '/onuw/lobbies/${s.code}/start/',
        ContractSamples.map('http/game/started_with_look'),
        status: 201,
      ),
  );
  await plainTap(
    tester,
    find.byType(PrimaryButton).last,
    why: 'the gallery\'s picture of a busy button is timed from the tap',
  );
  await setup.settle(tester);
}

/// A deal that got no answer: "Not sent." with "Try again".
Future<void> pumpTableDealNotSent(WidgetTester tester) async {
  final setup = await TableSetup.pump(
    tester,
    lobby: v2Lobby('detail_auto_deck_5'),
    viewer: 'Ana',
    before: (s) => s.http.answer(
      'POST',
      '/onuw/lobbies/${s.code}/start/',
      'Server Error',
      status: 503,
    ),
  );
  await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
  await setup.settle(tester);
}

/// A guest's "Leave" tapped, the server not answered yet.
Future<void> pumpTableLeaving(WidgetTester tester) async {
  final setup = await TableSetup.pump(
    tester,
    lobby: v2Lobby('detail_auto_deck_5'),
    viewer: 'Ben',
    timesOut: false,
    before: (s) => s.http
      ..hold(method: 'POST', path: '/lobbies/${s.code}/leave/')
      ..answer(
        'POST',
        '/lobbies/${s.code}/leave/',
        ContractSamples.load('http/lobby/left'),
      ),
  );
  await plainTap(
    tester,
    find.text(CommonCopy.leave).last,
    why: 'the gallery\'s picture of a busy button is timed from the tap',
  );
  await setup.settle(tester);
}

/// A leave that got no answer while the server still has the phone at the
/// table: "Not sent." with "Try again".
Future<void> pumpTableLeaveNotSent(WidgetTester tester) async {
  final setup = await TableSetup.pump(
    tester,
    lobby: v2Lobby('detail_auto_deck_5'),
    viewer: 'Ben',
    before: (s) => s.http.answer(
      'POST',
      '/lobbies/${s.code}/leave/',
      'Server Error',
      status: 503,
    ),
  );
  await pressLikeAFinger(tester, find.text(CommonCopy.leave).last);
  await setup.settle(tester);
}

/// 02 at Pia's table: Quin and two practice players the server plays
/// (Scarecrow and Teapot), each tagged "Practice"; [viewer]'s phone.
Future<void> pumpTablePractice(WidgetTester tester, {String viewer = 'Pia'}) =>
    TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_practice_guest'),
      viewer: viewer,
    );

/// 02 at Pia's table set for six: two people and two practice players
/// here, "4 of 6", "Play with 4" beside the practice players.
Future<void> pumpTablePracticeShort(WidgetTester tester) => TableSetup.pump(
  tester,
  lobby: v2Lobby('detail_practice_short'),
  viewer: 'Pia',
);

// ---------------------------------------------------------------------------
// 03 Deck and 03b
// ---------------------------------------------------------------------------

/// 03 while the table's lobby is read (the host has it open): the wait.
Future<void> pumpDeckWaiting(WidgetTester tester) async {
  late HeldReplies lobby;
  await TableSetup.pump(
    tester,
    lobby: v2Lobby('detail_auto_deck_5'),
    viewer: 'Ana',
    timesOut: false,
    before: (s) =>
        lobby = s.http.hold(method: 'GET', path: '/lobbies/${s.code}/'),
  );
  addTearDown(lobby.releaseAll);
  _openDeckWithoutLobby(tester);
  await tester.pump(const Duration(milliseconds: 100));
}

/// 03 while the lobby cannot be read: "One moment" with "Try again".
Future<void> pumpDeckOffline(WidgetTester tester) async {
  await TableSetup.pump(
    tester,
    lobby: v2Lobby('detail_auto_deck_5'),
    viewer: 'Ana',
    lobbyDown: true,
  );
  _openDeckWithoutLobby(tester);
  await tester.pump(const Duration(milliseconds: 100));
}

void _openDeckWithoutLobby(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(Scaffold).first),
  );
  container
      .read(localStepsProvider.notifier)
      .openDeck(container.read(myTableProvider).requireValue!);
}

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
    SpokenCopy.takeOut.fill({'role': RoleId.tanner.displayName}),
  );
  await tester.ensureVisible(minus);
  await tester.pumpAndSettle();
  await pressLikeAFinger(tester, minus);
  await tester.pump(const Duration(milliseconds: 300));
}

/// 03 on the host's own deck with two cards put in: two over the need, and
/// "Done" tapped once (the owner's dead end, 23 November 2026: the page used
/// to let her leave it so).
Future<void> pumpDeckGridOver(WidgetTester tester) async {
  await pumpDeckGrid(tester);
  _holdPatch(_setup!.code);
  await _tapCard(tester, RoleId.robber);
  await _tapCard(tester, RoleId.hunter);
  // The first "Done" does not leave: it brings the count into view and
  // nudges it.
  await pressLikeAFinger(tester, find.text(DeckCopy.done));
  await tester.pumpAndSettle();
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

/// 03 at Pia's table with two practice players: the Practice row under
/// Players (switched on: it shows nowhere else).
Future<void> pumpDeckPractice(WidgetTester tester) async {
  await _pumpHost(tester, 'detail_practice_guest', 'Pia');
  await _openDeck(tester);
}

/// 03 alone at a new table, "Players" just held: the Practice row at 0,
/// shown at once (the server's answer held).
Future<void> pumpDeckPracticeSwitched(WidgetTester tester) async {
  // A picture that holds an answer never waits it out.
  final setup = _setup = await TableSetup.pump(
    tester,
    lobby: v2Lobby('created_with_defaults'),
    viewer: 'Ana',
    timesOut: false,
  );
  await _openDeck(tester);
  final path = '/lobbies/${setup.code}/practice/';
  setup.http.hold(method: 'POST', path: path);
  setup.http.answer(
    'POST',
    path,
    ContractSamples.map('http/lobby/practice_on'),
  );
  await tester.longPress(find.text(DeckCopy.players));
  await tester.pump(const Duration(milliseconds: 300));
}

/// 03 scrolled to its lengths, at a new table.
Future<void> pumpDeckLengths(WidgetTester tester) async {
  await pumpDeckAlone(tester);
  final last = find.text(DeckCopy.hostAway);
  await tester.ensureVisible(last);
  await tester.pumpAndSettle();
}

/// 03 on the host's own deck, which holds a Doppelganger, scrolled to its
/// lengths: the Doppelganger's row is there.
Future<void> pumpDeckLengthsDoppelganger(WidgetTester tester) async {
  await pumpDeckGrid(tester);
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
  await pressLikeAFinger(tester, card);
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

/// 03b with the Werewolf: the card sheet of a table that is not in a game yet
/// (the owner's picture, 23 November 2026: the sheet had no portrait).
Future<void> pumpDeckRoleWerewolf(WidgetTester tester) async {
  await pumpDeckGrid(tester);
  await tester.longPress(
    find.byWidgetPredicate((w) => w is RoleCard && w.role == RoleId.werewolf),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDeck(WidgetTester tester) async {
  final edit = find.text(TableCopy.editDeck);
  await tester.ensureVisible(edit);
  await tester.pumpAndSettle();
  await pressLikeAFinger(tester, edit);
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
