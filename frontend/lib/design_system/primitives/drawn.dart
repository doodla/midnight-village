import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// What a drawing, not a border, is. A paper component paints no stroke of
/// its own (`dress_style.dart`): a stroke is allowed only inside a [Drawn] of
/// one of these, each a thing that IS a line by nature. `paper_strokes_test`
/// walks every component's paint and fails on a stroke outside them.
enum DrawnKind {
  /// A QR code's modules.
  qrCode,

  /// The wax and brush tick of a pick or a done mark, and the seal's cut.
  mark,

  /// Tally strokes struck on a vote's paper.
  tally,

  /// A lantern, its frame and cord (the village's own light).
  lantern,

  /// The hold ring: a gauge that fills as the finger stays down.
  holdGauge,

  /// The scanner's corners round what the camera sees.
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
