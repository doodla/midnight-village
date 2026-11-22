import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'primitives/art_precache.dart';
import 'skin/card_back.dart';
import 'skin/skin.dart';

/// Gets a skin ready to draw before anything is drawn in it: the art its
/// secrets show, decoded (`secretArt`). The app does this at start, so no
/// hold shows an empty card.
class SkinLoader {
  SkinLoader({AssetBundle? bundle, double Function()? devicePixelRatio})
    : _bundle = bundle ?? rootBundle,
      _ratio = devicePixelRatio ?? _screenRatio;

  final AssetBundle _bundle;
  final double Function() _ratio;

  static double _screenRatio() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    return views.isEmpty ? 1 : views.first.devicePixelRatio;
  }

  /// Decodes the art [skin]'s secrets show, at this screen's pixel ratio,
  /// and the card back [back] (the game this device was last in, if any;
  /// otherwise the fallback, the one outside a game).
  Future<void> prepare(Skin skin, {CardBack back = CardBack.fallback}) =>
      precacheArt(
        secretArt(skin, back: back),
        devicePixelRatio: _ratio(),
        bundle: _bundle,
      );
}
