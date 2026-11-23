import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../skin/art_set.dart';
import 'layered_art.dart';

/// The light a game screen stands in. Night is deep indigo under the village,
/// one cool moon pool and a cone of it falling on the table, a heavy vignette;
/// lantern the same dark with a warm lantern pooling on what is lit; dawn the
/// dark board with a warm pool; day the village at dawn under a low golden
/// sun in a long light, never a flat lilac field.
enum MoodKind { night, lantern, dawn, day }

/// The ground and the light of a phase, laid under the play surface of every
/// screen (`ScreenFrame` does it, so no screen asks): a ground, the game's own
/// village (the layered art, at real strength in the top third and falling
/// into shadow below it), a light and the vignette that keeps the eye on the
/// evidence. The whole is a few image layers and two painters inside one
/// repaint boundary, painted once and kept (no animation, no layer saved), so
/// it costs nothing per frame. Text keeps its contrast on every pixel of it
/// (`mood_test.dart`); where a word has to sit over the picture it sits on a
/// paper backing, never on a dulled scene.
class Mood extends StatelessWidget {
  const Mood({
    super.key,
    required this.kind,
    this.scene = true,
    this.lightAt = const Alignment(0, 0.1),
  });

  final MoodKind kind;

  /// Whether the village stands behind (a screen with a picture of its own
  /// has no need of it).
  final bool scene;

  /// Where the lantern's warm pool lies ([MoodKind.lantern] and
  /// [MoodKind.dawn]).
  final Alignment lightAt;

  /// How much of a quiet strip's fill shows (the night board's strip of
  /// centre cards): the village behind it shows through the rest.
  static const panelShow = 0.62;

  /// Night: the ground the village falls into, a moon pool of
  /// `rgba(220, 226, 255, .22)` and a cone of it, a vignette of
  /// `rgba(3, 4, 12, .62)` from a third of the way out.
  static const nightBase = Color(0xFF0C0E22);
  static const moon = Color(0xFFDCE2FF);
  static const moonAlpha = 0.2;
  static const vignetteInk = Color(0xFF03040C);
  static const nightVignette = 0.6;

  /// How much of the night's own ground lies over the village at its top, and
  /// where it is whole (of the picture's height): the top third is lit, the
  /// rest falls into shadow.
  static const veilTop = 0.0;
  static const veilFrom = 0.30;
  static const veilFromAlpha = 0.22;
  static const veilMid = 0.62;
  static const veilMidAlpha = 0.74;

  /// The lantern's `rgba(255, 190, 110, .30)` pooling on what it lights.
  static const lantern = Color(0xFFFFBE6E);
  static const lanternAlpha = 0.26;

  /// Day: a pale sky over a golden foot, the sun low and warm on the left,
  /// a soft vignette in a warm plum that stays above the reading floor's
  /// luminance.
  static const daySky = Color(0xFFD6CCE6);
  static const dayMid = Color(0xFFF0D2BC);
  static const dayFoot = Color(0xFFF5C27A);
  static const sun = Color(0xFFFFD98E);
  static const dayVignetteInk = Color(0xFF8A6A88);
  static const dayVignette = 0.26;

  /// Which way paper's shadow leans on a screen of this light: away from it.
  static double leanOf(MoodKind kind) => switch (kind) {
    MoodKind.night => -0.45, // the moon high on the right
    MoodKind.lantern => 0.0, // a lantern overhead
    MoodKind.dawn => 0.0,
    MoodKind.day => 0.8, // a low sun on the left: long shadows to the right
  };

  /// The village's height for a screen [size].
  static double sceneHeight(MoodKind kind, Size size) => kind == MoodKind.day
      ? math.min(size.height * 0.40, size.width * 0.9)
      : math.min(size.height * 0.66, size.width * 4 / 3);

  /// How far above the screen's foot the day's village stands: its roofs and
  /// the low sun clear the progress line and the action under it, whose words
  /// stay on the plain gold.
  static const dayFootMargin = 0.0;

  @override
  Widget build(BuildContext context) {
    final art = switch (kind) {
      MoodKind.night || MoodKind.lantern => LayeredSceneId.nightVillage,
      MoodKind.day => LayeredSceneId.dawnGallows,
      MoodKind.dawn => null,
    };
    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _GroundPainter(kind)),
            if (scene && art != null)
              LayoutBuilder(
                builder: (context, box) {
                  final height = sceneHeight(kind, box.biggest);
                  return Align(
                    // The lantern's village stands at the foot, behind the
                    // lower half a table's content leaves; the others hang
                    // from the top.
                    alignment: kind == MoodKind.lantern || kind == MoodKind.day
                        ? Alignment.bottomCenter
                        : Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: kind == MoodKind.day ? Mood.dayFootMargin : 0,
                      ),
                      child: SizedBox(
                        height: height,
                        width: box.maxWidth,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            LayeredArt(art, travel: false),
                            DecoratedBox(
                              decoration: BoxDecoration(gradient: _veil(kind)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            CustomPaint(painter: _LightPainter(kind, lightAt, scene)),
          ],
        ),
      ),
    );
  }

