import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:xml/xml.dart';

// The installed app's surface (docs/design/app-icon.md): the Android icon,
// launch screen and name, and the web app's icons, manifest and page. This
// machine may have no Android SDK, so this test reads the resources the way
// the build would: every XML well formed, every resource it names present
// in every density, every picture the size its density asks, and the names
// and the night colour the same everywhere. `just app-icon` makes the
// pictures (tool/app_icon.py).

const _main = 'android/app/src/main';
const _res = '$_main/res';
const _densities = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

/// Size in dp of each picture the icon script makes, by resource name.
const _dp = {
  'ic_launcher': 48,
  'ic_launcher_round': 48,
  'ic_launcher_foreground': 108,
  'ic_launcher_monochrome': 108,
  'launch_mark': 192,
};

final _android = 'http://schemas.android.com/apk/res/android';

List<File> _xmlFiles() => [
  File('$_main/AndroidManifest.xml'),
  ...Directory(_res)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.xml')),
]..sort((a, b) => a.path.compareTo(b.path));

XmlDocument _parse(File f) => XmlDocument.parse(f.readAsStringSync());

/// The folders of [type] (`mipmap`, `drawable`, `values`), qualifiers and all.
List<Directory> _folders(String type) =>
    Directory(_res).listSync().whereType<Directory>().where((d) {
      final name = d.uri.pathSegments.where((s) => s.isNotEmpty).last;
      return name == type || name.startsWith('$type-');
    }).toList();

String _folderName(Directory d) =>
    d.uri.pathSegments.where((s) => s.isNotEmpty).last;

/// The files named [name] (any extension) in [type]'s folders.
List<File> _resourceFiles(String type, String name) => [
  for (final dir in _folders(type))
    ...dir.listSync().whereType<File>().where(
      (f) => f.uri.pathSegments.last.split('.').first == name,
    ),
];

Set<String> _valuesNamed(String tag) => {
  for (final dir in _folders('values'))
    for (final f in dir.listSync().whereType<File>())
      if (f.path.endsWith('.xml'))
        for (final e in _parse(f).findAllElements(tag)) e.getAttribute('name')!,
};

