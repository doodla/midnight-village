import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../models/role.dart';
import 'card_back.dart';
import 'end_art.dart';
import 'werewolf_portrait.dart';

/// The emblems players are known by at the table, one per seat: the people's
/// ten, then the practice players' (each the thing it is named for: Teapot's
/// is [teapot]), never handed to a person.
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
  scythe,
  scarecrow(practice: true),
  teapot(practice: true),
  broom(practice: true),
  kettle(practice: true),
  haystack(practice: true),
  bucket(practice: true),
  candle(practice: true),
  weathervane(practice: true),
  wheelbarrow(practice: true);

  const TokenId({this.practice = false});

  /// A practice player's token (the server hands it out with the name).
  final bool practice;

  /// The tokens people are given.
  static List<TokenId> get people => [
    for (final t in values)
      if (!t.practice) t,
  ];

  /// The token the server names, or null for one this app does not know (a
  /// newer server's): `PlayerToken` then draws a plain disc.
  static TokenId? fromServer(String? name) => values.asNameMap()[name];
}

/// The scene pictures (flat). 04's village and 08's dawn are not here: they
/// are layered ([LayeredSceneId]).
enum Scene {
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

/// The share of a scene (0 to 1 of `Motion.scene`) a layer takes to travel
/// from where it starts to where it rests, in `Motion.curve`: it holds still
/// before [begin] and rests from [end].
@immutable
class ArrivalSpan {
  const ArrivalSpan(this.begin, this.end)
    : assert(0 <= begin && begin < end && end <= 1);

  final double begin;
  final double end;
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
    this.span,
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

  /// When in the scene it travels. Null: with the screen, over the sheet's
  /// own landing. A span later than that (the moon's) is its own arrival,
  /// after the sheet has landed.
  final ArrivalSpan? span;

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

/// One cut of the candle picture: its file in `candle/`, where its top left
/// lies on the cut's canvas, and its size, in pixels.
@immutable
class CandleCut {
  const CandleCut(this.file, this.at, this.size);

  final String file;
  final Offset at;
  final Size size;
}

/// The night's candle, cut from the candle picture
/// (`frontend/tool/candle/cut_candle.py`) so the clock can shorten the wax
/// and shrink the flame in steps while the paper stays the art's own: the
/// stick with its drips, the flame, and the iron holder that stands over the
/// stick's foot. Positions are in pixels of one canvas.
@immutable
class CandleArt {
  const CandleArt({
    required this.view,
    required this.wax,
    required this.flame,
    required this.holder,
    required this.wick,
    required this.stickBottom,
    required this.stickTop,
    required this.light,
  });

  /// The part of the canvas the candle is drawn in, flame to stem.
  final Rect view;
  final CandleCut wax;
  final CandleCut flame;
  final CandleCut holder;

  /// Where the flame's foot rests, on the wick's tip.
  final Offset wick;

  /// The row the stick's foot ends at (where the holder's dish takes over)
  /// and the row of its top at rest: the stick burns down between them.
  final double stickBottom;
  final double stickTop;

  /// The warm light the flame lays on what is behind it: the flame's own
  /// colour, part of the picture, not the interface's accent.
  final Color light;
}

/// One picture: its asset, its size in pixels, and the point in it that must
/// stay in view when it is cropped (CSS's `object-position`).
///
/// A picture is always drawn through [decodedFor] (the `ArtPicture`
/// primitive does it), which decodes it at the size it is shown, so a
/// 44-wide thumbnail does not hold a 576-wide portrait in memory, nor a frame
/// fill it. Sizes are rounded up to an eighth of the full width ([steps]), so
/// a picture is never decoded more than a step larger than it is drawn, and
/// the pictures decoded ahead (`precacheArt`, `ArtAhead`) are the ones later
/// drawn.
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

  /// The decode sizes: the full width in this many steps.
  static const steps = 8;

  /// The pixels a picture drawn to cover a [box] of logical pixels at
  /// [devicePixelRatio] needs across (its full width when unbounded).
  double neededWidth(Size box, double devicePixelRatio) {
    final full = pixels.width;
    if (!box.isFinite || box.isEmpty) return full;
    final cover = math.max(box.width / full, box.height / pixels.height);
    return full * cover * devicePixelRatio;
  }