  /// The ground laid over the picture, thin at the top and whole at its foot,
  /// so the village stands lit above and sinks into shadow below.
  static LinearGradient _veil(MoodKind kind) {
    if (kind == MoodKind.day) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFF2D3B6),
          Color(0xD9F0D2BC),
          Color(0x00F0D2BC),
          Color(0x00F0D2BC),
          Color(0xFFF2C98C),
          Color(0xFFF5C27A),
        ],
        stops: [0, 0.18, 0.38, 0.5, 0.66, 1],
      );
    }
    if (kind == MoodKind.lantern) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          nightBase,
          nightBase.withValues(alpha: 0.96),
          nightBase.withValues(alpha: 0.55),
          nightBase.withValues(alpha: 0.28),
          nightBase.withValues(alpha: 0.42),
        ],
        stops: const [0, 0.2, 0.36, 0.64, 1],
      );
    }
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        nightBase.withValues(alpha: veilTop),
        nightBase.withValues(alpha: veilFromAlpha),
        nightBase.withValues(alpha: veilMidAlpha),
        nightBase,
      ],
      stops: const [0, veilFrom, veilMid, 1],
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
      case MoodKind.night || MoodKind.lantern || MoodKind.dawn:
        paint.color = Mood.nightBase;
      case MoodKind.day:
        paint.shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Mood.daySky, Mood.dayMid, Mood.dayFoot],
          stops: [0, 0.5, 1],
        ).createShader(rect);
    }
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_GroundPainter old) => old.kind != kind;
}

class _LightPainter extends CustomPainter {
  const _LightPainter(this.kind, this.lightAt, this.scene);

  final MoodKind kind;
  final Alignment lightAt;
  final bool scene;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    switch (kind) {
      case MoodKind.night:
        _moonLight(canvas, size);
        _vignette(canvas, size, Mood.vignetteInk, Mood.nightVignette);
      case MoodKind.lantern:
        _lanternPool(canvas, size);
        _vignette(canvas, size, Mood.vignetteInk, Mood.nightVignette);
      case MoodKind.dawn:
        _lanternPool(canvas, size);
        _vignette(canvas, size, Mood.vignetteInk, Mood.nightVignette);
      case MoodKind.day:
        // The sun, low on the left, its light long: a hot core on the left
        // edge, a wide warm pool over the lower panel, and a band of light
        // lying across it that the shadows lean away from.
        _pool(
          canvas,
          size,
          at: const Alignment(-1.05, 0.30),
          rx: w * 1.3,
          ry: h * 0.45,
          colors: [
            Mood.sun.withValues(alpha: 0.95),
            Mood.sun.withValues(alpha: 0.42),
            Mood.sun.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        );
        final beam = Path()
          ..moveTo(0, h * 0.18)
          ..lineTo(w, h * 0.50)
          ..lineTo(w, h * 0.74)
          ..lineTo(0, h * 0.38)
          ..close();
        canvas.drawPath(
          beam,
          Paint()
            ..shader = LinearGradient(
              colors: [
                Mood.sun.withValues(alpha: 0.38),
                Mood.sun.withValues(alpha: 0.0),
              ],
            ).createShader(Rect.fromLTWH(0, 0, w, h)),
        );
        _vignette(canvas, size, Mood.dayVignetteInk, Mood.dayVignette);
    }
  }

  /// The moon in the village's top right: a cool pool round it and a cone of
  /// its light falling on the table, the cards in it lit.
  void _moonLight(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final art = Mood.sceneHeight(kind, size);
    final scale = math.max(w / 768, art / 1024);
    final moon = Offset((w - 768 * scale) / 2 + 650 * scale, 114 * scale);
    _pool(
      canvas,
      size,
      at: Alignment((moon.dx / w) * 2 - 1, (moon.dy / h) * 2 - 1),
      rx: w * 0.62,
      ry: w * 0.62,
      colors: [
        Mood.moon.withValues(alpha: Mood.moonAlpha),
        Mood.moon.withValues(alpha: Mood.moonAlpha / 3),
        Mood.moon.withValues(alpha: 0),
      ],
      stops: const [0, 0.5, 1],
      blend: BlendMode.screen,
    );
    final cone = Path()
      ..moveTo(moon.dx - 14, moon.dy + 10)
      ..lineTo(moon.dx + 14, moon.dy + 10)
      ..lineTo(w * 0.62, h * 0.86)
      ..lineTo(-w * 0.12, h * 0.80)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Mood.moon.withValues(alpha: 0.2),
            Mood.moon.withValues(alpha: 0.1),
            Mood.moon.withValues(alpha: 0.0),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromLTWH(0, moon.dy, w, h * 0.86 - moon.dy)),
    );
  }

  void _lanternPool(Canvas canvas, Size size) {
    final w = size.width;
    _pool(
      canvas,
      size,
      at: lightAt,
      rx: w * 0.85,
      ry: w * 0.62,
      colors: [
        Mood.lantern.withValues(alpha: Mood.lanternAlpha),
        Mood.lantern.withValues(alpha: Mood.lanternAlpha * 0.45),
        Mood.lantern.withValues(alpha: 0),
      ],
      stops: const [0, 0.5, 1],
      blend: BlendMode.screen,
    );
  }

  /// A heavy vignette: clear in the middle third, the whole [alpha] at the
  /// corners.
  void _vignette(Canvas canvas, Size size, Color ink, double alpha) {
    _pool(
      canvas,
      size,
      at: const Alignment(0, -0.08),
      rx: size.width * 0.78,
      ry: size.height * 0.60,
      colors: [
        ink.withValues(alpha: 0),
        ink.withValues(alpha: 0),
        ink.withValues(alpha: alpha),
      ],
      stops: const [0, 0.38, 1],
    );
  }

  @override
  bool shouldRepaint(_LightPainter old) =>
      old.kind != kind || old.lightAt != lightAt || old.scene != scene;
}
