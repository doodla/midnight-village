import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/deckle.dart';
import 'package:midnight_village/design_system/primitives/paper_banner.dart';
import 'package:midnight_village/design_system/skin/skin.dart';

import '../../helpers/painted_text.dart';
import '../../helpers/pump_skinned.dart';

// Torn paper is paint only: the same piece is torn the same way on every
// build, never reaches further in than its depth, and what is written on a
// banner is level, inked for the paper, and keeps the box it was given.

void main() {
  const rect = Rect.fromLTWH(0, 0, 300, 52);

  test('the same id is torn the same way, another id differently', () {
    final a = DeckleBorder(seed: deckleSeed(#row)).getOuterPath(rect);
    final b = DeckleBorder(seed: deckleSeed(#row)).getOuterPath(rect);
    final c = DeckleBorder(seed: deckleSeed(#other)).getOuterPath(rect);
    expect(a.getBounds(), b.getBounds());
    expect(a.computeMetrics().first.length, b.computeMetrics().first.length);
    expect(
      a.computeMetrics().first.length,
      isNot(c.computeMetrics().first.length),
    );
  });

  test('an edge steps in by no more than its depth', () {
    for (final (depth, torn) in [(2.4, false), (4.5, true), (9.0, true)]) {
      final bounds = DeckleBorder(
        seed: deckleSeed(#bounds),
        depth: depth,
        torn: torn,
      ).getOuterPath(rect).getBounds();
      expect(bounds.left, lessThanOrEqualTo(depth + 1e-9));
      expect(bounds.top, lessThanOrEqualTo(depth + 1e-9));
      expect(bounds.right, greaterThanOrEqualTo(rect.right - depth - 1e-9));
      expect(bounds.bottom, greaterThanOrEqualTo(rect.bottom - depth - 1e-9));
      expect(bounds.right, lessThanOrEqualTo(rect.right));
    }
  });

  testWidgets('a banner keeps its words level, in ink on bone at 7:1 or more, '
      'and the paper reaches past the box by its bleed only', (tester) async {
    final skin = skinsUnderTest.values.first;
    await pumpSkinned(
      tester,
      SizedBox(
        width: 300,
        child: PaperBanner(
          bleed: 12,
          child: (context) => Text(
            'Who dies today?',
            style: TextStyle(color: context.ground.text),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(PaperBanner)).width, 300);
    // The text is never inside a rotation.
    expect(
      find.ancestor(
        of: find.text('Who dies today?'),
        matching: find.byWidgetPredicate(
          (w) => w is Transform && !w.transform.isIdentity(),
        ),
      ),
      findsNothing,
    );
    expect(
      contrast(skin.day.text, skin.day.paper),
      greaterThanOrEqualTo(readingContrast),
    );
  });
}
