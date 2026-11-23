import 'paper_light.dart';
import 'package:flutter/widgets.dart';

import '../skin/dress.dart';
import '../skin/dress_style.dart';
import 'paper_piece.dart';

import '../skin/elevation.dart';
import '../skin/skin.dart';

/// [CountBadge]'s two sizes.
enum BadgeSize {
  /// On a thumbnail (S02, S08): 20 tall.
  small(20),

  /// On a card in the deck builder (S03): 24 tall, lifted.
  large(24);

  const BadgeSize(this.size);

  final double size;
}

/// How many of a card are in the deck, as a digit on its corner ("2": the
/// mocks' "×2" is cut, first-time play spec, copy rule 9).
class CountBadge extends StatelessWidget {
  const CountBadge(this.count, {super.key, this.size = BadgeSize.small});

  final int count;
  final BadgeSize size;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final side = size.size;
    final large = size == BadgeSize.large;
    final number = Center(
      // Centred in the badge, which keeps to its own size wherever it is.
      widthFactor: 1,
      heightFactor: 1,
      child: Text(
        '$count',
        style: skin.typography.badge.copyWith(color: ground.onMark, height: 1),
      ),
    );
    // Dressed up: a drop of wax (a [PaperPiece]), never a ring.
    if (context.dress.isPaper) {
      return PaperPiece(
        part: PaperPart.wax,
        id: count,
        fill: ground.mark,
        child: Container(
          constraints: BoxConstraints(minWidth: side, minHeight: side),
          padding: EdgeInsets.symmetric(horizontal: side / 4),
          alignment: Alignment.center,
          child: number,
        ),
      );
    }
    return Container(
      constraints: BoxConstraints(minWidth: side, minHeight: side),
      padding: EdgeInsets.symmetric(horizontal: side / 4),
      decoration: BoxDecoration(
        color: ground.mark,
        borderRadius: BorderRadius.circular(
          skin.shape.corner(side, skin.shape.badgeRoundness),
        ),
        boxShadow: (large ? ground.elevation.badge : Elevation.none).litBy(
          context,
        ),
      ),
      // Centred in the badge, which keeps to its own size wherever it is.
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          '$count',
          style: skin.typography.badge.copyWith(
            color: ground.onMark,
            height: 1,
          ),
        ),
      ),
    );
  }
}
