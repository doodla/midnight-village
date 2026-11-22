import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../models/role.dart';

/// The emblems players are known by at the table, one per seat.
enum TokenId {
  crow,
  key,
  moth,
  bell,
  thorn,
  antler,
  hare,
  lantern,
  spindle,
  scythe;

  /// The token the server names, or null for one this app does not know (a
  /// newer server's): `PlayerToken` then draws a plain disc.
  static TokenId? fromServer(String? name) => values.asNameMap()[name];
}

/// The scene pictures (flat). 04's village and 08's dawn are not here: they
/// are layered ([LayeredSceneId]).
enum Scene {
  cardBack('card_back'),
  candle('candle'),
  table('table'),
  streetDoor('street_door'),
  sleepingVillage('sleeping_village');

  const Scene(this.fileName);

  final String fileName;
}

/// The two header pictures that are drawn in layers, so a part of them can
/// move on its own when a scene brings its screen in.
enum LayeredSceneId {
  /// 04's village at night: the plate, the moon and the clouds.
  nightVillage,

  /// 08's dawn: the sky, the sun, the hills, the birds and the roofs.
  dawnGallows,
}

/// One piece of a [LayeredScene], in draw order.
@immutable
sealed class SceneEntry {
  const SceneEntry();
}

/// One cut of paper: a picture with its own alpha, laid where it belongs on
/// the scene's canvas.
@immutable
class SceneLayer extends SceneEntry {
  const SceneLayer(
    this.file, {
    required this.size,
    this.anchor = Offset.zero,
    this.from = Offset.zero,
    this.clipTo,
  });

  /// The file's name in the scene's folder, without `.webp`.
  final String file;

  /// The file's size in pixels (checked against the file by the contract
  /// test).
  final Size size;

  /// Where the file's top left sits on the scene's canvas, in canvas pixels.
  /// A layer that slides sideways carries paper beyond the canvas, so its
  /// anchor can be negative.
  final Offset anchor;

  /// Where the layer starts, from where it rests, in canvas pixels, when a
  /// scene brings the screen in (`SceneArrival`): it travels from here to
  /// rest over the arrival, so a layer that starts further away arrives
  /// last. Zero: it stays. Never further than the art was cut for (the paper
  /// under an overlap and the ends of a shadow are only drawn so far;
  /// `docs/design/art/layers/*/PROVENANCE.md`).
  final Offset from;

  /// The [file] of an earlier layer this one is drawn over only where that
  /// one has paint (a shadow cast on the moon), the two moving apart as
  /// they are given.
  final String? clipTo;
}

/// The sun's path across a scene, in canvas pixels: a quadratic curve, and
/// how far along it (0 to 1, by length) the sun is at the start of the talk
/// and at its end.
@immutable
class SceneArc {
  const SceneArc({
    required this.start,
    required this.control,
    required this.end,
    required this.rise,
    required this.set,
    required this.dip,
  });

  final Offset start;
  final Offset control;
  final Offset end;

  /// Where the sun stands at 0 of the talk and at 1 of it.
  final double rise;
  final double set;

  /// How far below its place the sun starts, in canvas pixels, when a scene
  /// brings it in: behind the hills, so it comes up from behind them.
  final double dip;
}

/// A place in the draw order the screen fills itself: the talk's sun and the
/// dotted path it climbs, which the hills hide the ends of.
@immutable
class SceneSlot extends SceneEntry {
  const SceneSlot(this.name, {this.arc, this.sprite});

  final String name;
  final SceneArc? arc;

  /// The picture drawn at the arc's point; its [SceneLayer.anchor] is
  /// where its top left sits from that point.
  final SceneLayer? sprite;
}

/// A picture drawn in layers, bottom to top: the cuts of paper a header is
/// made of, each laid on one canvas. Drawn at rest (no scene), they make the
/// flat picture they were cut from, to within the encoding
/// (`layered_scene_test.dart`).
@immutable
class LayeredScene {
  const LayeredScene({
    required this.folder,
    required this.canvas,
    required this.focus,
    required this.layers,
  });

  /// The scene's folder under `layers/`.
  final String folder;

  /// The size of the picture the layers were cut from, in pixels.
  final Size canvas;

  /// Where in the canvas the box it covers keeps in view (CSS's
  /// `object-position`).
  final Alignment focus;

  /// Bottom to top.
  final List<SceneEntry> layers;

  /// The layers that are files, in draw order (the sun's sprite included).
  Iterable<SceneLayer> get files sync* {
    for (final entry in layers) {
      switch (entry) {
        case SceneLayer():
          yield entry;
        case SceneSlot(:final sprite?):
          yield sprite;
        case SceneSlot():
          break;
      }
    }
  }
}

