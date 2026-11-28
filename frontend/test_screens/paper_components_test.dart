// The paper components in pictures, for a look: the table (host and guest),
// your card (back and face), the night board (5 and 10 at the table) and the
// card-details sheet (opened from the table and from the deck page), as the live app has them, at 2x. All of ONE recorded game
// (game 7: Ana the moth, Ben the hare, Cleo the spindle, Dev the scythe, Esme
// the bell; the ten-seat board is the same game with five more seats), so a
// player's sigil is the same on every picture. Run it with
// `just paper-components [folder]`; it is not part of `just flutter-test`. The same test
// on main and on a branch makes the before and after pictures.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../test/helpers/component_sheet.dart';
import '../test/helpers/pump_skinned.dart';
import '../test/helpers/sheet/night_pages.dart';
import '../test/helpers/sheet/sheet_data.dart';
import '../test/helpers/sheet/table_pages.dart';
import '../test/helpers/real_wait.dart';
import 'shell_fixtures.dart';
import '../test/helpers/finger.dart';

const _dir = String.fromEnvironment(
  'PAPER_COMPONENTS_DIR',
  defaultValue: 'build/paper_components',
);
const _ratio = 2.0;

Future<void> _save(WidgetTester tester, String name) async {
  debugDisableShadows = false;
  final png = await tester.runAsync(() async {
    final image = await captureImage(tester.binding.rootElement!);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  });
  debugDisableShadows = true;
  Directory(_dir).createSync(recursive: true);
  File('$_dir/$name.png').writeAsBytesSync(Uint8List.fromList(png!));
}

Future<void> _settle(WidgetTester tester) async {
  // The mood's layers decode on real I/O: wait for the picture, not a time.
  await untilMoodsArePainted(tester);
  await tester.runAsync(
    () => Future.wait([
      for (final e in find.byType(Image).evaluate())
        precacheImage((e.widget as Image).image, e),
    ]),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * _ratio, 844 * _ratio);
  tester.view.devicePixelRatio = _ratio;
  addTearDown(tester.view.reset);
}

Future<void> _page(WidgetTester tester, Widget home) => tester.pumpWidget(
  ProviderScope(
    overrides: learnedOverrides(ComponentPage.action.learned),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: skinTheme(skinsUnderTest.values.first),
      builder: (context, child) =>
          GroundScope(ground: GroundKind.night, child: child!),
      home: home,
    ),
  ),
);

void main() {
  for (final guest in [false, true]) {
    testWidgets('the table, ${guest ? 'guest' : 'host'}', (tester) async {
      _phone(tester);
      await _page(tester, TablePage(guest: guest, lobby: gameSevenLobby));
      await _settle(tester);
      await _save(tester, 'table-${guest ? 'guest' : 'host'}');
    });
  }

  testWidgets('the deck set-up page', (tester) async {
    _phone(tester);
    await _page(tester, const DeckPage(lobby: gameSevenLobby));
    await _settle(tester);
    await _save(tester, 'deck');
  });

  testWidgets('the card-details sheet, opened from the table', (tester) async {
    _phone(tester);
    await _page(tester, const TablePage(lobby: gameSevenLobby));
    await _settle(tester);
    await pressLikeAFinger(tester, find.byType(RoleCard).first);
    await tester.pump(const Duration(milliseconds: 600));
    await _settle(tester);
    await _save(tester, 'sheet');
  });

  testWidgets('the card-details sheet, opened from the deck set-up page', (
    tester,
  ) async {
    _phone(tester);
    await _page(tester, const DeckPage(lobby: gameSevenLobby));
    await _settle(tester);
    await tester.longPress(find.byType(RoleCard).first);
    await tester.pump(const Duration(milliseconds: 600));
    await _settle(tester);
    await _save(tester, 'deck-sheet');
  });

  testWidgets('your card, back', (tester) async {
    _phone(tester);
    await pumpYourCard(tester);
    await _settle(tester);
    await _save(tester, 'card-back');
  });

  testWidgets('your card, face', (tester) async {
    _phone(tester);
    await pumpYourCardHeld(tester);
    await _settle(tester);
    await _save(tester, 'card-face');
  });

  testWidgets('the night board, 5 at the table', (tester) async {
    _phone(tester);
    await _page(tester, const BoardPage(viewer: Viewer.seer));
    await _settle(tester);
    await _save(tester, 'board-5');
  });

  testWidgets('the night board, 10 at the table', (tester) async {
    _phone(tester);
    await _page(
      tester,
      BoardPage(
        viewer: Viewer.robber,
        // The same game 7 (Ben the Robber's phone), five more at the table (new seats, the tokens no
        // one has), the names long to show the worst.
        table: (me) => tableOf(me, add: 5, rename: longNames),
      ),
    );
    await _settle(tester);
    await _save(tester, 'board-10');
  });
}
