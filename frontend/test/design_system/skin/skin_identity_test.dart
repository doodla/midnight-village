import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';

// One layout, two skins: layout code reads the active skin's values and never
// asks which skin is active. This scans lib/ for code that names a skin or
// compares skins, outside the few files whose job that is.

/// Files allowed to name skins: their definitions (every file in skins/),
/// the registry, the theme that holds the one look, and `main`, which
/// decodes its art at start.
bool _allowed(String path) =>
    path.startsWith('lib/design_system/skin/skins/') ||
    const {
      'lib/design_system/skin/skin_id.dart',
      'lib/design_system/skin/skin_choice.dart',
      'lib/design_system/skin/skin_choice.g.dart',
      'lib/main.dart',
    }.contains(path);

/// Every skin's name in the registry, so a new skin is scanned for too.
final _names = SkinId.values.map((id) => id.name).join('|');

final _identity = [
  // Naming a skin: SkinId.shadowPaper, shadowPaper.
  RegExp('\\b(SkinId|$_names)\\b'),
  // Comparing skins: skin == x, x != skin, identical(skin, x); a null check
  // is not a comparison.
  RegExp(
    r'\bskin\b\s*[!=]=(?!\s*null\b)|[!=]=\s*\w*\.?skin\b|identical\([^)]*\bskin\b',
  ),
];

List<String> findIdentityChecks(Map<String, String> files) => [
  for (final MapEntry(key: path, value: source) in files.entries)
    if (!_allowed(path))
      for (final (number, line) in source.split('\n').indexed)
        if (!line.trimLeft().startsWith('//') &&
            _identity.any((pattern) => pattern.hasMatch(line)))
          '$path:${number + 1}: ${line.trim()}',
];

void main() {
  test('no layout code branches on which skin is active', () {
    final files = {
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          file.path.replaceAll(r'\', '/'): file.readAsStringSync(),
    };
    expect(files, isNotEmpty);
    expect(findIdentityChecks(files), isEmpty);
  });

  test('the scan catches the ways a screen could ask', () {
    const offenders = {
      'lib/a.dart': 'if (ref.watch(skinChoiceProvider) == SkinId.nightPrint) {',
      'lib/b.dart': 'final round = context.skin == shadowPaper;',
      'lib/c.dart': 'if (identical(context.skin, other)) {}',
      'lib/d.dart': 'return other != skin ? a : b;',
    };
    expect(findIdentityChecks(offenders), hasLength(offenders.length));
  });

  test('the scan lets skin values through', () {
    const fine = {
      'lib/a.dart': 'final r = context.skin.shape.radius;',
      'lib/b.dart': 'color: context.ground.text,',
      'lib/c.dart': '// SkinId.nightPrint is named in a comment only',
      'lib/d.dart': 'if (skin == null) throw StateError(\'no skin\');',
    };
    expect(findIdentityChecks(fine), isEmpty);
  });
}
