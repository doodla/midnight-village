import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import 'deckle.dart';

/// A screen's header on a banner of torn paper: the question or the timer (in
/// their own type roles, set in the day's ink on bone) on a strip with torn
/// ends and edges, set down a hair off square, a pin through each end and the
/// paper's shadow falling away from the screen's light. The words stay
/// level; the banner is the whole width it is given and as high as its
/// content and [padding].
class PaperBanner extends StatelessWidget {
  const PaperBanner({
    super.key,
    required this.child,
    this.id = #banner,
    this.angle = -0.012,
    this.bleed = 0,
    this.padding = const EdgeInsets.fromLTRB(
      Space.lg,
      Space.md,
      Space.lg,
      Space.md,
    ),
  });

  /// Built under the day's ground: its words are ink on the paper.
  final WidgetBuilder child;
  final Object id;

  /// In radians (positive is clockwise).
  final double angle;
  final EdgeInsetsGeometry padding;

  /// How far the paper reaches past the box on each side (the content keeps
  /// the box's width; the pins sit at the paper's ends).
  final double bleed;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final outer = context.ground;
    final day = skin.day;
    final pin = day.text.withValues(alpha: 0.78);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -bleed,
          right: -bleed,
          top: 0,
          bottom: 0,
          child: Transform.rotate(
            angle: angle,
            child: DecoratedBox(
              decoration: deckledPaper(
                context,
                fill: day.paper,
                id: id,
                elevation: outer.elevation.slab,
                torn: true,
                depth: 4.5,
                step: 13,
                edgeLine: false,
              ),
            ),
          ),
        ),
        Padding(
          padding: padding,
          child: GroundScope(
            ground: GroundKind.day,
            child: Builder(builder: child),
          ),
        ),
        Positioned(
          top: 1,
          left: Space.md,
          child: PaperPin(ink: pin),
        ),
        Positioned(
          top: 1,
          right: Space.md,
          child: PaperPin(ink: pin),
        ),
      ],
    );
  }
}
