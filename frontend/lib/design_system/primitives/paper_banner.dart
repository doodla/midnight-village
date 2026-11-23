import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/dress.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import 'deckled_paper.dart';
import 'paper_pin.dart';

/// A screen's header on a banner of torn paper: the question or the timer (in
/// their own type roles, set in the day's ink on bone) on a strip with torn
/// ends and edges, set down a hair off square, a pin through each end and the
/// paper's shadow falling away from the screen's light. The words stay
/// level; the banner is the whole width it is given and as high as its
/// content and [padding].
///
/// On a plain screen there is no banner: [child] is built as it is, on the
/// screen's own ground.
class PaperBanner extends StatelessWidget {
  const PaperBanner({
    super.key,
    required this.child,
    this.id = #banner,
    this.bleed = 0,
    this.padding = const EdgeInsets.fromLTRB(
      Space.lg,
      Space.md,
      Space.lg,
      Space.md,
    ),
  });

  /// Built under the day's ground on a dressed screen: its words are ink on
  /// the paper.
  final WidgetBuilder child;
  final Object id;
  final EdgeInsetsGeometry padding;

  /// How far the paper reaches past the box on each side (the content keeps
  /// the box's width; the pins sit at the paper's ends).
  final double bleed;

  @override
  Widget build(BuildContext context) {
    if (!context.dress.isPaper) return Builder(builder: child);
    final skin = context.skin;
    final parts = skin.parts;
    final day = skin.day;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -bleed,
          right: -bleed,
          top: 0,
          bottom: 0,
          child: Transform.rotate(
            angle: parts.bannerAngle,
            child: DecoratedBox(
              decoration: deckledPaper(
                context,
                fill: day.paper,
                id: id,
                elevation: context.ground.elevation.slab,
                torn: true,
                depth: parts.bannerDepth,
                step: parts.bannerStep,
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
          child: PaperPin(ink: day.text),
        ),
        Positioned(
          top: 1,
          right: Space.md,
          child: PaperPin(ink: day.text),
        ),
      ],
    );
  }
}
