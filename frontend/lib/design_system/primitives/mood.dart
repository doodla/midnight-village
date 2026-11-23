import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../skin/art_set.dart';
import '../skin/mood_palette.dart';
import '../skin/skin.dart';
import 'layered_art.dart' show SceneGeometry;

/// The light a game screen stands in. Night is deep indigo under the village,
/// one cool moon pool and a cone of it falling on the table, a heavy vignette;
/// lantern the same dark with a warm lantern pooling on what is lit; dawn the
/// dark board with a warm pool; day the village at dawn under a low golden
/// sun in a long light, never a flat lilac field.
enum MoodKind { night, lantern, dawn, day }

/// The ground and the light of a phase, laid under the play surface of a
/// screen dressed up (`ScreenFrame(dress: Dress.paper)` does it, so no screen
/// draws it): a ground, the game's own village (the layered art, at real
/// strength in the top third and falling into shadow below it), a light and
/// the vignette that keeps the eye on the evidence. Its colours and lengths are
/// the skin's (`skin.mood`, [MoodPalette]).
///
/// What it costs: it is composed ONCE per (screen size, phase, light) into one
/// picture (a few image draws, the veil, the pools and the vignette, with the
/// blends done there, never on a frame) kept in a small cache, and what a
/// frame draws is that one picture. Nothing in it is a layer to rasterise or a
/// blend over the screen: an animation ticking above it, a button press or the
/// keyboard rising does not draw it again (`mood_test.dart` counts: [composed]
/// and [painted] stay where they are). A picture is the screen's size at the
/// device's pixel ratio, at most [maxRatio]; two or three are kept. For the
/// frame or two before the village's layers are decoded (art is precached at
/// start) the ground and the lights are painted live, so the screen is never
/// bare. Text keeps its contrast on every pixel of it (`mood_test.dart`);
/// where a word has to sit over the picture it sits on a paper backing, never
/// on a dulled scene.
class Mood extends StatefulWidget {
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

  /// The pixel ratio the picture is made at, at most.
  static const maxRatio = 2.0;

  /// How many pictures are kept (a screen, the one it came from, a sheet's).
  static const kept = 3;

  /// How many times a mood was composed into a picture, and how many times
  /// any of it was painted by a painter (a composition, or the live ground
  /// before it is ready): for tests, which expect them not to move on a frame.
  @visibleForTesting
  static int composed = 0;
  @visibleForTesting
  static int painted = 0;

  /// Forgets every kept picture (a test that changes the art).
  @visibleForTesting
  static void forget() {
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
  }

  /// Which way paper's shadow leans on a screen of this light: away from it.
  static double leanOf(MoodKind kind, MoodPalette palette) => switch (kind) {
    MoodKind.night => palette.leanNight,
    MoodKind.lantern || MoodKind.dawn => palette.leanLantern,
    MoodKind.day => palette.leanDay,
  };

  /// What the pictures and the body's lower edge fade into: the ground the
  /// mood paints under them (the night's deep base, the day's golden foot).
  static Color fadeOf(MoodKind kind, MoodPalette palette) =>
      kind == MoodKind.day ? palette.dayFoot : palette.nightBase;

  /// The village's height for a screen [size].
  static double sceneHeight(MoodKind kind, Size size) => kind == MoodKind.day
      ? math.min(size.height * 0.40, size.width * 0.9)
      : math.min(size.height * 0.66, size.width * 4 / 3);

  static final _cache = <_Spec, ui.Image>{};

  @override
  State<Mood> createState() => _MoodState();
}

class _MoodState extends State<Mood> {
  /// The picture on show: this state's own clone of the cached one.
  ui.Image? _image;
  _Spec? _shown;
  _Spec? _loading;

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  void _show(_Spec spec, ui.Image image) {
    _image?.dispose();
    _image = image.clone();
    _shown = spec;
  }

  /// Composes [spec] from its loaded layers into a picture, keeps it.
  ui.Image _compose(_Spec spec, List<_Loaded> loaded) {
    Mood.composed++;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(spec.ratio);
    _paintMood(canvas, spec, loaded);
    final image = recorder.endRecording().toImageSync(
      (spec.size.width * spec.ratio).ceil(),
      (spec.size.height * spec.ratio).ceil(),
    );
    Mood._cache[spec] = image;
    while (Mood._cache.length > Mood.kept) {
      Mood._cache.remove(Mood._cache.keys.first)!.dispose();
    }
    return image;
  }

