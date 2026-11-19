import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import '../skin/skin_tilt.dart';
import 'art_picture.dart';

/// A box drawn as an outline on the ground, holding a summary that opens
/// something (the deck at the table, S02: thumbnails, "8 cards", "Change").
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

/// A quiet box set into the ground or the paper: a few lines of detail (what a
/// role wins with, S03b), in the ground's panel colour.
class InsetPanel extends StatelessWidget {
  const InsetPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.mdPlus,
        vertical: Space.md,
      ),
      decoration: BoxDecoration(
        color: ground.panel,
        borderRadius: BorderRadius.circular(skin.shape.radius),
      ),
      child: DefaultTextStyle.merge(
        style: skin.typography.small.copyWith(color: ground.quietText),
        child: child,
      ),
    );
  }
}

/// One of the table's pace settings (S03): a small label over its value,
/// in an outline. With [onTap] it is a button.
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
              vertical: 9,
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
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: skin.typography.micro.copyWith(
                    color: ground.quietText,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(value, style: skin.typography.heading),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "My night" (S08): a strip of night laid on the day, with a small
/// face-down card set into it at the skin's thumb tilt, a heading and a hint.
/// It is the cover of a `HoldToReveal`; every player's is the same.
class PeekBox extends StatelessWidget {
  const PeekBox({super.key, required this.title, required this.hint});

  final String title;
  final String hint;

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
        child: Builder(
          builder: (context) => Row(
            spacing: Space.mdPlus,
            children: [
              const _PeekCard(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: [
                    Text(title, style: skin.typography.heading),
                    Text(
                      hint,
                      style: skin.typography.small.copyWith(
                        color: context.ground.quietText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small card in the "My night" box: a card back ringed in the mark
/// colour, tilted.
class _PeekCard extends StatelessWidget {
  const _PeekCard();

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
        child: ClipRRect(
          borderRadius: radius,
          child: ArtPicture(skin.art.cardBack),
        ),
      ),
    );
  }
}
