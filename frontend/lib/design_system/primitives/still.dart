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
  const Still({
    super.key,
    this.live = false,
    this.spill = 0,
    this.opacity = 1,
    required this.child,
  });

  final bool live;
  final Widget child;

  /// How far what is inside may paint outside its box (a paper shadow), in
  /// logical pixels: the picture takes that much around the box.
  final double spill;

  /// How much of the picture shows (an `Opacity` inside would be a layer of
  /// its own, filled on every frame: here it is the picture's own alpha).
  final double opacity;

  /// Whether [context] is inside a [Still] (a part that would put a repaint
  /// boundary round itself leaves it out there: the still picture is its
  /// boundary).
  static bool isInside(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_StillMark>() != null;

  /// How many still pictures were made, for tests: a frame above a [Still]
  /// must not move it.
  @visibleForTesting
  static int made = 0;

  /// Every [Still] drawn live, for a test that compares the pictures with
  /// what they stand for.
  @visibleForTesting
  static bool debugAllLive = false;

  @override
  Widget build(BuildContext context) {
    if (isInside(context)) return child;
    return _StillMark(
      child: _StillBox(
        live: debugAllLive || live || SceneArrival.maybeOf(context) != null,
        spill: spill,
        opacity: opacity,
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
    required this.spill,
    required this.opacity,
    required this.ratio,
    required super.child,
  });

  final bool live;
  final double spill;
  final double opacity;
  final double ratio;

  @override
  RenderStill createRenderObject(BuildContext context) =>
      RenderStill(live: live, spill: spill, opacity: opacity, ratio: ratio);

  @override
  void updateRenderObject(BuildContext context, RenderStill renderObject) {
    renderObject
      ..live = live
      ..spill = spill
      ..opacity = opacity
      ..ratio = ratio;
  }
}

/// The render object of [Still]: its own repaint boundary, so it is painted
/// only when something inside it changed, and each such paint makes the
/// picture again.
class RenderStill extends RenderProxyBox {
  RenderStill({
    required bool live,
    required double spill,
    required double opacity,
    required double ratio,
  }) : _live = live,
       _spill = spill,
       _opacity = opacity,
       _ratio = ratio;

  double _opacity;
  set opacity(double value) {
    if (value == _opacity) return;
    _opacity = value;
    markNeedsPaint();
  }

  double _spill;
  set spill(double value) {
    if (value == _spill) return;
    _spill = value;
    markNeedsPaint();
  }

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
      if (child == null) return;
      if (_opacity >= 1) {
        context.paintChild(child, offset);
      } else {
        context.pushOpacity(
          offset,
          (_opacity * 255).round(),
          (context, offset) => context.paintChild(child, offset),
        );
      }
      return;
    }
    final bounds = _onPixels();
    final layer = OffsetLayer();
    final inner = PaintingContext(layer, bounds);
    inner.paintChild(child, Offset.zero);
    // ignore: invalid_use_of_protected_member
    inner.stopRecordingIfNeeded();
    final made = layer.toImageSync(bounds, pixelRatio: _ratio);
    layer.dispose();
    assert(_nothingMovesInside(child));
    _forget();
    _picture = made;
    Still.made++;
    context.canvas.drawImageRect(
      made,
      Offset.zero & (bounds.size * _ratio),
      bounds.shift(offset),
      Paint()
        ..filterQuality = FilterQuality.low
        ..color = Color.fromRGBO(0, 0, 0, _opacity),
    );
  }

  /// The box to draw the picture of, in this box's own coordinates: as
  /// large as it with its spill, and lying on whole device pixels, so the
  /// picture is drawn one pixel to one pixel and what is inside keeps the
  /// place it has between pixels when drawn live (a card in a grid at a
  /// fraction of a pixel). Under a scale or a turn it is the plain box.
  Rect _onPixels() {
    final r = _ratio;
    final spill = (_spill * r).ceil() / r;
    final m = getTransformTo(null);
    final plain =
        m.entry(0, 1) == 0 &&
        m.entry(1, 0) == 0 &&
        (m.entry(0, 0) - r).abs() < 1e-6 &&
        (m.entry(1, 1) - r).abs() < 1e-6;
    if (!plain) return (Offset.zero & size).inflate(spill);
    final x = m.entry(0, 3), y = m.entry(1, 3);
    final dx = (x - x.floorToDouble()) / r, dy = (y - y.floorToDouble()) / r;
    final w = ((size.width + dx) * r).ceil() / r;
    final h = ((size.height + dy) * r).ceil() / r;
    return Rect.fromLTWH(-dx, -dy, w, h).inflate(spill);
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
