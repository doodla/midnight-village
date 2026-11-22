import 'package:flutter/material.dart';

import '../skin/art_set.dart';
import '../skin/skin.dart';

/// The parts of the candle, the keys tests find them by.
enum CandlePart { wax, holder, flame, ledge }

/// The night's clock as a candle in cut paper: the art's own stick with its
/// red drips, flame and iron holder (`CandleArt`, cut from the candle
/// picture), each with a hard shadow, on a small ledge, with a little warm
/// light on what is behind the flame. As the window runs out the wax burns
/// down into the holder and the flame shrinks; with [share] 1 it is whole, at
/// 0 a short stub with a small flame (it never goes out: the server says when
/// the window ends).
///
/// It is a gauge, never the only carrier of the time (the seconds stand
/// beside it), and it only ever steps: [share] comes from the whole seconds
/// left ([StageShare.left]), so the picture changes once a second with the
/// number, with no tween, no flicker and no sway. A null [share] (the server
/// did not say how long the window is) shows the candle whole.
class CandleGauge extends StatelessWidget {
  const CandleGauge({super.key, required this.share, required this.height});

  /// How much of the window is left, 0 to 1; null shows it whole.
  final double? share;

  /// The candle's height, flame to ledge; its width follows the picture.
  final double height;

  /// The flame at the end of the window, as a share of the whole flame.
  static const lowFlame = 0.4;

  /// The wax at the end of the window, as a share of the whole stick.
  static const lowWax = 0.3;

  /// The flame's size for [share] (a step, never a tween).
  static double flameScale(double? share) =>
      lowFlame + (1 - lowFlame) * (share ?? 1).clamp(0.0, 1.0);

  /// The wax's height, of the whole stick's, for [share].
  static double waxScale(double? share) =>
      lowWax + (1 - lowWax) * (share ?? 1).clamp(0.0, 1.0);

  /// The width of a candle [height] high.
  static double widthFor(CandleArt art, double height) =>
      height * art.view.width / art.view.height;

  /// Decodes the candle's cuts for a candle [height] high, so the first frame
  /// of the board finds them. Not awaited.
  static void precache(BuildContext context, double height) {
    final art = context.skin.art;
    final scale = height / art.candleCut.view.height;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    for (final cut in [
      art.candleCut.wax,
      art.candleCut.flame,
      art.candleCut.holder,
    ]) {
      precacheImage(
        art.candleSprite(cut).decodedFor(cut.size * scale, ratio),
        context,
        onError: (_, _) {},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final art = skin.art;
    final cut = art.candleCut;
    final scale = height / cut.view.height;
    final width = widthFor(cut, height);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final fire = flameScale(share);
    // How far the wax has burned down, in pixels of the canvas.
    final drop = (1 - waxScale(share)) * (cut.stickBottom - cut.stickTop);

    Offset at(Offset canvas) => (canvas - cut.view.topLeft) * scale;

    Widget picture(CandleCut c, {Key? key, Color? shadow}) {
      final image = Image(
        key: key,
        image: art.candleSprite(c).decodedFor(c.size * scale, ratio),
        width: c.size.width * scale,
        height: c.size.height * scale,
        fit: BoxFit.fill,
        gaplessPlayback: true,
        excludeFromSemantics: true,
      );
      if (shadow == null) return image;
      return ColorFiltered(
        colorFilter: ColorFilter.mode(shadow, BlendMode.srcIn),
        child: image,
      );
    }

    Widget placed(CandleCut c, Widget child, {double dy = 0, double dx = 0}) {
      final top = at(c.at + Offset(0, dy));
      return Positioned(left: top.dx + dx, top: top.dy + dx, child: child);
    }

    // The foot of the stick, where the holder's dish takes over: below it
    // the burning-down stick is not drawn.
    final clipBottom = (cut.stickBottom - cut.view.top) * scale;
    final shadowOffset = 1.5 * (height / 90).clamp(0.8, 1.6);
    final flameBase = at(cut.wick + Offset(0, drop));
    final flameSize = cut.flame.size * scale;

    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // A little warm light on what is behind the flame.
            Positioned.fill(
              child: CustomPaint(
                painter: _GlowPainter(
                  centre: flameBase - Offset(0, flameSize.height * fire * 0.45),
                  radius: flameSize.width * (0.9 + 0.7 * fire),
                  colour: ground.accent,
                ),
              ),
            ),
            // Hard shadows: the holder's and the stick's silhouettes, offset.
            placed(
              cut.holder,
              picture(cut.holder, shadow: ground.shadow),
              dx: shadowOffset,
            ),
            Positioned.fill(
              child: ClipRect(
                clipper: _AboveRow(clipBottom + shadowOffset),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    placed(
                      cut.wax,
                      picture(cut.wax, shadow: ground.shadow),
                      dy: drop,
                      dx: shadowOffset,
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: ClipRect(
                clipper: _AboveRow(clipBottom),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    placed(
                      cut.wax,
                      picture(cut.wax, key: const ValueKey(CandlePart.wax)),
                      dy: drop,
                    ),
                  ],
                ),
              ),
            ),
            placed(
              cut.holder,
              picture(cut.holder, key: const ValueKey(CandlePart.holder)),
            ),
            // The flame stands on the wick, shrinking about its foot.
            Positioned(
              left: flameBase.dx - flameSize.width / 2,
              top: flameBase.dy - flameSize.height,
              child: Transform.scale(
                key: const ValueKey(CandlePart.flame),
                scale: fire,
                alignment: Alignment.bottomCenter,
                child: picture(cut.flame),
              ),
            ),
            // The ledge it stands on, over the cut stem.
            Positioned(
              left: -width * 0.04,
              right: -width * 0.1,
              bottom: -1,
              height: (height / 20).clamp(4.0, 7.0),
              child: DecoratedBox(
                key: const ValueKey(CandlePart.ledge),
                decoration: BoxDecoration(
                  color: ground.panel,
                  borderRadius: BorderRadius.circular(skin.shape.radiusTiny),
                  border: Border(
                    top: BorderSide(color: ground.hairline, width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(color: ground.shadow, offset: const Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The picture above [bottom] only (a stick burnt down into its holder is
/// not drawn below the dish).
class _AboveRow extends CustomClipper<Rect> {
  const _AboveRow(this.bottom);

  final double bottom;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-size.width, -size.height, size.width * 2, bottom);

  @override
  bool shouldReclip(_AboveRow old) => old.bottom != bottom;
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter({
    required this.centre,
    required this.radius,
    required this.colour,
  });

  final Offset centre;
  final double radius;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            colour.withValues(alpha: 0.3),
            colour.withValues(alpha: 0.1),
            colour.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.centre != centre || old.radius != radius || old.colour != colour;
}
