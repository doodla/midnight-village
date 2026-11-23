import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../skin/dress.dart';
import '../skin/end_art.dart';
import '../skin/skin.dart';
import 'art_picture.dart';

/// The end board's one light, as an object: the paper lantern hung from the
/// board's top right (the picture turned round, [EndArt.lanternSize] drawn),
/// lit, with its warm glow spilling round it ([glow] across, laid on with the
/// screen blend). The light's own point, for [OneLight], is the centre of its
/// panes (`OneLight.lantern(box)`). Unlit (`lit: false`, while the night is
/// replayed and the moon is the light) it is the same lantern with no glow.
/// Plain, it is the picture alone.
class EndLantern extends StatelessWidget {
  const EndLantern({super.key, this.lit = true});

  final bool lit;

  /// How wide the glow is.
  static const glow = 180.0;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final size = EndArt.lanternSize;
    final light = Offset(
      EndArt.lanternLight.dx * size.width,
      EndArt.lanternLight.dy * size.height,
    );
    return ExcludeSemantics(
      child: IgnorePointer(
        child: SizedBox.fromSize(
          size: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (lit && context.dress.isPaper)
                Positioned(
                  left: light.dx - glow / 2,
                  top: light.dy - glow / 2,
                  width: glow,
                  height: glow,
                  child: CustomPaint(
                    painter: _GlowPainter(
                      color: skin.mood.lantern,
                      alpha: skin.parts.lanternGlowAlpha,
                    ),
                  ),
                ),
              Positioned.fill(
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),
                  child: ArtPicture(skin.art.end.piece(EndPiece.lantern)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A radial warm glow, laid on with the screen blend (it only ever lightens).
class _GlowPainter extends CustomPainter {
  const _GlowPainter({required this.color, required this.alpha});

  final Color color;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.4),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      color != old.color || alpha != old.alpha;
}
