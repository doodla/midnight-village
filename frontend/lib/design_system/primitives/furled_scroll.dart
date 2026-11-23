import 'package:flutter/widgets.dart';

import '../skin/dress.dart';
import '../skin/skin.dart';

/// The end board's banner before it unrolls: a roll of bone paper lying
/// across, its curl showing at each end, tied twice with twine, and a soft
/// shadow under it. Drawn in code from the skin's colours (no new art). The
/// roll is the paper's back, so it is bone whatever the banner will say.
/// Plain, it draws nothing (the end board is paper only).
class FurledScroll extends StatelessWidget {
  const FurledScroll({super.key, required this.width});

  final double width;

  /// How thick the roll is.
  static const thickness = 18.0;

  /// Where its two ties are, a share of its length from the left.
  static const ties = [0.3, 0.7];

  /// How wide a tie is.
  static const tieWidth = 3.0;

  @override
  Widget build(BuildContext context) {
    final size = Size(width, thickness);
    if (!context.dress.isPaper) return SizedBox.fromSize(size: size);
    final skin = context.skin;
    return ExcludeSemantics(
      child: CustomPaint(
        size: size,
        painter: _RollPainter(
          paper: skin.paper.paper,
          shade: skin.parts.boardShade,
          twine: skin.paper.text,
          shadow: context.ground.shadow,
        ),
      ),
    );
  }
}

class _RollPainter extends CustomPainter {
  const _RollPainter({
    required this.paper,
    required this.shade,
    required this.twine,
    required this.shadow,
  });

  final Color paper;
  final Color shade;
  final Color twine;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final body = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.elliptical(h * 0.35, h / 2),
    );
    // The shadow it throws on the roof.
    canvas.drawRRect(
      body.shift(Offset(0, h * 0.3)),
      Paint()
        ..color = shadow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.25),
    );
    // The roll: lit along its top, in its own shade under.
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            paper,
            Color.lerp(paper, shade, 0.12)!,
            Color.lerp(paper, shade, 0.4)!,
          ],
          stops: const [0.15, 0.55, 1],
        ).createShader(Offset.zero & size),
    );
    // The curl at each end: the paper's edge seen end on.
    // (Filled shapes, as paper is cut: a darker oval with the paper's own
    // inside it.)
    for (final x in [h * 0.35, size.width - h * 0.35]) {
      final outer = Rect.fromCenter(
        center: Offset(x, h / 2),
        width: h * 0.4,
        height: h * 0.8,
      );
      canvas
        ..drawOval(outer, Paint()..color = Color.lerp(paper, shade, 0.45)!)
        ..drawOval(
          outer.deflate(h * 0.08),
          Paint()..color = Color.lerp(paper, shade, 0.15)!,
        );
    }
    // Two ties of twine round it, as bands.
    final tie = Paint()..color = twine;
    for (final at in FurledScroll.ties) {
      final x = size.width * at;
      canvas.drawRect(
        Rect.fromLTRB(
          x - FurledScroll.tieWidth / 2,
          -h * 0.04,
          x + FurledScroll.tieWidth / 2,
          h * 1.04,
        ),
        tie,
      );
    }
  }

  @override
  bool shouldRepaint(_RollPainter old) =>
      paper != old.paper ||
      shade != old.shade ||
      twine != old.twine ||
      shadow != old.shadow;
}
