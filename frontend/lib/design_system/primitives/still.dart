import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'scene_arrival.dart';

/// A still part of a screen (its header picture faded into the ground, a
/// layered scene at rest) drawn ONCE into one picture at the screen's pixel
/// ratio, and that one picture drawn on every frame after.
///
/// What it saves: on the web every frame draws every layer of the screen
/// again, whatever changed. A picture faded by a mask, or a moon with its
/// shadow blended onto it, is a layer of its own to fill and blend on each of
/// those frames; inside a [Still] the fill and the blends happen once, when
/// what is inside changes (a size, a picture decoded), and a frame is one
/// picture drawn where it stands.
///
/// The rule that keeps it right: nothing inside a [Still] moves by itself.
/// A thing that moves (a candle, drifting mist, a breathing cue) sits ABOVE
/// it in a [Stack], in its own repaint boundary, so its frames never draw the
/// still part again (`still_test.dart`). Inside, a repaint boundary is
/// refused in debug builds (it would repaint without telling the still
/// picture, which would go stale), and a [Still] inside a [Still] is the
/// plain child: the outer one holds it.
///
/// [live]: drawn as it is, with no picture. A part is always live while a
/// scene brings its screen in (`SceneArrival`): its layers travel on every
/// frame, and a picture per frame would cost more than drawing them.
class Still extends StatelessWidget {
  const Still({super.key, this.live = false, required this.child});

  final bool live;
  final Widget child;

  /// Whether [context] is inside a [Still] (a part that would put a repaint
  /// boundary round itself leaves it out there: the still picture is its
  /// boundary).
  static bool isInside(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_StillMark>() != null;

  /// How many still pictures were made, for tests: a frame above a [Still]
  /// must not move it.
  @visibleForTesting
  static int made = 0;

  @override
  Widget build(BuildContext context) {
    if (isInside(context)) return child;
    return _StillMark(
      child: _StillBox(
        live: live || SceneArrival.maybeOf(context) != null,
        ratio: MediaQuery.maybeDevicePixelRatioOf(context) ?? 1,
        child: child,
      ),
    );
  }
}

class _StillMark extends InheritedWidget {
  const _StillMark({required super.child});

  @override
  bool updateShouldNotify(_StillMark oldWidget) => false;
}

class _StillBox extends SingleChildRenderObjectWidget {
  const _StillBox({
    required this.live,
    required this.ratio,
    required super.child,
  });

  final bool live;
  final double ratio;

  @override
  RenderStill createRenderObject(BuildContext context) =>
      RenderStill(live: live, ratio: ratio);

  @override
  void updateRenderObject(BuildContext context, RenderStill renderObject) {
    renderObject
      ..live = live
      ..ratio = ratio;
  }
}

/// The render object of [Still]: its own repaint boundary, so it is painted
/// only when something inside it changed, and each such paint makes the
/// picture again.
class RenderStill extends RenderProxyBox {
  RenderStill({required bool live, required double ratio})
    : _live = live,
      _ratio = ratio;

  bool _live;
  bool get live => _live;
  set live(bool value) {
    if (value == _live) return;
    _live = value;
    markNeedsPaint();
  }

  double _ratio;
  set ratio(double value) {
    if (value == _ratio) return;
    _ratio = value;
    markNeedsPaint();
  }

  ui.Image? _picture;

  /// The picture drawn on each frame, or null while [live] (tests).
  @visibleForTesting
  ui.Image? get picture => _picture;

  @override
  bool get isRepaintBoundary => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null || size.isEmpty || _live) {
      _forget();
      if (child != null) context.paintChild(child, offset);
      return;
    }
    final layer = OffsetLayer();
    final inner = PaintingContext(layer, Offset.zero & size);
    inner.paintChild(child, Offset.zero);
    // ignore: invalid_use_of_protected_member
    inner.stopRecordingIfNeeded();
    final made = layer.toImageSync(Offset.zero & size, pixelRatio: _ratio);
    layer.dispose();
    assert(_nothingMovesInside(child));
    _forget();
    _picture = made;
    Still.made++;
    context.canvas.drawImageRect(
      made,
      Offset.zero & (size * _ratio),
      offset & size,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  bool _nothingMovesInside(RenderObject root) {
    void visit(RenderObject node) {
      if (node.isRepaintBoundary) {
        throw FlutterError.fromParts([
          ErrorSummary('A repaint boundary inside a Still.'),
          ErrorDescription(
            'Inside a Still nothing may repaint by itself: put '
            '${node.runtimeType} above the Still, in a Stack, not inside it.',
          ),
        ]);
      }
      node.visitChildren(visit);
    }

    root.visitChildren(visit);
    if (root.isRepaintBoundary) visit(root);
    return true;
  }

  void _forget() {
    _picture?.dispose();
    _picture = null;
  }

  @override
  void dispose() {
    _forget();
    super.dispose();
  }
}
