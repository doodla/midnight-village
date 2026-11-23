import 'package:flutter/material.dart';

import '../skin/skin.dart';
import '../skin/dress.dart';

/// A small cut-paper lantern, the village's own light (the one in the door's
/// window in 01, the candle of the night): a paper body with ribs, a dark
/// cap and foot, a hard paper shadow, and a warm glow inside that is [lit]
/// from 0 (out, the paper alone) to 1 (burning). The glow is the lantern
/// amber of the ground (`Ground.accent`): art, never a fill of the screen's
/// own. Hung on a cord of [cord] px from whatever is above it.
class PaperLantern extends StatelessWidget {
  const PaperLantern({
    super.key,
    required this.width,
    required this.lit,
    this.cord = 0,
  });

  /// The body's width; the lantern is [heightFor] it tall, cord included.
  final double width;

  /// How brightly it burns, 0 to 1.
  final double lit;

  /// The cord it hangs on, above the cap.
  final double cord;

  /// The body's height for a [width].
  static double bodyHeight(double width) => width * 1.45;

  /// The whole height for a [width] and a [cord].
  static double heightFor(double width, double cord) =>
      cord + bodyHeight(width) + capHeight(width) * 2;

  static double capHeight(double width) => width * 0.18;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    return CustomPaint(
      size: Size(width, heightFor(width, cord)),
      painter: _LanternPainter(
        cord: cord,
        lit: lit.clamp(0, 1),
        paper: ground.paper,
        rib: ground.hairline,
        cap: ground.paperEdge,
        ink: ground.outline,
        shadow: ground.shadow,
        glow: ground.accent,
        stroke: skin.shape.stroke,
        cut: context.dress.isPaper,
      ),
    );
  }
}

class _LanternPainter extends CustomPainter {
  _LanternPainter({
    required this.cord,
    required this.lit,
    required this.paper,
    required this.rib,
    required this.cap,
    required this.ink,
    required this.shadow,
    required this.glow,
    required this.stroke,
    this.cut = false,
  });

  /// Dressed up: every part is a filled shape of paper (the cord a thin strip,
  /// the ribs slivers), no stroke and no outline.
  final bool cut;
  final double cord;
  final double lit;
  final Color paper;
  final Color rib;
  final Color cap;
  final Color ink;
  final Color shadow;
  final Color glow;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final capH = PaperLantern.capHeight(w);
    final bodyH = PaperLantern.bodyHeight(w);
    final cx = w / 2;
    final bodyTop = cord + capH;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.04, bodyTop, w * 0.92, bodyH),
      Radius.circular(w * 0.34),
    );

    // The cord, up to what it hangs from.
    if (cut) {
      canvas.drawRect(
        Rect.fromLTRB(cx - stroke * 0.4, 0, cx + stroke * 0.4, bodyTop),
        Paint()..color = ink,
      );
    } else {
      canvas.drawLine(
        Offset(cx, 0),
        Offset(cx, bodyTop),
        Paint()
          ..color = ink
          ..strokeWidth = stroke * 0.8,
      );
    }

    // The glow in the air round it, then the hard paper shadow.
    if (lit > 0) {
      final halo = Rect.fromCircle(center: body.center, radius: w * 1.25);
      canvas.drawCircle(
        body.center,
        w * 1.25,
        Paint()
          ..shader = RadialGradient(
            colors: [
              glow.withValues(alpha: 0.34 * lit),
              glow.withValues(alpha: 0),
            ],
          ).createShader(halo),
      );
    }
    canvas.drawRRect(
      body.shift(Offset(w * 0.07, w * 0.09)),
      Paint()..color = shadow,
    );

    // The paper body, lit from inside.
    canvas.drawRRect(body, Paint()..color = paper);
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(
      body.outerRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glow.withValues(alpha: 0.95 * lit),
            glow.withValues(alpha: 0.55 * lit),
            glow.withValues(alpha: 0.08 * lit),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(body.outerRect),
    );
    // The ribs of the paper.
    final ribs = Paint()
      ..color = rib
      ..strokeWidth = stroke * 0.6
      ..style = PaintingStyle.stroke;
    for (final k in [-0.24, 0.0, 0.24]) {
      final x = cx + w * k;
      final top = cx + (x - cx) * 0.35;
      final bow = cx + (x - cx) * 1.5;
      if (cut) {
        // A sliver of darker paper: two curves a rib's width apart, filled.
        final half = stroke * 0.3;
        canvas.drawPath(
          Path()
            ..moveTo(top - half, bodyTop)
            ..quadraticBezierTo(
              bow - half,
              bodyTop + bodyH / 2,
              top - half,
              bodyTop + bodyH,
            )
            ..lineTo(top + half, bodyTop + bodyH)
            ..quadraticBezierTo(
              bow + half,
              bodyTop + bodyH / 2,
              top + half,
              bodyTop,
            )
            ..close(),
          Paint()..color = rib,
        );
        continue;
      }
      canvas.drawPath(
        Path()
          ..moveTo(top, bodyTop)
          ..quadraticBezierTo(bow, bodyTop + bodyH / 2, top, bodyTop + bodyH),
        ribs,
      );
    }
    canvas.restore();
    if (!cut) {
      canvas.drawRRect(
        body,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 0.8,
      );
    }

    // The cap and the foot.
    final capPaint = Paint()..color = cap;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.24, cord, w * 0.52, capH),
        Radius.circular(capH * 0.4),
      ),
      capPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.24, bodyTop + bodyH, w * 0.52, capH),
        Radius.circular(capH * 0.4),
      ),
      capPaint,
    );
  }

  @override
  bool shouldRepaint(_LanternPainter old) =>
      old.lit != lit ||
      old.cord != cord ||
      old.paper != paper ||
      old.glow != glow ||
      old.ink != ink ||
      old.cut != cut;
}

