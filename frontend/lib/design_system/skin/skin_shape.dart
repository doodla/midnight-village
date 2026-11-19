import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Corner radii, stroke widths and the few shape choices a skin makes.
/// Roundness values run from 0 (square corners) to 1 (fully round).
@immutable
class SkinShape {
  const SkinShape({
    required this.radius,
    required this.radiusSmall,
    required this.radiusTiny,
    required this.sheetRadius,
    required this.rowLeadRoundness,
    required this.tokenRoundness,
    required this.badgeRoundness,
    required this.ring,
    required this.selectedRing,
    required this.stroke,
    required this.edgeWidth,
    required this.pressKeep,
    required this.pip,
    required this.pipRoundness,
    required this.pipEmptyStroke,
  });

  /// Cards, buttons, panels, portraits in a grid.
  final double radius;

  /// Chips, small portraits.
  final double radiusSmall;

  /// Tags, and a picture set inside a card.
  final double radiusTiny;

  /// The top corners of a bottom sheet.
  final double sheetRadius;

  /// How round the leading end of a player row is (the end with the token).
  final double rowLeadRoundness;

  /// How round a player token is.
  final double tokenRoundness;

  /// How round a count badge is.
  final double badgeRoundness;

  /// Rings around tokens and portraits.
  final double ring;

  /// The ring of the selected thing.
  final double selectedRing;

  /// Outline buttons and inputs.
  final double stroke;

  /// The line around paper shapes, in [Ground.edge]; 0 for none.
  final double edgeWidth;

  /// How much of its shadow a pressed button keeps (0 to 1).
  final double pressKeep;

  /// One progress pip.
  final Size pip;
  final double pipRoundness;

  /// The outline of an empty pip; 0 draws it as a filled hairline instead.
  final double pipEmptyStroke;

  /// Corners of a box [height] tall at [roundness].
  double corner(double height, double roundness, {double square = 0}) =>
      square + (height / 2 - square) * roundness;
}