  /// The width, in pixels, to decode this picture at to cover a [box] of
  /// logical pixels at [devicePixelRatio]: the smallest step that is still
  /// sharp, never larger than the picture.
  int decodeWidth(Size box, double devicePixelRatio) {
    final full = pixels.width;
    final step = full / steps;
    final needed = neededWidth(box, devicePixelRatio);
    final count = (needed / step - 1e-6).ceil().clamp(1, steps);
    return (count * step).round();
  }

  /// The image to draw for a [box] of logical pixels at [devicePixelRatio].
  /// The asset bundle comes from the image configuration (the widget tree's
  /// `DefaultAssetBundle`).
  ImageProvider decodedFor(Size box, double devicePixelRatio) =>
      ArtDecode(this, width: decodeWidth(box, devicePixelRatio));

  @override
  bool operator ==(Object other) =>
      other is ArtImage &&
      other.path == path &&
      other.pixels == pixels &&
      other.focus == focus;

  @override
  int get hashCode => Object.hash(path, pixels, focus);
}

/// A picture decoded for the box it is drawn in ([ArtImage.decodedFor]): a
/// [ResizeImage] that knows its picture, so the screen sweep can tell how
/// much larger than drawn it was decoded (`test/helpers/frame_cost.dart`).
class ArtDecode extends ResizeImage {
  ArtDecode(this.art, {required int width})
    : super(AssetImage(art.path), width: width, allowUpscaling: false);

  final ArtImage art;
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
    required this.cardBackPixels,
    required this.layered,
    required this.candleCut,
    required this.portraitFocus,
    this.sceneFocus = const {},
  });

  final String folder;

  /// Files of the skin's folder no screen draws any more, kept because a phone
  /// that still runs an older build asks for them: the web app's service
  /// worker drops a file the new build does not list the moment the new build
  /// arrives, while a tab or installed app left open keeps running the old
  /// code, which asks the server for it and is answered with the app's page
  /// (a Werewolf with no picture, 23 November 2026). Each is a copy of the
  /// file that replaced it; one is dropped only once no phone runs a build
  /// that draws it. Never drawn by this build (`skin_contract_test.dart`).
  static const retired = {'roles/werewolf.webp': 'roles/werewolf_lunge.webp'};

  /// Every role portrait's size in pixels.
  final Size rolePixels;

  /// Every token's size in pixels.
  final Size tokenPixels;

  /// Each scene's size in pixels.
  final Map<Scene, Size> scenePixels;

  /// Every card back's size in pixels (`scenes/card_back_<name>.webp`).
  final Size cardBackPixels;

  /// The layered scenes, in `layers/<folder>/<file>.webp`.
  final Map<LayeredSceneId, LayeredScene> layered;

  /// The night's candle, in `candle/<file>.webp`.
  final CandleArt candleCut;

  /// Where a role portrait's face is, wherever it is cropped.
  final Alignment portraitFocus;

  final Map<Scene, Alignment> sceneFocus;

  /// [role]'s portrait. The Werewolf has three ([WerewolfPortrait]); [wolf]
  /// says which. Screens never pass it: they draw `context.roleArt(role)`.
  ArtImage role(
    RoleId role, {
    WerewolfPortrait wolf = WerewolfPortrait.fallback,
  }) => ArtImage(
    role == RoleId.werewolf
        ? '$folder/roles/werewolf_${wolf.fileName}.webp'
        : '$folder/roles/${role.name}.webp',
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

  /// The picture of card back [back]. Screens never call this: a card back
  /// is drawn from `context.cardBack`, the game's one back (`CardBackScope`).
  ArtImage cardBack(CardBack back) => ArtImage(
    '$folder/scenes/card_back_${back.fileName}.webp',
    pixels: cardBackPixels,
  );

  /// The layered scene [id].
  LayeredScene layeredScene(LayeredSceneId id) => layered[id]!;

  /// One layer's picture, at its own size in pixels.
  ArtImage layer(LayeredSceneId id, SceneLayer layer) => ArtImage(
    '$folder/layers/${layered[id]!.folder}/${layer.file}.webp',
    pixels: layer.size,
  );

  /// One cut of the candle, at its own size in pixels.
  ArtImage candleSprite(CandleCut cut) =>
      ArtImage('$folder/candle/${cut.file}.webp', pixels: cut.size);

  /// The end board's ornaments (`end/`).
  EndArt get end => EndArt(folder);

  ArtImage get candle => scene(Scene.candle);
  ArtImage get table => scene(Scene.table);
  ArtImage get streetDoor => scene(Scene.streetDoor);
  ArtImage get sleepingVillage => scene(Scene.sleepingVillage);
}
