import 'dart:convert';

import 'package:flutter/services.dart';

/// Registers every font family the app declares (the skin's faces and
/// MaterialIcons, from the same FontManifest.json the engine uses) so tests,
/// goldens and the screen gallery draw real glyphs instead of the test
/// font's boxes. A family added to pubspec.yaml is picked up without touching
/// this file.
///
/// Then registers Figtree as `Roboto`, Material's default family on the test
/// platform, used by any text whose style names no family (the debug
/// toolbar's): legible, in Figtree, not its real face, in its four weights.
/// The app declares `Roboto` too, as Figtree's regular face (pubspec.yaml: so
/// the web engine does not fetch Roboto at start), and draws no screen in it.
///
/// Needs the test binding (its asset handler serves the manifest).
Future<void> loadAppFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final fonts = (entry['fonts'] as List).cast<Map<String, dynamic>>();
    await _load(entry['family'] as String, [
      for (final font in fonts) rootBundle.load(font['asset'] as String),
    ]);
  }

  final figtree = {
    for (final MapEntry(key: weight, value: asset) in _figtree.entries)
      weight: await rootBundle.load(asset),
  };
  await _load('Roboto', [
    for (final font in figtree.values) Future.value(font),
  ]);
}

Future<void> _load(String family, List<Future<ByteData>> fonts) {
  final loader = FontLoader(family);
  fonts.forEach(loader.addFont);
  return loader.load();
}

const _figtree = {
  FontWeight.w400: 'assets/fonts/figtree/Figtree-Regular.ttf',
  FontWeight.w500: 'assets/fonts/figtree/Figtree-Medium.ttf',
  FontWeight.w600: 'assets/fonts/figtree/Figtree-SemiBold.ttf',
  FontWeight.w700: 'assets/fonts/figtree/Figtree-Bold.ttf',
};
