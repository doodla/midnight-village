import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../layout/space.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import '../skin/skin_tilt.dart';
import '../teach/hold_cue.dart';
import 'art_picture.dart';
import 'fit_line.dart';

/// A box drawn as an outline on the ground, holding a summary that opens
/// something (the deck strip at the table, S02: thumbnails and "Edit").
/// With [onTap] it is a button.
class OutlinePanel extends StatelessWidget {
  const OutlinePanel({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final radius = BorderRadius.circular(skin.shape.radius);
    final panel = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.smPlus,
      ),
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: ground.hairline, width: skin.shape.stroke),
      ),
      child: child,
    );
    if (onTap == null) return panel;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          highlightColor: Colors.transparent,
          child: panel,
        ),
      ),
    );
  }
}

/// One of the table's pace settings (S03): its name over its value, in an
/// outline. With [onTap] it is a button (it opens a stepper).
class PaceTile extends StatelessWidget {
  const PaceTile({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final radius = BorderRadius.circular(skin.shape.radius);
    return Semantics(
      button: onTap != null,
      label: '$label $value',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          highlightColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.smPlus,
              vertical: Space.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: ground.hairline,
                width: skin.shape.stroke,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Space.hairline,
              children: [
                FitLine(
                  label,
                  style: skin.typography.caption.copyWith(
                    color: ground.quietText,
                  ),
                ),
                FitLine(value, style: skin.typography.heading),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "My night" (S08): a strip of night laid on the day, with a small
/// face-down card set into it at the skin's thumb tilt, and its title. It is
/// the cover of a `HoldToReveal`; every player's is the same. The card
/// carries the hold ring ([teaching]), its word under the title.
class PeekBox extends StatelessWidget {
  const PeekBox({super.key, required this.title, required this.teaching});

  final String title;
  final bool teaching;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Space.smPlus,
        Space.smPlus,
        Space.lg,
        Space.smPlus,
      ),
      decoration: BoxDecoration(
        color: skin.night.ground,
        borderRadius: BorderRadius.circular(skin.shape.radius),
        border: skin.shape.edgeWidth > 0
            ? Border.all(color: ground.edge, width: skin.shape.edgeWidth)
            : null,
        boxShadow: ground.elevation.raised.boxShadows,
      ),
      child: GroundScope(
        ground: GroundKind.night,
        child: Row(
          spacing: Space.mdPlus,
          children: [
            _PeekCard(teaching: teaching),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FitWords(title, style: skin.typography.heading),
                  if (teaching)
                    Text(
                      CommonCopy.hold,
                      style: skin.typography.cue.copyWith(
                        color: skin.night.text,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The small card in the "My night" box: a card back ringed in the mark
/// colour, tilted, with the hold ring on it while taught.
class _PeekCard extends StatelessWidget {
  const _PeekCard({required this.teaching});

  final bool teaching;

  /// The mock's 50 x 68.
  static const size = Size(50, 68);

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final radius = BorderRadius.circular(skin.shape.radiusSmall);
    return Transform.rotate(
      angle: skin.tilt.angle(Tilt.thumb),
      child: Container(
        width: size.width,
        height: size.height,
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: context.ground.mark,
            width: skin.shape.ring,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: radius,
              child: ArtPicture(skin.art.cardBack),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.xxs),
              child: HoldCue(teaching: teaching, size: size.width, word: false),
            ),
          ],
        ),
      ),
    );
  }
}
