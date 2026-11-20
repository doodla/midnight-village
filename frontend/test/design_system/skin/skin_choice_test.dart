import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:midnight_village/app.dart';
import 'package:midnight_village/core/router/app_router.dart';
import 'package:midnight_village/core/storage/device_preferences.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/skin/skin_choice.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A loader that records what it was asked to load and finishes when told.
class _Loader extends SkinLoader {
  _Loader() : super(loadFamily: (_, _) async {});

  final prepared = <Skin>[];
  final fontsLoaded = <Skin>[];
  Completer<void>? gate;

  @override
  Future<void> loadFonts(Skin skin) async => fontsLoaded.add(skin);

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

/// main(): reads the saved skin before the first frame.
Future<SkinId> _launch(_Loader loader) =>
    restoreSkin(preferences: DevicePreferences(), loader: loader);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    forgetRestoredSkin();
  });

  test('a new device starts in the default skin', () async {
    final loader = _Loader();
    expect(await _launch(loader), SkinId.fallback);
    expect(_start(loader).read(skinChoiceProvider), SkinId.fallback);
  });

  test('the saved skin is read, and its faces loaded, before the first '
      'frame', () async {
    SharedPreferences.setMockInitialValues({'skin': 'nightPrint'});
    final loader = _Loader();
    expect(await _launch(loader), SkinId.nightPrint);
    expect(loader.fontsLoaded, [SkinId.nightPrint.skin]);
    // The app's first build is already in it: nothing to wait for.
    expect(_start(loader).read(skinChoiceProvider), SkinId.nightPrint);
  });

  test('the choice survives a restart', () async {
    final loader = _Loader();
    await _start(
      loader,
    ).read(skinChoiceProvider.notifier).choose(SkinId.nightPrint);
    forgetRestoredSkin();
    expect(await _launch(_Loader()), SkinId.nightPrint);
  });

  test('a skin is switched to only once it is ready', () async {
    final loader = _Loader()..gate = Completer<void>();
    final app = _start(loader);
    final choosing = app
        .read(skinChoiceProvider.notifier)
        .choose(SkinId.nightPrint);
    await Future<void>.delayed(Duration.zero);
    expect(loader.prepared, [SkinId.nightPrint.skin]);
    expect(app.read(skinChoiceProvider), SkinId.fallback);

    loader.gate!.complete();
    await choosing;
    expect(app.read(skinChoiceProvider), SkinId.nightPrint);
    expect(
      app.read(appThemeProvider).extension<Skin>(),
      same(SkinId.nightPrint.skin),
    );
  });

  test('when choices overlap the last one made wins', () async {
    final loader = _Loader()..gate = Completer<void>();
    final app = _start(loader);
    final notifier = app.read(skinChoiceProvider.notifier);
    final first = notifier.choose(SkinId.nightPrint);
    final second = notifier.choose(SkinId.shadowPaper);
    loader.gate!.complete();
    await Future.wait([first, second]);
    expect(app.read(skinChoiceProvider), SkinId.shadowPaper);
  });

  test('an unknown saved skin is ignored', () async {
    SharedPreferences.setMockInitialValues({'skin': 'firelitGothic'});
    expect(await _launch(_Loader()), SkinId.fallback);
  });

  test('storage that fails costs the preference, not the app', () async {
    final broken = DevicePreferences(
      open: () async => throw PlatformException(code: 'locked'),
    );
    expect(await broken.readSkin(), isNull);
    await broken.saveSkin('nightPrint');
    expect(
      await restoreSkin(preferences: broken, loader: _Loader()),
      SkinId.fallback,
    );
  });

  group('the loader', () {
    test('loads each on-demand family once, and nothing for the default '
        'skin', () async {
      final asked = <String>[];
      final loader = SkinLoader(
        loadFamily: (family, files) async {
          asked.add(family);
          await Future.wait(files);
        },
      );
      await loader.loadFonts(SkinId.fallback.skin);
      expect(asked, isEmpty);
      await loader.loadFonts(SkinId.nightPrint.skin);
      await loader.loadFonts(SkinId.nightPrint.skin);
      expect(asked, SkinId.nightPrint.skin.fonts.onDemand.keys.toList());
    });
  });

  group('the switch is whole', () {
    test('a skin is never blended with another', () {
      final [a, b] = [SkinId.shadowPaper.skin, SkinId.nightPrint.skin];
      expect(a.lerp(b, 0.5), same(a));
      expect(a.lerp(b, 0.99), same(a));
      expect(a.lerp(b, 1), same(b));
    });

    testWidgets('the frame after the switch is all in the new skin', (
      tester,
    ) async {
      late BuildContext page;
      final loader = _Loader();
      final container = ProviderContainer(
        overrides: [
          skinLoaderProvider.overrideWithValue(loader),
          appRouterProvider.overrideWithValue(
            GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, _) => Builder(
                    builder: (context) {
                      page = context;
                      return const SizedBox();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const App()),
      );
      await tester.pumpAndSettle();

      await container
          .read(skinChoiceProvider.notifier)
          .choose(SkinId.nightPrint);
      await tester.pump();
      final theme = Theme.of(page);
      final next = SkinId.nightPrint.skin;
      expect(theme.extension<Skin>(), same(next));
      expect(theme.colorScheme.surface, next.night.ground);
      expect(
        theme.textTheme.bodyMedium!.fontFamily,
        next.typography.body.fontFamily,
      );
    });
  });
}
