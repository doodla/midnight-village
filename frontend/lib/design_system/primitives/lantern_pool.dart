import 'package:flutter/widgets.dart';

import '../skin/dress.dart';
import '../skin/skin.dart';

/// The warm light of a lantern lying round [child] and behind it (the lantern
/// by the door on the name field): a pool of the mood's lantern colour, wider
/// than the child and reaching past it above and below. Paint only; it takes
/// no room and no touch. On a plain screen there is no pool: [child] as it is.
class LanternPool extends StatelessWidget {
  const LanternPool({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!context.dress.isPaper) return child;
    final mood = context.skin.mood;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: -mood.poolReach,
          bottom: -mood.poolReach,
          child: IgnorePointer(
            child: Transform.scale(
              scaleX: mood.poolWide,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      mood.lantern.withValues(alpha: mood.poolAlpha),
                      mood.lantern.withValues(alpha: mood.poolEdgeAlpha),
                      mood.lantern.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
