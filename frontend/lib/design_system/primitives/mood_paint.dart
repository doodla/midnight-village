part of 'mood.dart';

/// Everything of a mood on [canvas] (the size of [spec], at logical pixels):
/// the ground, the village with its veil, the light and the vignette.
void _paintMood(Canvas canvas, _Spec spec, List<_Loaded> layers) {
  Mood.painted++;
  final size = spec.size;
  final kind = spec.kind;
  final palette = spec.palette;
  final rect = Offset.zero & size;
  final ground = Paint();
  switch (kind) {
    case MoodKind.night || MoodKind.lantern || MoodKind.dawn:
      ground.color = palette.nightBase;
    case MoodKind.day:
      ground.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.daySky, palette.dayMid, palette.dayFoot],
        stops: const [0, 0.5, 1],
      ).createShader(rect);
  }
  canvas.drawRect(rect, ground);
  if (spec.sceneId != null && layers.isNotEmpty) {
    final box = spec.sceneRect;
    canvas
      ..save()
      ..clipRect(box);
    _paintVillage(canvas, spec, layers);
    canvas.drawRect(
      box,
      Paint()..shader = _veil(kind, palette).createShader(box),
    );
    canvas.restore();
  }
  _paintLight(canvas, spec);
}

/// The village's layers in order; a layer with a `clipTo` is a shadow cast on
/// the one before it, drawn over it only where that one has paint.
void _paintVillage(Canvas canvas, _Spec spec, List<_Loaded> layers) {
  final paint = Paint()..filterQuality = FilterQuality.medium;
  void draw(_Loaded l) {
    final image = l.image;
    if (image == null) return;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      l.rect,
      paint,
    );
  }

  final cast = <String, List<_Loaded>>{};
  for (final l in layers) {
    if (l.layer.clipTo case final to?) (cast[to] ??= []).add(l);
  }
  for (final l in layers) {
    if (l.layer.clipTo != null) continue;
    final shadows = cast[l.layer.file];
    if (shadows == null) {
      draw(l);
      continue;
    }
    final bounds = l.rect.inflate(1);
    canvas.saveLayer(bounds, Paint());
    draw(l);
    for (final shadow in shadows) {
      canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.srcATop);
      draw(shadow);
      canvas.restore();
    }
    canvas.restore();
  }
}

/// The ground laid over the picture, thin at the top and whole at its foot,
/// so the village stands lit above and sinks into shadow below.
LinearGradient _veil(MoodKind kind, MoodPalette p) {
  if (kind == MoodKind.day) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        p.dayVeilTop,
        p.dayMid.withValues(alpha: 0.85),
        p.dayMid.withValues(alpha: 0),
        p.dayMid.withValues(alpha: 0),
        p.dayVeilFoot,
        p.dayFoot,
      ],
      stops: const [0, 0.18, 0.38, 0.5, 0.66, 1],
    );
  }
  if (kind == MoodKind.lantern) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        p.nightBase,
        p.nightBase.withValues(alpha: 0.96),
        p.nightBase.withValues(alpha: 0.55),
        p.nightBase.withValues(alpha: 0.28),
        p.nightBase.withValues(alpha: 0.42),
      ],
      stops: const [0, 0.2, 0.36, 0.64, 1],
    );
  }
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      p.nightBase.withValues(alpha: 0),
      p.nightBase.withValues(alpha: p.veilFromAlpha),
      p.nightBase.withValues(alpha: p.veilMidAlpha),
      p.nightBase,
    ],
    stops: [0, p.veilFrom, p.veilMid, 1],
  );
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

void _paintLight(Canvas canvas, _Spec spec) {
  final size = spec.size;
  final p = spec.palette;
  final w = size.width;
  final h = size.height;
  switch (spec.kind) {
    case MoodKind.night:
      _moonLight(canvas, spec);
      _vignette(canvas, size, p.vignetteInk, p.nightVignette);
    case MoodKind.lantern || MoodKind.dawn:
      _lanternPool(canvas, spec);
      _vignette(canvas, size, p.vignetteInk, p.nightVignette);
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
          p.sun.withValues(alpha: 0.95),
          p.sun.withValues(alpha: 0.42),
          p.sun.withValues(alpha: 0),
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
              p.sun.withValues(alpha: 0.38),
              p.sun.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, w, h)),
      );
      _vignette(canvas, size, p.dayVignetteInk, p.dayVignette);
  }
}

/// The moon in the village's top right: a cool pool round it and a cone of
/// its light falling on the table, the cards in it lit.
void _moonLight(Canvas canvas, _Spec spec) {
  final size = spec.size;
  final p = spec.palette;
  final w = size.width;
  final h = size.height;
  final art = Mood.sceneHeight(spec.kind, size);
  final scale = math.max(w / 768, art / 1024);
  final moon = Offset((w - 768 * scale) / 2 + 650 * scale, 114 * scale);
  _pool(
    canvas,
    size,
    at: Alignment((moon.dx / w) * 2 - 1, (moon.dy / h) * 2 - 1),
    rx: w * 0.62,
    ry: w * 0.62,
    colors: [
      p.moon.withValues(alpha: p.moonAlpha),
      p.moon.withValues(alpha: p.moonAlpha / 3),
      p.moon.withValues(alpha: 0),
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
          p.moon.withValues(alpha: 0.2),
          p.moon.withValues(alpha: 0.1),
          p.moon.withValues(alpha: 0.0),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(Rect.fromLTWH(0, moon.dy, w, h * 0.86 - moon.dy)),
  );
}

void _lanternPool(Canvas canvas, _Spec spec) {
  final p = spec.palette;
  _pool(
    canvas,
    spec.size,
    at: spec.lightAt,
    rx: spec.size.width * 0.85,
    ry: spec.size.width * 0.62,
    colors: [
      p.lantern.withValues(alpha: p.lanternAlpha),
      p.lantern.withValues(alpha: p.lanternAlpha * 0.45),
      p.lantern.withValues(alpha: 0),
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
