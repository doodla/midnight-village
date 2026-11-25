import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Everything that loops goes through `Ambient` (lib/design_system/feel/
// ambient.dart, feel.md section 2): it is the one place that knows a loop
// stops with the app in the background, under a covering screen and with
// reduce motion. A `.repeat(` anywhere else in lib/ fails here.
const _ambient = 'lib/design_system/feel/ambient.dart';

/// Today's three loops, written before `Ambient` (25 November 2026). Each
/// moves onto it in a later piece and leaves this list then: a listed file
/// that no longer repeats fails, so the list only shrinks.
const _before = {
  'lib/design_system/primitives/waiting_sign.dart',
  'lib/design_system/primitives/paper_lantern.dart',
  'lib/design_system/teach/hold_cue.dart',
};

bool _repeats(String path) =>
    File(path).readAsStringSync().contains('.repeat(');

void main() {
  test('nothing in lib/ repeats an animation except Ambient', () {
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          if (file.path.replaceAll(r'\', '/') case final path
              when path != _ambient &&
                  !_before.contains(path) &&
                  _repeats(path))
            path,
    ];
    expect(offenders, isEmpty, reason: 'loop through Ambient ($_ambient)');
  });

  test('Ambient repeats, and every file still listed still loops', () {
    expect(_repeats(_ambient), isTrue);
    final moved = [
      for (final path in _before)
        if (!File(path).existsSync() || !_repeats(path)) path,
    ];
    expect(moved, isEmpty, reason: 'take these off the list in this test');
  });
}
