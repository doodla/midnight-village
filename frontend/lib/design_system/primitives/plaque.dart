import 'package:flutter/widgets.dart';

import '../skin/elevation.dart';
import '../skin/paper_parts.dart';
import '../skin/skin.dart';
import '../skin/skin_tilt.dart';
import 'deckled_paper.dart';
import 'tilted_paper.dart';

/// The primary button's paper when a screen is dressed up: deckled amber
/// paper on a darker paper backing (the elevation's edge), a cut line set in
/// from its edge and a pin at each end (ink on the amber, nothing the eye
/// reads as a word), set down a hair off square (the same every build, from
/// [id]); what is written on it, [child], stays level and where it was.
/// Colours, sizes and the angle are the skin's (`skin.parts`, `skin.tilt`).
class Plaque extends StatelessWidget {
  const Plaque({
    super.key,
    required this.id,
    required this.fill,
    required this.ink,
    required this.elevation,
    required this.duration,
    this.side,
    required this.child,
  });

  /// What seeds its tear and its tilt (the label).
  final Object id;
  final Color fill;

  /// The ink of the cut line and the pins.
  final Color ink;
  final Elevation elevation;
  final Duration duration;

  /// The amber's own edge line, where the skin has one.
  final BorderSide? side;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final parts = skin.parts;
    return TiltedPaper(
      angle: skin.tilt.angle(Tilt.seededRow(id)),
      duration: duration,
      decoration: deckledPaper(
        context,
        fill: fill,
        id: (id, #plaque),
        elevation: elevation,
        depth: parts.plaqueDepth,
        step: parts.plaqueStep,
        side: side,
      ),
      child: Stack(
        fit: StackFit.passthrough,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: _PlaqueTrim(
                ink: ink,
                radius: BorderRadius.circular(skin.shape.radius),
                parts: parts,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// The plaque's trim: an inset line and a pin at each end.
class _PlaqueTrim extends StatelessWidget {
  const _PlaqueTrim({
    required this.ink,
    required this.radius,
    required this.parts,
  });

  final Color ink;
  final BorderRadius radius;
  final PaperParts parts;

  @override
  Widget build(BuildContext context) {
    final pin = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ink.withValues(alpha: parts.plaquePinAlpha),
      ),
    );
    return Padding(
      padding: EdgeInsets.all(parts.plaqueInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: ink.withValues(alpha: parts.plaqueLineAlpha),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width:
                  parts.plaquePinIn - parts.plaqueInset - parts.plaquePin / 2,
            ),
            SizedBox.square(dimension: parts.plaquePin, child: pin),
            const Spacer(),
            SizedBox.square(dimension: parts.plaquePin, child: pin),
            SizedBox(
              width:
                  parts.plaquePinIn - parts.plaqueInset - parts.plaquePin / 2,
            ),
          ],
        ),
      ),
    );
  }
}
