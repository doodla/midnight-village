import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'paper_light.dart';

import '../feel/atmo.dart';
import '../feel/atmo_parts.dart';

import '../skin/art_set.dart';
import '../skin/dress.dart';
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

  /// How the candle burns: the share of the window left, raised to this, so
  /// it is slow at first and steeper toward the end, where the last seconds
  /// must show (on a 30 s window the last five take the wax down by a fifth
  /// of the stick).
  static const burnCurve = 0.6;

  /// The burning that is left, 0 to 1, for [share].
  static double left(double? share) =>
      math.pow((share ?? 1).clamp(0.0, 1.0), burnCurve).toDouble();

  /// The flame's size for [share] (a step, never a tween).
  static double flameScale(double? share) =>
      lowFlame + (1 - lowFlame) * left(share);

  /// The wax's height, of the whole stick's, for [share].
  static double waxScale(double? share) => lowWax + (1 - lowWax) * left(share);

  /// A candle this high gets a hard shadow [shadowReach] logical pixels long,
  /// more on a taller one and less on a shorter, between the two bounds.
  static const referenceHeight = 90.0;
  static const shadowReach = 1.5;
  static const shadowReachMost = 1.6;
  static const shadowReachLeast = 0.8;

  /// The warm light behind the flame: its radius in flame widths (a base and
  /// what the flame adds), how high up the flame it centres, and how strong
  /// it is at its centre, halfway and at its edge.
  static const glowRadiusBase = 0.9;
  static const glowRadiusGrow = 0.7;
  static const glowRise = 0.45;
  static const glowAlphas = [0.3, 0.1, 0.0];
  static const glowStops = [0.0, 0.45, 1.0];

  /// The dark nook the candle stands in, in the village: it quiets whatever
  /// the picture draws behind the stick (a chimney would read as a ghost of
  /// the wax once it burns down). Its radius in candle widths, where on the
  /// stick it centres (0 the top, 1 the foot) and how dark it is at its
  /// centre.
  static const nookRadius = 1.05;
  static const nookCentre = 0.3;
  static const nookAlpha = 0.85;

  /// The ledge: how high it is (a share of the candle's height, held between
  /// the bounds) and how far it reaches out of the candle's width on each
  /// side.
  static const ledgeShare = 1 / 20;
  static const ledgeLeast = 4.0;
  static const ledgeMost = 7.0;
  static const ledgeReachLeft = 0.04;
  static const ledgeReachRight = 0.0;

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
    final shadowOffset =
        shadowReach *
        (height / referenceHeight).clamp(shadowReachLeast, shadowReachMost);
    final flameBase = at(cut.wick + Offset(0, drop));
    final flameSize = cut.flame.size * scale;

    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // A dark nook in the village behind the stick, then a little warm
            // light on what is behind the flame.
            Positioned.fill(
              child: Ambient(
                effect: AtmoEffect.flame,
                restFor: (t) => AtmoFlame.restFor(t, share),
                builder: (context, t, _) => CustomPaint(
                  painter: _GlowPainter(
                    nook: at(
                      Offset(
                        cut.wick.dx,
                        cut.stickTop +
                            nookCentre * (cut.stickBottom - cut.stickTop),
                      ),
                    ),
                    nookRadius: nookRadius * width,
                    nookColour: ground.ground,
                    centre:
                        flameBase -
                        Offset(0, flameSize.height * fire * glowRise),
                    radius:
                        flameSize.width *
                        (glowRadiusBase + glowRadiusGrow * fire) *
                        (0.92 + 0.08 * flameLight(t)),
                    colour: cut.light.withValues(
                      alpha: (cut.light.a * flameLight(t)).clamp(0.0, 1.0),
                    ),
                  ),
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
                child: AtmoFlame(share: share, child: picture(cut.flame)),
              ),
            ),
            if (AtmoCandleAir.any)
              Positioned(
                left: flameBase.dx - flameSize.height * 4,
                top: flameBase.dy - flameSize.height * 5,
                width: flameSize.height * 8,
                height: flameSize.height * 6,
                child: AtmoCandleAir(
                  flame: Offset(
                    flameSize.height * 4,
                    flameSize.height * (5 - 0.5 * fire),
                  ),
                  light: cut.light.withValues(alpha: 1),
                  flameHeight: flameSize.height,
                ),
              ),
            // The ledge it stands on, over the cut stem.
            Positioned(
              left: -width * ledgeReachLeft,
              right: -width * ledgeReachRight,
              bottom: -1,
              height: (height * ledgeShare).clamp(ledgeLeast, ledgeMost),
              child: DecoratedBox(
                key: const ValueKey(CandlePart.ledge),
                decoration: BoxDecoration(
                  color: ground.panel,
                  borderRadius: BorderRadius.circular(skin.shape.radiusTiny),
                  border: context.dress.isPaper
                      ? null
                      : Border(
                          top: BorderSide(color: ground.hairline, width: 1),
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: ground.shadow,
                      offset: Offset(PaperLight.of(context) * 2, 2),
                    ),
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
    required this.nook,
    required this.nookRadius,
    required this.nookColour,
    required this.centre,
    required this.radius,
    required this.colour,
  });

  final Offset nook;
  final double nookRadius;
  final Color nookColour;
  final Offset centre;
  final double radius;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawCircle(
        nook,
        nookRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              nookColour.withValues(alpha: CandleGauge.nookAlpha),
              nookColour.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: nook, radius: nookRadius)),
      )
      ..drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              for (final a in CandleGauge.glowAlphas)
                colour.withValues(alpha: a),
            ],
            stops: CandleGauge.glowStops,
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.nook != nook ||
      old.nookRadius != nookRadius ||
      old.nookColour != nookColour ||
      old.centre != centre ||
      old.radius != radius ||
      old.colour != colour;
}
