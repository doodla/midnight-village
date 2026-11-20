// The screen gallery: renders every entry of the screen catalogue from the
// real widgets to PNG, next to its mock. Run it with `just screens` (see
// frontend/CLAUDE.md); it is not part of `just test`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/skin_choice.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screen_catalogue.dart';
import 'screen_gallery.dart';

/// `--dart-define=SCREENS_WIDTH=360` renders at another phone width.
const _width = int.fromEnvironment('SCREENS_WIDTH', defaultValue: 390);

/// `--dart-define=SCREENS_STRICT=true` fails each screen with findings.
const _strict = bool.fromEnvironment('SCREENS_STRICT');

/// `--dart-define=SCREENS_SKIN=nightPrint` renders in another skin of the
/// registry; `default` is the registry's first, `all` is every one.
const _skinName = String.fromEnvironment(
  'SCREENS_SKIN',
  defaultValue: 'default',
);

List<SkinId> _skins() {
  if (_skinName == 'default') return [SkinId.fallback];
  if (_skinName == 'all') return SkinId.values;
  final skin = SkinId.byName(_skinName);
  if (skin == null) {
    throw ArgumentError.value(
      _skinName,
      'SCREENS_SKIN',
      'must be default, all, or one of '
          '${SkinId.values.map((s) => s.name).join(', ')}',
    );
  }
  return [skin];
}

void main() {
  for (final skin in _skins()) {
    group(skin.name, () {
      final results = <String, ScreenResult>{};

      setUpAll(() async {
        clearOutput(_width, skin);
        // The app finds the skin where it keeps it, saved on the device, and
        // reads it before its first frame, as main() does.
        // Test code; the analyzer only counts test/ and *_test.dart as tests.
        // ignore: invalid_use_of_visible_for_testing_member
        SharedPreferences.setMockInitialValues({'skin': skin.name});
        await restoreSkin();
      });
      tearDownAll(() {
        final summary = summarize(
          results,
          width: _width,
          strict: _strict,
          skin: skin,
        );
        File('${outputDir(_width, skin)}/summary.txt')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('$summary\n');
        // ignore: avoid_print
        print('\n$summary');
      });

      for (final entry in screenCatalogue.where((e) => e.build != null)) {
        testWidgets(entry.id, (tester) async {
          final capture = await captureScreen(
            tester,
            entry.build!,
            width: _width,
            playerScreen: entry.playerScreen,
          );
          results[entry.id] = saveScreen(
            entry,
            capture,
            width: _width,
            skin: skin,
          );
          // A screen that cannot be built always fails the run.
          if (capture.failure case final failure?) fail(failure);
          if (_strict) expect(capture.findings, isEmpty, reason: entry.id);
        });
      }
    });
  }
}
