import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../skin/art_set.dart';
import '../skin/mood_palette.dart';
import '../skin/skin.dart';
import 'layered_art.dart' show SceneGeometry;

part 'mood_paint.dart';

/// The light a game screen stands in. Night is deep indigo under the village,
/// one cool moon pool and a cone of it falling on the table, a heavy vignette;
/// lantern the same dark with a warm lantern pooling on what is lit; dawn the
/// dark board with a warm pool; day the village at dawn under a low golden
/// sun in a long light, never a flat lilac field.
enum MoodKind { night, lantern, dawn, day }

/// Where a lantern's or dawn's pool lies (the skin says where: `skin.mood`).
enum MoodLight { standard, high }

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
    this.light = MoodLight.standard,
  });

  final MoodKind kind;

  /// Whether the village stands behind (a screen with a picture of its own
  /// has no need of it).
  final bool scene;

  /// Where the lantern's warm pool lies ([MoodKind.lantern] and
  /// [MoodKind.dawn]).
  final MoodLight light;

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

  /// How many finished pictures are kept (one made without a layer that
  /// failed to load is never one of them).
  @visibleForTesting
  static int get cachedPictures => _cache.length;

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
  /// The picture on show: this state's own picture, or its own clone of the
  /// cached one.
  ui.Image? _image;
  _Spec? _shown;

  /// The layers being decoded for a picture not yet made (at most one: a new
  /// spec cancels it, and so does this state going away).
  _Load? _load;

  @override
  void dispose() {
    _load?.cancel();
    _load = null;
    _image?.dispose();
    _image = null;
    super.dispose();
  }

  void _show(_Spec spec, ui.Image image, {required bool cached}) {
    _image?.dispose();
    _image = cached ? image.clone() : image;
    _shown = spec;
  }

  /// Composes [spec] from its loaded layers into a picture. A picture made
  /// with every layer is kept in the cache (a picture lacking one is not: it
  /// would stay without its village for the next screen too; the caller owns
  /// it). Returns the picture and whether it is the cache's.
  (ui.Image, bool) _compose(_Spec spec, _Load load) {
    final loaded = [
      for (final (i, item) in load.plan.indexed)
        _Loaded(item.layer, item.rect, load.images[i]),
    ];
    final cached = Mood._cache[spec];
    if (cached != null) {
      // Another screen of the same spec was first: keep its picture.
      load.release();
      return (cached, true);
    }
    Mood.composed++;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(spec.ratio);
    _paintMood(canvas, spec, loaded);
    final image = recorder.endRecording().toImageSync(
      (spec.size.width * spec.ratio).ceil(),
      (spec.size.height * spec.ratio).ceil(),
    );
    final complete = !load.failed;
    load.release();
    if (!complete) return (image, false);
    Mood._cache[spec] = image;
    while (Mood._cache.length > Mood.kept) {
      Mood._cache.remove(Mood._cache.keys.first)!.dispose();
    }
    return (image, true);
  }

  /// Gets [spec]'s picture: from the cache, composed at once if its layers are
  /// decoded, or null until they are (then this state shows it). Asking again
  /// for the spec already loading starts nothing.
  (ui.Image, bool)? _get(_Spec spec) {
    final cached = Mood._cache.remove(spec);
    if (cached != null) {
      Mood._cache[spec] = cached; // most recent last
      return (cached, true);
    }
    if (_load?.spec == spec) return null;
    _load?.cancel();
    _load = null;
    final load = _Load(spec, _layerPlan(spec), (load) {
      if (!mounted || _load != load) return;
      _load = null;
      final (image, cached) = _compose(spec, load);
      setState(() => _show(spec, image, cached: cached));
    });
    load.start();
    if (load.done) return _compose(spec, load);
    _load = load;
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
            lightAt: switch (widget.light) {
              MoodLight.standard => skin.mood.lanternAt,
              MoodLight.high => skin.mood.lanternHighAt,
            },
            scene: widget.scene,
            palette: skin.mood,
            art: skin.art,
          );
          if (_shown != spec) {
            final got = _get(spec);
            if (got != null) _show(spec, got.$1, cached: got.$2);
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

/// The decoding of a picture's layers: it holds a copy of each image until the
/// picture is composed ([release]) or it is given up ([cancel]), so nothing
/// it copied is ever left undisposed.
class _Load {
  _Load(this.spec, this.plan, this._onDone)
    : images = List<ui.Image?>.filled(plan.length, null),
      _pending = plan.length;

  final _Spec spec;
  final List<_Plan> plan;
  final List<ui.Image?> images;
  final void Function(_Load) _onDone;
  final _listening = <(ImageStream, ImageStreamListener)>[];
  int _pending;
  bool _starting = true;
  bool _cancelled = false;

  /// A layer failed to load: the picture would be without it.
  bool failed = false;

  bool get done => _pending <= 0;

  void start() {
    for (final (i, item) in plan.indexed) {
      final stream = item.provider.resolve(ImageConfiguration.empty);
      late ImageStreamListener listener;
      void settle() {
        stream.removeListener(listener);
        _pending--;
        if (_pending <= 0 && !_starting && !_cancelled) _onDone(this);
      }

      listener = ImageStreamListener(
        (info, _) {
          if (_cancelled) {
            stream.removeListener(listener);
            return;
          }
          images[i] = info.image.clone();
          settle();
        },
        onError: (_, _) {
          failed = true;
          if (_cancelled) {
            stream.removeListener(listener);
            return;
          }
          settle();
        },
      );
      _listening.add((stream, listener));
      stream.addListener(listener);
    }
    _starting = false;
  }

  /// Gives the copies back (the picture is composed, or never will be).
  void release() {
    for (final image in images) {
      image?.dispose();
    }
    images.fillRange(0, images.length, null);
  }

  void cancel() {
    _cancelled = true;
    for (final (stream, listener) in _listening) {
      stream.removeListener(listener);
    }
    release();
  }
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
