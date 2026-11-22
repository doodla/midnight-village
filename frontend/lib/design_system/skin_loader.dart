import 'package:flutter/widgets.dart';

import 'load_once_bundle.dart';
import 'primitives/art_precache.dart';
import 'skin/skin.dart';

/// Gets a skin ready to draw before anything is drawn in it: first the
/// picture the app opens on (`openingArt`: 01's village, which the opening
/// wait shows too), then the art its secrets show (`secretArt`), decoded.
/// The app does this at start, so the first screen's picture does not queue
/// behind the secrets' and no hold shows an empty card.
class SkinLoader {
  SkinLoader({AssetBundle? bundle, double Function()? devicePixelRatio})
    : _bundle = bundle ?? appAssets,
      _ratio = devicePixelRatio ?? _screenRatio;

  final AssetBundle _bundle;
  final double Function() _ratio;

  /// The bundle it reads from: the app's ([appAssets]) unless given, the
  /// one the screens draw from, so what it decodes is what they find.
  AssetBundle get bundle => _bundle;

  static double _screenRatio() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    return views.isEmpty ? 1 : views.first.devicePixelRatio;
  }

  /// Decodes the opening picture, then the art [skin]'s secrets show, at
  /// this screen's pixel ratio. The secrets' art is asked for once the
  /// opening picture is in (or failed): one picture, long before any card is
  /// dealt.
  Future<void> prepare(Skin skin) async {
    final ratio = _ratio();
    await precacheArt(
      openingArt(skin),
      devicePixelRatio: ratio,
      bundle: _bundle,
    );
    await precacheArt(
      secretArt(skin),
      devicePixelRatio: ratio,
      bundle: _bundle,
    );
  }
}
