import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// What a drawing, not a border, is. A paper component paints no stroke of
/// its own (`dress_style.dart`): a stroke is allowed only inside a [Drawn] of
/// one of these, each a thing that IS a line by nature and no piece of paper.
/// The marks, tally strokes and lanterns are not here: dressed up they are
/// filled shapes of paper with a shadow, cut like the rest. The role and card
/// back pictures are images, not strokes, and need no entry.
/// `paper_components_test` walks every component's paint and fails on a stroke
/// outside them.
enum DrawnKind {
  /// A QR code's modules: the code is its squares, nothing to dress.
  qrCode,

  /// The scanner's camera frame (the corners round what the camera sees, and
  /// the same corners on 01's scan glyph): a viewfinder is its lines.
  scanner,
}

/// Marks [child] as a drawing of [kind]: it paints as it always did, and the
/// stroke test leaves it be.
class Drawn extends SingleChildRenderObjectWidget {
  const Drawn(this.kind, {super.key, super.child});

  final DrawnKind kind;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderDrawn(kind);

  @override
  void updateRenderObject(BuildContext context, RenderDrawn renderObject) =>
      renderObject.kind = kind;
}

class RenderDrawn extends RenderProxyBox {
  RenderDrawn(this.kind);

  DrawnKind kind;
}
