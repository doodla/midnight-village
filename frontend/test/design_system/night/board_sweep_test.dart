import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/night/board_layout.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'board_harness.dart' show card;
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

/// The phones: the mocks' shape at 320, 360 and 390 wide, and the short
/// ones (an iPhone SE's 320 x 568, a small Android's 360 x 640).
const _phones = [
  Size(320, 692),
  Size(320, 568),
  Size(360, 779),
  Size(360, 640),
  Size(390, 844),
];
const _textScales = [1.0, 1.3, 2.0];

/// The names at the table: as recorded (short), long, or short with two
/// names of three words that wrap (the last two seats, so every table from
/// 3 up has them).
enum _Names {
  short({}),
  long(longNames),
  wrapping({'Hana': 'Mary Jane Lee', 'Ida': 'Ana Paula Silva'});

  const _Names(this.rename);

  final Map<String, String> rename;
}

/// Game 8's table (nine, the Drunk's phone) at [seats], named [names].
/// Seats leave from the front; the Drunk stays.
Map<String, dynamic> _table(int seats, _Names names) {
  final me = Viewer.drunk.nightMe;
  final others = [
    for (final seat in NightSeat.seatsOf(me))
      if (seat.id != selfIn(me)) seat.name,
  ];
  return tableOf(
    me,
    leave: {...others.take(9 - seats.clamp(1, 9))},
    add: seats > 9 ? seats - 9 : 0,
    rename: names.rename,
  );
}

/// The seats' cards (not the table's), grouped into rows by where they lie.
List<int> _rows(WidgetTester tester) {
  final tops = <double, int>{};
  for (final element in find.byType(FaceDownCard).evaluate()) {
    final card = element.widget as FaceDownCard;
    // The seats: "You" is in front, not among them.
    if (card.ownerName == null || card.ownerName == NightCopy.you) continue;
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

  for (final names in _Names.values) {
    for (final phone in _phones) {
      for (final scale in _textScales) {
        testWidgets('${names.name} names on a ${phone.width.round()} x '
            '${phone.height.round()} phone, text x$scale: 3 to 10 seats, no '
            'card alone on a row, every name whole, every card on screen and '
            'a thumb wide', (tester) async {
          tester.view.physicalSize = phone;
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
                table: (_) => _table(seats, names),
              ),
            );
            final where = '$seats seats';
            final rows = _rows(tester);
            expect(rows.reduce((a, b) => a + b), seats - 1, reason: where);
            if (rows.length > 1 && rows.contains(1)) {
              findings.add('$where: a card alone on a row ($rows)');
            }
            findings.addAll([
              for (final cut in truncatedText(tester)) '$where: $cut',
              for (final word in brokenWords(tester)) '$where: $word',
              for (final card in offBoard(tester)) '$where: $card',
              for (final element in find.byType(FaceDownCard).evaluate())
                if (tester.getSize(find.byWidget(element.widget)) case final hit
                    when hit.width < BoardLayout.minTap - 0.5 ||
                        hit.height < BoardLayout.minTap - 0.5)
                  '$where: "${(element.widget as FaceDownCard).semanticLabel}" '
                      'is tapped in ${hit.width.toStringAsFixed(1)} x '
                      '${hit.height.toStringAsFixed(1)}',
            ]);
            final error = tester.takeException();
            if (error != null) findings.add('$where: $error');
          }
          expect(findings, isEmpty);
        });
      }
    }
  }

  // The button says what will happen, with the names picked: "Swap Ana, Ben"
  // with the two longest names the server allows. A name is never cut: the
  // label wraps between words onto a second line, is set smaller if a word is
  // too wide, and the board takes the height.
  for (final phone in const [Size(320, 692), Size(320, 568)]) {
    for (final scale in _textScales) {
      testWidgets('the longest names in the button of every role on a '
          '${phone.width.round()} x ${phone.height.round()} phone, text '
          'x$scale: whole, on screen, no card pushed off', (tester) async {
        tester.view.physicalSize = phone;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        const long = ['Rosalind Fairweather', 'Bartholomew Longname'];

        final findings = <String>[];
        for (final (viewer, picks) in [
          (Viewer.seer, 1),
          (Viewer.robber, 1),
          (Viewer.troublemaker, 2),
          (Viewer.doppelganger, 1),
        ]) {
          final me = viewer.nightMe;
          final others = [
            for (final seat in NightSeat.seatsOf(me))
              if (seat.id != selfIn(me)) seat.name,
          ];
          final names = others.take(picks).toList();
          // A phone that has shown no board yet: nothing kept from the last.
          await tester.pumpWidget(const SizedBox());
          await _pump(
            tester,
            BoardPage(
              viewer: viewer,
              table: (me) => tableOf(
                me,
                rename: {for (final (i, name) in names.indexed) name: long[i]},
              ),
            ),
          );
          // The opening wave, done.
          await tester.pump(const Duration(seconds: 2));
          for (var i = 0; i < picks; i++) {
            await tester.tap(card(long[i]));
            await tester.pump();
          }
          final label = find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.data != null &&
                w.data!.contains(long[0]) &&
                w.data!.length > long[0].length,
          );
          final where = '${viewer.name} x$scale';
          expect(label, findsOneWidget, reason: where);
          final text = (tester.widget(label) as Text).data!;
          expect(text, switch (viewer) {
            Viewer.troublemaker => 'Swap ${long.join(', ')}',
            Viewer.robber => 'Swap with ${long[0]}',
            Viewer.doppelganger => 'Copy ${long[0]}',
            _ => 'See ${long[0]}',
          }, reason: where);
          findings.addAll([
            for (final cut in truncatedText(tester)) '$where: $cut',
            for (final word in brokenWords(tester)) '$where: $word',
            for (final card in offBoard(tester)) '$where: $card',
            if (tester.getRect(label).right > phone.width ||
                tester.getRect(label).left < 0)
              '$where: the label runs off the screen',
          ]);
          final error = tester.takeException();
          if (error != null) findings.add('$where: $error');
        }
        expect(findings, isEmpty);
      });
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
