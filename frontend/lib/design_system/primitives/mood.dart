import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The light a game screen stands in. Night is deep indigo with one cool
/// moon pool and a strong vignette; dawn the same dark board with a warm
/// lantern pooling on it; day a low golden sun in a long soft light, never a
/// flat lilac field.
enum MoodKind { night, dawn, day }

/// The ground and the light of a phase, laid under the play surface of every
/// screen (`ScreenFrame` does it, so no screen asks): a ground, the village's
/// roofs cut in paper continuing behind the rows and cards, dimmed, a light and
/// the vignette that keeps the eye on the evidence. The whole is one picture, painted once and
/// kept (a repaint boundary, no animation, no layer saved), so it costs
/// nothing per frame. Text keeps its contrast on every pixel of it
/// (`mood_contrast_test.dart`).
class Mood extends StatelessWidget {
  const Mood({super.key, required this.kind});

  final MoodKind kind;

  /// How much of a quiet strip's fill shows (the night board's strip of
  /// centre cards): the village behind it shows through the rest.
  static const panelShow = 0.62;

  /// The recipe by phase (mood recipe of the designers' round 2 sheet).
  ///
  /// Night: a ground of `#0b0d20` over the ground, a moon pool of
  /// `rgba(220, 226, 255, .10)` fading by 60% and a vignette of
  /// `rgba(3, 4, 12, .62)` from 50%.
  static const nightBase = Color(0xFF14172F);
  static const moon = Color(0xFFDCE2FF);
  static const moonAlpha = 0.10;
  static const vignetteInk = Color(0xFF03040C);
  static const nightVignette = 0.62;

  /// Dawn: the lantern's `rgba(255, 200, 130, .14)` pooling low on the board.
  static const lantern = Color(0xFFFFC882);
  static const lanternAlpha = 0.14;

  /// Day: a pale sky over a golden foot, the sun low and warm, a soft vignette
  /// in a warm plum that stays above the reading floor's luminance.
  static const daySky = Color(0xFFD9D4EA);
  static const dayMid = Color(0xFFECD5C2);
  static const dayFoot = Color(0xFFF2C98C);
  static const sun = Color(0xFFFFE2A8);
  static const dayVignetteInk = Color(0xFF7A6488);
  static const dayVignette = 0.14;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _GroundPainter(kind)),
            CustomPaint(painter: _SkylinePainter(kind)),
            CustomPaint(painter: _LightPainter(kind)),
          ],
        ),
      ),
    );
  }
}

/// A radial light of [colors] over an ellipse [rx] wide and [ry] tall (in
/// pixels, a radius each), centred at [at] of the screen.
void _pool(
  Canvas canvas,
  Size size, {
  required Alignment at,
  required double rx,
  required double ry,
  required List<Color> colors,
  required List<double> stops,
  BlendMode blend = BlendMode.srcOver,
}) {
  final centre = at.alongSize(size);
  final squash = ry / rx;
  canvas
    ..save()
    ..translate(centre.dx, centre.dy)
    ..scale(1, squash);
  canvas.drawRect(
    Rect.fromLTRB(
      -centre.dx,
      -centre.dy / squash,
      size.width - centre.dx,
      (size.height - centre.dy) / squash,
    ),
    Paint()
      ..shader = RadialGradient(
        colors: colors,
        stops: stops,
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: rx))
      ..blendMode = blend,
  );
  canvas.restore();
}

class _GroundPainter extends CustomPainter {
  const _GroundPainter(this.kind);

  final MoodKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint();
    switch (kind) {
      case MoodKind.night || MoodKind.dawn:
        paint.color = Mood.nightBase;
      case MoodKind.day:
        paint.shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Mood.daySky, Mood.dayMid, Mood.dayFoot],
          stops: [0, 0.55, 1],
        ).createShader(rect);
    }
    canvas.drawRect(rect, paint);
    if (kind == MoodKind.dawn) {
      // The lantern pools on the board behind the roofs, which stand dark
      // against it.
      _pool(
        canvas,
        size,
        at: const Alignment(0, 0.25),
        rx: size.width * 0.9,
        ry: size.height * 0.5,
        colors: [
          Mood.lantern.withValues(alpha: Mood.lanternAlpha),
          Mood.lantern.withValues(alpha: Mood.lanternAlpha / 2),
          Mood.lantern.withValues(alpha: 0),
        ],
        stops: const [0, 0.5, 1],
        blend: BlendMode.screen,
      );
    }
  }

  @override
  bool shouldRepaint(_GroundPainter old) => old.kind != kind;
}

