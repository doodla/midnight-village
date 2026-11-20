import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/storage/device_preferences.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/skin/skin_choice.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A loader that records what it was asked to prepare and finishes when told.
class _Loader extends SkinLoader {
  final prepared = <Skin>[];
  Completer<void>? gate;

  @override
  Future<void> prepare(Skin skin) async {
    prepared.add(skin);
    await gate?.future;
  }
}

ProviderContainer _start(_Loader loader) {
  final container = ProviderContainer(
    overrides: [skinLoaderProvider.overrideWithValue(loader)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<String?> _saved() async =>
    (await SharedPreferences.getInstance()).getString('skin');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    forgetRestoredSkin();
  });

  test('a new device starts in the default skin', () async {
    expect(await restoreSkin(), SkinId.fallback);
    expect(_start(_Loader()).read(skinChoiceProvider), SkinId.fallback);
  });

  test('the saved skin is read before the first frame', () async {
    SharedPreferences.setMockInitialValues({'skin': 'shadowPaper'});
    expect(await restoreSkin(), SkinId.shadowPaper);
    expect(_start(_Loader()).read(skinChoiceProvider), SkinId.shadowPaper);
  });

  test('a skin since removed falls back to the default', () async {
    SharedPreferences.setMockInitialValues({'skin': 'nightPrint'});
    expect(await restoreSkin(), SkinId.fallback);
  });

  test('a choice is saved only once its art is ready', () async {
    final loader = _Loader()..gate = Completer<void>();
    final choosing = _start(
      loader,
    ).read(skinChoiceProvider.notifier).choose(SkinId.shadowPaper);
    await Future<void>.delayed(Duration.zero);
    expect(loader.prepared, [SkinId.shadowPaper.skin]);
    expect(await _saved(), isNull);

    loader.gate!.complete();
    await choosing;
    expect(await _saved(), 'shadowPaper');
  });

  test('storage that fails costs the preference, not the app', () async {
    final broken = DevicePreferences(
      open: () async => throw PlatformException(code: 'locked'),
    );
    expect(await broken.readSkin(), isNull);
    await broken.saveSkin('shadowPaper');
    expect(await restoreSkin(preferences: broken), SkinId.fallback);
  });

  test('a skin is swapped whole, never blended', () {
    final a = SkinId.shadowPaper.skin;
    final b = a.copyWith(dimmed: a.dimmed / 2);
    expect(a.lerp(b, 0.5), same(a));
    expect(a.lerp(b, 0.99), same(a));
    expect(a.lerp(b, 1), same(b));
  });
}
