import 'package:flutter/widgets.dart';

import '../skin/dress.dart';
import '../skin/skin.dart';
import 'paper_light.dart';

/// A flat matte pin through a piece of paper, with its own small shadow (hard,
/// offset away from the light like everything else): [ink] is its colour,
/// [size] its diameter (the skin's pin when null). On a plain screen there is
/// no pin: it takes no room and draws nothing.
class PaperPin extends StatelessWidget {
  const PaperPin({super.key, required this.ink, this.size});

  final Color ink;
  final double? size;

  @override
  Widget build(BuildContext context) {
    if (!context.dress.isPaper) return const SizedBox.shrink();
    final lean = PaperLight.of(context);
    final pin = context.skin.parts;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size ?? pin.pinSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ink.withValues(alpha: pin.pinInkAlpha),
              boxShadow: [
                BoxShadow(
                  color: pin.pinShadow,
                  offset: Offset(lean * pin.pinDrop.dx, pin.pinDrop.dy),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
