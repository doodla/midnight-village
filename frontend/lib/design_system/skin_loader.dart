import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'primitives/art_precache.dart';
import 'skin/skin.dart';

/// Loads one font family from its files (`FontLoader`, in the app).
typedef FontFamilyLoader =
    Future<void> Function(String family, List<Future<ByteData>> files);

Future<void> _loadWithFontLoader(String family, List<Future<ByteData>> files) {
  final loader = FontLoader(family);
  files.forEach(loader.addFont);
  return loader.load();
}

/// Gets a skin ready to draw before anything is drawn in it:
/// - its faces, when they are not bundled with the app (only the default
///   skin's are: a phone that never chooses another skin never downloads or
///   loads its fonts);
/// - the art its secrets show, decoded (`secretArt`).
///
/// The skin switch waits for both before switching, so no frame shows the new
/// skin with fallback fonts or an empty card.
class SkinLoader {
  SkinLoader({
    AssetBundle? bundle,
    FontFamilyLoader? loadFamily,
    double Function()? devicePixelRatio,
  }) : _bundle = bundle ?? rootBundle,
       _loadFamily = loadFamily ?? _loadWithFontLoader,
       _ratio = devicePixelRatio ?? _screenRatio;

  final AssetBundle _bundle;
  final FontFamilyLoader _loadFamily;
  final double Function() _ratio;
  final _families = <String, Future<void>>{};

  static double _screenRatio() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    return views.isEmpty ? 1 : views.first.devicePixelRatio;
  }

  /// Loads [skin]'s on-demand faces, each family once.
  Future<void> loadFonts(Skin skin) => Future.wait([
    for (final MapEntry(key: family, value: files)
        in skin.fonts.onDemand.entries)
      _families[family] ??= _loadFamily(family, [
        for (final file in files) _bundle.load(file),
      ]),
  ]);

  /// Decodes the art [skin]'s secrets show, at this screen's pixel ratio.
  Future<void> precacheSecrets(Skin skin) =>
      precacheArt(secretArt(skin), devicePixelRatio: _ratio(), bundle: _bundle);

  /// Both: what the skin switch waits for.
  Future<void> prepare(Skin skin) =>
      Future.wait([loadFonts(skin), precacheSecrets(skin)]);
}
