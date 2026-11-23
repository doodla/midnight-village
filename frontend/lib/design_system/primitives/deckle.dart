import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The edge of a piece of paper that was torn, not cut: a rectangle whose four
/// sides step in and out by a hair (a deckle), seeded so the same piece is
/// the same on every build and phone. [depth] is how far an edge may step in;
/// [step] the length of one nibble. A [torn] edge is the wider, rougher one
/// of a banner or a sheet's top: longer bites with the odd deep notch.
///
/// Only the paint changes: the layout box, the hit target and the text inside
/// are the plain rectangle's (`dimensions` is zero).
class DeckleBorder extends ShapeBorder {
  const DeckleBorder({
    required this.seed,
    this.depth = 2.4,
    this.step = 6,
    this.torn = false,
    this.side = BorderSide.none,
    this.round = false,
    this.blob = false,
  });

  final int seed;
  final double depth;
  final double step;
  final bool torn;
  final BorderSide side;

  /// A disc, not a rectangle: a circle whose rim steps in and out by a hair
  /// (a cut disc of paper). [blob] smooths it into a drop of wax.
  final bool round;
  final bool blob;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  /// A number from 0 to 1 from [seed], the edge [edge] and nibble [i]
  /// (deterministic, no randomness).
  double _h(int edge, int i) {
    var x = (seed * 73856093) ^ (edge * 19349663) ^ (i * 83492791);
    x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff;
    x = (x ^ (x >> 16)) & 0x7fffffff;
    return (x % 1000) / 1000;
  }

  double _bite(int edge, int i) {
    final h = _h(edge, i);
    if (!torn) return depth * h;
    // A tear: mostly shallow, with the odd deep bite.
    return depth * (h < 0.12 ? 1 : 0.15 + 0.6 * h);
  }

  Path _roundPath(Rect rect) {
    final centre = rect.center;
    final radius = math.min(rect.width, rect.height) / 2;
    final n = math.max(10, (2 * math.pi * radius / step).round());
    final points = [
      for (var i = 0; i < n; i++)
        centre +
            Offset.fromDirection(
              2 * math.pi * i / n,
              radius - (blob ? depth * (0.3 + 1.4 * _h(0, i)) : _bite(0, i)),
            ),
    ];
    final path = Path();
    if (!blob) return path..addPolygon(points, true);
    // Wax: the rim runs through the midpoints, the points pulling it.
    Offset mid(int i) => (points[i % n] + points[(i + 1) % n]) / 2;
    path.moveTo(mid(n - 1).dx, mid(n - 1).dy);
    for (var i = 0; i < n; i++) {
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid(i).dx, mid(i).dy);
    }
    return path..close();
  }

  Path _path(Rect rect) {
    if (round) return _roundPath(rect);
    final path = Path();
    final w = rect.width;
    final h = rect.height;
    final nx = math.max(2, (w / step).round());
    final ny = math.max(2, (h / step).round());
    // Top edge, left to right.
    path.moveTo(rect.left + _bite(0, 0) * 0.5, rect.top + _bite(0, 0));
    for (var i = 1; i <= nx; i++) {
      path.lineTo(rect.left + w * i / nx, rect.top + _bite(0, i));
    }
    // Right edge, top to bottom.
    for (var i = 1; i <= ny; i++) {
      path.lineTo(rect.right - _bite(1, i), rect.top + h * i / ny);
    }
    // Bottom edge, right to left.
    for (var i = 1; i <= nx; i++) {
      path.lineTo(rect.right - w * i / nx, rect.bottom - _bite(2, i));
    }
    // Left edge, bottom to top.
    for (var i = 1; i < ny; i++) {
      path.lineTo(rect.left + _bite(3, i), rect.bottom - h * i / ny);
    }
    path.close();
    return path;
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    canvas.drawPath(
      _path(rect),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = side.width
        ..color = side.color,
    );
  }

  @override
  ShapeBorder scale(double t) => this;

  @override
  bool operator ==(Object other) =>
      other is DeckleBorder &&
      other.seed == seed &&
      other.depth == depth &&
      other.step == step &&
      other.torn == torn &&
      other.round == round &&
      other.blob == blob &&
      other.side == side;

  @override
  int get hashCode => Object.hash(seed, depth, step, torn, side, round, blob);
}

/// A seed from any id (djb2 over its text; the same on every platform).
int deckleSeed(Object id) {
  var hash = 5381;
  for (final unit in id.toString().codeUnits) {
    hash = ((hash << 5) + hash + unit) & 0x7fffffff;
  }
  return hash;
}
