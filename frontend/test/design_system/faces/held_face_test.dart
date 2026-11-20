import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/models/role.dart';

import '../../helpers/pump_skinned.dart';

// A face sets its words smaller rather than spill out of its frame; the
// whole role card (04) must still fit at full size on the narrow phones, so
// every role's words stay at the reading floor.

void main() {
  for (final width in [320.0, 360.0]) {
    testWidgets('every role card fits its face unshrunk at $width wide', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final shrunk = <String>[];
      for (final role in RoleId.values) {
        await pumpSkinned(
          tester,
          Center(child: HeldFace(content: FaceContent.roleText(role), page: 0)),
        );
        final box = tester.renderObject<RenderBox>(
          find.byType(FittedBox).first,
        );
        final words = tester.renderObject<RenderBox>(
          find
              .descendant(
                of: find.byType(FittedBox).first,
                matching: find.byType(SizedBox),
              )
              .first,
        );
        if (words.size.height > box.size.height) shrunk.add(role.name);
      }
      expect(shrunk, isEmpty);
    });
  }
}