  /// Gets [spec]'s picture: from the cache, composed at once if its layers are
  /// decoded, or null until they are (then this state shows it).
  ui.Image? _get(_Spec spec) {
    final cached = Mood._cache.remove(spec);
    if (cached != null) {
      Mood._cache[spec] = cached; // most recent last
      return cached;
    }
    final plan = _layerPlan(spec);
    final images = List<ui.Image?>.filled(plan.length, null);
    var pending = plan.length;
    var asking = true;
    ui.Image compose() {
      final loaded = [
        for (final (i, item) in plan.indexed)
          _Loaded(item.layer, item.rect, images[i]),
      ];
      final image = _compose(spec, loaded);
      for (final loaded in images) {
        loaded?.dispose();
      }
      return image;
    }

    void arrived() {
      pending--;
      if (pending > 0 || asking || !mounted || _loading != spec) return;
      final image = compose();
      setState(() => _show(spec, image));
    }

    for (final (i, item) in plan.indexed) {
      final stream = item.provider.resolve(ImageConfiguration.empty);
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          images[i] = info.image.clone();
          stream.removeListener(listener);
          arrived();
        },
        onError: (_, _) {
          stream.removeListener(listener);
          arrived();
        },
      );
      stream.addListener(listener);
    }
    asking = false;
    if (pending <= 0) return compose();
    _loading = spec;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ratio = math.min(
      MediaQuery.devicePixelRatioOf(context),
      Mood.maxRatio,
    );
    final screen = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          // The picture is the screen's size, however much of it the keyboard
          // leaves: the body shrinking never makes a new one.
          final size = Size(
            box.maxWidth.isFinite ? box.maxWidth : screen.width,
            math.max(box.maxHeight.isFinite ? box.maxHeight : 0, screen.height),
          );
          final spec = _Spec(
            kind: widget.kind,
            size: size,
            ratio: ratio,
            lightAt: widget.lightAt,
            scene: widget.scene,
            palette: skin.mood,
            art: skin.art,
          );
          if (_shown != spec) {
            final image = _get(spec);
            if (image != null) {
              _image?.dispose();
              _image = image.clone();
              _shown = spec;
            }
          }
          final image = _shown == spec ? _image : null;
          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minWidth: size.width,
              maxWidth: size.width,
              minHeight: size.height,
              maxHeight: size.height,
              child: image != null
                  ? RawImage(
                      image: image,
                      width: size.width,
                      height: size.height,
                      scale: ratio,
                      fit: BoxFit.fill,
                    )
                  // Till the layers are decoded: the ground and the lights.
                  : CustomPaint(size: size, painter: _LivePainter(spec)),
            ),
          );
        },
      ),
    );
  }
}

/// What a picture is of; its key in the cache.
@immutable
class _Spec {
  const _Spec({
    required this.kind,
    required this.size,
    required this.ratio,
    required this.lightAt,
    required this.scene,
    required this.palette,
    required this.art,
  });

  final MoodKind kind;
  final Size size;
  final double ratio;
  final Alignment lightAt;
  final bool scene;
  final MoodPalette palette;
  final ArtSet art;

  LayeredSceneId? get sceneId => !scene
      ? null
      : switch (kind) {
          MoodKind.night || MoodKind.lantern => LayeredSceneId.nightVillage,
          MoodKind.day => LayeredSceneId.dawnGallows,
          MoodKind.dawn => null,
        };

  /// The village's box: hung from the top, or standing at the foot.
  Rect get sceneRect {
    final height = Mood.sceneHeight(kind, size);
    final atFoot = kind == MoodKind.lantern || kind == MoodKind.day;
    return Rect.fromLTWH(
      0,
      atFoot ? size.height - height : 0,
      size.width,
      height,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _Spec &&
      other.kind == kind &&
      other.size == size &&
      other.ratio == ratio &&
      other.lightAt == lightAt &&
      other.scene == scene &&
      other.palette == palette &&
      identical(other.art, art);

  @override
  int get hashCode => Object.hash(
    kind,
    size,
    ratio,
    lightAt,
    scene,
    palette,
    identityHashCode(art),
  );
}

/// A layer of the village, where it lies on the screen.
class _Loaded {
  const _Loaded(this.layer, this.rect, this.image);

  final SceneLayer layer;
  final Rect rect;
  final ui.Image? image;

  _Loaded withImage(ui.Image image) => _Loaded(layer, rect, image);
}

class _Plan {
  const _Plan(this.layer, this.rect, this.provider);

  final SceneLayer layer;
  final Rect rect;
  final ImageProvider provider;
}

List<_Plan> _layerPlan(_Spec spec) {
  final id = spec.sceneId;
  if (id == null) return const [];
  final scene = spec.art.layeredScene(id);
  final box = spec.sceneRect;
  final geometry = SceneGeometry.cover(scene, box.size);
  return [
    for (final entry in scene.layers)
      if (entry is SceneLayer)
        () {
          final rect = geometry
              .rect(entry.anchor, entry.size)
              .shift(box.topLeft);
          return _Plan(
            entry,
            rect,
            spec.art.layer(id, entry).decodedFor(rect.size, spec.ratio),
          );
        }(),
  ];
}

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

/// Before the village's layers are decoded: the ground and the lights, painted
/// live (it is for a frame or two; the picture takes over).
class _LivePainter extends CustomPainter {
  const _LivePainter(this.spec);

  final _Spec spec;

  @override
  void paint(Canvas canvas, Size size) => _paintMood(canvas, spec, const []);

  @override
  bool shouldRepaint(_LivePainter old) => old.spec != spec;
}
