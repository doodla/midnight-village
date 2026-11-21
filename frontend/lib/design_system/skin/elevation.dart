import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// One layer of a cut-paper shadow: a hard copy of the shape, offset, never
/// blurred. There is deliberately no blur or spread here.
@immutable
class HardShadow {
  const HardShadow(this.offset, this.color);

  final Offset offset;
  final Color color;
}

/// A stack of [HardShadow]s, listed top layer first (as CSS lists them), so
/// `[edge at 0,5; dark at 0,10]` is a paper edge lying on a dark one.
@immutable
class Elevation {
  const Elevation(this.layers);

  static const none = Elevation([]);

  final List<HardShadow> layers;

  /// For a [BoxDecoration]: Flutter paints shadows in list order, the last on
  /// top, so the layers go in reversed.
  List<BoxShadow> get boxShadows => [
    for (final layer in layers.reversed)
      BoxShadow(color: layer.color, offset: layer.offset),
  ];

  /// The same stack with the shape pressed down: each layer keeps [keep] of
  /// its offset. Move the shape itself by [travel] so the shadow's far edge
  /// stays where it was.
  Elevation pressed(double keep) => Elevation([
    for (final layer in layers) HardShadow(layer.offset * keep, layer.color),
  ]);

  /// The same stack with every offset times [factor]: a bigger or smaller
  /// copy of the same thing (a large button, a small card).
  Elevation scaled(double factor) => Elevation([
    for (final layer in layers) HardShadow(layer.offset * factor, layer.color),
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
}
