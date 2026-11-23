import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../skin/dress.dart';
import '../skin/elevation.dart';
import '../skin/skin.dart';
import '../primitives/drawn.dart';

/// The one mark for "picked" and "done": a drop of ink-dark wax pressed on the
/// paper, its edge a little uneven, a ring stamped in it and a brush tick
/// across it, in the ground's own mark colours (bone on night, ink on day and
/// paper; never amber, never a stock tick in a circle). A picked row or card
/// wears it on its corner ([PaperMarkCorner]); a button that is done wears it
/// before its word. It is a still picture: nothing animates, so reduced motion
/// shows it as it is.
class PaperMark extends StatelessWidget {
  const PaperMark({super.key, required this.size, this.color, this.onColor});

  /// Its width and height.
  final double size;

  /// The wax and the tick on it: the ground's `mark` and `onMark` when null.
  final Color? color;
  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    final ground = context.ground;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: Drawn(
          DrawnKind.mark,
          child: CustomPaint(
            size: Size.square(size),
            painter: _MarkPainter(
              wax: color ?? ground.mark,
              tick: onColor ?? ground.onMark,
              cast: ground.shadow,
            ),
          ),
        ),
      ),
    );
  }
}

/// A [PaperMark] on the upper corner of what is picked, half over its edge
/// (on a dressed screen; a plain one marks a pick by its ring alone).
class PaperMarkCorner extends StatelessWidget {
  const PaperMarkCorner({super.key, required this.child, required this.shown});

  /// What wears the mark.
  final Widget child;
  final bool shown;

  /// The mark's width, and how far it hangs over the corner.
  static const size = 22.0;
  static const hang = 8.0;

  @override
  Widget build(BuildContext context) => !context.dress.isPaper
      ? child
      : Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (shown)
              const Positioned(
                top: -hang,
                right: -hang,
                child: IgnorePointer(child: PaperMark(size: size)),
              ),
          ],
        );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.wax,
    required this.tick,
    required this.cast,
  });

  final Color wax;
  final Color tick;
  final Color cast;

  /// The wax's edge: this many bumps, each up to this much of the radius.
  static const _bumps = 7;
  static const _wobble = 0.07;

  Path _blob(Offset centre, double radius) {
    final path = Path();
    const steps = 36;
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * math.pi * 2;
      final r = radius * (1 + _wobble * math.sin(a * _bumps + 0.6));
      final p = centre + Offset(math.cos(a), math.sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width;
    final centre = size.center(Offset.zero);
    final radius = unit * 0.46;
    // What it casts: the paper shadow, as flat steps.
    for (final shadow in PaperShadow.of(Offset(0, unit * 0.12), cast)) {
      canvas.drawPath(
        _blob(centre + shadow.offset, radius + shadow.spreadRadius * 0.5),
        Paint()..color = shadow.color,
      );
    }
    canvas.drawPath(_blob(centre, radius), Paint()..color = wax);
    // The ring pressed into it.
    canvas.drawCircle(
      centre,
      radius * 0.72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.045
        ..color = tick.withValues(alpha: 0.35),
    );
    // The brush tick: a short stroke down, a long one up, heavier at the turn.
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = tick;
    final turn = centre + Offset(-unit * 0.04, unit * 0.15);
    canvas.drawLine(
      centre + Offset(-unit * 0.2, unit * 0.01),
      turn,
      ink..strokeWidth = unit * 0.115,
    );
    canvas.drawLine(
      turn,
      centre + Offset(unit * 0.22, -unit * 0.17),
      ink..strokeWidth = unit * 0.085,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.wax != wax || old.tick != tick || old.cast != cast;
}
