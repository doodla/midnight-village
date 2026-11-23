import 'paper_light.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../layout/space.dart';
import '../skin/card_back_scope.dart';
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

/// "My night" (S08): a strip of night laid on the day, with a small
/// face-down card set into it at the skin's thumb tilt, and its title. It is
/// the cover of a `HoldToReveal`; every player's is the same. The card
/// carries the hold ring ([teaching]), its word under the title. [large]
/// where it is the one thing on the screen's body (08 Talk): a larger card
/// and title, more room round them.
class PeekBox extends StatelessWidget {
  const PeekBox({
    super.key,
    required this.title,
    required this.teaching,
    this.large = false,
  });

  final String title;
  final bool teaching;
  final bool large;

  /// The mock's card, and the large box's.
  static const cardSize = Size(50, 68);
  static const largeCardSize = Size(76, 103);

  /// How tall the box is drawn, before it is laid out (08 chooses the large
  /// box only where the deck still fits under it).
  static double heightFor(
    BuildContext context, {
    required bool large,
    required bool teaching,
    required String title,
  }) {
    final skin = context.skin;
    final scaler = MediaQuery.textScalerOf(context);
    double line(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final inset = large ? Space.lg : Space.smPlus;
    final card = (large ? largeCardSize : cardSize).height;
    final words =
        line(title, large ? skin.typography.display : skin.typography.heading) +
        (teaching ? line(CommonCopy.hold, skin.typography.cue) : 0);
    return 2 * inset + 2 * skin.shape.edgeWidth + math.max(card, words);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final inset = large ? Space.lg : Space.smPlus;
    return Container(
      padding: EdgeInsets.fromLTRB(inset, inset, Space.lg, inset),
      decoration: BoxDecoration(
        color: skin.night.ground,
        borderRadius: BorderRadius.circular(skin.shape.radius),
        border: skin.shape.edgeWidth > 0
            ? Border.all(color: ground.edge, width: skin.shape.edgeWidth)
            : null,
        boxShadow: ground.elevation.raised.litBy(context),
      ),
      child: GroundScope(
        ground: GroundKind.night,
        child: Row(
          spacing: Space.mdPlus,
          children: [
            _PeekCard(
              teaching: teaching,
              size: large ? largeCardSize : cardSize,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Set smaller rather than broken over two lines.
                  FitWords(
                    title,
                    maxLines: 1,
                    style: large
                        ? skin.typography.display
                        : skin.typography.heading,
                  ),
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
  const _PeekCard({required this.teaching, required this.size});

  final bool teaching;
  final Size size;

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
              child: ArtPicture(context.cardBack),
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
