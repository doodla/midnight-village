import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/skin.dart';

/// A seal cut from paper: a bone disc with a scalloped edge, a hard shadow
/// under it and a padlock cut out in dried-blood red. It is what a locked
/// vote is stamped with (09).
///
/// It lands once when it first appears with [lands] true: it comes down from
/// 1.7 times its size to rest over [Motion.quick] on [Motion.land] (a short
/// overshoot, under a tenth) and fades in over [Motion.press]; with reduce
/// motion, or [lands] false (a screen that opens already locked), it is just
/// there.
class PaperSeal extends StatefulWidget {
  const PaperSeal({super.key, required this.size, this.lands = true});

  /// The disc's width and height.
  final double size;
  final bool lands;

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
          final scale = 1 + 0.7 * (1 - Motion.land.transform(t));
          return Opacity(
            opacity:
                (t /
                        (Motion.press.inMilliseconds /
                            Motion.quick.inMilliseconds))
                    .clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: PaperSeal.tilt * 2 * math.pi * (2 - t),
              child: Transform.scale(scale: scale, child: child),
            ),
          );
        },
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
      ..drawPath(edge.shift(const Offset(0, 2)), Paint()..color = shadow)
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
