import 'package:flutter/widgets.dart';

import '../skin/skin.dart';

/// A short tag on a card ("Village team"). [danger] marks the Werewolf team.
/// Plain tags invert the ground: its text colour as the fill.
class TagChip extends StatelessWidget {
  const TagChip(this.text, {super.key, this.danger = false});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: skin.spacing.md,
        vertical: skin.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: danger ? ground.danger : ground.text,
        borderRadius: BorderRadius.circular(skin.shape.radiusTiny),
      ),
      child: Text(
        text,
        style: skin.typography.tag.copyWith(
          color: danger ? ground.onDanger : ground.ground,
        ),
      ),
    );
  }
}
