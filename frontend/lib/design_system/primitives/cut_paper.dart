import 'package:flutter/widgets.dart';

import '../skin/elevation.dart';
import '../skin/skin.dart';

/// The decoration of a cut-paper shape on the current ground: [fill], the
/// skin's edge line (when its shape draws one) and a hard [elevation].
BoxDecoration cutPaper(
  BuildContext context, {
  required Color fill,
  required BorderRadius radius,
  Elevation elevation = Elevation.none,
}) {
  final edgeWidth = context.skin.shape.edgeWidth;
  return BoxDecoration(
    color: fill,
    borderRadius: radius,
    border: edgeWidth > 0
        ? Border.all(color: context.ground.edge, width: edgeWidth)
        : null,
    boxShadow: elevation.boxShadows,
  );
}

/// A ring drawn just outside a shape, without changing its size (CSS's
/// `box-shadow: 0 0 0 <width> <color>`). Paint it as a foreground decoration.
BoxDecoration ringDecoration({
  required Color color,
  required double width,
  required BorderRadius radius,
}) => BoxDecoration(
  borderRadius: radius,
  border: Border.all(
    color: color,
    width: width,
    strokeAlign: BorderSide.strokeAlignOutside,
  ),
);
