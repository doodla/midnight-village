import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/skin.dart';

/// A short nudge for the thing a locked button points at (the name field
/// "Start a table" needs, the count "Done" will not leave): it shakes across
/// [Motion.quick] twice over, or, when the phone asks for reduced motion,
/// does not move and flashes in the danger ink instead. `nudge()` on its
/// state (a `GlobalKey<NudgeState>`) plays it.
class Nudge extends StatefulWidget {
  const Nudge({super.key, required this.child});

  final Widget child;

  @override
  State<Nudge> createState() => NudgeState();
}

class NudgeState extends State<Nudge> with SingleTickerProviderStateMixin {
  /// How many swings the shake makes.
  static const _swings = 3;

  late final _run = AnimationController(vsync: this, duration: Motion.settle);

  /// Plays it, from the start.
  void nudge() => _run.forward(from: 0);

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final flash = context.ground.dangerText;
    return AnimatedBuilder(
      animation: _run,
      child: widget.child,
      // One shape always (the child is never re-parented: a field keeps its
      // focus and its text).
      builder: (context, child) {
        final left = _run.isAnimating ? 1 - _run.value : 0.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: still ? flash.withValues(alpha: 0.3 * left) : null,
            borderRadius: BorderRadius.circular(context.skin.shape.radius),
          ),
          child: Transform.translate(
            offset: Offset(
              still
                  ? 0
                  : math.sin(_run.value * 2 * math.pi * _swings) *
                        Space.sm *
                        left,
              0,
            ),
            child: child,
          ),
        );
      },
    );
  }
}
