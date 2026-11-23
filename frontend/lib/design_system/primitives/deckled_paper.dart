import 'package:flutter/widgets.dart';

import '../skin/dress.dart';
import '../skin/elevation.dart';
import '../skin/skin.dart';
import 'cut_paper.dart';
import 'deckle.dart';
import 'paper_grain.dart';
import 'paper_light.dart';

/// Torn paper on the current ground: [fill], the grain, a deckled edge seeded
/// by [id] (the same piece is torn the same on every build and phone) and the
/// paper shadow of [elevation], leaning from the screen's light. On a plain
/// screen it is the cut paper the game has always had ([cutPaper], with
/// [radius] or the skin's corner), so a part may use it anywhere.
Decoration deckledPaper(
  BuildContext context, {
  required Color fill,
  required Object id,
  Elevation elevation = Elevation.none,
  double? depth,
  double? step,
  bool torn = false,
  bool grain = true,
  bool edgeLine = true,
  BorderSide? side,
  BorderRadius? radius,
}) {
  final skin = context.skin;
  if (!context.dress.isPaper) {
    return cutPaper(
      context,
      fill: fill,
      radius: radius ?? BorderRadius.circular(skin.shape.radius),
      elevation: elevation,
    ).copyWith(
      border: side != null && side.width > 0
          ? Border.fromBorderSide(side)
          : null,
    );
  }
  final edgeWidth = skin.shape.edgeWidth;
  final parts = skin.parts;
  return ShapeDecoration(
    color: fill,
    image: grain ? PaperGrain.image : null,
    shape: DeckleBorder(
      seed: deckleSeed(id),
      depth: depth ?? parts.deckleDepth,
      step: step ?? parts.deckleStep,
      torn: torn,
      side:
          side ??
          (edgeLine && edgeWidth > 0
              ? BorderSide(color: context.ground.edge, width: edgeWidth)
              : BorderSide.none),
    ),
    shadows: elevation.litBy(context),
  );
}

/// A ring drawn along the torn edge of a [deckledPaper] of the same [id] (and
/// [depth] and [step]): the pick's outline, the viewer's own row's. Never a
/// rounded ring over torn paper; paint it as a foreground decoration. On a
/// plain screen the paper is cut, so it is a [ringDecoration] of [radius].
Decoration deckledRing(
  BuildContext context, {
  required Object id,
  required Color color,
  required double width,
  BorderRadius? radius,
}) {
  final skin = context.skin;
  if (!context.dress.isPaper) {
    return ringDecoration(
      color: color,
      width: width,
      radius: radius ?? BorderRadius.circular(skin.shape.radius),
    );
  }
  return ShapeDecoration(
    shape: DeckleBorder(
      seed: deckleSeed(id),
      depth: skin.parts.deckleDepth,
      step: skin.parts.deckleStep,
      side: BorderSide(color: color, width: width),
    ),
  );
}
