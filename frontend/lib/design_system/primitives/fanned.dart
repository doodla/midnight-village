import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/dress.dart';
import '../skin/skin.dart';

/// One card of a fan: turned a little further from the middle one, the middle
/// ones standing a little higher and every card a touch larger, so they
/// overlap, on a dressed screen. PAINT ONLY: [Transform] is told not to move
/// hit testing, so what a finger lands on is the card's own untransformed
/// slot, never a tilted neighbour that overlaps it. [index] of [count], the
/// turn, the scale and the lift are the skin's (`skin.parts`). On a plain
/// screen the card is as it is.
class Fanned extends StatelessWidget {
  const Fanned({
    super.key,
    required this.index,
    required this.count,
    required this.child,
  });

  final int index;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!context.dress.isPaper) return child;
    final parts = context.skin.parts;
    final mid = (count - 1) / 2;
    final spread = mid == 0 ? 0.0 : (index - mid) / mid;
    return Transform.translate(
      offset: Offset(0, -Space.xs * spread * spread),
      transformHitTests: false,
      child: Transform.rotate(
        angle: spread * parts.fanAngle,
        alignment: Alignment.bottomCenter,
        transformHitTests: false,
        child: Transform.scale(
          scale: parts.fanScale,
          transformHitTests: false,
          child: child,
        ),
      ),
    );
  }
}
