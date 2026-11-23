import 'dart:async';

import 'package:flutter/widgets.dart';

import '../faces/held_face.dart';
import '../load_once_bundle.dart';
import '../models/role.dart';
import '../skin/art_set.dart';
import '../skin/card_back.dart';
import '../skin/skin.dart';
import '../skin/werewolf_portrait.dart';
import 'face_down_card.dart';
import 'role_card.dart';

/// The pictures a secret can show, at the sizes it shows them: every role's
/// portrait in a held face's portrait slot (`HeldFace`) and in every
/// thumbnail (the deck strips), and the card back in use ([back]: at start,
/// before any game, the fallback) at every face-down size. Only the back in
/// use: the other four are fetched by no one.
/// Decoding all of them before any is shown means the first hold never
/// shows an empty face, and revealing a role fetches nothing: no request for
/// one role's picture crosses the table's Wi-Fi at the moment a player looks
/// at their card.
List<(ArtImage, Size)> secretArt(
  Skin skin, {
  CardBack back = CardBack.fallback,
  WerewolfPortrait wolf = WerewolfPortrait.fallback,
}) => [
  for (final role in RoleId.values) ...[
    (skin.art.role(role, wolf: wolf), HeldFace.portraitBox),
    for (final size in RoleCardSize.values)
      if (size.thumbnail case final thumbnail?)
        (skin.art.role(role, wolf: wolf), thumbnail),
  ],
  for (final size in FaceDownSize.values) (skin.art.cardBack(back), size.mock),
  // A face that saw no card (the moon over the sleeping village).
  (skin.art.sleepingVillage, HeldFace.portraitBox),
];

/// The picture the app opens on: 01's village (`TopArtLayout.fill`), which
/// the opening wait shows too. Its bytes are read before [secretArt]'s
/// (`SkinLoader`), so it is not queued behind the secrets' pictures on a slow
/// line; it is not decoded here: 01 decodes it at the size it draws, from
/// those same bytes (`LoadOnceBundle`). Decoded here at full size, it was a
/// second, larger copy that no screen drew.
List<ArtImage> openingArt(Skin skin) => [skin.art.streetDoor];

/// Decodes the Werewolf portrait [wolf] at the sizes secrets show it, for the
/// game that is about to show it (the one in use, not the other two).
Future<void> precacheWerewolf(BuildContext context, WerewolfPortrait wolf) {
  final skin = context.skin;
  return precacheArt(
    [
      (skin.art.role(RoleId.werewolf, wolf: wolf), HeldFace.portraitBox),
      for (final size in RoleCardSize.values)
        if (size.thumbnail case final thumbnail?)
          (skin.art.role(RoleId.werewolf, wolf: wolf), thumbnail),
    ],
    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    bundle: DefaultAssetBundle.of(context),
  );
}

/// Decodes card back [back] at every face-down size, for the game that is
/// about to show it: the one back in use, not the other four. Not awaited by
/// anyone; a card back never waits for it (an undecoded one draws a frame
/// late from the bundle).
Future<void> precacheCardBack(BuildContext context, CardBack back) {
  final skin = context.skin;
  return precacheArt(
    [
      for (final size in FaceDownSize.values)
        (skin.art.cardBack(back), size.mock),
    ],
    devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    bundle: DefaultAssetBundle.of(context),
  );
}

/// Decodes each picture in [uses] at the size `ArtPicture` will draw it, into
/// the image cache, and completes when all are in (or failed: a missing
/// picture costs that picture, not the app). [bundle] must be the one the
/// widget tree draws from (`DefaultAssetBundle`): a decoded picture is kept
/// under its bundle, so one decoded from another bundle is not found when it
/// is drawn. The app's is [appAssets], the default. A picture that does not
/// decode (the bytes were not a picture: a Wi-Fi sign-in page) is evicted
/// from the bundle, so the next draw reads it again.
Future<void> precacheArt(
  Iterable<(ArtImage, Size)> uses, {
  required double devicePixelRatio,
  AssetBundle? bundle,
}) {
  final configuration = ImageConfiguration(
    bundle: bundle ?? appAssets,
    devicePixelRatio: devicePixelRatio,
  );
  return Future.wait([
    for (final (image, box) in uses)
      _resolve(
        image.decodedFor(box, devicePixelRatio),
        configuration,
        image.path,
      ),
  ]);
}

Future<void> _resolve(
  ImageProvider provider,
  ImageConfiguration config,
  String path,
) {
  final done = Completer<void>();
  final stream = provider.resolve(config);
  late final ImageStreamListener listener;
  void finish() {
    if (done.isCompleted) return;
    done.complete();
    // The cache keeps the decoded image; this listener is no longer needed.
    scheduleMicrotask(() => stream.removeListener(listener));
  }

  listener = ImageStreamListener(
    (image, _) {
      image.dispose();
      finish();
    },
    onError: (_, _) {
      config.bundle?.evict(path);
      finish();
    },
  );
  stream.addListener(listener);
  return done.future;
}
