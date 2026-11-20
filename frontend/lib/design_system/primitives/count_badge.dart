import 'package:flutter/widgets.dart';

import '../skin/elevation.dart';
import '../skin/skin.dart';

/// [CountBadge]'s two sizes.
enum BadgeSize {
  /// On a thumbnail ("×2", S02, S08): 20 tall, the badge type (12).
  small(20),

  /// On a card in the deck builder (S03): 24 tall, at 14 and lifted.
  large(24);

  const BadgeSize(this.size);

  final double size;
}

/// A small count on the corner of a card ("2", "×2").
class CountBadge extends StatelessWidget {
  const CountBadge(this.text, {super.key, this.size = BadgeSize.small});

  final String text;
  final BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final side = size.size;
    final large = size == BadgeSize.large;
    return Container(
      constraints: BoxConstraints(minWidth: side, minHeight: side),
      padding: EdgeInsets.symmetric(horizontal: side / 4),
      decoration: BoxDecoration(
        color: ground.mark,
        borderRadius: BorderRadius.circular(
          skin.shape.corner(side, skin.shape.badgeRoundness),
        ),
        boxShadow: (large ? ground.elevation.badge : Elevation.none).boxShadows,
      ),
      // Centred in the badge, which keeps to its own size wherever it is.
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          text,
          style: (large ? skin.typography.smallStrong : skin.typography.badge)
              .copyWith(color: ground.onMark, height: 1),
        ),
      ),
    );
  }
}
