import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/night/board_layout.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../../helpers/component_sheet.dart';
import '../../helpers/fit_checks.dart';
import '../../helpers/pump_skinned.dart';
import '../../helpers/sheet/night_pages.dart';
import '../../helpers/sheet/sheet_data.dart';
import '../../helpers/truncated_text.dart';

// The night board at every table the server seats (3 to 10), on the narrow
// phones and with the text made larger, with long names and short: no row
// holds one seat's card alone (unless it is the only row), every name is
// drawn whole (never cut, never broken inside a word), and every card is on
// the screen above the button.

const _widths = [320.0, 360.0, 390.0];
const _textScales = [1.0, 1.3, 2.0];

/// Game 8's table (nine, the Drunk's phone) at [seats], long names or the
/// recorded short ones. Seats leave from the front; the Drunk stays.
Map<String, dynamic> _table(int seats, {required bool long}) {
  final me = Viewer.drunk.nightMe;
  final others = [
    for (final seat in NightSeat.seatsOf(me))
      if (seat.id != selfIn(me)) seat.name,
  ];
  return tableOf(
    me,
    leave: {...others.take(9 - seats.clamp(1, 9))},
    add: seats > 9 ? seats - 9 : 0,
    rename: long ? longNames : const {},
  );
}

/// The seats' cards (not the table's), grouped into rows by where they lie.
List<int> _rows(WidgetTester tester) {
  final tops = <double, int>{};
  for (final element in find.byType(FaceDownCard).evaluate()) {
    final card = element.widget as FaceDownCard;
    if (card.ownerName == null) continue;
    final top = tester.getTopLeft(find.byWidget(card)).dy.roundToDouble();
    tops[top] = (tops[top] ?? 0) + 1;
  }
  return [for (final top in tops.keys.toList()..sort()) tops[top]!];
}

void main() {
  test('the splits never leave a card alone on a row', () {
    for (var seats = 3; seats <= 10; seats++) {
      for (final rows in BoardLayout.splits(seats)) {
        expect(rows.reduce((a, b) => a + b), seats);
        expect(rows.first - rows.last, lessThanOrEqualTo(1));
        if (rows.length > 1) expect(rows.last, greaterThan(1), reason: '$rows');
      }
    }
    expect(BoardLayout.splits(5), anyElement(equals([3, 2])));
    expect(BoardLayout.splits(5), isNot(anyElement(equals([4, 1]))));
    expect(
      BoardLayout.splits(9),
      containsAll([
        [5, 4],
        [3, 3, 3],
      ]),
    );
  });

  for (final long in [false, true]) {
    for (final width in _widths) {
      for (final scale in _textScales) {
        testWidgets('${long ? 'long' : 'short'} names at $width wide, text '
            'x$scale: 3 to 10 seats, no card alone on a row, every name '
            'whole, every card on screen', (tester) async {
          tester.view.physicalSize = Size(width, width * 844 / 390);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          final findings = <String>[];
          for (var seats = 3; seats <= 10; seats++) {
            await _pump(
              tester,
              BoardPage(
                viewer: Viewer.drunk,
                table: (_) => _table(seats, long: long),
              ),
            );
            final where = '$seats seats';
            final rows = _rows(tester);
            expect(rows.reduce((a, b) => a + b), seats, reason: where);
            if (rows.length > 1 && rows.contains(1)) {
              findings.add('$where: a card alone on a row ($rows)');
            }
            findings.addAll([
              for (final cut in truncatedText(tester)) '$where: $cut',
              for (final word in brokenWords(tester)) '$where: $word',
              for (final card in offBoard(tester)) '$where: $card',
            ]);
            final error = tester.takeException();
            if (error != null) findings.add('$where: $error');
          }
          expect(findings, isEmpty);
        });
      }
    }
  }

  testWidgets('the board is laid out from every name at the table: a long '
      'name moves every phone\'s board the same', (tester) async {
    tester.view.physicalSize = const Size(320, 692);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final layouts = <List<Rect>>[];
    for (final viewer in [Viewer.drunk, Viewer.doppelganger]) {
      await _pump(
        tester,
        BoardPage(
          viewer: viewer,
          table: (me) =>
              tableOf(me, rename: {...longNames, 'Gus': 'Anna Maria Lopez'}),
        ),
      );
      layouts.add([
        for (final element in find.byType(FaceDownCard).evaluate())
          tester.getRect(find.byWidget(element.widget)),
      ]);
    }
    expect(layouts.last, layouts.first);
  });
}

/// [page] as a phone in its first game has it (the hold learned).
Future<void> _pump(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: learnedOverrides(ComponentPage.action.learned),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: skinTheme(skinsUnderTest.values.first),
        builder: (context, child) =>
            GroundScope(ground: GroundKind.night, child: child!),
        home: page,
      ),
    ),
  );
  await tester.pump();
}
