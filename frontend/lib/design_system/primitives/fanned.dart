import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/dress.dart';
import '../skin/skin.dart';

/// One card of a fan: turned a little further from the middle one, the middle
/// ones standing a little higher and every card a touch larger, on a dressed
/// screen. PAINT ONLY: what a finger lands on is the card's own untransformed
/// slot, never a tilted neighbour that overlaps it. So that what is seen is
/// what is tapped, the paper never reaches past its own slot further than half
/// of the [gap] to a neighbour (the turn and the size are the skin's
/// (`skin.parts`), taken down only as far as that takes): no pixel of a card
/// is over the slot of another, so no tap can land on the wrong one. Nor does
/// the paper reach the row above it further than half of [above]. [index] of
/// [count]. On a plain screen the card is as it is.
class Fanned extends StatelessWidget {
  const Fanned({
    super.key,
    required this.index,
    required this.count,
    required this.child,
    this.gap = Space.sm,
    this.above = Space.sm,
  });

  final int index;
  final int count;
  final Widget child;

  /// The space the row leaves between two slots.
  final double gap;

  /// The space between this row and the one above it: the paper's lift and
  /// its turned and enlarged top never reach further up than half of it.
  final double above;

  @override
  Widget build(BuildContext context) {
    if (!context.dress.isPaper) return child;
    final parts = context.skin.parts;
    final mid = (count - 1) / 2;
    final spread = mid == 0 ? 0.0 : (index - mid) / mid;
    return _FanPaint(
      angle: spread * parts.fanAngle,
      scale: parts.fanScale,
      lift: -Space.xs * spread * spread,
      room: gap / 2,
      roomAbove: above / 2,
      left: index > 0,
      right: index < count - 1,
      child: child,
    );
  }
}

class _FanPaint extends SingleChildRenderObjectWidget {
  const _FanPaint({
    required this.angle,
    required this.scale,
    required this.lift,
    required this.room,
    required this.roomAbove,
    required this.left,
    required this.right,
    required super.child,
  });

  final double angle;
  final double scale;
  final double lift;
  final double room;
  final double roomAbove;
  final bool left;
  final bool right;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _FanRender(angle, scale, lift, room, roomAbove, left, right);

  @override
  void updateRenderObject(BuildContext context, _FanRender render) {
    render
      ..angle = angle
      ..scale = scale
      ..lift = lift
      ..room = room
      ..roomAbove = roomAbove
      ..left = left
      ..right = right;
  }
}

/// Paints its child turned and enlarged, hit-tests it where its slot is.
class _FanRender extends RenderProxyBox {
  _FanRender(
    this._angle,
    this._scale,
    this._lift,
    this._room,
    this._roomAbove,
    this._left,
    this._right,
  );

  double _angle;
  double _scale;
  double _lift;
  double _room;
  double _roomAbove;
  bool _left;
  bool _right;

  set angle(double v) => _set(_angle, v, () => _angle = v);
  set scale(double v) => _set(_scale, v, () => _scale = v);
  set lift(double v) => _set(_lift, v, () => _lift = v);
  set room(double v) => _set(_room, v, () => _room = v);
  set roomAbove(double v) => _set(_roomAbove, v, () => _roomAbove = v);
  set left(bool v) => _set(_left, v, () => _left = v);
  set right(bool v) => _set(_right, v, () => _right = v);

  void _set(Object old, Object value, VoidCallback apply) {
    if (old == value) return;
    apply();
    markNeedsPaint();
  }

  /// How far the paper reaches past the slot's left and right edges for a
  /// [scale] and an [angle] (the card is scaled about its centre, then turned
  /// about the middle of its foot).
  (double, double) _reach(double w, double h, double scale, double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    var least = double.infinity;
    var most = -double.infinity;
    for (final px in [0.0, w]) {
      for (final py in [0.0, h]) {
        final x = w / 2 + (px - w / 2) * scale;
        final y = h / 2 + (py - h / 2) * scale;
        final turned = w / 2 + (x - w / 2) * cos - (y - h) * sin;
        least = math.min(least, turned);
        most = math.max(most, turned);
      }
    }
    return (-least, most - w);
  }

  /// The lift that is kept: the skin's, never further up than the room above.
  double get _liftKept => math.max(_lift, -_roomAbove);

  /// How far the paper reaches above the slot's top edge, lift included.
  double _rise(double w, double h, double scale, double angle) {
    final cos = math.cos(angle);
    final sin = math.sin(angle);
    var top = double.infinity;
    for (final px in [0.0, w]) {
      for (final py in [0.0, h]) {
        final x = (px - w / 2) * scale;
        final y = h / 2 + (py - h / 2) * scale;
        top = math.min(top, h + x * sin + (y - h) * cos);
      }
    }
    return -(top + _liftKept);
  }

  bool _fits(double w, double h, double scale, double angle) {
    final (toLeft, toRight) = _reach(w, h, scale, angle);
    return (!_left || toLeft <= _room) &&
        (!_right || toRight <= _room) &&
        _rise(w, h, scale, angle) <= _roomAbove + 0.01;
  }

  /// The skin's size and turn, taken down until the paper stays within its
  /// room: the size first (never under its own), then the turn.
  (double, double) _fitted(double w, double h) {
    if (_fits(w, h, _scale, _angle)) return (_scale, _angle);
    if (_fits(w, h, 1, _angle)) {
      var low = 1.0;
      var high = _scale;
      for (var i = 0; i < 16; i++) {
        final middle = (low + high) / 2;
        if (_fits(w, h, middle, _angle)) {
          low = middle;
        } else {
          high = middle;
        }
      }
      return (low, _angle);
    }
    var low = 0.0;
    var high = 1.0;
    for (var i = 0; i < 16; i++) {
      final middle = (low + high) / 2;
      if (_fits(w, h, 1, _angle * middle)) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return (1, _angle * low);
  }

  Matrix4 get _paintMatrix {
    final w = size.width;
    final h = size.height;
    final (scale, angle) = _fitted(w, h);
    return Matrix4.identity()
      ..translateByDouble(0, _liftKept, 0, 1)
      ..translateByDouble(w / 2, h, 0, 1)
      ..rotateZ(angle)
      ..translateByDouble(0, -h / 2, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-w / 2, -h / 2, 0, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    layer = context.pushTransform(
      needsCompositing,
      offset,
      _paintMatrix,
      super.paint,
      oldLayer: layer as TransformLayer?,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_paintMatrix);
  }
}
