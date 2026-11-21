import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../copy/role_text.dart';
import '../layout/space.dart';
import '../models/role.dart';
import '../skin/skin.dart';
import 'fit_line.dart';
import 'role_card.dart';
import 'tag_chip.dart';

/// The role sheet's words (03b, opened by holding any role card): the
/// portrait and the name, loudest; the tag; then the role text, the same
/// lines the 04 face shows (`RoleText`).
class RoleSheetBody extends StatelessWidget {
  const RoleSheetBody(this.role, {super.key});

  final RoleId role;

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final text = RoleText.of(role);
    final ink = context.ground.text;
    TextSpan labelled(String label, String line) => TextSpan(
      children: [
        TextSpan(
          text: '$label ',
          style: TextStyle(fontWeight: type.action.fontWeight),
        ),
        TextSpan(text: line),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.lg,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: Space.lg,
          children: [
            RolePortrait(role: role, width: RolePortrait.sheet, framed: true),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.sm,
                children: [
                  TagChip(text.tag, small: true),
                  FitLine(role.displayName, style: type.headline),
                ],
              ),
            ),
          ],
        ),
        for (final line in [
          labelled(RoleCopy.nightLabel, text.night),
          labelled(RoleCopy.winsLabel, text.wins),
          const TextSpan(text: RoleCopy.shared),
        ])
          Text.rich(line, style: type.bodyLarge.copyWith(color: ink)),
      ],
    );
  }
}
