import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../skin/elevation.dart';
import '../skin/skin.dart';
import 'one_light.dart';
import 'paper_light.dart';

/// What a twine says: a thread pulled from one card to another. A [move] is
/// solid (something went from one card to the other); a [look] is gapped
/// (someone looked, nothing moved). Red is the Werewolf team's, and only its
/// ([Twine.werewolf]).
enum TwineKind { move, look }

/// How a twine ends at a card: bare, a filled [head] (a card went this way),
/// or a filled [dot] (the card looked at).
enum TwineEnd { none, head, dot }

/// A twine's path: a quadratic curve from [from] to [to] bent toward
/// [control], all in the board's coordinates.
@immutable
class TwineRoute {
  const TwineRoute(this.from, this.control, this.to);

  final Offset from;
  final Offset control;
  final Offset to;

  Offset at(double t) {
    final u = 1 - t;
    return from * (u * u) + control * (2 * u * t) + to * (t * t);
  }

  /// [steps] + 1 points along it, ends included.
  List<Offset> sample([int steps = 48]) => [
    for (var i = 0; i <= steps; i++) at(i / steps),
  ];

  Rect get bounds {
    final points = sample(24);
    var rect = Rect.fromPoints(points.first, points.first);
    for (final p in points) {
      rect = rect.expandToInclude(Rect.fromPoints(p, p));
    }
    return rect;
  }

  /// Whether the thread, but for its [ends] share at each end (where it is
  /// tied on), passes through any of [rects].
  bool crosses(Iterable<Rect> rects, {double ends = 0.1}) {
    // The ends are tied to a card's corner: only the middle is judged.
    final points = sample();
    final first = (points.length * ends).ceil();
    final last = points.length - first;
    for (var i = first; i < last; i++) {
      for (final rect in rects) {
        if (rect.contains(points[i])) return true;
      }
    }
    return false;
  }

  /// A twine from a corner of [a] to a corner of [b], the corners that face
  /// each other, hung with a sag; where that would pass through anything in
  /// [avoid] (the cards' words, other cards) it is bent further, to the one
  /// side and the other, until it clears them all. [avoid] is in the same
  /// coordinates as the rects. A twine that cannot clear anything is the
  /// straightest one (the last candidate: the widest bow).
  factory TwineRoute.between(
    Rect a,
    Rect b, {
    Iterable<Rect> avoid = const [],
    double sag = 14,
    double clearance = 2,
  }) {
    final dx = b.center.dx - a.center.dx;
    final dy = b.center.dy - a.center.dy;
    // Cards in one column face by their sides: the twine leaves each by the
    // corner on the side the two are nearest to (the outer one, below).
    final stacked = dx.abs() < math.min(a.width, b.width) / 2;
    final Offset from;
    final Offset to;
    if (stacked) {
      final lower = dy >= 0;
      from = lower ? a.bottomLeft : a.topLeft;
      to = lower ? b.topLeft : b.bottomLeft;
    } else {
      final right = dx >= 0;
      from = Offset(right ? a.right : a.left, dy >= 0 ? a.bottom : a.top);
      to = Offset(right ? b.left : b.right, dy >= 0 ? b.top : b.bottom);
    }
    final middle = Offset.lerp(from, to, 0.5)!;
    final line = to - from;
    final length = line.distance;
    // Perpendicular, always pointing down on the page for the sag.
    var normal = length == 0
        ? const Offset(0, 1)
        : Offset(-line.dy / length, line.dx / length);
    if (normal.dy < 0) normal = -normal;
    final cleared = avoid.map((r) => r.inflate(clearance)).toList();
    final bows = [
      sag * 2,
      for (final k in [2, 4, 6, 9, 13]) ...[sag * 2 * k, -sag * 2 * k],
    ];
    TwineRoute route = TwineRoute(from, middle + normal * bows.first, to);
    for (final bow in bows) {
      route = TwineRoute(from, middle + normal * bow, to);
      if (!route.crosses(cleared)) return route;
    }
    return route;
  }
}

/// The thread of a twine, painted as a FILLED ribbon of [width] along the
/// route (a stroke is not paper: `paper_components_test.dart` fails one), in
/// one length for a [TwineKind.move], in dashes for a [TwineKind.look], with
/// the paper shadow under it falling away from the light; with [head], a
/// filled head at its far end ([TwineRoute.to]) says which way it went.
class TwinePainter extends CustomPainter {
  const TwinePainter({
    required this.route,
    required this.kind,
    required this.color,
    required this.shadow,
    required this.lean,
    this.width = 2.2,
    this.drop = 3,
    this.dash = 8,
    this.gap = 6,
    this.alpha = 1,
    this.head = false,
    this.tail = TwineEnd.none,
    this.headSize = headLength,
    this.dotSize = dotRadius,
    TwineEnd tip = TwineEnd.none,
  }) : tip = head ? TwineEnd.head : tip;

  final TwineRoute route;
  final TwineKind kind;
  final Color color;

  /// A head at the far end: the way a card went, or a look's way.
  final bool head;

  /// How it ends at its start ([TwineRoute.from]) and at its far end.
  final TwineEnd tail;
  final TwineEnd tip;

