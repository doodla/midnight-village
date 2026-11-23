import 'package:flutter/widgets.dart';

import '../layout/space.dart';

/// A piece of paper set down a hair off square: only its PAPER (the fill, the
/// grain, the shadow, the ring) is turned by [angle]; what is written on it
/// stays level and keeps its place, so layout, hit targets and text baselines
/// are exactly what they were. [angle] comes from `Tilt.seededRow` or
/// `Tilt.seededCard` of the item's own id (`skin.tilt.angle`; zero on a plain
/// screen). The paper animates [decoration] over [duration] as an
/// `AnimatedContainer` does.
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
