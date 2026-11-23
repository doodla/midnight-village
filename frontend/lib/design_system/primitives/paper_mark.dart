import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../skin/dress.dart';
import '../skin/elevation.dart';
import '../skin/skin.dart';

/// The one mark for "picked" and "done": a drop of ink-dark wax pressed on the
/// paper, its edge a little uneven and a tick cut from paper laid on it
/// (filled shapes with a shadow each: no stroke, no ring), in the ground's own mark colours (bone on night, ink on day and
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
        child: CustomPaint(
          size: Size.square(size),
          painter: _MarkPainter(
            wax: color ?? ground.mark,
            tick: onColor ?? ground.onMark,
            cast: ground.shadow,
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
    // The tick: a paper cut, a short stroke down and a long one up, heavier
    // at the turn, with its own small shadow on the wax.
    final cut = _tick(centre, unit);
    canvas
      ..drawPath(
        cut.shift(Offset(0, unit * 0.035)),
        Paint()..color = cast.withValues(alpha: 0.4),
      )
      ..drawPath(cut, Paint()..color = tick);
  }

  /// The tick as one filled shape: two tapering bars meeting at the turn.
  Path _tick(Offset centre, double unit) {
    final start = centre + Offset(-unit * 0.2, unit * 0.01);
    final turn = centre + Offset(-unit * 0.04, unit * 0.15);
    final end = centre + Offset(unit * 0.22, -unit * 0.17);
    final down = unit * 0.115 / 2;
    final up = unit * 0.085 / 2;
    // The bars' sides, from each bar's normal.
    Offset normal(Offset a, Offset b) {
      final d = b - a;
      return Offset(-d.dy, d.dx) / d.distance;
    }

    final n1 = normal(start, turn);
    final n2 = normal(turn, end);
    final nTurn = (n1 + n2) / (n1 + n2).distance;
    return Path()
      ..moveTo((start + n1 * down).dx, (start + n1 * down).dy)
      ..lineTo((turn + nTurn * up * 1.2).dx, (turn + nTurn * up * 1.2).dy)
      ..lineTo((end + n2 * up).dx, (end + n2 * up).dy)
      ..lineTo((end - n2 * up).dx, (end - n2 * up).dy)
      ..lineTo((turn - nTurn * up * 0.9).dx, (turn - nTurn * up * 0.9).dy)
      ..lineTo((start - n1 * down).dx, (start - n1 * down).dy)
      ..close();
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.wax != wax || old.tick != tick || old.cast != cast;
}
