import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'twine.dart';

// A link: the thread that says what one card did to another (a look, a card
// taken, two cards swapped, a team that saw each other), tied from card edge
// to card edge. One part, so every place that links two cards draws it the
// same way: given the cards as they lie (turned and placed) it finds where
// the thread is tied and how it bends; [TwinePainter] paints it.

/// A card as it lies: its rect before it is turned, and its turn about its
/// centre (radians).
@immutable
class LaidCard {
  const LaidCard(this.rect, [this.angle = 0]);

  final Rect rect;
  final double angle;

  Offset get center => rect.center;

  /// The four corners as drawn (turned).
  List<Offset> get corners => [
    for (final p in [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ])
      _turn(p - center, angle) + center,
  ];

  /// The box the turned card fills.
  Rect get bounds {
    final c = corners;
    return Rect.fromLTRB(
      c.map((p) => p.dx).reduce(math.min),
      c.map((p) => p.dy).reduce(math.min),
      c.map((p) => p.dx).reduce(math.max),
      c.map((p) => p.dy).reduce(math.max),
    );
  }

  /// [p] in the card's own unturned frame.
  Offset _local(Offset p) => _turn(p - center, -angle) + center;

  /// Whether [p] lies on the card, [inset] inside its edges.
  bool contains(Offset p, {double inset = 0}) =>
      rect.deflate(inset).contains(_local(p));

  /// How far [p] is from the card's edge (0 on it).
  double edgeDistance(Offset p) {
    final q = _local(p);
    final r = rect;
    final dx = math.max(r.left - q.dx, q.dx - r.right);
    final dy = math.max(r.top - q.dy, q.dy - r.bottom);
    if (dx <= 0 && dy <= 0) return -math.max(dx, dy);
    return Offset(math.max(dx, 0), math.max(dy, 0)).distance;
  }

  /// Where a ray from the card's centre toward [toward] leaves the card: a
  /// point on its edge, on the side that faces [toward].
  Offset edgeToward(Offset toward) {
    final d = _turn(toward - center, -angle);
    if (d == Offset.zero) return center;
    final hw = rect.width / 2, hh = rect.height / 2;
    final sx = d.dx == 0 ? double.infinity : hw / d.dx.abs();
    final sy = d.dy == 0 ? double.infinity : hh / d.dy.abs();
    return _turn(d * math.min(sx, sy), angle) + center;
  }

  static Offset _turn(Offset v, double a) {
    final c = math.cos(a), s = math.sin(a);
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }
}

/// What a link says. A [look] (a copy is a look) is gapped and ends in a dot
/// at the card seen; a [team] is gapped with a dot at both ends (they saw
/// each other); a [take] and a [swap] are solid with a head at both ends
/// (each card received the other's).
enum LinkKind {
  look,
  team,
  take,
  swap;

  bool get moves => this == take || this == swap;
}

/// A link planned: its route and what each end shows.
@immutable
class CardLink {
  const CardLink({
    required this.route,
    required this.kind,
    required this.clear,
  });

  final TwineRoute route;
  final LinkKind kind;

  /// Whether the route found keeps every rule (false: the least bad one).
  final bool clear;

  TwineKind get thread => kind.moves ? TwineKind.move : TwineKind.look;
  TwineEnd get start => switch (kind) {
    LinkKind.look => TwineEnd.none,
    LinkKind.team => TwineEnd.dot,
    LinkKind.take || LinkKind.swap => TwineEnd.head,
  };
  TwineEnd get end => kind.moves ? TwineEnd.head : TwineEnd.dot;

  /// How gently a link bends: its bow is this share of its length, first;
  /// then more, either way, until it clears.
  static const bows = [
    0.1, -0.1, 0, 0.2, -0.2, 0.32, -0.32, 0.48, -0.48, 0.7, -0.7, 1.0, -1.0, //
    1.4, -1.4,
  ];

  /// Turns of the aim off the line between the cards (radians), so an end
  /// can slide along the edge off a seal.
  static const aims = [0.0, 0.35, -0.35, 0.7, -0.7, 1.05, -1.05];

  /// The link from [a] to [b]: tied on each card's edge where the two face
  /// each other (never under anything in [avoid]: the other cards, every
  /// seal and tag), bending gently and as little as clears [avoid], inside
  /// [frame]. Where nothing clears, the gentlest that stays off its own
  /// cards, marked not [clear].
  factory CardLink.between(
    LaidCard a,
    LaidCard b, {
    required LinkKind kind,
    Iterable<Rect> avoid = const [],
    Rect? frame,
    double clearance = 3,
  }) {
    final others = [for (final r in avoid) r.inflate(clearance)];
    final line = b.center - a.center;
    final length = math.max(line.distance, 1.0);
    // Perpendicular, pointing down the page: a positive bow sags.
    var normal = Offset(-line.dy, line.dx) / length;
    if (normal.dy < 0 || (normal.dy == 0 && normal.dx < 0)) normal = -normal;
    // A move's two heads need room between them: a short link bows out
    // until its thread is this long, where it can.
    final least = kind.moves ? TwinePainter.headLength * 4 : 0.0;
    TwineRoute? fallback;
    TwineRoute? short;
    for (final bow in bows) {
      for (final aim in aims) {
        final control =
            Offset.lerp(a.center, b.center, 0.5)! + normal * (bow * length);
        final from = a.edgeToward(_aimed(a.center, control, aim));
        final to = b.edgeToward(_aimed(b.center, control, -aim));
        final span = (to - from).distance;
        final route = TwineRoute(
          from,
          Offset.lerp(from, to, 0.5)! + normal * (bow * span),
          to,
        );
        if (!_offItsCards(route, a, b)) continue;
        fallback ??= route;
        if (others.any((r) => r.contains(from) || r.contains(to))) continue;
        if (frame != null && !_inside(route, frame)) continue;
        if (_crosses(route, others)) continue;
        if (_length(route) < least) {
          short ??= route;
          continue;
        }
        return CardLink(route: route, kind: kind, clear: true);
      }
    }
    if (short != null) return CardLink(route: short, kind: kind, clear: true);
    final from = a.edgeToward(b.center), to = b.edgeToward(a.center);
    return CardLink(
      route: fallback ?? TwineRoute(from, Offset.lerp(from, to, 0.5)!, to),
      kind: kind,
      clear: false,
    );
  }

  static Offset _aimed(Offset centre, Offset at, double turn) =>
      LaidCard._turn(at - centre, turn) + centre;

  /// The points judged: the route's, but for its two ends (on the edges).
  static Iterable<Offset> _inner(TwineRoute route) {
    final points = route.sample(TwinePainter.steps);
    return points.sublist(1, points.length - 1);
  }

  static double _length(TwineRoute route) {
    final points = route.sample(TwinePainter.steps);
    var length = 0.0;
    for (var i = 1; i < points.length; i++) {
      length += (points[i] - points[i - 1]).distance;
    }
    return length;
  }

  static bool _offItsCards(TwineRoute route, LaidCard a, LaidCard b) => _inner(
    route,
  ).every((p) => !a.contains(p, inset: -0.5) && !b.contains(p, inset: -0.5));

  static bool _inside(TwineRoute route, Rect frame) =>
      route.sample(TwinePainter.steps).every(frame.inflate(0.5).contains);

  static bool _crosses(TwineRoute route, List<Rect> rects) =>
      _inner(route).any((p) => rects.any((r) => r.contains(p)));
}
