import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import '../skin/skin_tilt.dart';
import 'deckle.dart';

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
    this.pinned = false,
    this.id,
  });

  final Widget child;
  final PaperLift lift;
  final EdgeInsetsGeometry padding;
  final Tilt tilt;

  /// A notice pinned up: a flat pin through each top corner.
  final bool pinned;

  /// What seeds the torn edge (the same piece is torn the same on every
  /// build); the lift's name where none is given.
  final Object? id;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final elevation = context.ground.elevation;
    final card = DecoratedBox(
      decoration: deckledPaper(
        context,
        fill: context.ground.paper,
        id: id ?? (lift, #card),
        depth: pinned ? 3.2 : 2.4,
        step: pinned ? 8 : 6,
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
    final shown = angle == 0
        ? card
        : Transform.rotate(angle: angle, child: card);
    if (!pinned) return shown;
    final pin = skin.paper.text.withValues(alpha: 0.82);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        shown,
        Positioned(
          top: -2,
          left: Space.lg,
          child: PaperPin(ink: pin, size: 11),
        ),
        Positioned(
          top: -2,
          right: Space.lg,
          child: PaperPin(ink: pin, size: 11),
        ),
      ],
    );
  }
}
