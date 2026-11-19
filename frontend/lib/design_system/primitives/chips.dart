import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/skin.dart';

/// A small piece of paper beside a title or at the top of a screen: what
/// phase this is ("Night one · your card", S04, [lifted]) or how the screen
/// stands ("8 of 8 cards", S03). [icon] goes before the words.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.icon, this.lifted = false});

  final String text;
  final IconData? icon;
  final bool lifted;

  /// The mock's height when lifted (S04).
  static const liftedHeight = 36.0;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final ink = skin.paper.text;
    return Container(
      constraints: BoxConstraints(minHeight: lifted ? liftedHeight : 0),
      padding: EdgeInsets.symmetric(
        horizontal: lifted ? Space.lg : Space.smPlus,
        vertical: Space.xs,
      ),
      decoration: BoxDecoration(
        color: ground.paper,
        borderRadius: BorderRadius.circular(skin.shape.radiusSmall),
        border: skin.shape.edgeWidth > 0
            ? Border.all(color: ground.edge, width: skin.shape.edgeWidth)
            : null,
        boxShadow: lifted
            ? ground.elevation.badge.scaled(1.5).boxShadows
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: Space.sm,
        children: [
          if (icon case final icon?) Icon(icon, size: Space.lg, color: ink),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: skin.typography.smallStrong.copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// One of a few presets to choose from ("First game", "Classic", "Chaos",
/// S03): paper when [selected], an outline otherwise. 44 tall.
class PresetChip extends StatelessWidget {
  const PresetChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  static const height = 44.0;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final radius = BorderRadius.circular(skin.shape.radiusSmall);
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: Motion.quick,
            curve: Motion.curve,
            constraints: const BoxConstraints(minHeight: height),
            padding: const EdgeInsets.symmetric(horizontal: Space.mdPlus),
            decoration: BoxDecoration(
              color: selected ? ground.paper : Colors.transparent,
              borderRadius: radius,
              border: Border.all(
                color: selected ? ground.paper : ground.outline,
                width: skin.shape.stroke,
              ),
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: skin.typography.smallStrong.copyWith(
                  color: selected ? skin.paper.text : ground.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small dot that says something is happening ("Holding", S04): the
/// ground's mark with a faint halo.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key});

  static const size = 12.0;

  @override
  Widget build(BuildContext context) {
    final ground = context.ground;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ground.mark,
        shape: BoxShape.circle,
        border: Border.all(
          color: ground.mark.withValues(alpha: 0.25),
          width: 5,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
    );
  }
}
