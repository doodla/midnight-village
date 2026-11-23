import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';

/// A file removed or renamed in the bundle is a picture (or font) that an app
/// left open on the last release still asks for: the web app's service worker
/// drops it the moment the new build arrives, and the host used to answer the
/// request with the app's page (the owner's blank Werewolf, 23 November 2026).
/// The app now reloads itself for a new build (`lib/core/update/`), but a
/// removal still needs an answer here: `tool/release_assets.json` lists the
/// files of the last release (`just record-assets` writes it, deliberately),
/// and every path missing from the bundle is either a retired alias that
/// stays in the bundle as a copy (`ArtSet.retired`) or on the file's
/// "removedOnPurpose" list with a date and the reason.
void main() {
  final recorded =
      json.decode(File('tool/release_assets.json').readAsStringSync())
          as Map<String, dynamic>;
  final files = (recorded['files'] as List).cast<String>();
  final onPurpose = (recorded['removedOnPurpose'] as Map)
      .cast<String, String>();
  final bundle = {
    for (final entity in Directory('assets').listSync(recursive: true))
      if (entity is File) entity.path.replaceAll(r'\', '/'),
  };
  final retired = {
    for (final old in ArtSet.retired.keys) 'assets/skins/shadow_paper/$old',
  };

  test('every file of the last release is still in the bundle, or says why '
      'not', () {
    final uncovered = [
      for (final path in files)
        if (!bundle.contains(path) && !onPurpose.containsKey(path)) path,
    ];
    expect(
      uncovered,
      isEmpty,
      reason:
          'These files of the last release are gone from the bundle. An app '
          'left open on that release still asks for them. Keep each as a copy '
          'of its successor and list it in ArtSet.retired, or, when nothing '
          'draws it any more and it is safe to lose, add it to '
          '"removedOnPurpose" in tool/release_assets.json with a date and a '
          'reason ("2026-11-24: why"). Then `just record-assets` when the '
          'build goes out.',
    );
  });

  test('a retired alias stays in the bundle', () {
    for (final path in retired) {
      expect(bundle, contains(path), reason: 'ArtSet.retired names $path');
    }
  });

  test('a removal on purpose has a date and a reason, and is really gone', () {
    final dated = RegExp(r'^\d{4}-\d{2}-\d{2}: \S.*');
    for (final MapEntry(key: path, value: why) in onPurpose.entries) {
      expect(dated.hasMatch(why), isTrue, reason: '$path: "$why"');
      expect(bundle, isNot(contains(path)), reason: '$path is in the bundle');
      expect(retired, isNot(contains(path)), reason: '$path is retired too');
    }
  });

  test('the record is sorted and names only files under assets/', () {
    expect(files, [...files]..sort());
    for (final path in files) {
      expect(path, startsWith('assets/'));
    }
  });
}
