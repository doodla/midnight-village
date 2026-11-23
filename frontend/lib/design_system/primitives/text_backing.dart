import 'package:flutter/widgets.dart';

import '../skin/dress.dart';
import '../skin/skin.dart';

/// A backing of the ground's own panel colour behind words that would
/// otherwise sit over the village or a light of a dressed screen, reaching a
/// little past the words on every side ([bleed] and the skin's `backingAlpha`),
/// so they keep their contrast whatever is behind (`dressed_contrast_test.dart`
/// measures it). PAINT ONLY: it takes no room and no touch, and the words keep
/// the box they had. The scene is never dulled to make room for words. On a
/// plain screen there is no backing: [child] as it is.
class TextBacking extends StatelessWidget {
  const TextBacking({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!context.dress.isPaper) return child;
    final skin = context.skin;
    final parts = skin.parts;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -parts.backingBleed.dx,
          right: -parts.backingBleed.dx,
          top: -parts.backingBleed.dy,
          bottom: -parts.backingBleed.dy,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.ground.panel.withValues(
                  alpha: parts.backingAlpha,
                ),
                borderRadius: BorderRadius.circular(skin.shape.radius),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
