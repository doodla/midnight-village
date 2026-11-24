import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/copy/role_text.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/role_rules.dart';

import '../../helpers/pump_skinned.dart';
import '../../helpers/truncated_text.dart';

// The role text's shape (owner, 24 November 2026, on 04: "There's a double
// label as well" and "different formatting so it's easier to parse"): a tag
// that never repeats the name, then the same rows for every role, then the
// shared line.

void main() {
  test('no role\'s tag is its own name; red only for the Werewolf team', () {
    for (final role in RoleId.values) {
      final text = RoleText.of(role);
      expect(text.tag, isNot(role.displayName), reason: role.name);
      expect(
        text.team == TeamId.werewolf,
        role == RoleId.werewolf || role == RoleId.minion,
        reason: role.name,
      );
    }
    expect(RoleText.of(RoleId.werewolf).tag, 'Werewolf team');
    expect(RoleText.of(RoleId.minion).tag, 'Werewolf team');
    expect(RoleText.of(RoleId.tanner).tag, RoleCopy.alone);
  });

  test('every role fills the same rows: Night first, Wins last, at most two '
      'short lines each, the shared line after', () {
    for (final role in RoleId.values) {
      final text = RoleText.of(role);
      expect(text.parts.first.label, RoleCopy.nightLabel, reason: role.name);
      expect(text.parts.last.label, RoleCopy.winsLabel, reason: role.name);
      for (final part in text.parts) {
        expect(part.lines.length, inInclusiveRange(1, 2), reason: role.name);
      }
      expect(text.lines.last, RoleCopy.shared, reason: role.name);
      expect(text.lines.where((l) => l == RoleCopy.shared), hasLength(1));
    }
  });

  testWidgets('the rows set their labels beside the lines, or above them '
      'where a word would not fit; no word is ever broken', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final (width, scale, beside) in const [
      (300.0, 1.0, true),
      (150.0, 1.6, false),
    ]) {
      await pumpSkinned(
        tester,
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: RoleRules(
                RoleText.of(RoleId.minion),
                body: const TextStyle(fontSize: 15),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final label = tester.getTopLeft(find.text(RoleCopy.winsLabel));
      final line = tester.getTopLeft(find.text(RoleCopy.minionWins));
      expect(line.dx > label.dx, beside, reason: 'at $width x$scale');
      expect(line.dy > label.dy, !beside, reason: 'at $width x$scale');
      expect(truncatedText(tester), isEmpty);
    }
  });
}
