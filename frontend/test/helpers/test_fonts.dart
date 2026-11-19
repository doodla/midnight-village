import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';

/// Registers every font family the app declares (the default skin's bundled
/// faces and MaterialIcons, from the same FontManifest.json the engine uses,
/// and every other skin's on-demand faces, from the skin registry) so tests,
/// goldens and the screen gallery draw real glyphs instead of the test
/// font's boxes. A family added to pubspec.yaml or to a skin is picked up
/// without touching this file.
///
/// Then registers Figtree under the names of families the app's text asks for
/// but nothing bundles, so that text is legible too (in Figtree, not its real
/// face):
/// - `Roboto`: Material's default family on the test platform, used by any
///   text whose style names no family (e.g. the test theme,
///   `MidnightVillageTheme`). On a phone it is the system font.
/// - the retired families, see below.
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

  for (final id in SkinId.values) {
    for (final MapEntry(key: family, value: files)
        in id.skin.fonts.onDemand.entries) {
      await _load(family, [for (final file in files) rootBundle.load(file)]);
    }
  }

  final figtree = {
    for (final MapEntry(key: weight, value: asset) in _figtree.entries)
      weight: await rootBundle.load(asset),
  };
  await _load('Roboto', [
    for (final font in figtree.values) Future.value(font),
  ]);
  for (final family in _retiredFamilies) {
    for (final weight in FontWeight.values) {
      final font = Future.value(figtree[_nearestFigtree(weight)]!);
      for (final italic in [false, true]) {
        await _load(_googleFontsName(family, weight, italic: italic), [font]);
      }
    }
  }
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

/// The bundled Figtree weight closest to [weight].
FontWeight _nearestFigtree(FontWeight weight) => switch (weight.value) {
  <= 400 => FontWeight.w400,
  >= 700 => FontWeight.w700,
  _ => weight,
};

// ---------------------------------------------------------------------------
// Retired families. Delete this section with the old look.
//
// The old theme (`FirelitGothicTheme`) asks google_fonts for Epilogue,
// DM Sans, Space Grotesk and Libre Baskerville. They are not bundled (they are
// going away) and tests may not fetch them, so every style built from them
// makes google_fonts raise an async error and print a three-line report.
// ---------------------------------------------------------------------------

/// google_fonts' names for the retired families, as in `DMSans-Regular`.
const _retiredFamilies = [
  'Epilogue',
  'DMSans',
  'SpaceGrotesk',
  'LibreBaskerville',
];

/// The family google_fonts puts on a style: `DMSans_regular`, `Epilogue_700`,
/// `LibreBaskerville_italic`. The test engine never falls back to the style's
/// `fontFamilyFallback` (the bare family), so the stand-ins need these names.
String _googleFontsName(
  String family,
  FontWeight weight, {
  required bool italic,
}) {
  final regular = weight == FontWeight.w400;
  final variant = switch (italic) {
    false => regular ? 'regular' : '${weight.value}',
    true => regular ? 'italic' : '${weight.value}italic',
  };
  return '${family}_$variant';
}

/// Runs [build], which makes old-theme text styles, keeping google_fonts'
/// failed loads of the retired families out of the test output: the async
/// error each miss raises is dropped and the report it prints is silenced.
/// Any other error or print goes through.
T quietRetiredFonts<T>(T Function() build) {
  late T result;
  var inRetiredReport = false;
  runZonedGuarded(
    () => result = build(),
    (error, stack) {
      if (!_mentionsRetiredFont('$error')) {
        Zone.current.handleUncaughtError(error, stack);
      }
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        if (_mentionsRetiredFont(line)) {
          inRetiredReport = true;
          return;
        }
        if (inRetiredReport && _isGoogleFontsReportTail(line)) return;
        inRetiredReport = false;
        parent.print(zone, line);
      },
    ),
  );
  return result;
}

/// google_fonts' miss, as raised ("... but font Epilogue-Bold was not found")
/// and as printed ("... unable to load font Epilogue-Bold because ...").
bool _mentionsRetiredFont(String text) =>
    (text.contains('google_fonts') || text.contains('GoogleFonts')) &&
    _retiredFamilies.any((family) => text.contains('font $family-'));

/// The two advice lines google_fonts prints after each miss.
bool _isGoogleFontsReportTail(String line) =>
    line.contains('packages/google_fonts/example/test') ||
    line.startsWith("If troubleshooting doesn't solve the problem");
