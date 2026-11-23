import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// One layer of what a piece of paper casts. A plain layer is a hard copy of
/// the shape, offset, never blurred (the look the game has today). A [drop]
/// layer (the dressed-up paper) is how far the paper lies above what is under
/// it, in the ink it casts, drawn as the two-layer paper shadow
/// ([PaperShadow]). An [edge] layer is the thickness of the paper itself (a
/// stack of sheets, a button's backing): a hard copy of the shape, offset, in
/// the paper's own colour, that never leans away from a light.
@immutable
class HardShadow {
  const HardShadow(this.offset, this.color) : edge = false, drop = false;

  /// The edge of the paper: hard, never soft.
  const HardShadow.edge(this.offset, this.color) : edge = true, drop = false;

  /// A drop of dressed-up paper: the paper shadow ([PaperShadow]).
  const HardShadow.drop(this.offset, this.color) : edge = false, drop = true;

  final Offset offset;
  final Color color;
  final bool edge;
  final bool drop;

  HardShadow withColor(Color color) => edge
      ? HardShadow.edge(offset, color)
      : drop
      ? HardShadow.drop(offset, color)
      : HardShadow(offset, color);

  HardShadow withOffset(Offset offset) => edge
      ? HardShadow.edge(offset, color)
      : drop
      ? HardShadow.drop(offset, color)
      : HardShadow(offset, color);
}

/// The paper shadow, the one token every cast shadow goes through: a tight
/// CONTACT shadow where the paper meets what it lies on, and a soft CAST
/// shadow beyond it. The reach comes from the drop (the layer's larger
/// offset); both fall AWAY from the screen's one light (`PaperLight`: straight
/// down, or leaning to a side). The cast is a few stacked flat copies of the
/// shape, each pushed a little further than the one above and fainter, so it
/// reads as soft with no blur, no layer and no cost per frame (a blur per list
/// item was ruled out). A copy is only ever MOVED, never grown: a shadow that
/// is wider than its paper (a spread) shows on the side of the light, an
/// all-round halo that reads as a border, and `paper_shadow_test.dart` fails
/// any shadow that has one or that falls toward the light. A press scales the
/// drop and so shrinks both.
abstract final class PaperShadow {
  /// The contact shadow: its alpha, and how much of the drop it takes.
  static const contactAlpha = 0.62;
  static const contactReach = 0.2;

  /// The cast: the steps, how far it falls (of the drop) and the alpha of
  /// each step (they add up near 0.4 next to the paper).
  static const castSteps = 5;
  static const castFall = 2.0;
  static const castAlpha = 0.08;

  /// The shadows of a drop of [offset] cast in [ink], outermost first (the
  /// order a [BoxDecoration] paints them: the last is on top).
  static List<BoxShadow> of(Offset offset, Color ink) {
    final drop = math.max(offset.dy, offset.dx.abs());
    if (drop <= 0) return const [];
    final lean = offset.dx / drop;
    double alpha(double a) => ink.a * a;
    return [
      for (var i = castSteps; i >= 1; i--)
        BoxShadow(
          color: ink.withValues(alpha: alpha(castAlpha)),
          offset: Offset(
            lean * drop * castFall * i / castSteps,
            drop * castFall * i / castSteps,
          ),
        ),
      BoxShadow(
        color: ink.withValues(alpha: alpha(contactAlpha)),
        offset: Offset(lean * 0.5, 0.5 + drop * contactReach),
      ),
    ];
  }
}

/// A stack of [HardShadow]s, listed top layer first (as CSS lists them), so
/// `[edge at 0,5; dark at 0,10]` is a paper edge lying on a dark one.
@immutable
class Elevation {
  const Elevation(this.layers);

  static const none = Elevation([]);

  final List<HardShadow> layers;

  /// For a [BoxDecoration]: Flutter paints shadows in list order, the last on
  /// top, so the layers go in reversed. A [HardShadow.drop] is the paper
  /// shadow; any other layer a hard offset copy.
  List<BoxShadow> get boxShadows => boxShadowsLeaning(0);

  /// The same, the drops leaning sideways by [lean] of their fall (away from
  /// the screen's light); an edge, the paper's own thickness, stays under it.
  List<BoxShadow> boxShadowsLeaning(double lean) => [
    for (final layer in layers.reversed)
      if (!layer.drop)
        // The paper's own thickness leans with the light too: one light. (A
        // plain layer is the hard copy of today and never leans.)
        BoxShadow(
          color: layer.color,
          offset: layer.edge
              ? layer.offset + Offset(lean * layer.offset.dy, 0)
              : layer.offset,
        )
      else
        for (final s in PaperShadow.of(layer.offset, layer.color))
          if (lean == 0)
            s
          else
            BoxShadow(
              color: s.color,
              blurRadius: s.blurRadius,
              spreadRadius: s.spreadRadius,
              offset: s.offset + Offset(lean * s.offset.dy, 0),
            ),
  ];

  /// The same stack with the shape pressed down: each layer keeps [keep] of
  /// its offset. Move the shape itself by [travel] so the shadow's far edge
  /// stays where it was.
  Elevation pressed(double keep) => Elevation([
    for (final layer in layers) layer.withOffset(layer.offset * keep),
  ]);

  /// The same stack with every offset times [factor]: a bigger or smaller
  /// copy of the same thing (a large button, a small card).
  Elevation scaled(double factor) => Elevation([
    for (final layer in layers) layer.withOffset(layer.offset * factor),
  ]);

  /// The same stack with the shape sunk by [by] under a finger: every layer
  /// loses that much of its downward offset (never below none), so a shape
  /// moved down by [by] leaves its shadow where it was.
  Elevation lowered(double by) => Elevation([
    for (final layer in layers)
      layer.withOffset(
        Offset(layer.offset.dx, math.max(0, layer.offset.dy - by)),
      ),
  ]);

  /// How far the shape moves when pressed down to [keep].
  Offset travel(double keep) => _deepest * (1 - keep);

  Offset get _deepest => layers.fold(
    Offset.zero,
    (deepest, layer) =>
        layer.offset.distance > deepest.distance ? layer.offset : deepest,
  );
}

/// The shadows things cast on one ground, by what they are.
@immutable
class GroundElevation {
  const GroundElevation({
    required this.card,
    required this.lying,
    required this.raised,
    required this.slab,
    required this.heroSlab,
    required this.primary,
    required this.selected,
    required this.badge,
    this.glow,
  });

  /// Rows and small cards.
  final Elevation card;

  /// A card lying face down on the table (S05, S06), at its 78-wide size;
  /// smaller and larger cards scale it.
  final Elevation lying;

  /// Inputs, panels and paper buttons: a little higher than [card].
  final Elevation raised;

  /// A large paper card lying on the table (a stack of paper edges).
  final Elevation slab;

  /// The one card a screen is about: your card, the dead player's card.
  final Elevation heroSlab;

  /// The primary button at its regular size; the large and compact sizes
  /// scale it.
  final Elevation primary;

  /// Whatever the player has picked.
  final Elevation selected;

  /// Count badges and small chips.
  final Elevation badge;

  /// The soft light a picked card gives off, where its ground has one (the
  /// night's bone; none on the day, where a selection is ink): the one
  /// blurred thing in the skin, kept faint, so a pick reads as lifted into
  /// the light and the hard shadow keeps the paper's edge.
  final Color? glow;
}
