import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'primitives/art_precache.dart';
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

  /// Decodes the art [skin]'s secrets show, at this screen's pixel ratio.
  Future<void> prepare(Skin skin) =>
      precacheArt(secretArt(skin), devicePixelRatio: _ratio(), bundle: _bundle);
}
