import 'package:flutter/widgets.dart';

import '../skin/elevation.dart';
import '../skin/skin.dart';

/// A small count on the corner of a card ("2", "×2").
class CountBadge extends StatelessWidget {
  const CountBadge(this.text, {super.key, this.size = 20, this.lifted = false});

  final String text;

  /// Height; the badge is at least as wide. Taller than 20, it uses the
  /// larger tag type.
  final double size;

  /// Casts the ground's badge shadow.
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    return Container(
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      padding: EdgeInsets.symmetric(horizontal: skin.spacing.xs),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ground.mark,
        borderRadius: BorderRadius.circular(
          skin.shape.corner(size, skin.shape.badgeRoundness),
        ),
        boxShadow:
            (lifted ? ground.elevation.badge : Elevation.none).boxShadows,
      ),
      child: Text(
        text,
        style: (size > 20 ? skin.typography.tag : skin.typography.badge)
            .copyWith(color: ground.onMark, height: 1),
      ),
    );
  }
}
