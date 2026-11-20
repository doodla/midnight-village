import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';

import '../../helpers/pump_skinned.dart';
import '../../helpers/sheet/sheet_data.dart';

// A face is the role card (S04). On 04 it fills the face-down card's frame;
// the whole role text must fit it at full size, the portrait taking what the
// words leave, so every role's words stay at the reading floor. Drawn over a
// screen, it is as tall as its words and portrait need: no empty lower half.

/// The words' scale inside a face: 1 when they fit at full size.
double _scale(WidgetTester tester) {
  // The face's own FittedBox is its first (the name's line has another).
  final face = find
      .descendant(of: find.byType(HeldFace), matching: find.byType(FittedBox))
      .first;
  final fitted = tester.renderObject<RenderBox>(face);
  final words = tester.renderObject<RenderBox>(
    find.descendant(of: face, matching: find.byType(SizedBox)).first,
  );
  return fitted.size.height / words.size.height;
}

void main() {
  // 04's frame on a phone this wide: the hero card across the column.
  for (final width in [320.0, 360.0, 390.0]) {
    testWidgets('04: every role card fits its frame unshrunk at $width wide', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cardWidth = width - 2 * Space.gutter;
      final frame = Size(
        cardWidth,
        cardWidth / FaceDownSize.hero.mock.aspectRatio,
      );
      final shrunk = <String>[];
      for (final role in RoleId.values) {
        await pumpSkinned(
          tester,
          SizedBox.fromSize(
            size: frame,
            child: HeldFace(
              content: FaceContent.roleText(role),
              page: 0,
              fill: true,
            ),
          ),
        );
        expect(tester.getSize(find.byType(HeldFace)), frame);
        if (_scale(tester) < 1) shrunk.add(role.name);
      }
      expect(shrunk, isEmpty);
    });
  }

  testWidgets('drawn over a screen it is as tall as its words and a portrait '
      'of its own shape, no taller; with less room the portrait gives way', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final face = Viewer.seer.you;
    Future<Size> pumpIn(double room) async {
      await pumpSkinned(
        tester,
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 342, maxHeight: room),
          child: HeldFace(content: face, page: 0),
        ),
      );
      return tester.getSize(find.byType(HeldFace));
    }

    final roomy = await pumpIn(800);
    expect(roomy.height, lessThan(800), reason: 'no empty lower half');
    final tight = await pumpIn(roomy.height - 100);
    expect(tight.height, roomy.height - 100);
    expect(_scale(tester), 1, reason: 'the portrait gave way, not the words');
  });
}