/// One picture: its asset, its size in pixels, and the point in it that must
/// stay in view when it is cropped (CSS's `object-position`).
///
/// A picture is always drawn through [decodedFor] (the `ArtPicture`
/// primitive does it), which decodes it no larger than it is shown, so a
/// 44-wide thumbnail does not hold a 576-wide portrait in memory. Sizes are
/// rounded up to a few steps (the full width, a half, a quarter), so the
/// pictures precached at start (`precacheArt`) are the ones later drawn.
@immutable
class ArtImage {
  const ArtImage(
    this.path, {
    required this.pixels,
    this.focus = Alignment.center,
  });

  final String path;

  /// The asset's size in pixels (checked against the files by
  /// skin_contract_test.dart).
  final Size pixels;
  final Alignment focus;

  /// How many halvings below the full size a picture may be decoded at.
  static const _steps = 2;

  /// The width, in pixels, to decode this picture at to cover a [box] of
  /// logical pixels at [devicePixelRatio]: the smallest step that is still
  /// sharp. An unbounded box gets the full size.
  int decodeWidth(Size box, double devicePixelRatio) {
    final full = pixels.width;
    if (!box.isFinite || box.isEmpty) return full.round();
    final cover = math.max(box.width / full, box.height / pixels.height);
    final needed = full * cover * devicePixelRatio;
    var width = full;
    for (var step = 0; step < _steps && width / 2 >= needed; step++) {
      width /= 2;
    }
    return width.round();
  }

  /// The image to draw for a [box] of logical pixels at [devicePixelRatio].
  /// The asset bundle comes from the image configuration (the widget tree's
  /// `DefaultAssetBundle`).
  ImageProvider decodedFor(Size box, double devicePixelRatio) => ResizeImage(
    AssetImage(path),
    width: decodeWidth(box, devicePixelRatio),
    allowUpscaling: false,
  );

  @override
  bool operator ==(Object other) =>
      other is ArtImage &&
      other.path == path &&
      other.pixels == pixels &&
      other.focus == focus;

  @override
  int get hashCode => Object.hash(path, pixels, focus);
}

/// All the pictures of a skin, in one folder laid out as
/// `roles/<role>.webp`, `tokens/<token>.webp`, `scenes/<scene>.webp` and
/// `layers/<scene>/<layer>.webp`.
@immutable
class ArtSet {
  const ArtSet({
    required this.folder,
    required this.rolePixels,
    required this.tokenPixels,
    required this.scenePixels,
    required this.layered,
    required this.portraitFocus,
    this.faceCentres = const {},
    this.sceneFocus = const {},
  });

  final String folder;

  /// Every role portrait's size in pixels.
  final Size rolePixels;

  /// Every token's size in pixels.
  final Size tokenPixels;

  /// Each scene's size in pixels.
  final Map<Scene, Size> scenePixels;

  /// The layered scenes, in `layers/<folder>/<file>.webp`.
  final Map<LayeredSceneId, LayeredScene> layered;

  /// Where a role portrait's face is, wherever it is cropped.
  final Alignment portraitFocus;

  /// How far down each role's portrait its face's middle is (0 the top, 1
  /// the bottom), read off the art: where a short crop centres
  /// ([portraitCrop]) so the face stays whole.
  final Map<RoleId, double> faceCentres;

  /// The alignment that keeps [role]'s face in the middle of a [box] the
  /// portrait covers (as much as the picture allows): a short, wide box
  /// shows the face whole rather than the portrait's top or middle.
  Alignment portraitCrop(RoleId role, Size box) {
    final centre = faceCentres[role];
    if (centre == null || box.isEmpty || !box.isFinite) return portraitFocus;
    // The share of the picture's height the box shows, the picture scaled
    // to cover it.
    final shown =
        box.height / (box.width * rolePixels.height / rolePixels.width);
    if (shown >= 1) return portraitFocus;
    final top = (centre - shown / 2).clamp(0.0, 1 - shown);
    return Alignment(0, 2 * top / (1 - shown) - 1);
  }

  final Map<Scene, Alignment> sceneFocus;

  ArtImage role(RoleId role) => ArtImage(
    '$folder/roles/${role.name}.webp',
    pixels: rolePixels,
    focus: portraitFocus,
  );

  ArtImage token(TokenId token) =>
      ArtImage('$folder/tokens/${token.name}.webp', pixels: tokenPixels);

  ArtImage scene(Scene scene) => ArtImage(
    '$folder/scenes/${scene.fileName}.webp',
    pixels: scenePixels[scene]!,
    focus: sceneFocus[scene] ?? Alignment.center,
  );

  /// The layered scene [id].
  LayeredScene layeredScene(LayeredSceneId id) => layered[id]!;

  /// One layer's picture, at its own size in pixels.
  ArtImage layer(LayeredSceneId id, SceneLayer layer) => ArtImage(
    '$folder/layers/${layered[id]!.folder}/${layer.file}.webp',
    pixels: layer.size,
  );

  ArtImage get cardBack => scene(Scene.cardBack);
  ArtImage get candle => scene(Scene.candle);
  ArtImage get table => scene(Scene.table);
  ArtImage get streetDoor => scene(Scene.streetDoor);
  ArtImage get sleepingVillage => scene(Scene.sleepingVillage);
}
