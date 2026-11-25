import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/skin.dart';
import 'scene_arrival.dart';

import '../feel/atmo.dart';
import '../feel/atmo_village.dart';

/// Where a [LayeredScene]'s canvas lies in the box it is drawn in: the canvas
/// scaled to cover the box and kept around the scene's focus, exactly as a
/// flat picture is cropped by `ArtPicture`, so a layer sits where the flat
/// picture it was cut from sat.
@immutable
class SceneGeometry {
  const SceneGeometry({
    required this.box,
    required this.scale,
    required this.origin,
  });

  factory SceneGeometry.cover(LayeredScene scene, Size box) {
    final canvas = scene.canvas;
    final scale = box.width / canvas.width > box.height / canvas.height
        ? box.width / canvas.width
        : box.height / canvas.height;
    final shown = Size(canvas.width * scale, canvas.height * scale);
    return SceneGeometry(
      box: box,
      scale: scale,
      origin: scene.focus.alongOffset(
        Offset(box.width - shown.width, box.height - shown.height),
      ),
    );
  }

  /// The box the scene covers, in logical pixels.
  final Size box;

  /// Logical pixels to a canvas pixel.
  final double scale;

  /// Where the canvas's top left lies in the box (negative where it is
  /// cropped).
  final Offset origin;

  /// A point of the canvas, in the box.
  Offset point(Offset canvas) => origin + canvas * scale;

  /// A cut of [size] canvas pixels with its top left at [anchor], in the box.
  Rect rect(Offset anchor, Size size) => Rect.fromLTWH(
    origin.dx + anchor.dx * scale,
    origin.dy + anchor.dy * scale,
    size.width * scale,
    size.height * scale,
  );

  @override
  bool operator ==(Object other) =>
      other is SceneGeometry &&
      other.box == box &&
      other.scale == scale &&
      other.origin == origin;

  @override
  int get hashCode => Object.hash(box, scale, origin);
}

/// What the screen draws at a [SceneSlot], laid over the whole box.
typedef SceneSlotBuilder =
    Widget Function(
      BuildContext context,
      SceneGeometry geometry,
      SceneSlot slot,
      Animation<double>? arrival,
    );

/// A [LayeredScene] drawn in the box it is given: every cut of paper in its
/// order, each where it sits on the canvas. Brought in by a scene
/// (`SceneArrival`), each layer travels from where its `from` says to where it
/// rests, over the arrival; with no scene running it is the flat picture, still.
/// Nothing in it moves by itself: no ticker, so a screen with it settles.
///
/// A layer with a `clipTo` is a shadow cast on the one before it: drawn over
/// it only where that one has paint.
///
/// It is its own repaint boundary: the screen around it repainting (a button
/// press, the hold ring breathing) does not draw the layers again.
class LayeredArt extends StatelessWidget {
  const LayeredArt(
    this.id, {
    super.key,
    this.slots = const {},
    this.travel = true,
    this.from,
  });

  final LayeredSceneId id;

  /// What the screen draws at each [SceneSlot], by name.
  final Map<String, SceneSlotBuilder> slots;

  /// Whether the layers start from their `from` when a scene brings the screen
  /// in. False: they only rest (the sheet carries them).
  final bool travel;

  /// A strip of the picture: the row of the canvas (in its own pixels) the
  /// box starts at, the box showing the picture from there down. Null: the
  /// scene's own focus.
  final double? from;

  /// The focus that puts canvas row [from] at the top of a [box] the scene
  /// covers.
  static Alignment focusFrom(LayeredScene scene, Size box, double from) {
    final canvas = scene.canvas;
    final scale = box.width / canvas.width > box.height / canvas.height
        ? box.width / canvas.width
        : box.height / canvas.height;
    final spare = canvas.height * scale - box.height;
    if (spare <= 0) return Alignment.topCenter;
    final top = (from * scale).clamp(0.0, spare);
    return Alignment(0, 2 * top / spare - 1);
  }

