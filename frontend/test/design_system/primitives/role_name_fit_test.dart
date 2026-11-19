import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../../helpers/pump_skinned.dart';

// A role's name never breaks mid-word: on the narrowest phone (360 wide) the
// longest names still sit on one line, whole, inside their card.

const _longest = [RoleId.doppelganger, RoleId.troublemaker];

/// The lines [text] was laid out on.
int _lines(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  return boxes.map((box) => box.top).toSet().length;
}

/// Checks [role]'s name is one whole line inside [card].
void _expectWhole(WidgetTester tester, RoleId role, Finder card) {
  final name = role.displayName;
  expect(_lines(tester, name), 1, reason: '$name is on one line');
  final drawn = tester.getRect(find.text(name));
  final inside = tester.getRect(card);
  expect(
    drawn.left >= inside.left - 0.5 && drawn.right <= inside.right + 0.5,
    isTrue,
    reason: '$name ($drawn) is within its card ($inside)',
  );
}

Future<void> _pumpAt360(WidgetTester tester, Skin skin, Widget child) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: skinTheme(skin),
      builder: (context, app) =>
          GroundScope(ground: GroundKind.night, child: app!),
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    ),
  );
}

void main() {
  for (final MapEntry(key: name, value: skin) in skinsUnderTest.entries) {
    testWidgets('$name: the deck grid keeps long names whole at 360', (
      tester,
    ) async {
      await _pumpAt360(
        tester,
        skin,
        GridView.count(
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          childAspectRatio: 0.6,
          children: [
            for (final role in _longest)
              RoleCard(role: role, lit: role == RoleId.troublemaker, count: 1),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      for (final role in _longest) {
        _expectWhole(
          tester,
          role,
          find.ancestor(
            of: find.text(role.displayName),
            matching: find.byType(RoleCard),
          ),
        );
      }
    });

    testWidgets('$name: a large card half the screen wide keeps them whole', (
      tester,
    ) async {
      await _pumpAt360(
        tester,
        skin,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            for (final role in _longest)
              Expanded(
                child: RoleCard(
                  role: role,
                  size: RoleCardSize.large,
                  team: 'Village team',
                ),
              ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      for (final role in _longest) {
        _expectWhole(
          tester,
          role,
          find.ancestor(
            of: find.text(role.displayName),
            matching: find.byType(RoleCard),
          ),
        );
      }
    });
  }
}
