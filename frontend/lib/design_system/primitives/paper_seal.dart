import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/skin.dart';
import '../primitives/drawn.dart';

/// A seal cut from paper: a scalloped disc with a hard shadow under it and a
/// padlock cut out of it. It is what a locked vote is stamped with (09), on
/// the pick's dried-blood red paper: a bone disc with a red padlock.
///
/// It lands once when it first appears with [lands] true: it comes down from
/// [landFrom] times its size to rest over [Motion.quick] on [Motion.land] (a
/// short overshoot, under a tenth) and fades in over [Motion.press]; with
/// reduce motion, or [lands] false (a screen that opens already locked), it
/// is just there. It grows from its lower right corner, so the growth goes up
/// and to the left, over the token it is stamped on and away from the name
/// beside it.
class PaperSeal extends StatefulWidget {
  const PaperSeal({super.key, required this.size, this.lands = true});

  /// The disc's width and height.
  final double size;
  final bool lands;

  /// How large it is as it comes down, times its size.
  static const landFrom = 1.4;

  /// How far the room around a seal at rest reaches past its disc, as a share
  /// of its size: the tilt's corners (about a tenth each side).
  static const tiltReach = 0.1;

  /// The shadow's drop under the disc.
  static const drop = 2.0;

  /// The scalloped edge's lobes.
  static const lobes = 14;

  /// How far the edge dips between two lobes, as a share of the radius.
  static const scallop = 0.07;

  /// The seal's tilt at rest, in turns: stamped by hand, never square.
  static const tilt = -0.035;

  @override
  State<PaperSeal> createState() => _PaperSealState();
}

class _PaperSealState extends State<PaperSeal>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: Motion.quick,
    value: widget.lands ? 0 : 1,
  );

  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || !widget.lands) return;
    _started = true;
    if (Motion.within(context, Motion.quick) == Duration.zero) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ground = context.ground;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final scale =
              1 + (PaperSeal.landFrom - 1) * (1 - Motion.land.transform(t));
          return Opacity(
            opacity:
                (t /
                        (Motion.press.inMilliseconds /
                            Motion.quick.inMilliseconds))
                    .clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: PaperSeal.tilt * 2 * math.pi * (1.5 - 0.5 * t),
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.bottomRight,
                child: child,
              ),
            ),
          );
        },
        child: Drawn(
          DrawnKind.mark,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _SealPainter(
              paper: ground.paper,
              shadow:
                  ground.elevation.card.layers.firstOrNull?.color ??
                  ground.shadow,
              mark: ground.danger,
            ),
            child: SizedBox.square(
              dimension: widget.size,
              child: Icon(
                Icons.lock,
                size: widget.size * 0.5,
                color: ground.danger,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  _SealPainter({required this.paper, required this.shadow, required this.mark});

  final Color paper;
  final Color shadow;
  final Color mark;

  Path _edge(Offset centre, double radius) {
    final path = Path();
    const steps = 120;
    for (var i = 0; i <= steps; i++) {
      final angle = 2 * math.pi * i / steps;
      final dip =
          PaperSeal.scallop * (0.5 + 0.5 * math.cos(PaperSeal.lobes * angle));
      final r = radius * (1 - dip);
      final point = centre + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.width / 2;
    final edge = _edge(centre, radius);
    canvas
      ..drawPath(
        edge.shift(const Offset(0, PaperSeal.drop)),
        Paint()..color = shadow,
      )
      ..drawPath(edge, Paint()..color = paper)
      ..drawCircle(
        centre,
        radius * 0.78,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, radius * 0.07)
          ..color = mark,
      );
  }

  @override
  bool shouldRepaint(_SealPainter old) =>
      paper != old.paper || shadow != old.shadow || mark != old.mark;
}
