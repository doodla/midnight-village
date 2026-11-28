import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/features/lobby/presentation/at_table_screen.dart';

import '../../../helpers/finger.dart';
import '../../../helpers/live_game_setup.dart' show testHealTiming;
import '../../../helpers/table_setup.dart';

// A seated phone asks "where am I" again and again (the slow poll). An answer
// that says the same thing must redraw nothing: the waiting table and the deck
// used to rebuild whole, about 480 widgets, on every answer.

/// The widgets rebuilt while [polls] polls answer, by type.
Future<Map<String, int>> _rebuiltOver(WidgetTester tester, int polls) async {
  final rebuilt = <String, int>{};
  debugOnRebuildDirtyWidget = (element, _) {
    final type = '${element.widget.runtimeType}';
    rebuilt[type] = (rebuilt[type] ?? 0) + 1;
  };
  addTearDown(() => debugOnRebuildDirtyWidget = null);
  for (var i = 0; i < polls; i++) {
    await tester.pump(testHealTiming.tablePoll);
    await tester.pump();
  }
  debugOnRebuildDirtyWidget = null;
  return rebuilt;
}

void main() {
  testWidgets('02: the poll answers the same ten times and the table is '
      'not rebuilt', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_seats_8_four_here'),
      viewer: 'Tia',
    );
    await setup.settle(tester);
    // The poll heals a socket that is down: its socket dropped.
    setup.lobbySocketDown(tester, 'D3GL6S');
    expect(find.byType(AtTableView), findsOneWidget);
    final asked = setup.http.requests
        .where((r) => r.path.contains('/me/table/'))
        .length;

    final rebuilt = await _rebuiltOver(tester, 10);

    expect(
      setup.http.requests.where((r) => r.path.contains('/me/table/')).length,
      greaterThan(asked + 5),
      reason: 'the poll did ask, again and again',
    );
    expect(rebuilt['AtTableView'], isNull, reason: '$rebuilt');
    expect(rebuilt['AtTableScreen'], isNull, reason: '$rebuilt');
    await setup.close(tester);
  });

  testWidgets('02: the same answers ask for no frame at all', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_seats_8_four_here'),
      viewer: 'Tia',
    );
    await setup.settle(tester);
    setup.lobbySocketDown(tester, 'D3GL6S');
    final asked = setup.http.requests
        .where((r) => r.path.contains('/me/table/'))
        .length;
    var frames = 0;
    for (var i = 0; i < 10; i++) {
      await tester.binding.delayed(testHealTiming.tablePoll);
      if (tester.binding.hasScheduledFrame) {
        frames++;
        await tester.pump();
      }
    }
    expect(
      setup.http.requests.where((r) => r.path.contains('/me/table/')).length,
      greaterThan(asked + 5),
      reason: 'the poll did ask, again and again',
    );
    // A frame is drawn whole on the web (CanvasKit): an answer that changed
    // nothing draws none (the owner, 24 November 2026: "it felt like I was
    // watching a ppt").
    expect(frames, 0);
    await setup.close(tester);
  });

  testWidgets('02 with its socket up: the poll asks nothing (the socket '
      'hears a deal itself)', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_seats_8_four_here'),
      viewer: 'Tia',
    );
    await setup.settle(tester);
    final asked = setup.http.requests
        .where((r) => r.path.contains('/me/table/'))
        .length;
    await _rebuiltOver(tester, 10);
    expect(
      setup.http.requests.where((r) => r.path.contains('/me/table/')).length,
      asked,
    );
    // It drops: from then on the poll is the backstop again.
    setup.lobbySocketDown(tester, 'D3GL6S');
    await _rebuiltOver(tester, 10);
    expect(
      setup.http.requests.where((r) => r.path.contains('/me/table/')).length,
      greaterThan(asked + 5),
    );
    await setup.close(tester);
  });

  testWidgets('03: the same on the deck', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_seats_8_four_here'),
      viewer: 'Tia',
    );
    await setup.settle(tester);
    final edit = find.text(TableCopy.editDeck);
    await tester.ensureVisible(edit);
    await tester.pump();
    await pressLikeAFinger(tester, edit);
    await setup.settle(tester);
    expect(find.text(DeckCopy.headline), findsOneWidget);

    final rebuilt = await _rebuiltOver(tester, 10);

    expect(rebuilt['DeckScreen'], isNull, reason: '$rebuilt');
    expect(rebuilt['AtTableScreen'], isNull, reason: '$rebuilt');
    await setup.close(tester);
  });
}
