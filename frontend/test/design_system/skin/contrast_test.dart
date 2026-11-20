import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/component_sheet.dart';
import '../../helpers/painted_text.dart';
import '../../helpers/pump_skinned.dart';

// WCAG 2.1 AA, measured on what is painted, not on a list of colour pairs:
// every page of the component sheet (each primitive in each state on every
// ground, and every mock rebuilt from them) in every skin is rendered, and
// each run of text is checked against the colour actually painted behind
// it, with the opacity of everything above it. Text in a disabled control is
// exempt, as WCAG has it; large text and icons need 3:1, the rest 4.5:1.

void main() {
  test('the WCAG formula gives its known answers', () {
    expect(
      contrast(const Color(0xFF000000), const Color(0xFFFFFFFF)),
      closeTo(21, 0.01),
    );
    expect(
      contrast(const Color(0xFF777777), const Color(0xFFFFFFFF)),
      closeTo(4.48, 0.01),
    );
  });

  testWidgets('the reader finds faint text and the colour behind it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(200, 100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: Color(0xFF14172F),
          child: Center(
            child: Opacity(
              opacity: 0.4,
              child: Text(
                'Working',
                style: TextStyle(fontSize: 14, color: Color(0xFFE9E2D0)),
              ),
            ),
          ),
        ),
      ),
    );
    final [reading] = await readPaintedText(tester);
    expect(reading.background, const Color(0xFF14172F));
    expect(reading.passes, isFalse, reason: '$reading');
  });

  for (final MapEntry(key: name, value: skin) in skinsUnderTest.entries) {
    group(name, () {
      for (final page in ComponentPage.values) {
        for (final ground in page.grounds) {
          testWidgets('${page.name} on ${ground.name}', (tester) async {
            // Tall enough that no page scrolls, so every line is painted.
            tester.view.physicalSize = const Size(390, 1500);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await pumpComponentPage(tester, page, ground, skin: skin);

            final readings = await readPaintedText(tester);
            expect(readings, isNotEmpty);
            expect([
              for (final r in readings)
                if (!r.passes) '$r',
            ], isEmpty);
          });
        }
      }
    });
  }
}
