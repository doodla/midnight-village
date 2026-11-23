import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/paper_card.dart';
import 'package:midnight_village/design_system/skin/dress.dart';

import '../../helpers/sheet/sheet_data.dart';
import 'board_harness.dart';

// The own card's slip (its role's name, face up) holds every role name in the
// deck at 360 wide with ten players, whatever the text size up to 1.6: one
// line, whole, never under 12, and on its paper place (it is set smaller to
// fit the card, down to 12; a name that cannot fit the card even then grows
// the slip evenly, and the place has the room for it).

void main() {
  for (final scale in const [1.0, 1.3, 1.6]) {
    testWidgets('every role name fits its slip on the own card, 360 wide, ten '
        'players, text x$scale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(360, 779);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final harness = BoardHarness(
        tableOf(Viewer.drunk.nightMe, add: 1),
        dress: Dress.paper,
      );
      await harness.pump(tester);
      final findings = <String>[];
      for (final role in RoleId.values) {
        harness.dealt = role;
        await tester.pumpWidget(harness.build());
        await tester.pump();
        final name = find.descendant(
          of: you,
          matching: find.text(role.displayName),
        );
        final text = tester.widget<Text>(name);
        final drawn = text.style!.fontSize!;
        final rect = tester.getRect(name);
        final place = tester.getRect(
          find.ancestor(of: you, matching: find.byType(PaperCard)).first,
        );
        final at =
            '${role.displayName} (${drawn.toStringAsFixed(1)} px, '
            '${rect.width.toStringAsFixed(1)} wide, place ${place.left}..${place.right})';
        if (drawn < 12 - 0.01) findings.add('$at: under 12');
        if (text.maxLines != 1 || text.overflow == TextOverflow.ellipsis) {
          findings.add('$at: cut');
        }
        // On its paper place, within a few pixels (the slip's own padding).
        if (rect.left < place.left - 1 || rect.right > place.right + 1) {
          findings.add('$at: past its paper');
        }
        final error = tester.takeException();
        if (error != null) findings.add('$at: $error');
      }
      expect(findings, isEmpty);
    });
  }
}
