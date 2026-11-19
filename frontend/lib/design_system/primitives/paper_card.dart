import 'package:flutter/widgets.dart';

import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import 'cut_paper.dart';

/// How high a [PaperCard] lies.
enum PaperLift { card, raised, slab, heroSlab }

/// A piece of paper on the ground: a panel, a code, a role card. Its content
/// is on paper ([GroundKind.paper]), so text and tokens in it take paper's ink.
/// [tilted] gives it the skin's card tilt.
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.lift = PaperLift.card,
    this.padding,
    this.tilted = false,
  });

  final Widget child;
  final PaperLift lift;

  /// Defaults to the skin's medium spacing.
  final EdgeInsetsGeometry? padding;
  final bool tilted;

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
        padding: padding ?? EdgeInsets.all(skin.spacing.md),
        child: GroundScope(ground: GroundKind.paper, child: child),
      ),
    );
    return tilted ? Transform.rotate(angle: skin.tilt.card, child: card) : card;
  }
}
