import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/chips.dart';
import 'package:midnight_village/design_system/primitives/cut_paper.dart';
import 'package:midnight_village/design_system/primitives/paper_mark.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/tag_chip.dart';

import '../../helpers/pump_skinned.dart';

// A little life in placement: a seeded tilt from the item's own id, the same
// every build, within 1.5 degrees on cards and 0.6 on rows, chips and tags;
// only the paint turns, never the layout.

double _angleOf(WidgetTester tester, Finder inside) {
  // The paper is turned; what is written on it is not.
  final paper = find.ancestor(of: inside, matching: find.byType(TiltedPaper));
  expect(paper, findsAtLeastNWidgets(1));
  return tester.widget<TiltedPaper>(paper.first).angle;
}

void main() {
  const bound = 0.6 * math.pi / 180;

  testWidgets('a row, a chip and a tag keep their tilt across a rebuild', (
    tester,
  ) async {
    Widget page() => Column(
      children: [
        PlayerRow(token: null, name: 'Cleo', onTap: () {}),
        PlayerRow(token: null, name: 'Maximilian', onTap: () {}),
        PresetChip(label: 'Classic', selected: false, onTap: () {}),
        const TagChip('Village team'),
      ],
    );
    await pumpSkinned(tester, page());
    final first = [
      _angleOf(tester, find.text('Cleo')),
      _angleOf(tester, find.text('Maximilian')),
      _angleOf(tester, find.text('Classic')),
      _angleOf(tester, find.text('Village team')),
    ];
    await pumpSkinned(tester, SizedBox(child: page()));
    await tester.pump();
    final second = [
      _angleOf(tester, find.text('Cleo')),
      _angleOf(tester, find.text('Maximilian')),
      _angleOf(tester, find.text('Classic')),
      _angleOf(tester, find.text('Village team')),
    ];
    expect(second, first);
    for (final angle in first) {
      expect(angle.abs(), lessThanOrEqualTo(bound + 1e-9));
    }
    expect(first.toSet().length, greaterThan(1), reason: 'they differ by id');
  });

  testWidgets('the words stay level and where they were: a tilted row is as '
      'big as an untilted one', (tester) async {
    await pumpSkinned(
      tester,
      Center(
        child: PlayerRow(token: null, name: 'Cleo', onTap: () {}),
      ),
    );
    final row = tester.getRect(find.byType(PlayerRow));
    final word = tester.getRect(find.text('Cleo'));
    expect(row.height, 48);
    expect(word.top, greaterThan(row.top));
    expect(word.bottom, lessThan(row.bottom));
  });

  testWidgets('a picked row wears the mark and an unpicked one does not', (
    tester,
  ) async {
    await pumpSkinned(
      tester,
      Column(
        children: [
          PlayerRow(token: null, name: 'Cleo', picked: true, onTap: () {}),
          PlayerRow(token: null, name: 'Dev', onTap: () {}),
        ],
      ),
    );
    expect(find.byType(PaperMark), findsOneWidget);
  });
}
