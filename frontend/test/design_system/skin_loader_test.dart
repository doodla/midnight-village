import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/load_once_bundle.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin_loader.dart';

/// The app's bundle, noting every read; a read of a path in [held] waits
/// until the test lets it go.
class _Bundle extends AssetBundle {
  final asked = <String>[];
  final held = <String, Completer<void>>{};

  /// The pictures read (not the bundle's own manifest).
  List<String> get art => [
    for (final key in asked)
      if (key.contains('/skins/')) key,
  ];

  Future<void> _wait(String key) => held[key]?.future ?? Future.value();

  @override
  Future<ByteData> load(String key) async {
    asked.add(key);
    await _wait(key);
    return rootBundle.load(key);
  }

  @override
  Future<ui.ImmutableBuffer> loadBuffer(String key) async {
    asked.add(key);
    await _wait(key);
    return rootBundle.loadBuffer(key);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      rootBundle.loadString(key, cache: cache);

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) => rootBundle.loadStructuredData(key, parser);
}

/// A bundle whose first read of each path fails.
class _Flaky extends AssetBundle {
  final asked = <String>[];

  @override
  Future<ByteData> load(String key) async {
    asked.add(key);
    if (asked.where((k) => k == key).length == 1) throw Exception('lost');
    return rootBundle.load(key);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      rootBundle.loadString(key, cache: cache);

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) => rootBundle.loadStructuredData(key, parser);
}

void main() {
  final skin = SkinId.fallback.skin;
  final door = skin.art.streetDoor.path;

  test('the app opens on its village first: no secret\'s picture is asked '
      'for until it is in, then every one is', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final bundle = _Bundle();
    final doorIn = Completer<void>();
    bundle.held[door] = doorIn;

    final prepared = SkinLoader(
      bundle: bundle,
      devicePixelRatio: () => 3,
    ).prepare(skin);
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(bundle.art, [door]);

    doorIn.complete();
    await prepared.timeout(const Duration(seconds: 20));

    expect(bundle.art.first, door);
    expect(
      bundle.asked.where((p) => p.contains('/roles/')).toSet(),
      hasLength(RoleId.values.length),
      reason: 'every secret is still decoded at start',
    );
    expect(bundle.asked, contains(skin.art.cardBack.path));
  });

  test('each picture is read once, whatever sizes it is decoded at', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final inner = _Bundle();
    final once = LoadOnceBundle(inner);
    final portrait = skin.art.role(RoleId.seer).path;

    final reads = await Future.wait([
      once.loadBuffer(portrait),
      once.loadBuffer(portrait),
      once
          .load(portrait)
          .then(
            (b) => ui.ImmutableBuffer.fromUint8List(b.buffer.asUint8List()),
          ),
    ]);

    expect(inner.asked, [portrait]);
    expect(reads.map((b) => b.length).toSet(), hasLength(1));
    expect(reads.first.length, greaterThan(0));
    for (final b in reads) {
      b.dispose();
    }
  });

  test('a read that failed is asked again', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final inner = _Flaky();
    final once = LoadOnceBundle(inner);
    final portrait = skin.art.role(RoleId.seer).path;

    await expectLater(once.load(portrait), throwsException);
    final bytes = await once.load(portrait);

    expect(bytes.lengthInBytes, greaterThan(0));
    expect(inner.asked, [portrait, portrait]);
  });
}
