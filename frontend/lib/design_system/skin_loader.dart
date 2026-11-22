import 'package:flutter/widgets.dart';

import 'load_once_bundle.dart';
import 'primitives/art_precache.dart';
import 'skin/card_back.dart';
import 'skin/skin.dart';

/// Gets a skin ready to draw before anything is drawn in it: first the
/// bytes of the picture the app opens on (`openingArt`: 01's village, which
/// the opening wait shows too; 01 decodes it), then the art its secrets show
/// (`secretArt`), decoded. The app does this at start, so the first screen's
/// picture does not queue behind the secrets' and no hold shows an empty
/// card.
class SkinLoader {
  SkinLoader({AssetBundle? bundle, double Function()? devicePixelRatio})
    : _bundle = bundle ?? appAssets,
      _ratio = devicePixelRatio ?? _screenRatio;

  final AssetBundle _bundle;
  final double Function() _ratio;

  /// The bundle it reads from: the app's ([appAssets]) unless given, the
  /// one the screens draw from, so what it reads and decodes is what they
  /// find.
  AssetBundle get bundle => _bundle;

  static double _screenRatio() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    return views.isEmpty ? 1 : views.first.devicePixelRatio;
  }

  /// Reads the opening picture, then decodes the art [skin]'s secrets show
  /// with the card back [back] (the game this device was last in, if any;
  /// otherwise the fallback, the one outside a game), at this screen's pixel
  /// ratio. The secrets' art is asked for once the opening picture is in (or
  /// failed: it costs that picture, and 01 asks again): one picture, long
  /// before any card is dealt.
  Future<void> prepare(Skin skin, {CardBack back = CardBack.fallback}) async {
    await Future.wait([
      for (final image in openingArt(skin))
        _bundle.load(image.path).then((_) {}, onError: (Object _) {}),
    ]);
    await precacheArt(
      secretArt(skin, back: back),
      devicePixelRatio: _ratio(),
      bundle: _bundle,
    );
  }
}