/// Every `@type/name` an XML file names, the platform's own (`@android:`)
/// aside.
Iterable<(String, String, String)> _references() sync* {
  final ref = RegExp(r'^@(mipmap|drawable|color|style)/([a-z0-9_]+)$');
  for (final f in _xmlFiles()) {
    for (final node in _parse(f).descendants) {
      final texts = [
        if (node is XmlElement) ...node.attributes.map((a) => a.value),
        if (node is XmlElement && node.children.length == 1)
          node.innerText.trim(),
      ];
      for (final t in texts) {
        final m = ref.firstMatch(t);
        if (m != null) yield (f.path, m.group(1)!, m.group(2)!);
      }
    }
  }
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

void main() {
  final night = _hex(SkinId.fallback.skin.ground(GroundKind.night).ground);

  group('Android', () {
    test('every resource XML and the manifest are well formed', () {
      final files = _xmlFiles();
      expect(files.length, greaterThan(5));
      for (final f in files) {
        expect(() => _parse(f), returnsNormally, reason: f.path);
      }
    });

    test('every resource an XML names is there, in every density', () {
      final colors = _valuesNamed('color');
      final styles = _valuesNamed('style');
      final refs = _references().toList();
      expect(refs, isNotEmpty);
      for (final (file, type, name) in refs) {
        final why = '$file names @$type/$name';
        switch (type) {
          case 'color':
            expect(colors, contains(name), reason: why);
          case 'style':
            expect(styles, contains(name), reason: why);
          default:
            final found = _resourceFiles(type, name);
            expect(found, isNotEmpty, reason: why);
            final bitmaps = found.where((f) => !f.path.endsWith('.xml'));
            final xmls = found.where((f) => f.path.endsWith('.xml'));
            // A picture, or an adaptive icon (Android 8+) whose older
            // phones (minSdk 24) fall back to pictures: in all densities.
            if (bitmaps.isNotEmpty ||
                xmls.every((f) => f.path.contains('-v'))) {
              final have = {
                for (final f in bitmaps) _folderName(f.parent).split('-').last,
              };
              expect(have, containsAll(_densities.keys), reason: why);
            }
        }
      }
    });

    test('each picture is its size in each density', () {
      for (final MapEntry(key: name, value: dp) in _dp.entries) {
        for (final MapEntry(key: density, value: scale) in _densities.entries) {
          final type = name == 'launch_mark' ? 'drawable' : 'mipmap';
          final file = File('$_res/$type-$density/$name.webp');
          expect(file.existsSync(), isTrue, reason: file.path);
          final picture = img.decodeWebP(file.readAsBytesSync());
          expect(picture, isNotNull, reason: file.path);
          final px = (dp * scale).round();
          expect(
            (picture!.width, picture.height),
            (px, px),
            reason: '${file.path}: $dp dp at $density',
          );
        }
      }
    });

    test('the adaptive icons have a background, a foreground and a '
        'monochrome layer (themed icons)', () {
      for (final name in ['ic_launcher', 'ic_launcher_round']) {
        final icon = _parse(
          File('$_res/mipmap-anydpi-v26/$name.xml'),
        ).rootElement;
        expect(icon.name.local, 'adaptive-icon');
        for (final layer in ['background', 'foreground', 'monochrome']) {
          expect(
            icon
                .findElements(layer)
                .single
                .getAttribute('drawable', namespace: _android),
            isNotNull,
            reason: '$name: $layer',
          );
        }
      }
    });

    test('the launcher name is the game\'s, and the icons are set', () {
      final app = _parse(
        File('$_main/AndroidManifest.xml'),
      ).findAllElements('application').single;
      String? attr(String name) => app.getAttribute(name, namespace: _android);
      expect(attr('label'), JoinCopy.title);
      expect(attr('icon'), '@mipmap/ic_launcher');
      expect(attr('roundIcon'), '@mipmap/ic_launcher_round');
    });

    test('the launch screen and the windows are the night ground, '
        'whatever the phone\'s dark mode', () {
      final colors = {
        for (final e in _parse(
          File('$_res/values/colors.xml'),
        ).findAllElements('color'))
          e.getAttribute('name'): e.innerText.trim().toUpperCase(),
      };
      expect(colors['night'], '#FF${night.substring(1)}');
      expect(colors['ic_launcher_background'], colors['night']);
      // One look: no values-night (a day launch would flash).
      expect(
        _folders('values').map(_folderName),
        isNot(contains('values-night')),
      );
      final splash = _parse(
        File('$_res/values-v31/styles.xml'),
      ).findAllElements('item');
      String? item(String name) => splash
          .where((e) => e.getAttribute('name') == 'android:$name')
          .singleOrNull
          ?.innerText;
      expect(item('windowSplashScreenBackground'), '@color/night');
      expect(item('windowSplashScreenAnimatedIcon'), '@drawable/splash_icon');
    });
  });

  group('web', () {
    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync())
            as Map<String, Object?>;

    test('the manifest names the game, in its night colour', () {
      expect(manifest['name'], JoinCopy.title);
      expect(manifest['short_name'], JoinCopy.title);
      expect(manifest['background_color'], night);
      expect(manifest['theme_color'], night);
    });

    test('every icon the manifest lists is there, at its size', () {
      final icons = (manifest['icons']! as List).cast<Map<String, Object?>>();
      expect(icons.map((i) => i['purpose']), contains('maskable'));
      for (final icon in icons) {
        final file = File('web/${icon['src']}');
        expect(file.existsSync(), isTrue, reason: file.path);
        final picture = img.decodePng(file.readAsBytesSync())!;
        expect('${picture.width}x${picture.height}', icon['sizes']);
      }
    });

    test('the page: its title, colour, icons and launch mark', () {
      final page = File('web/index.html').readAsStringSync();
      expect(page, contains('<title>${JoinCopy.title}</title>'));
      expect(page, contains('name="theme-color" content="$night"'));
      expect(page, contains('background: $night'));
      for (final href in RegExp(
        r'(?:href|src)="((?:icons/|favicon)[^"]+)"',
      ).allMatches(page).map((m) => m[1]!)) {
        expect(File('web/$href').existsSync(), isTrue, reason: href);
      }
      expect(page, contains('apple-touch-icon'));
      expect(page, contains('id="launch"'));
      expect(
        File('web/flutter_bootstrap.js').readAsStringSync(),
        contains("getElementById('launch')"),
      );
    });

    test('the page loads the app without waiting for a service worker on a '
        'first visit, and knows the deployed build on every open', () {
      final page = File('web/index.html').readAsStringSync();
      final boot = File('web/flutter_bootstrap.js').readAsStringSync();
      // Inlined in the page, which the worker fetches from the network
      // first: a separate bootstrap would come from the worker's cache.
      expect(page, contains('<script>{{flutter_bootstrap_js}}</script>'));
      expect(page, isNot(contains('src="flutter_bootstrap.js"')));
      // Flutter's worker check (and its wait) only for a phone a worker
      // already serves; a first visit loads at once and registers the worker
      // once the app's own start is in (`webStartDone`).
      final returning = boot.indexOf('workers.controller');
      final settings = boot.indexOf('serviceWorkerSettings');
      expect(returning, isNonNegative);
      expect(settings, greaterThan(returning));
      expect(boot, contains('_flutter.loader.load();'));
      expect(boot, contains('window.mvStarted = function'));
      expect(
        File('lib/core/web/start_done_web.dart').readAsStringSync(),
        contains("@JS('mvStarted')"),
      );
    });
  });

  test('nothing still says what the Flutter template said', () {
    final files = [
      File('$_main/AndroidManifest.xml'),
      File('web/index.html'),
      File('web/manifest.json'),
      File('android/app/build.gradle.kts'),
    ];
    for (final f in files) {
      final text = f.readAsStringSync();
      for (final stale in [
        'A new Flutter project',
        '"midnight_village"',
        '>midnight_village<',
        'label="midnight_village"',
        'frontend',
        'TODO: Specify your own unique Application ID',
      ]) {
        expect(text, isNot(contains(stale)), reason: '${f.path}: $stale');
      }
    }
  });
}
