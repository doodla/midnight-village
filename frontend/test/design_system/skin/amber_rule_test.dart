import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';

import '../../helpers/component_sheet.dart';
import '../../helpers/pump_skinned.dart';

// The amber rule (docs/specs/frontend/first-time-play.md, copy rule 10): one
// amber fill per screen, and it is the primary button; nothing else is
// amber (art aside). Counted on what every component-sheet page lays out in
// every skin: each box's fill, border and shadows, and each run of text.

/// Every place [amber] is painted on screen, by what paints it.
({List<Element> fills, List<String> elsewhere}) _amberOnScreen(
  WidgetTester tester,
  Color amber,
) {
  final fills = <Element>[];
  final elsewhere = <String>[];
  for (final element in find.byType(DecoratedBox).evaluate()) {
    final box = element.renderObject;
    if (box is! RenderDecoratedBox || !box.hasSize || box.size.isEmpty) {
      continue;
    }
    final decoration = box.decoration;
    if (decoration is! BoxDecoration) continue;
    if (decoration.color == amber) fills.add(element);
    final border = decoration.border;
    if (border is Border &&
        [
          border.top,
          border.left,
          border.right,
          border.bottom,
        ].any((side) => side.color == amber && side.width > 0)) {
      elsewhere.add('a border (${element.widget.runtimeType})');
    }
    if (decoration.boxShadow?.any((s) => s.color == amber) ?? false) {
      elsewhere.add('a shadow');
    }
  }
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph) continue;
    paragraph.text.visitChildren((span) {
      if (span.style?.color == amber) {
        elsewhere.add('text "${span.toPlainText()}"');
      }
      return true;
    });
  }
  return (fills: fills, elsewhere: elsewhere);
}

bool _inPrimaryButton(Element element) {
  var inside = false;
  element.visitAncestorElements((ancestor) {
    inside = ancestor.widget is PrimaryButton;
    return !inside;
  });
  return inside;
}

void main() {
  testWidgets('the count sees an amber fill that is not a button', (
    tester,
  ) async {
    const amber = Color(0xFFE3A13A);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: amber),
              child: SizedBox.square(dimension: 10),
            ),
            Text('lit', style: TextStyle(color: amber)),
          ],
        ),
      ),
    );
    final found = _amberOnScreen(tester, amber);
    expect(found.fills, hasLength(1));
    expect(_inPrimaryButton(found.fills.single), isFalse);
    expect(found.elsewhere, ['text "lit"']);
  });

  for (final MapEntry(key: name, value: skin) in skinsUnderTest.entries) {
    group(name, () {
      for (final page in ComponentPage.values) {
        for (final ground in page.grounds) {
          testWidgets('${page.name} on ${ground.name}: one amber fill at '
              'most, the primary button, and no amber elsewhere', (
            tester,
          ) async {
            tester.view.physicalSize = const Size(390, 1500);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await pumpComponentPage(tester, page, ground, skin: skin);

            final amber = skin.ground(ground).accent;
            final found = _amberOnScreen(tester, amber);
            if (page.playerScreen) {
              expect(found.fills.length, lessThanOrEqualTo(1));
            }
            expect(found.fills.where((e) => !_inPrimaryButton(e)), isEmpty);
            expect(found.elsewhere, isEmpty);
          });
        }
      }
    });
  }
}
