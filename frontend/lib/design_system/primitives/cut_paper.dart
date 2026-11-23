import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/elevation.dart';
import '../skin/skin.dart';
import 'paper_grain.dart';

/// The decoration of a cut-paper shape on the current ground: [fill], the
/// skin's edge line (when its shape draws one), the paper's grain
/// ([PaperGrain], tiled over the fill) and the paper shadow of an [elevation].
BoxDecoration cutPaper(
  BuildContext context, {
  required Color fill,
  required BorderRadius radius,
  Elevation elevation = Elevation.none,
  bool grain = true,
}) {
  final edgeWidth = context.skin.shape.edgeWidth;
  return BoxDecoration(
    color: fill,
    image: grain ? PaperGrain.image : null,
    borderRadius: radius,
    border: edgeWidth > 0
        ? Border.all(color: context.ground.edge, width: edgeWidth)
        : null,
    boxShadow: elevation.boxShadows,
  );
}

/// A ring drawn just outside a shape, without changing its size (CSS's
/// `box-shadow: 0 0 0 <width> <color>`). Paint it as a foreground decoration.
BoxDecoration ringDecoration({
  required Color color,
  required double width,
  required BorderRadius radius,
}) => BoxDecoration(
  borderRadius: radius,
  border: Border.all(
    color: color,
    width: width,
    strokeAlign: BorderSide.strokeAlignOutside,
  ),
);

/// A piece of paper set down a hair off square: only its PAPER (the fill, the
/// grain, the shadow, the ring) is turned by [angle]; what is written on it
/// stays level and keeps its place, so layout, hit targets and text baselines
/// are exactly what they were. [angle] comes from `Tilt.seededRow` or
/// `Tilt.seededCard` of the item's own id. The paper animates [decoration]
/// over [duration] as an `AnimatedContainer` does.
class TiltedPaper extends StatelessWidget {
  const TiltedPaper({
    super.key,
    required this.angle,
    required this.decoration,
    this.foregroundDecoration,
    this.duration = Duration.zero,
    required this.child,
  });

  final double angle;
  final Decoration decoration;
  final Decoration? foregroundDecoration;
  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final paper = AnimatedContainer(
      duration: duration,
      curve: Motion.curve,
      decoration: decoration,
      foregroundDecoration: foregroundDecoration,
    );
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: angle == 0
              ? paper
              : Transform.rotate(angle: angle, child: paper),
        ),
        child,
      ],
    );
  }
}
