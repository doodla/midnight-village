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

/// The scene pictures.
enum Scene {
  cardBack('card_back'),
  candle('candle'),
  table('table'),
  streetDoor('street_door'),
  sleepingVillage('sleeping_village'),
  nightVillage('night_village'),
  dawnRooftops('dawn_rooftops'),
  dawnGallows('dawn_gallows');

  const Scene(this.fileName);

  final String fileName;
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
/// `roles/<role>.webp`, `tokens/<token>.webp` and `scenes/<scene>.webp`.
@immutable
class ArtSet {
  const ArtSet({
    required this.folder,
    required this.rolePixels,
    required this.tokenPixels,
    required this.scenePixels,
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

  ArtImage get cardBack => scene(Scene.cardBack);
  ArtImage get candle => scene(Scene.candle);
  ArtImage get table => scene(Scene.table);
  ArtImage get streetDoor => scene(Scene.streetDoor);
  ArtImage get sleepingVillage => scene(Scene.sleepingVillage);
  ArtImage get nightVillage => scene(Scene.nightVillage);
  ArtImage get dawnRooftops => scene(Scene.dawnRooftops);
  ArtImage get dawnGallows => scene(Scene.dawnGallows);
}
