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
  scythe,
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

/// One picture and the point in it that must stay in view when it is
/// cropped (CSS's `object-position`).
@immutable
class ArtImage {
  const ArtImage(this.path, {this.focus = Alignment.center});

  final String path;
  final Alignment focus;

  ImageProvider get provider => AssetImage(path);
}

/// What a token looks like: its picture, or, for a token not drawn yet, its
/// [TokenFallback] (drawn by `PlayerToken` as a plain disc with the token's
/// first letters).
sealed class TokenArt {
  const TokenArt(this.id);

  final TokenId id;
}

class TokenPicture extends TokenArt {
  const TokenPicture(super.id, this.image);

  final ArtImage image;
}

class TokenFallback extends TokenArt {
  const TokenFallback(super.id);

  /// Drawn on the fallback disc: two letters, as spindle and scythe share
  /// one ("Sp", "Sc").
  String get initials => '${id.name[0].toUpperCase()}${id.name[1]}';
}

/// All the pictures of a skin, in one folder laid out as
/// `roles/<role>.webp`, `tokens/<token>.webp` and `scenes/<scene>.webp`.
@immutable
class ArtSet {
  const ArtSet({
    required this.folder,
    required this.drawnTokens,
    required this.portraitFocus,
    this.sceneFocus = const {},
  });

  final String folder;

  /// The tokens that have a picture; the rest fall back (see [TokenFallback]).
  final Set<TokenId> drawnTokens;

  /// Where a role portrait's face is.
  final Alignment portraitFocus;

  final Map<Scene, Alignment> sceneFocus;

  ArtImage role(RoleId role) =>
      ArtImage('$folder/roles/${role.name}.webp', focus: portraitFocus);

  TokenArt token(TokenId token) => drawnTokens.contains(token)
      ? TokenPicture(token, ArtImage('$folder/tokens/${token.name}.webp'))
      : TokenFallback(token);

  ArtImage scene(Scene scene) => ArtImage(
    '$folder/scenes/${scene.fileName}.webp',
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
