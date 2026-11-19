import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/storage/device_preferences.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/skin/skin_choice.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:mocktail/mocktail.dart';

class _BrokenStorage extends Mock implements FlutterSecureStorage {}

/// A fresh app start on a device whose storage holds [saved].
ProviderContainer _start() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}

/// Lets the saved choice be read.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('a new device starts in Shadow paper', () async {
    final app = _start();
    expect(app.read(skinChoiceProvider), SkinId.shadowPaper);
    await _settle();
    expect(app.read(skinChoiceProvider), SkinId.shadowPaper);
  });

  test('the choice survives a restart', () async {
    await _start().read(skinChoiceProvider.notifier).choose(SkinId.nightPrint);

    final restarted = _start();
    restarted.read(skinChoiceProvider);
    await _settle();

    expect(restarted.read(skinChoiceProvider), SkinId.nightPrint);
  });

  test('the app theme follows the choice', () async {
    final app = _start();
    expect(
      app.read(appThemeProvider).extension<Skin>(),
      same(SkinId.shadowPaper.skin),
    );
    await app.read(skinChoiceProvider.notifier).choose(SkinId.nightPrint);
    expect(
      app.read(appThemeProvider).extension<Skin>(),
      same(SkinId.nightPrint.skin),
    );
  });

  test('a choice made before the saved one is read wins', () async {
    FlutterSecureStorage.setMockInitialValues({'skin': 'nightPrint'});
    final app = _start();
    app.read(skinChoiceProvider);
    await app.read(skinChoiceProvider.notifier).choose(SkinId.shadowPaper);
    await _settle();
    expect(app.read(skinChoiceProvider), SkinId.shadowPaper);
  });

  test('an unknown saved skin is ignored', () async {
    FlutterSecureStorage.setMockInitialValues({'skin': 'firelitGothic'});
    final app = _start();
    app.read(skinChoiceProvider);
    await _settle();
    expect(app.read(skinChoiceProvider), SkinId.shadowPaper);
  });

  test('storage that fails costs the preference, not the app', () async {
    final broken = _BrokenStorage();
    when(
      () => broken.read(key: any(named: 'key')),
    ).thenThrow(Exception('keychain locked'));
    when(
      () => broken.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenThrow(Exception('keychain locked'));
    final app = ProviderContainer(
      overrides: [
        devicePreferencesProvider.overrideWithValue(
          DevicePreferences(storage: broken),
        ),
      ],
    );
    addTearDown(app.dispose);

    app.read(skinChoiceProvider);
    await _settle();
    expect(app.read(skinChoiceProvider), SkinId.shadowPaper);

    await app.read(skinChoiceProvider.notifier).choose(SkinId.nightPrint);
    expect(app.read(skinChoiceProvider), SkinId.nightPrint);
  });
}
