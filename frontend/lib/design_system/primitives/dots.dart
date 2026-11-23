import 'package:flutter/material.dart';

import '../skin/dress.dart';
import '../skin/dress_style.dart';
import '../skin/skin.dart';
import 'paper_piece.dart';

/// One place at a table set for a number (02, 03): taken, a filled disc in
/// [ink]; empty, an outline on a plain screen and a darker paper disc on a
/// paper one (a [PaperPiece]: no outline).
class SeatDot extends StatelessWidget {
  const SeatDot({
    super.key,
    required this.taken,
    required this.side,
    required this.ink,
    required this.outline,
    required this.stroke,
  });

  final bool taken;
  final double side;

  /// A taken seat's colour.
  final Color ink;

  /// An empty seat's outline on a plain screen.
  final Color outline;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    if (context.dress.isPaper) {
      return SizedBox.square(
        dimension: side,
        child: PaperPiece(
          part: PaperPart.disc,
          id: taken,
          fill: taken ? ink : context.ground.panel,
          child: const SizedBox.expand(),
        ),
      );
    }
    return Container(
      width: side,
      height: side,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: taken ? ink : null,
        border: Border.all(color: taken ? ink : outline, width: stroke),
      ),
    );
  }
}

/// One slot of the deck's count (03): filled for a card picked, empty for one
/// still to add; a plain screen outlines the empty one, a paper one lays a
/// darker paper slip.
class SlotMark extends StatelessWidget {
  const SlotMark({
    super.key,
    required this.filled,
    required this.size,
    required this.ink,
    required this.outline,
  });

  final bool filled;
  final Size size;
  final Color ink;
  final Color outline;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    if (context.dress.isPaper) {
      return SizedBox.fromSize(
        size: size,
        child: PaperPiece(
          part: PaperPart.chip,
          id: filled,
          fill: filled ? ink : context.ground.panel,
          child: const SizedBox.expand(),
        ),
      );
    }
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(skin.shape.radiusSmall / 2),
        color: filled ? ink : null,
        border: Border.all(
          color: filled ? ink : outline,
          width: skin.shape.stroke,
        ),
      ),
    );
  }
}
