import 'paper_light.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../layout/space.dart';
import '../skin/card_back_scope.dart';
import '../skin/dress.dart';
import '../skin/dress_style.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import '../skin/skin_tilt.dart';
import '../teach/hold_cue.dart';
import 'art_picture.dart';
import 'cut_paper.dart';
import 'face_down_card.dart' show CardBackPaper;
import 'fit_line.dart';
import 'paper_piece.dart';

/// A box drawn as an outline on the ground, holding a summary that opens
/// something (the deck strip at the table, S02: thumbnails and "Edit").
/// With [onTap] it is a button. Dressed up it is a panel of paper set into
/// the ground (a [PaperPiece]), never an outline. [color], [width] and
/// [padding] are the plain outline's own where a screen needs another.
class OutlinePanel extends StatelessWidget {
  const OutlinePanel({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.color,
    this.width,
    this.padding = const EdgeInsets.symmetric(
      horizontal: Space.md,
      vertical: Space.smPlus,
    ),
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// The plain outline's colour and width: the hairline and the skin's stroke
  /// where null.
  final Color? color;
  final double? width;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final radius = BorderRadius.circular(skin.shape.radius);
    final dressed = context.dress.isPaper;
    final Widget panel = dressed
        ? PaperPiece(
            part: PaperPart.panel,
            id: semanticLabel ?? #panel,
            child: Padding(padding: padding, child: child),
          )
        : Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: color ?? ground.hairline,
                width: width ?? skin.shape.stroke,
              ),
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
          focusColor: dressed ? Colors.transparent : null,
          hoverColor: dressed ? Colors.transparent : null,
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
    final padding = EdgeInsets.fromLTRB(inset, inset, Space.lg, inset);
    Widget laid(Widget child) => context.dress.isPaper
        // Dressed up: a panel of night paper (a [PaperPiece]), deckled, with the
        // paper shadow of the screen's light; no edge line.
        ? PaperPiece(
            part: PaperPart.panel,
            id: #peek,
            fill: skin.night.panel,
            child: Padding(padding: padding, child: child),
          )
        : Container(
            padding: padding,
            decoration: BoxDecoration(
              color: skin.night.ground,
              borderRadius: BorderRadius.circular(skin.shape.radius),
              border: skin.shape.edgeWidth > 0
                  ? Border.all(color: ground.edge, width: skin.shape.edgeWidth)
                  : null,
              boxShadow: ground.elevation.raised.litBy(context),
            ),
            child: child,
          );
    return laid(
      GroundScope(
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
    if (context.dress.isPaper) {
      return Transform.rotate(
        angle: skin.tilt.angle(Tilt.thumb),
        child: SizedBox.fromSize(
          size: size,
          child: CardBackPaper(
            id: 'peek',
            elevation: context.ground.elevation.card,
            over: Padding(
              padding: const EdgeInsets.all(Space.xxs),
              child: HoldCue(teaching: teaching, size: size.width, word: false),
            ),
          ),
        ),
      );
    }
    return Transform.rotate(
      angle: skin.tilt.angle(Tilt.thumb),
      child: Container(
        width: size.width,
        height: size.height,
        foregroundDecoration: frameRing(
          context,
          color: context.ground.mark,
          width: skin.shape.ring,
          radius: radius,
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