  /// Decodes every layer of [id] for a [box] of logical pixels, as they are
  /// drawn in it, so the first frame of a scene finds them. Not awaited.
  static void precache(BuildContext context, LayeredSceneId id, Size box) {
    final art = context.skin.art;
    final scene = art.layeredScene(id);
    final geometry = SceneGeometry.cover(scene, box);
    final ratio = MediaQuery.devicePixelRatioOf(context);
    for (final layer in scene.files) {
      final size = geometry.rect(layer.anchor, layer.size).size;
      precacheImage(
        art.layer(id, layer).decodedFor(size, ratio),
        context,
        onError: (_, _) {},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final art = context.skin.art;
    final flat = art.layeredScene(id);
    final arrival = travel ? SceneArrival.maybeOf(context) : null;
    final clock = travel ? SceneArrival.sceneOf(context) : null;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return RepaintBoundary(
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scene = from == null
                ? flat
                : LayeredScene(
                    folder: flat.folder,
                    canvas: flat.canvas,
                    focus: focusFrom(flat, constraints.biggest, from!),
                    layers: flat.layers,
                  );
            final geometry = SceneGeometry.cover(scene, constraints.biggest);

            Widget placed(SceneLayer layer) {
              final rect = geometry.rect(layer.anchor, layer.size);
              return Positioned.fromRect(
                rect: rect,
                child: _Travel(
                  from: layer.from * geometry.scale,
                  arrival: arrival,
                  clock: clock,
                  span: layer.span,
                  child: _drift(
                    layer,
                    geometry.scale,
                    Image(
                      image: art.layer(id, layer).decodedFor(rect.size, ratio),
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              );
            }

            final cast = <String, List<SceneLayer>>{};
            for (final entry in scene.layers) {
              if (entry case SceneLayer(:final clipTo?)) {
                (cast[clipTo] ??= []).add(entry);
              }
            }
            final children = <Widget>[];
            for (final entry in scene.layers) {
              switch (entry) {
                case SceneLayer(clipTo: != null):
                  break;
                case SceneLayer():
                  final shadows = cast[entry.file];
                  children.add(
                    shadows == null
                        ? placed(entry)
                        : Positioned.fill(
                            child: _SrcAtopStack(
                              // At rest the layer is the moon's own rect;
                              // while the scene moves it, as far as it moves.
                              room: arrival == null
                                  ? 0
                                  : entry.from.distance * geometry.scale,
                              children: [
                                placed(entry),
                                for (final shadow in shadows) placed(shadow),
                              ],
                            ),
                          ),
                  );
                  _atmoOver(entry, geometry, children);
                case SceneSlot():
                  final builder = slots[entry.name];
                  if (builder != null) {
                    children.add(
                      Positioned.fill(
                        child: builder(context, geometry, entry, arrival),
                      ),
                    );
                  }
              }
            }
            if (id == LayeredSceneId.nightVillage &&
                Atmo.has(AtmoEffect.mist)) {
              children.add(
                Positioned.fill(
                  child: AtmoMist(
                    top: geometry.point(const Offset(0, 640)).dy,
                    bottom: geometry.point(const Offset(0, 790)).dy,
                  ),
                ),
              );
            }
            return Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: children,
            );
          },
        ),
      ),
    );
  }

  /// PROTOTYPE: a cloud (and its shadows) drifting a few pixels, slowly.
  Widget _drift(SceneLayer layer, double scale, Widget image) {
    if (id != LayeredSceneId.nightVillage || !Atmo.has(AtmoEffect.clouds)) {
      return image;
    }
    if (AtmoVillage.cloudDrift(layer.file, 1) == Offset.zero) return image;
    // A shadow on the moon is painted inside the moon's own layer: no
    // boundary of its own there.
    final inMoon = layer.clipTo != null;
    return Ambient(
      effect: AtmoEffect.clouds,
      restFor: AtmoVillage.skyBursts.restAt,
      child: inMoon ? image : RepaintBoundary(child: image),
      builder: (context, t, child) => Transform.translate(
        offset:
            AtmoVillage.cloudDrift(layer.file, AtmoVillage.skyTime(t) * 3) *
            scale,
        child: child,
      ),
    );
  }

  /// PROTOTYPE: what lives just over [layer]: the lit windows over the
  /// plate, the moon's breathing light over the moon.
  void _atmoOver(SceneLayer layer, SceneGeometry g, List<Widget> children) {
    if (id != LayeredSceneId.nightVillage) return;
    if (layer.file == 'moon' && Atmo.has(AtmoEffect.clouds)) {
      children.add(
        Positioned.fill(
          child: AtmoMoonLight(
            centre: g.point(const Offset(600, 177)),
            radius: 230 * g.scale,
          ),
        ),
      );
    }
    if (layer.file == 'village_plate' && Atmo.has(AtmoEffect.windows)) {
      children.add(
        Positioned.fill(
          child: AtmoWindows(
            toBox: (r) =>
                Rect.fromPoints(g.point(r.topLeft), g.point(r.bottomRight)),
          ),
        ),
      );
    }
  }
}

/// [child] [from] away (logical pixels) while the scene's [arrival] is at 0,
/// travelling to where it rests as the arrival lands; at rest, where it is.
class _Travel extends StatelessWidget {
  const _Travel({
    required this.from,
    required this.arrival,
    required this.clock,
    required this.span,
    required this.child,
  });

