import 'package:flutter/material.dart';

import '../copy/role_text.dart';
import '../layout/space.dart';
import '../models/role.dart';
import '../skin/skin.dart';
import 'fit_line.dart';
import 'role_card.dart';
import 'role_rules.dart';
import 'tag_chip.dart';

/// The role sheet's words (03b, opened by holding any role card): the
/// portrait and the name, loudest; the tag; then the role text, the same
/// rows the 04 face shows (`RoleRules`).
class RoleSheetBody extends StatelessWidget {
  const RoleSheetBody(this.role, {super.key});

  final RoleId role;

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final text = RoleText.of(role);
    final ink = context.ground.text;

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
                  RoleHead(
                    name: role.displayName,
                    tag: text.tag,
                    team: text.team,
                    style: type.headline.copyWith(color: ink),
                  ),
                ],
              ),
            ),
          ],
        ),
        RoleRules(text, body: type.bodyLarge.copyWith(color: ink)),
      ],
    );
  }
}

/// A role's name with its team tag ABOVE it, the one layout on every card,
/// page and sheet (the tag small and level, the name under it in [style]); the
/// tag is the team's own colour (`TagChip.team`). Either may be absent.
class RoleHead extends StatelessWidget {
  const RoleHead({
    super.key,
    required this.name,
    required this.tag,
    required this.team,
    required this.style,
  });

  final String? name;
  final String? tag;
  final TeamId? team;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    spacing: Space.xs,
    children: [
      if (tag case final tag?) TagChip.team(tag, team: team ?? TeamId.village),
      if (name case final name?) FitLine(name, style: style),
    ],
  );
}
