import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../faces/held_face.dart';
import '../models/role.dart';
import '../skin/art_set.dart';
import '../skin/skin.dart';
import 'face_down_card.dart';
import 'role_card.dart';

/// The pictures a secret can show, at the sizes it shows them: every role's
/// portrait in a held face's portrait slot (`HeldFace`) and in every
/// thumbnail (the deck strips), and the card back at every face-down size.
/// Decoding all of them before any is shown means the first hold never
/// shows an empty face, and revealing a role fetches nothing: no request for
/// one role's picture crosses the table's Wi-Fi at the moment a player looks
/// at their card.
List<(ArtImage, Size)> secretArt(Skin skin) => [
  for (final role in RoleId.values) ...[
    (skin.art.role(role), HeldFace.portraitBox),
    for (final size in RoleCardSize.values)
      if (size.thumbnail case final thumbnail?)
        (skin.art.role(role), thumbnail),
  ],
  for (final size in FaceDownSize.values) (skin.art.cardBack, size.mock),
];

/// Decodes each picture in [uses] at the size `ArtPicture` will draw it, into
/// the image cache, and completes when all are in (or failed: a missing
/// picture costs that picture, not the app). [bundle] must be the one the
/// widget tree draws from (`DefaultAssetBundle`; the app's is [rootBundle]).
Future<void> precacheArt(
  Iterable<(ArtImage, Size)> uses, {
  required double devicePixelRatio,
  AssetBundle? bundle,
}) {
  final configuration = ImageConfiguration(
    bundle: bundle ?? rootBundle,
    devicePixelRatio: devicePixelRatio,
  );
  return Future.wait([
    for (final (image, box) in uses)
      _resolve(image.decodedFor(box, devicePixelRatio), configuration),
  ]);
}

Future<void> _resolve(ImageProvider provider, ImageConfiguration config) {
  final done = Completer<void>();
  final stream = provider.resolve(config);
  late final ImageStreamListener listener;
  void finish() {
    if (done.isCompleted) return;
    done.complete();
    // The cache keeps the decoded image; this listener is no longer needed.
    scheduleMicrotask(() => stream.removeListener(listener));
  }

  listener = ImageStreamListener((image, _) {
    image.dispose();
    finish();
  }, onError: (_, _) => finish());
  stream.addListener(listener);
  return done.future;
}