  /// A dot's radius.
  static const dotRadius = 3.4;

  /// The head's length along the thread and its width across (the
  /// defaults: a twine's own, read at a card's size).
  static const headLength = 9.0;

  /// This twine's head, as long along the thread as it is wide across, and
  /// its dots' radius.
  final double headSize;
  final double dotSize;
  final Color shadow;

  /// Which way the shadow leans (`PaperLight`'s lean): away from the light.
  final double lean;
  final double width;

  /// How far the shadow falls under the thread.
  final double drop;
  final double dash;
  final double gap;

  /// How much of it shows (an earlier step's twine is dimmed).
  final double alpha;

  /// The points of the route, evenly spaced along it.
  static const steps = 64;

  /// The thread as filled shapes: one for a move, one per dash for a look.
  Path thread() {
    final points = route.sample(steps);
    final path = Path();
    void strip(List<Offset> run) {
      if (run.length < 2) return;
      final left = <Offset>[];
      final right = <Offset>[];
      for (var i = 0; i < run.length; i++) {
        final before = run[math.max(0, i - 1)];
        final after = run[math.min(run.length - 1, i + 1)];
        final along = after - before;
        final length = along.distance;
        final normal = length == 0
            ? Offset.zero
            : Offset(-along.dy / length, along.dx / length) * (width / 2);
        left.add(run[i] + normal);
        right.add(run[i] - normal);
      }
      path.addPolygon([...left, ...right.reversed], true);
    }

    _end(path, tip, route.to, route.at(0.9));
    _end(path, tail, route.from, route.at(0.1));
    if (kind == TwineKind.move) {
      strip(points);
      return path;
    }
    // Gapped: walk the curve by length, a dash on, a gap off.
    var run = <Offset>[points.first];
    var on = true;
    var left = dash;
    for (var i = 1; i < points.length; i++) {
      var from = points[i - 1];
      final to = points[i];
      var span = (to - from).distance;
      while (span > left) {
        final cut = Offset.lerp(from, to, left / span)!;
        if (on) {
          run.add(cut);
          strip(run);
          run = [];
        } else {
          run = [cut];
        }
        span -= left;
        from = cut;
        on = !on;
        left = on ? dash : gap;
      }
      left -= span;
      if (on) run.add(to);
    }
    if (on) strip(run);
    return path;
  }

  /// An end: a dot on [tip], or a filled triangle whose tip is [tip],
  /// turned along the thread's stretch from [back].
  void _end(Path path, TwineEnd end, Offset tip, Offset back) {
    if (end == TwineEnd.none) return;
    if (end == TwineEnd.dot) {
      path.addOval(Rect.fromCircle(center: tip, radius: dotSize));
      return;
    }
    final along = tip - back;
    final length = along.distance;
    if (length == 0) return;
    final unit = along / length;
    final normal = Offset(-unit.dy, unit.dx) * (headSize / 2);
    final base = tip - unit * headSize;
    path.addPolygon([tip, base + normal, base - normal], true);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = thread();
    final ink = alpha.clamp(0.0, 1.0);
    // The shadow: moved copies of the thread, each further and fainter, as
    // every paper shadow is (no blur, no layer).
    for (final s in PaperShadow.of(Offset(lean * drop, drop), shadow)) {
      canvas.drawPath(
        path.shift(s.offset),
        Paint()..color = s.color.withValues(alpha: s.color.a * ink),
      );
    }
    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: color.a * ink),
    );
  }

  @override
  bool shouldRepaint(TwinePainter old) =>
      route.from != old.route.from ||
      route.control != old.route.control ||
      route.to != old.route.to ||
      kind != old.kind ||
      color != old.color ||
      shadow != old.shadow ||
      lean != old.lean ||
      alpha != old.alpha ||
      tip != old.tip ||
      tail != old.tail ||
      width != old.width ||
      headSize != old.headSize ||
      dotSize != old.dotSize;
}

/// A twine between cards, in the board's coordinates: paper thread in the
/// ground's bone, or in the Werewolf team's red ([werewolf]; the one red that
/// is not a team tag). It lies on the board, takes no touch and says nothing to
/// a screen reader: the cards it joins say it. It leans its shadow away from
/// the board's light ([OneLight], else the screen's [PaperLight]).
class Twine extends StatelessWidget {
  const Twine({
    super.key,
    required this.route,
    this.kind = TwineKind.move,
    this.werewolf = false,
    this.alpha = 1,
    this.head = false,
  });

  final TwineRoute route;
  final TwineKind kind;

  /// A head at the far end ([TwinePainter.head]).
  final bool head;

  /// A werewolf's: red.
  final bool werewolf;

  /// Dimmed to this much (an earlier step's twine: 0.55).
  final double alpha;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final lean =
        OneLight.maybeOf(context)?.leanFor(route.bounds) ??
        PaperLight.of(context);
    final ink = ground.elevation.card.layers.firstOrNull?.color;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: TwinePainter(
              route: route,
              kind: kind,
              color: werewolf ? skin.parts.werewolfTag : ground.text,
              shadow: ink ?? ground.shadow,
              lean: lean,
              alpha: alpha,
              head: head,
            ),
          ),
        ),
      ),
    );
  }
}
