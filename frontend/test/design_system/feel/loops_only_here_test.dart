import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Everything that loops goes through `Ambient` (lib/design_system/feel/
// ambient.dart, feel.md section 2): it is the one place that knows a loop
// rests between bursts, holds while a finger is down, and stops with the app
// in the background, under a covering screen and with reduce motion. A
// `.repeat(` anywhere else in lib/ fails here: there is no list of
// exceptions (the three older loops moved onto it, 25 November 2026).
const _ambient = 'lib/design_system/feel/ambient.dart';

bool _repeats(String path) =>
    File(path).readAsStringSync().contains('.repeat(');

void main() {
  test('nothing in lib/ repeats an animation except Ambient', () {
    final offenders = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          if (file.path.replaceAll(r'\', '/') case final path
              when path != _ambient && _repeats(path))
            path,
    ];
    expect(offenders, isEmpty, reason: 'loop through Ambient ($_ambient)');
  });

  test('Ambient is where the repeating is', () {
    expect(_repeats(_ambient), isTrue);
  });
}
