import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../skin/skin.dart';

/// The night's clock as a candle drawn in cut paper: a bone stick on a dish
/// with its hard shadow, and a flame. As the window runs out the flame
/// shrinks and the wax burns down; with [share] 1 it is whole, at 0 a short
/// stub with a small flame (it never goes out: the server says when the
/// window ends).
///
/// It is a gauge, never the only carrier of the time (the seconds stand
/// beside it), and it only ever steps: [share] comes from the whole seconds
/// left ([StageShare.left]), so the picture changes once a second with the
/// number, with no tween, no flicker and no sway. A null [share] (the server
/// did not say how long the window is) shows the candle whole.
class CandleGauge extends StatelessWidget {
  const CandleGauge({super.key, required this.share, this.height = tallest});

  /// How much of the window is left, 0 to 1; null shows it whole.
  final double? share;

  /// The candle's height; its width follows ([aspect]).
  final double height;

  /// Width over height.
  static const aspect = 0.42;

  /// The height it is drawn at when nothing says otherwise.
  static const tallest = 64.0;

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

  @override
  Widget build(BuildContext context) {
    final ground = context.ground;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(height * aspect, height),
        painter: _CandlePainter(
          share: share,
          wax: ground.paper,
          waxShade: ground.paperEdge,
          dish: ground.quietText,
          flame: ground.accent,
          core: ground.paper,
          shadow: ground.shadow,
        ),
      ),
    );
  }
}

class _CandlePainter extends CustomPainter {
  const _CandlePainter({
    required this.share,
    required this.wax,
    required this.waxShade,
    required this.dish,
    required this.flame,
    required this.core,
    required this.shadow,
  });

  final double? share;
  final Color wax;
  final Color waxShade;
  final Color dish;
  final Color flame;
  final Color core;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 26 x 64 sheet, scaled to the box.
    const sheet = Size(26, 64);
    final scale = math.min(
      size.width / sheet.width,
      size.height / sheet.height,
    );
    canvas
      ..translate((size.width - sheet.width * scale) / 2, 0)
      ..scale(scale);

    final cx = sheet.width / 2;
    const dishTop = 58.0;
    const waxWidth = 14.0;
    const waxFull = 28.0;
    final waxHeight = waxFull * CandleGauge.waxScale(share);
    final waxTop = dishTop - waxHeight;
    final stick = RRect.fromLTRBR(
      cx - waxWidth / 2,
      waxTop,
      cx + waxWidth / 2,
      dishTop + 1,
      const Radius.circular(1.5),
    );
    final plate = RRect.fromLTRBR(
      2,
      dishTop,
      sheet.width - 2,
      sheet.height,
      const Radius.circular(2),
    );

    // The paper's hard shadow: offset copies, never blurred.
    final shade = Paint()..color = shadow;
    canvas
      ..drawRRect(plate.shift(const Offset(1.5, 1.5)), shade)
      ..drawRRect(stick.shift(const Offset(2, 1.5)), shade)
      // The dish, the stick and the shaded side of the stick.
      ..drawRRect(plate, Paint()..color = dish)
      ..drawRRect(stick, Paint()..color = wax)
      ..save()
      ..clipRRect(stick)
      ..drawRect(
        Rect.fromLTRB(cx + waxWidth * 0.18, waxTop, cx + waxWidth / 2, dishTop),
        Paint()..color = waxShade,
      )
      ..restore();

    // The wick, then the flame growing from its tip.
    const wick = 4.0;
    final wickTop = waxTop - wick;
    canvas.drawLine(
      Offset(cx, waxTop),
      Offset(cx, wickTop),
      Paint()
        ..color = waxShade
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
    final whole = wickTop + 2;
    final height = 24.0 * CandleGauge.flameScale(share);
    canvas
      ..drawPath(
        _drop(cx, whole - height, height, whole),
        Paint()..color = flame,
      )
      ..drawPath(
        _drop(cx, whole - height * 0.55, height * 0.55, whole - 0.5),
        Paint()..color = core,
      );
  }

  /// A teardrop from [top] down to [base], its width 0.46 of its height.
  Path _drop(double cx, double top, double height, double base) {
    final w = height * 0.46;
    return Path()
      ..moveTo(cx, top)
      ..quadraticBezierTo(
        cx + w * 0.62,
        top + height * 0.55,
        cx + w * 0.5,
        top + height * 0.8,
      )
      ..quadraticBezierTo(cx + w * 0.42, base, cx, base)
      ..quadraticBezierTo(cx - w * 0.42, base, cx - w * 0.5, top + height * 0.8)
      ..quadraticBezierTo(cx - w * 0.62, top + height * 0.55, cx, top)
      ..close();
  }

  @override
  bool shouldRepaint(_CandlePainter old) =>
      old.share != share ||
      old.wax != wax ||
      old.waxShade != waxShade ||
      old.dish != dish ||
      old.flame != flame ||
      old.core != core ||
      old.shadow != shadow;
}
