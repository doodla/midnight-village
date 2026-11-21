import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import '../skin/skin_tilt.dart';
import 'cut_paper.dart';

/// How high a [PaperCard] lies.
enum PaperLift { card, raised, slab, heroSlab }

/// A piece of paper on the ground: a panel, a code, a role card. Its content
/// is on paper ([GroundKind.paper]), so text and tokens in it take paper's ink.
/// [tilt] turns it by one of the skin's tilts.
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.lift = PaperLift.card,
    this.padding = const EdgeInsets.all(Space.md),
    this.tilt = Tilt.none,
  });

  final Widget child;
  final PaperLift lift;
  final EdgeInsetsGeometry padding;
  final Tilt tilt;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final elevation = context.ground.elevation;
    final card = DecoratedBox(
      decoration: cutPaper(
        context,
        fill: context.ground.paper,
        radius: BorderRadius.circular(skin.shape.radius),
        elevation: switch (lift) {
          PaperLift.card => elevation.card,
          PaperLift.raised => elevation.raised,
          PaperLift.slab => elevation.slab,
          PaperLift.heroSlab => elevation.heroSlab,
        },
      ),
      child: Padding(
        padding: padding,
        child: GroundScope(ground: GroundKind.paper, child: child),
      ),
    );
    final angle = skin.tilt.angle(tilt);
    return angle == 0 ? card : Transform.rotate(angle: angle, child: card);
  }
}