/// Three banks of cut-paper roofs along the foot of the screen, far to near,
/// each darker and taller than the one behind (night and dawn), or a sheer
/// haze of the same in the day: seeded, so every phone cuts the same village,
///. No lit windows: a window's glow behind a word would break its contrast.
class _SkylinePainter extends CustomPainter {
  const _SkylinePainter(this.kind);

  final MoodKind kind;

  static const _seed = 31;

  /// Each bank: where its roofs' feet are (of the height), the tallest roof
  /// (of the height) and the colour, far first.
  static const _banks = [
    (foot: 0.80, tall: 0.12, night: Color(0xFF262E58), day: Color(0xFFE7D2C4)),
    (foot: 0.88, tall: 0.10, night: Color(0xFF1E2448), day: Color(0xFFE3C9B8)),
    (foot: 0.96, tall: 0.08, night: Color(0xFF141830), day: Color(0xFFE0C2AE)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final random = math.Random(_seed);
    final night = kind != MoodKind.day;
    for (var b = 0; b < _banks.length; b++) {
      final bank = _banks[b];
      final foot = h * bank.foot;
      final path = Path()..moveTo(0, h);
      var x = -random.nextDouble() * 20;
      path.lineTo(x, foot);
      while (x < w) {
        final width = 26 + random.nextDouble() * 38;
        final wall = foot - h * bank.tall * (0.25 + random.nextDouble() * 0.5);
        final peak = wall - width * (0.35 + random.nextDouble() * 0.45);
        final lean = (random.nextDouble() - 0.5) * width * 0.3;
        path
          ..lineTo(x, wall)
          ..lineTo(x + width / 2 + lean, peak)
          ..lineTo(x + width, wall)
          ..lineTo(x + width, foot);
        // A chimney now and then, a spire on the far bank.
        if (random.nextDouble() < 0.3) {
          path
            ..lineTo(x + width * 0.78, wall)
            ..lineTo(x + width * 0.78, peak - 6)
            ..lineTo(x + width * 0.78 - 6, peak - 6)
            ..lineTo(x + width * 0.78 - 6, wall + 2)
            ..lineTo(x + width, wall + 2)
            ..lineTo(x + width, foot);
        }
        if (b == 0 && random.nextDouble() < 0.12) {
          path
            ..lineTo(x + width * 0.4, foot)
            ..lineTo(x + width * 0.4, wall - h * 0.06)
            ..lineTo(x + width * 0.5, wall - h * 0.16)
            ..lineTo(x + width * 0.6, wall - h * 0.06)
            ..lineTo(x + width * 0.6, foot);
        }
        x += width;
      }
      path
        ..lineTo(w, foot)
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = night ? bank.night : bank.day);
    }
  }

  @override
  bool shouldRepaint(_SkylinePainter old) => old.kind != kind;
}

class _LightPainter extends CustomPainter {
  const _LightPainter(this.kind);

  final MoodKind kind;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    switch (kind) {
      case MoodKind.night:
        _pool(
          canvas,
          size,
          at: const Alignment(0.45, -0.62),
          rx: w * 0.85,
          ry: w * 0.98,
          colors: [
            Mood.moon.withValues(alpha: Mood.moonAlpha),
            Mood.moon.withValues(alpha: Mood.moonAlpha / 3),
            Mood.moon.withValues(alpha: 0),
          ],
          stops: const [0, 0.6, 1],
          blend: BlendMode.screen,
        );
        _vignette(canvas, size, Mood.vignetteInk, Mood.nightVignette);
      case MoodKind.dawn:
        _vignette(canvas, size, Mood.vignetteInk, Mood.nightVignette * 0.9);
      case MoodKind.day:
        // The sun, low and a little to one side, its light long and soft.
        _pool(
          canvas,
          size,
          at: const Alignment(0.55, 0.78),
          rx: w * 1.05,
          ry: h * 0.5,
          colors: [
            Mood.sun.withValues(alpha: 0.85),
            Mood.sun.withValues(alpha: 0.28),
            Mood.sun.withValues(alpha: 0),
          ],
          stops: const [0, 0.55, 1],
        );
        _vignette(canvas, size, Mood.dayVignetteInk, Mood.dayVignette);
    }
  }

  /// `radial-gradient(130% 95% at 50% 42%, transparent 50%, ink)`.
  void _vignette(Canvas canvas, Size size, Color ink, double alpha) {
    _pool(
      canvas,
      size,
      at: const Alignment(0, -0.16),
      rx: size.width * 0.9,
      ry: size.height * 0.7,
      colors: [
        ink.withValues(alpha: 0),
        ink.withValues(alpha: 0),
        ink.withValues(alpha: alpha),
      ],
      stops: const [0, 0.5, 1],
    );
  }

  @override
  bool shouldRepaint(_LightPainter old) => old.kind != kind;
}