  final Offset from;
  final Animation<double>? arrival;
  final Animation<double>? clock;
  final ArrivalSpan? span;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final span = this.span;
    final clock = this.clock;
    // A layer with a window of its own runs the scene's clock through it; any
    // other (or a scene with no clock) goes with the sheet's landing.
    final run = span != null && clock != null ? clock : arrival;
    if (run == null || from == Offset.zero) return child;
    final curve = span == null
        ? null
        : Interval(span.begin, span.end, curve: Motion.curve);
    return AnimatedBuilder(
      animation: run,
      child: child,
      builder: (context, child) => Transform.translate(
        offset:
            from *
            (1 -
                (curve == null || clock == null
                    ? run.value
                    : curve.transform(run.value))),
        child: child,
      ),
    );
  }
}

/// A stack whose first child is painted as it is and the others only over it
/// (`BlendMode.srcATop`, in a layer of their own as large as the first child
/// and what it can travel): a shadow on the moon stays on the moon whichever
/// way the two move.
class _SrcAtopStack extends Stack {
  const _SrcAtopStack({required this.room, required super.children})
    : super(fit: StackFit.expand, clipBehavior: Clip.none);

  /// How far the first child may be moved from where it is laid out, in
  /// logical pixels: the layer is as large as the child and this around it.
  final double room;

  @override
  RenderStack createRenderObject(BuildContext context) => _RenderSrcAtop(
    room: room,
    alignment: alignment,
    textDirection: textDirection ?? Directionality.maybeOf(context),
    fit: fit,
    clipBehavior: clipBehavior,
  );

  @override
  void updateRenderObject(BuildContext context, RenderStack renderObject) {
    super.updateRenderObject(context, renderObject);
    (renderObject as _RenderSrcAtop).room = room;
  }
}

class _RenderSrcAtop extends RenderStack {
  _RenderSrcAtop({
    required double room,
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior,
  }) : _room = room;

  double _room;
  set room(double value) {
    if (value == _room) return;
    _room = value;
    markNeedsPaint();
  }

  @override
  void paintStack(PaintingContext context, Offset offset) {
    final first = firstChild;
    if (first == null) return;
    final canvas = context.canvas;
    final firstData = first.parentData! as StackParentData;
    final bounds = ((firstData.offset + offset) & first.size).inflate(
      _room + 1,
    );
    canvas.saveLayer(bounds, Paint());
    context.paintChild(first, firstData.offset + offset);
    var child = firstData.nextSibling;
    while (child != null) {
      final data = child.parentData! as StackParentData;
      canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.srcATop);
      context.paintChild(child, data.offset + offset);
      canvas.restore();
      child = data.nextSibling;
    }
    canvas.restore();
  }
}