/// The mark beside a button's words while its tap is on its way: a small
/// lantern in the label's own ink, its flame breathing; a button that is
/// busy also sinks into its shadow (`PrimaryButton`). It sits where it does
/// not move the words (the buttons lay it in their own padding). With reduce
/// motion the flame burns steadily.
class LanternMark extends StatefulWidget {
  const LanternMark({super.key, required this.size, this.color});

  /// The lantern's height.
  final double size;
  final Color? color;

  @override
  State<LanternMark> createState() => _LanternMarkState();
}

class _LanternMarkState extends State<LanternMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath.stop();
      _breath.value = 1;
    } else if (!_breath.isAnimating) {
      _breath.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.ground.text;
    final stroke = context.skin.shape.stroke;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _breath,
        builder: (context, _) => CustomPaint(
          size: Size(widget.size * 0.7, widget.size),
          painter: _MarkPainter(
            color: color,
            flame: 0.35 + 0.65 * _breath.value,
            stroke: stroke,
            cut: context.dress.isPaper,
            cast: context.ground.shadow,
          ),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({
    required this.color,
    required this.flame,
    required this.stroke,
    this.cut = false,
    this.cast = const Color(0x00000000),
  });

  final Color color;
  final double flame;
  final double stroke;

  /// Dressed up: a lantern cut from paper (cap, body and foot filled, the
  /// flame a hole through it that breathes) with a small shadow, no outline.
  final bool cut;
  final Color cast;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (cut) return _paintCut(canvas, w, h);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    // Cap, body and foot.
    canvas.drawLine(
      Offset(w * 0.25, stroke / 2),
      Offset(w * 0.75, stroke / 2),
      line,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(stroke / 2, h * 0.14, w - stroke, h * 0.72),
        Radius.circular(w * 0.4),
      ),
      line,
    );
    canvas.drawLine(
      Offset(w * 0.25, h - stroke / 2),
      Offset(w * 0.75, h - stroke / 2),
      line,
    );
    // The flame.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.52),
        width: w * 0.3,
        height: h * 0.36,
      ),
      Paint()..color = color.withValues(alpha: flame),
    );
  }

  void _paintCut(Canvas canvas, double w, double h) {
    final cap = h * 0.1;
    final shape = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.25, 0, w * 0.5, cap),
          Radius.circular(cap * 0.4),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, h * 0.14, w, h * 0.72),
          Radius.circular(w * 0.4),
        ),
      )
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.25, h - cap, w * 0.5, cap),
          Radius.circular(cap * 0.4),
        ),
      );
    // The flame is a hole through the paper, as large as it burns.
    final hole = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset(w / 2, h * 0.52),
          width: w * 0.34 * flame,
          height: h * 0.4 * flame,
        ),
      );
    final cutOut = Path.combine(PathOperation.difference, shape, hole);
    canvas
      ..drawPath(
        cutOut.shift(Offset(0, h * 0.06)),
        Paint()..color = cast.withValues(alpha: 0.4),
      )
      ..drawPath(cutOut, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.flame != flame || old.color != color || old.cut != cut;
}
