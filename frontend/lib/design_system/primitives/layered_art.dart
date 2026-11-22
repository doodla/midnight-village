import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../skin/art_set.dart';
import '../skin/skin.dart';
import 'scene_arrival.dart';

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
  });

  final LayeredSceneId id;

  /// What the screen draws at each [SceneSlot], by name.
  final Map<String, SceneSlotBuilder> slots;

  /// Whether the layers start from their `from` when a scene brings the screen
  /// in. False: they only rest (the sheet carries them).
  final bool travel;

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
    final scene = art.layeredScene(id);
    final arrival = travel ? SceneArrival.maybeOf(context) : null;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return RepaintBoundary(
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final geometry = SceneGeometry.cover(scene, constraints.biggest);

            Widget placed(SceneLayer layer) {
              final rect = geometry.rect(layer.anchor, layer.size);
              return Positioned.fromRect(
                rect: rect,
                child: _Travel(
                  from: layer.from * geometry.scale,
                  arrival: arrival,
                  child: Image(
                    image: art.layer(id, layer).decodedFor(rect.size, ratio),
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                    excludeFromSemantics: true,
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
                              children: [
                                placed(entry),
                                for (final shadow in shadows) placed(shadow),
                              ],
                            ),
                          ),
                  );
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
}

/// [child] [from] away (logical pixels) while the scene's [arrival] is at 0,
/// travelling to where it rests as the arrival lands; at rest, where it is.
class _Travel extends StatelessWidget {
  const _Travel({
    required this.from,
    required this.arrival,
    required this.child,
  });

  final Offset from;
  final Animation<double>? arrival;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final arrival = this.arrival;
    if (arrival == null || from == Offset.zero) return child;
    return AnimatedBuilder(
      animation: arrival,
      child: child,
      builder: (context, child) =>
          Transform.translate(offset: from * (1 - arrival.value), child: child),
    );
  }
}

/// A stack whose first child is painted as it is and the others only over it
/// (`BlendMode.srcATop`, in a layer of their own as large as the first child
/// and what it can travel): a shadow on the moon stays on the moon whichever
/// way the two move.
class _SrcAtopStack extends Stack {
  const _SrcAtopStack({required super.children})
    : super(fit: StackFit.expand, clipBehavior: Clip.none);

  @override
  RenderStack createRenderObject(BuildContext context) => _RenderSrcAtop(
    alignment: alignment,
    textDirection: textDirection ?? Directionality.maybeOf(context),
    fit: fit,
    clipBehavior: clipBehavior,
  );
}

class _RenderSrcAtop extends RenderStack {
  _RenderSrcAtop({
    super.alignment,
    super.textDirection,
    super.fit,
    super.clipBehavior,
  });

  /// How far the first child may be moved from where it is laid out, in
  /// logical pixels: the layer is as large as the child and this around it.
  static const _room = 96.0;

  @override
  void paintStack(PaintingContext context, Offset offset) {
    final first = firstChild;
    if (first == null) return;
    final canvas = context.canvas;
    final firstData = first.parentData! as StackParentData;
    final bounds = ((firstData.offset + offset) & first.size).inflate(_room);
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
