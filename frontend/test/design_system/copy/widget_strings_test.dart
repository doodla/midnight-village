// Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../helpers/spoken_strings.dart';

// Every word a player sees or hears is in lib/design_system/copy/copy.dart
// (first-time play spec, section 1), so the widgets that draw the first-time
// play screens hold none: this reads their syntax and fails on any string
// that could reach a screen or a screen reader (what counts:
// test/helpers/spoken_strings.dart).

const _folders = [
  'lib/design_system/primitives',
  'lib/design_system/faces',
  'lib/design_system/night',
  'lib/design_system/teach',
];

void main() {
  test('the first-time play widgets hold no words of their own', () {
    final found = [
      for (final folder in _folders)
        for (final file in Directory(folder).listSync(recursive: true))
          if (file is File &&
              file.path.endsWith('.dart') &&
              !file.path.endsWith('.g.dart'))
            for (final string in spokenStrings(file.readAsStringSync()))
              '${file.path}: "$string"',
    ];
    expect(found, isEmpty);
  });

  test('the scan finds a label written in a widget', () {
    expect(spokenStrings("final b = Text('Working');"), ['Working']);
    expect(
      spokenStrings("final s = Semantics(label: 'You, \$name');"),
      hasLength(1),
    );
    expect(spokenStrings("final k = json['action_prompt'];"), isEmpty);
    expect(spokenStrings("final t = Text('\${n}s');"), hasLength(1));
    expect(spokenStrings("final k = '\${kind}_seen';"), isEmpty);
    expect(spokenStrings("void f() => throw FormatException('No');"), isEmpty);
  });
}
